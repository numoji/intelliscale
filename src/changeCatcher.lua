--!strict
local Janitor = require(script.Parent.Parent.Packages.Janitor)

local changeDeduplicator = require(script.Parent.utility.changeDeduplicator)
local changeHistoryHelper = require(script.Parent.utility.changeHistoryHelper)
local containerHelper = require(script.Parent.utility.containerHelper)
local mathUtil = require(script.Parent.utility.mathUtil)
local realTransform = require(script.Parent.utility.realTransform)
local repeatSettings = require(script.Parent.utility.settingsHelper.repeatSettings)
local repeating = require(script.Parent.repeating)
local scaling = require(script.Parent.scaling)
local selectionHelper = require(script.Parent.utility.selectionHelper)
local sizeSettings = require(script.Parent.utility.settingsHelper.sizeSettings)
local studioHandlesStalker = require(script.Parent.utility.studioHandlesStalker)
local types = require(script.Parent.types)
local changeCatcher = {}

local janitor = Janitor.new()

type InitialProps = {
	cframes: { [BasePart]: CFrame },
	sizes: { [BasePart]: Vector3 },
}

local initialProps: InitialProps
local rotationCatching: { BasePart }

local isCatching = false

local function cacheSelectionInitialProps(selection: { Instance })
	initialProps = {
		cframes = {},
		sizes = {},
	}
	rotationCatching = {}

	for _, instance in pairs(selection) do
		local realInstance = selectionHelper.getRealInstance(instance)

		if containerHelper.isValidContainedOrContainer(realInstance) and realInstance:IsA("BasePart") and instance:IsA("BasePart") then
			if containerHelper.isValidContained(realInstance) then
				-- We only need to catch non-orthagonal rotations if the part is
				-- inside a container
				table.insert(rotationCatching, instance)
			end

			if instance ~= realInstance or repeatSettings.doesHaveAnyRepeatSettings(realInstance) then
				initialProps.cframes[instance] = instance.CFrame
				initialProps.sizes[instance] = instance.Size
				continue
			end

			-- If part has any children, we'll want to trigger an update if its
			-- resized.
			if realInstance:FindFirstChildWhichIsA("BasePart") then
				initialProps.sizes[instance] = instance.Size
			end
		end
	end
end

function changeCatcher.startCatching()
	isCatching = true
	local _selection, fauxSelection = selectionHelper.getUnvalidatedSelection()
	cacheSelectionInitialProps(fauxSelection)
end

local function orthonormalizeVector(vector: Vector3)
	local x, y, z = math.abs(vector.X), math.abs(vector.Y), math.abs(vector.Z)

	if x > y and x > z then
		x = math.sign(vector.X)
		y = 0
		z = 0
	elseif y > x and y > z then
		x = 0
		y = math.sign(vector.Y)
		z = 0
	else
		x = 0
		y = 0
		z = math.sign(vector.Z)
	end

	return Vector3.new(x, y, z)
end

local function orthonormalizePart(part: BasePart)
	local realPart = selectionHelper.getRealInstance(part) :: BasePart
	local parent = realPart.Parent :: BasePart
	local xDot = math.abs(parent.CFrame.XVector:Dot(part.CFrame.XVector))
	local yDot = math.abs(parent.CFrame.YVector:Dot(part.CFrame.YVector))
	local zDot = math.abs(parent.CFrame.ZVector:Dot(part.CFrame.ZVector))

	local isXOrth = mathUtil.fuzzyEq(xDot, 1) or mathUtil.fuzzyEq(xDot, 0)
	local isYOrth = mathUtil.fuzzyEq(yDot, 1) or mathUtil.fuzzyEq(yDot, 0)
	local isZOrth = mathUtil.fuzzyEq(zDot, 1) or mathUtil.fuzzyEq(zDot, 0)

	if not isXOrth or not isYOrth or not isZOrth then
		local relativeCFrame = parent.CFrame:ToObjectSpace(part.CFrame)
		local newRelativeCFrame = CFrame.lookAlong(
			relativeCFrame.Position,
			orthonormalizeVector(-relativeCFrame.ZVector),
			orthonormalizeVector(relativeCFrame.YVector)
		)

		part.CFrame = parent.CFrame * newRelativeCFrame
	end
end

local function updateCFrame(part: BasePart, previousCFrame: CFrame): boolean
	local realPart = selectionHelper.getRealInstance(part) :: BasePart

	if not mathUtil.cframeFuzzyEq(previousCFrame, part.CFrame) then
		local deltaCFrame = previousCFrame:ToObjectSpace(part.CFrame)
		if part ~= realPart or realTransform.hasTransform(realPart) then
			scaling.cframeRecursive(realPart, deltaCFrame, true, true)
		elseif repeating.isFolderUnselected(realPart) then
			scaling.updateChildrenCFrames(repeating.getFolder(realPart), part.CFrame, previousCFrame)
		end
		return true
	end

	return false
