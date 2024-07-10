--!strict
local CoreGui = game:GetService("CoreGui")
local packages = script.Parent.Parent.Packages
local Janitor = require(packages.Janitor)

local epsilon = 1e-5

local source = script.Parent
local changeHistoryHelper = require(source.utility.changeHistoryHelper)
local geometryHelper = require(source.utility.geometryHelper)
local realTransform = require(source.utility.realTransform)
local round = require(source.utility.round)
local selectionHelper = require(source.utility.selectionHelper)
local types = require(source.types)

local janitor = Janitor.new()
local scaling = {}

local partScaledWithHandlesEvent = janitor:Add(Instance.new("BindableEvent"))
scaling.partScaledWithHandles = partScaledWithHandlesEvent.Event

type ScaleFunctionsMap = {
	[types.ConstraintString]: (Enum.Axis, BasePart, Vector3) -> (CFrame, Vector3),
}

local function getDeltaPositionFromEdgeConstraint(axisEnum: Enum.Axis, partToScale: BasePart, newParentSize: Vector3): (number, Vector3)
	local axis = geometryHelper.axisByEnum[axisEnum]

	local parent = partToScale.Parent :: BasePart

	local prevParentSizeInAxis = parent.Size:Dot(axis)
	local newParentSizeInAxis = newParentSize:Dot(axis)

	return ((newParentSizeInAxis - prevParentSizeInAxis) / 2), axis
end

local scaleFunctionsMap: ScaleFunctionsMap = {
	Min = function(axisEnum, partToScale, newParentSize)
		local deltaMovement, axis = getDeltaPositionFromEdgeConstraint(axisEnum, partToScale, newParentSize)
		return CFrame.new(-deltaMovement * axis), Vector3.zero
	end,
	Max = function(axisEnum, partToScale, newParentSize)
		local deltaMovement, axis = getDeltaPositionFromEdgeConstraint(axisEnum, partToScale, newParentSize)
		return CFrame.new(deltaMovement * axis), Vector3.zero
	end,
	MinMax = function(axisEnum, partToScale, newParentSize)
		local axis = geometryHelper.axisByEnum[axisEnum]

		local positionInAxis, sizeInAxis = geometryHelper.getPositionAndSizeInParentAxis(axis, partToScale)

		local maxPartEdge = positionInAxis + sizeInAxis / 2
		local minPartEdge = positionInAxis - sizeInAxis / 2
		local partSize = maxPartEdge - minPartEdge
		local partCenter = (maxPartEdge + minPartEdge) / 2

		local edgeDeltaPosition = getDeltaPositionFromEdgeConstraint(axisEnum, partToScale, newParentSize)
		local newMaxPartEdge = maxPartEdge + edgeDeltaPosition
		local newMinPartEdge = minPartEdge - edgeDeltaPosition
		local newPartSize = newMaxPartEdge - newMinPartEdge
		local newPartCenter = (newMaxPartEdge + newMinPartEdge) / 2

		local deltaMovement = newPartCenter - partCenter
		local deltaSize = newPartSize - partSize

		return CFrame.new(deltaMovement * axis), deltaSize * axis
	end,
	Center = function()
		return CFrame.identity, Vector3.zero
	end,
	Scale = function(axisEnum, partToScale, newParentSize: Vector3)
		local axis = geometryHelper.axisByEnum[axisEnum]

		local positionInAxis, sizeInAxis = geometryHelper.getPositionAndSizeInParentAxis(axis, partToScale)

		local parent = partToScale.Parent :: BasePart
		local parentSizeScalar = newParentSize:Dot(axis) / parent.Size:Dot(axis)

		local newSize = sizeInAxis * parentSizeScalar
		local newPosition = positionInAxis * parentSizeScalar

		local deltaMovement = newPosition - positionInAxis
		local deltaSize = newSize - sizeInAxis

		return CFrame.new(deltaMovement * axis), deltaSize * axis
	end,
}

function scaling.moveChildrenRecursive(deltaPosition: Vector3, part: BasePart)
	for _, child in part:GetChildren() do
		if child:IsA("BasePart") then
			scaling.moveChildrenRecursive(deltaPosition, child)
		end
	end

	part.Position += deltaPosition
end

function scaling.cframeChildrenRecursive(
	part: BasePart,
	deltaCFrame: CFrame?,
	shouldNotMoveStretchRepeat: boolean?,
	shouldMoveRepeats: boolean?,
	newParentCFrame: CFrame?,
	parentCFrame: CFrame?
)
	local currentCFrame = part.CFrame
	local shouldUseAttribute = false
	if shouldNotMoveStretchRepeat and selectionHelper.isValidContained(part) and realTransform.hasCFrame(part) then
		currentCFrame = realTransform.getGlobalCFrame(part, parentCFrame)
		shouldUseAttribute = true
	end

	local newCFrame
	if deltaCFrame and not (parentCFrame and newParentCFrame) then
		newCFrame = currentCFrame * deltaCFrame
	else
		newCFrame = newParentCFrame * parentCFrame:ToObjectSpace(part.CFrame)
	end

	if shouldUseAttribute then
		realTransform.setGlobalCFrame(part, newCFrame, newParentCFrame)
		return
	end

	for _, child in part:GetChildren() do
		if child:IsA("BasePart") then
			scaling.cframeChildrenRecursive(child, nil, true, true, newCFrame, currentCFrame)
		elseif child:IsA("Folder") and shouldMoveRepeats then
			for _, folderChild in child:GetChildren() do
				if folderChild:IsA("BasePart") then
					scaling.cframeChildrenRecursive(folderChild, nil, true, true, newCFrame, currentCFrame)
				end
			end
		end
	end

	part.CFrame = newCFrame
