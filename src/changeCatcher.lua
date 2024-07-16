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

	for _, instance in selection do
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

		changeDeduplicator.setProp("scaling", part, "CFrame", parent.CFrame * newRelativeCFrame)
	end
end

local function updateCFrame(part: BasePart, previousCFrame: CFrame): boolean
	local realPart = selectionHelper.getRealInstance(part) :: BasePart

	if not mathUtil.cframeFuzzyEq(previousCFrame, part.CFrame) then
		local deltaCFrame = previousCFrame:ToObjectSpace(part.CFrame)
		if part ~= realPart or realTransform.hasTransform(realPart) then
			scaling.cframeRecursive(realPart, deltaCFrame, true, true)
		end
		return true
	end

	return false
end

local function updateSize(part: BasePart, previousSize: Vector3, repeatUpdates: { BasePart }): boolean
	local realPart = selectionHelper.getRealInstance(part) :: BasePart

	if realPart ~= part then
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
	elseif not part.Size:FuzzyEq(previousSize, mathUtil.epsilon) then
		local scalar = part.Size / previousSize
		scaling.scaleAttributeTransformsRecursive(realPart, scalar)
		return true
	end

	return false
end

function changeCatcher.finishCatching()
	-- Fix any non-orthagonal rotations
	for _, part in rotationCatching do
		orthonormalizePart(part)
	end

	local repeatUpdates = {}
	local checkParents = {}

	local didUpdateSize = false
	for part, previousSize in initialProps.sizes do
		didUpdateSize = updateSize(part, previousSize, repeatUpdates)
		local realPart = selectionHelper.getRealInstance(part) :: BasePart

		if didUpdateSize and realPart ~= part then
			if containerHelper.isValidContained(realPart) then
				if repeatSettings.doesHaveAnyRepeatSettings(realPart) then
					table.insert(repeatUpdates, realPart)
				else
					table.insert(checkParents, realPart)
				end
			end
		end
	end

	if not didUpdateSize then
		for part, previousCFrame in initialProps.cframes do
			local didUpdateCFrame = updateCFrame(part, previousCFrame)
			if didUpdateCFrame then
				local realPart = selectionHelper.getRealInstance(part) :: BasePart
				if repeatSettings.doesHaveAnyRepeatSettings(realPart) then
					table.insert(repeatUpdates, realPart)
				else
					table.insert(checkParents, realPart)
				end
			end
		end
	end

	if #repeatUpdates > 0 then
		local pendingRepeatUpdateSet = {}
		for _, part in repeatUpdates do
			pendingRepeatUpdateSet[part] = true
		end

		for _, part in repeatUpdates do
			repeating.updateRepeat(part, pendingRepeatUpdateSet)
		end
	elseif #checkParents > 0 then
		local repeatUpdateSet = {}
		for _, part in checkParents do
			repeating.updateParentRecursive(part, repeatUpdateSet)
		end
	end

	isCatching = false
end

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
			print("-------- CHANGE --------")
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

			local sizeSettingGroup = sizeSettings.getSettingGroup(realInstance)
			if isCatching and not (sizeSettingGroup and sizeSettingGroup.updateContinuous) then
				return
			end

			if containerHelper.isValidContained(realInstance) then
				orthonormalizePart(changedInstance)
			end

			local repeatUpdates = {}

			local didUpdateSize, didUpdateCFrame = false, false
			if initialProps.sizes[changedInstance] then
				didUpdateSize = updateSize(changedInstance, initialProps.sizes[changedInstance], repeatUpdates)

				if didUpdateSize then
					initialProps.sizes[changedInstance] = changedInstance.Size
					initialProps.cframes[changedInstance] = changedInstance.CFrame
				end

				if realInstance == changedInstance then
					return
				end
			end

			if not didUpdateSize then
				if initialProps.cframes[changedInstance] then
					didUpdateCFrame = updateCFrame(changedInstance, initialProps.cframes[changedInstance])
					initialProps.cframes[changedInstance] = changedInstance.CFrame
				end
			end

			if
				(didUpdateSize or didUpdateCFrame)
				and containerHelper.isValidContained(realInstance)
				and repeatSettings.doesHaveAnyRepeatSettings(realInstance)
			then
				table.insert(repeatUpdates, realInstance)
			end

			if #repeatUpdates > 0 then
				local pendingRepeatUpdateSet = {}
				for _, part in repeatUpdates do
					pendingRepeatUpdateSet[part] = true
				end

				for _, part in repeatUpdates do
					repeating.updateRepeat(part, pendingRepeatUpdateSet)
				end
			else
				local repeatUpdateSet = {}
				repeating.updateParentRecursive(realInstance, repeatUpdateSet)
			end
		end
	)

	return janitor
end

return changeCatcher