end

local function updateSize(part: BasePart, previousSize: Vector3, repeatUpdates: { BasePart }): boolean
	local realPart = selectionHelper.getRealInstance(part) :: BasePart

	local axes: { types.AxisString } = {}
	if not mathUtil.fuzzyEq(previousSize.X, part.Size.X) then
		table.insert(axes, "x")
	end
	if not mathUtil.fuzzyEq(previousSize.Y, part.Size.Y) then
		table.insert(axes, "y")
	end
	if not mathUtil.fuzzyEq(previousSize.Z, part.Size.Z) then
		table.insert(axes, "z")
	end

	if #axes > 0 then
		local newParentSize = part.Size
		local newParentCFrame = part.CFrame

		scaling.moveAndScaleChildrenRecursive(realPart, newParentSize, newParentCFrame, axes, repeatUpdates, true)
		return true
	end

	return false
end

function changeCatcher.finishCatching()
	-- Fix any non-orthagonal rotations
	for _, part in rotationCatching do
		orthonormalizePart(part)
	end

	local deferredRepeatingUpdates = {}

	for part, previousCFrame in initialProps.cframes do
		local didUpdate = updateCFrame(part, previousCFrame)
		if didUpdate then
			local realPart = selectionHelper.getRealInstance(part) :: BasePart
			table.insert(deferredRepeatingUpdates, realPart)
		end
	end

	for part, previousSize in initialProps.sizes do
		updateSize(part, previousSize, deferredRepeatingUpdates)
	end

	for _, part in deferredRepeatingUpdates do
		if containerHelper.isValidContained(part) then
			repeating.updateRepeat(part)
		end
	end
	isCatching = false
end

local fauxPartChangedTo = {}

function changeCatcher.initialize(plugin: Plugin)
	studioHandlesStalker.handlesPressed:Connect(function()
		changeHistoryHelper.startAppendingAfterNextCommit()
		changeCatcher.startCatching()
	end)

	studioHandlesStalker.handlesReleased:Connect(function()
		changeHistoryHelper.recordUndoChange(function()
			changeCatcher.finishCatching()
		end)

		changeHistoryHelper.stopAppending()
	end)

	selectionHelper.addSelectionChangeCallback(selectionHelper.callbackDicts.containerOrContained, function(_, fauxSelection)
		if isCatching then
			return
		end

		cacheSelectionInitialProps(fauxSelection)
	end, function()
		initialProps = {
			cframes = {},
			sizes = {},
		}
		rotationCatching = {}
	end)

	selectionHelper.addPropertyChangeCallback(
		selectionHelper.callbackDicts.containerOrContained,
		{ "CFrame", "Size" },
		function(changedInstance, selection, fauxSelection, fromString: any)
			local realInstance = selectionHelper.getRealInstance(changedInstance)
			if not (changedInstance:IsA("BasePart") and realInstance:IsA("BasePart")) then
				return
			end

			if selectionHelper.fauxPartByPart[changedInstance] then
				local fauxPart = selectionHelper.fauxPartByPart[changedInstance]
				local realSize, realCFrame = realTransform.getSizeAndGlobalCFrame(changedInstance)

				if fauxPart.Size ~= realSize or fauxPart.CFrame ~= realCFrame then
					changeDeduplicator.setProp("scaling", fauxPart, "Size", realSize)
					changeDeduplicator.setProp("scaling", fauxPart, "CFrame", realCFrame)
				end
			end

			if not changeDeduplicator.isChanged("scaling", changedInstance) then
				return
			end

			local sizeSettingGroup = sizeSettings.getSettingGroup(changedInstance)
			if isCatching and not (sizeSettingGroup and sizeSettingGroup.updateContinuous) then
				return
			end

			if containerHelper.isValidContained(changedInstance) then
				orthonormalizePart(changedInstance)
			end

			local repeatUpdates = {}

			if initialProps.sizes[changedInstance] then
				local didUpdateSize = updateSize(changedInstance, initialProps.sizes[changedInstance], repeatUpdates)

				if didUpdateSize then
					initialProps.sizes[changedInstance] = changedInstance.Size
					initialProps.cframes[changedInstance] = changedInstance.CFrame
					fauxPartChangedTo[changedInstance] = nil
					table.insert(repeatUpdates, realInstance)
				end
			end

			if initialProps.cframes[changedInstance] then
				local didUpdateCFrame = updateCFrame(changedInstance, initialProps.cframes[changedInstance])
				if didUpdateCFrame then
					fauxPartChangedTo[changedInstance] = nil
					table.insert(repeatUpdates, realInstance)
				end

				initialProps.cframes[changedInstance] = changedInstance.CFrame
			end

			for _, part in repeatUpdates do
				if containerHelper.isValidContained(part) then
					repeating.updateRepeat(part)
				end
			end
		end
	)

	return janitor
end

return changeCatcher