end

function scaling.moveAndScaleChildrenRecursive(
	part: BasePart,
	newSize: Vector3,
	newCFrame: CFrame,
	axes: { types.AxisString },
	changedList: { BasePart },
	shouldNotResizeStretchedRepeat: boolean?,
	newParentCFrame: CFrame?
)
	if shouldNotResizeStretchedRepeat and realTransform.hasTransform(part) then
		realTransform.setSizeAndGlobalCFrame(part, newSize, newCFrame, newParentCFrame)
		return
	end

	for _, child in part:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(changedList, 1, child)
			local totalRelativeDeltaCFrame = CFrame.identity
			local totalDeltaSize = Vector3.zero
			for _, axis: types.AxisString in axes do
				local constraint = child:GetAttribute(`{axis}Constraint`) or "Scale"
				local constraintType: types.ConstraintString = geometryHelper.constraintMap[constraint]

				local scaleFunction = scaleFunctionsMap[constraintType]
				local axisEnum = geometryHelper.axisEnumByString[axis]
				local relativeDeltaCFrame, deltaSize = scaleFunction(axisEnum, child, newSize)

				totalRelativeDeltaCFrame *= relativeDeltaCFrame
				totalDeltaSize += deltaSize
			end

			if totalRelativeDeltaCFrame.Position.Magnitude < epsilon then
				totalRelativeDeltaCFrame = CFrame.identity
			end

			local size, relativeCFrame = realTransform.getSizeAndRelativeCFrame(child)
			local childCFrame = part.CFrame * relativeCFrame
			local newChildCFrame = newCFrame * totalRelativeDeltaCFrame * relativeCFrame
			local newChildSize = size + totalDeltaSize

			if totalDeltaSize == Vector3.zero then
				scaling.cframeChildrenRecursive(child, childCFrame:ToObjectSpace(newChildCFrame), true, true, newCFrame)
			else
				scaling.moveAndScaleChildrenRecursive(child, newChildSize, newChildCFrame, axes, changedList, true, newCFrame)
			end
		end
	end

	part.Size = newSize
	part.CFrame = newCFrame
end

local scalingHandles
function scaling.initializeHandles(plugin)
	scalingHandles = janitor:Add(Instance.new("Handles"))
	scalingHandles.Color3 = Color3.fromHex("#f69fd6")
	scalingHandles.Style = Enum.HandlesStyle.Resize
	scalingHandles.Visible = false
	scalingHandles.Parent = CoreGui
	scalingHandles.Transparency = 0.5
	scalingHandles.Archivable = false

	local mouse = plugin:GetMouse()

	local enterIcon = ""
	local isMouseDown = false

	scalingHandles.MouseEnter:Connect(function()
		if not isMouseDown then
			mouse.Icon = "rbxasset://SystemCursors/OpenHand"
		end
		enterIcon = "rbxasset://SystemCursors/OpenHand"
	end)

	scalingHandles.MouseLeave:Connect(function()
		if not isMouseDown then
			mouse.Icon = ""
		end
		enterIcon = ""
	end)

	local beginningSize
	local currentSize
	scalingHandles.MouseButton1Down:Connect(function(face: Enum.NormalId)
		local scalingPart = scalingHandles.Adornee :: BasePart
		beginningSize = geometryHelper.getComponent(geometryHelper.axisEnumByNormalIdMap[face], scalingPart.Size)
		currentSize = beginningSize

		isMouseDown = true
		mouse.Icon = "rbxasset://SystemCursors/ClosedHand"
		changeHistoryHelper.startAppendingAfterNextCommit()
	end)

	scalingHandles.MouseButton1Up:Connect(function()
		isMouseDown = false
		mouse.Icon = enterIcon
		changeHistoryHelper.stopAppending()
	end)

	scalingHandles.MouseDrag:Connect(function(face: Enum.NormalId, distance: number)
		local scalingPart = scalingHandles.Adornee :: BasePart

		local newSize = beginningSize + round(distance, plugin.GridSize)
		if newSize == currentSize or newSize < plugin.GridSize then
			return
		end

		local deltaSize = newSize - currentSize
		local axis = geometryHelper.getAxisFromNormalId(face, CFrame.new())

		local newParentSize = scalingPart.Size + axis:Abs() * deltaSize
		local newParentCFrame = scalingPart.CFrame * CFrame.new(axis * deltaSize / 2)
		local axisName: types.AxisString = geometryHelper.axisNameByNormalIdMap[face]

		local relativeCFrameOrSizeChangedList = { scalingPart }

		changeHistoryHelper.recordUndoChange(function()
			scaling.moveAndScaleChildrenRecursive(
				scalingPart,
				newParentSize,
				newParentCFrame,
				{ axisName },
				relativeCFrameOrSizeChangedList,
				true
			)
		end)

		partScaledWithHandlesEvent:Fire(relativeCFrameOrSizeChangedList)

		currentSize = newSize
	end)

	janitor:Add(function()
		plugin:GetMouse().Icon = ""
	end)

	janitor:Add(selectionHelper.bindToSingleContainerSelection(function(selectedPart: BasePart)
		scalingHandles.Adornee = selectedPart
	end, function()
		scalingHandles.Adornee = nil
	end))

	return janitor
end

function scaling.toggleHandleVisibility()
	scalingHandles.Visible = not scalingHandles.Visible
end

return scaling
