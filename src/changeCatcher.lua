--!strict
local packages = script.Parent.Parent.Packages
local Janitor = require(packages.Janitor)

local source = script.Parent
local changeHistoryHelper = require(source.utility.changeHistoryHelper)
local mathUtil = require(source.utility.mathUtil)
local repeating = require(source.repeating)
local scaling = require(source.scaling)
local selectionHelper = require(source.utility.selectionHelper)
local studioHandlesStalker = require(source.utility.studioHandlesStalker)
local types = require(source.types)
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
		if selectionHelper.isValidContainedOrContainer(realInstance) and realInstance:IsA("BasePart") and instance:IsA("BasePart") then
			if selectionHelper.isValidContained(realInstance) then
				-- We only need to catch non-orthagonal rotations if the part is
				-- inside a container
				table.insert(rotationCatching, instance)

				-- If part has any repeat settings, its at least dependent on
				-- rotation and size changes to update the repeats. If it uses
				-- extents settings, we'll want to check for position changes as well.
				if repeating.doesPartHaveAnyRepeatSettings(realInstance) then
					initialProps.cframes[instance] = instance.CFrame
					initialProps.sizes[instance] = instance.Size
					continue
				end
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
		if part ~= realPart then
			local deltaCFrame = previousCFrame:ToObjectSpace(part.CFrame)
			scaling.cframeChildrenRecursive(realPart, deltaCFrame, true, true)
		end
		return true
	end

	return false
end

local function updateSize(part: BasePart, previousSize: Vector3, repeatUpdates: { BasePart })
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
	end
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
		repeating.updateRepeat(part)
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

	selectionHelper.bindToEitherSelection(function(selection, fauxSelection)
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

	selectionHelper.bindToAnyEitherChanged(function(changedInstance, selection, fauxSelection)
		if isCatching then
			return
		end

		if not changedInstance:IsA("BasePart") then
			return
		end

		if selectionHelper.isValidContained(changedInstance) then
			orthonormalizePart(changedInstance)
		end

		local repeatUpdates = {}

		if initialProps.sizes[changedInstance] then
			updateSize(changedInstance, initialProps.sizes[changedInstance], repeatUpdates)
		end

		if initialProps.cframes[changedInstance] then
			local didUpdateCFrame = updateCFrame(changedInstance, initialProps.cframes[changedInstance])
			if didUpdateCFrame then
				local realPart = selectionHelper.getRealInstance(changedInstance) :: BasePart
				table.insert(repeatUpdates, realPart)
			end
		end

		for _, part in repeatUpdates do
			repeating.updateRepeat(part)
		end
	end)

	return janitor
end

return changeCatcher