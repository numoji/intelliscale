--!strict
local CoreGui = game:GetService("CoreGui")
local Selection = game:GetService("Selection")
local packages = script.Parent.Parent.Packages
local Janitor = require(packages.Janitor)

local epsilon = 1e-5

local source = script.Parent
local changeHistoryHelper = require(source.utility.changeHistoryHelper)
local geometryHelper = require(source.utility.geometryHelper)
local repeating = require(source.repeating)
local round = require(source.utility.round)
local types = require(source.types)

local janitor = Janitor.new()
local scaling = {}

local function getDeltaMovementInAxis(axis: Vector3, newContainerCFrame: CFrame, newContainerSize: Vector3, partToScale: BasePart): number
	local currentParentFacePosition = geometryHelper.getFacePosition(partToScale.Parent :: BasePart, axis)
	local newParentFacePosition = geometryHelper.getFacePositionFromSizeAndCFrame(newContainerSize, newContainerCFrame, axis)

	local offset = newParentFacePosition - currentParentFacePosition
	local delta = offset:Dot(axis)

	return delta
end

local function getLocalSpaceFaceComponent(axisEnum: Enum.Axis, sign: number, part: BasePart): number
	local parent = part.Parent :: BasePart
	local axis = geometryHelper.getCFrameAxis(parent.CFrame, axisEnum) * sign
	local localSpaceFacePosition = parent.CFrame:PointToObjectSpace(geometryHelper.getFacePosition(part, axis))
	return geometryHelper.getComponent(axisEnum, localSpaceFacePosition)
end

type ScaleFunctionsMap = {
	[string]: (
		axisEnum: Enum.Axis,
		newContainerCFrame: CFrame,
		newContainerSize: Vector3,
		partToScale: BasePart
	) -> (Vector3, Vector3),
}
local scaleFunctionsMap: ScaleFunctionsMap = {
	Min = function(axisEnum: Enum.Axis, newContainerCFrame: CFrame, newContainerSize: Vector3, partToScale: BasePart)
		local axis = -geometryHelper.getCFrameAxis(newContainerCFrame, axisEnum)
		local deltaMovement = getDeltaMovementInAxis(axis, newContainerCFrame, newContainerSize, partToScale)

		return axis * deltaMovement, Vector3.zero
	end,
	Max = function(axisEnum: Enum.Axis, newContainerCFrame: CFrame, newContainerSize: Vector3, partToScale: BasePart)
		local axis = geometryHelper.getCFrameAxis(newContainerCFrame, axisEnum)
		local deltaMovement = getDeltaMovementInAxis(axis, newContainerCFrame, newContainerSize, partToScale)

		return axis * deltaMovement, Vector3.zero
	end,
	MinMax = function(axisEnum: Enum.Axis, newContainerCFrame: CFrame, newContainerSize: Vector3, partToScale: BasePart)
		local positiveAxis = geometryHelper.getCFrameAxis(newContainerCFrame, axisEnum)
		local negativeAxis = -positiveAxis

		local currentMax = getLocalSpaceFaceComponent(axisEnum, 1, partToScale)
		local currentMin = getLocalSpaceFaceComponent(axisEnum, -1, partToScale)
		local currentCenter = (currentMax + currentMin) / 2
		local currentSize = currentMax - currentMin

		local newPartMax = currentMax + getDeltaMovementInAxis(positiveAxis, newContainerCFrame, newContainerSize, partToScale)
		local newPartMin = currentMin - getDeltaMovementInAxis(negativeAxis, newContainerCFrame, newContainerSize, partToScale)
		local newPartCenter = (newPartMax + newPartMin) / 2
		local newPartSize = newPartMax - newPartMin

		local partAxis = geometryHelper.getCFrameAxis(partToScale.CFrame, axisEnum)
		return positiveAxis * (newPartCenter - currentCenter), partAxis * (newPartSize - currentSize)
	end,
	Center = function(axisEnum: Enum.Axis, newContainerCFrame: CFrame, _newContainerSize: Vector3, partToScale: BasePart)
		local axis = geometryHelper.getCFrameAxis(newContainerCFrame, axisEnum)
		local container = partToScale.Parent :: BasePart

		local currentContainerCenter = container.Position
		local newContainerCenter = newContainerCFrame.Position

		local offset = newContainerCenter - currentContainerCenter

		return offset:Dot(axis) * axis, Vector3.zero
	end,
	Scale = function(axisEnum: Enum.Axis, newContainerCFrame: CFrame, newContainerSize: Vector3, partToScale: BasePart)
		local axis = geometryHelper.getCFrameAxisZPositive(newContainerCFrame, axisEnum)
		local container = partToScale.Parent :: BasePart

		local sizeChange = geometryHelper.getComponent(axisEnum, newContainerSize) / geometryHelper.getComponent(axisEnum, container.Size)

		local currentPosition = geometryHelper.getComponent(axisEnum, container.CFrame:PointToObjectSpace(partToScale.Position))
		local currentSize = partToScale.Size:Dot(axis)

		local plainAxis = geometryHelper.axisByEnum[axisEnum]
		local newGlobalPosition = (newContainerCFrame * CFrame.new(plainAxis * currentPosition * sizeChange)).Position

		local deltaPosition = newGlobalPosition - partToScale.Position

		local partAxis = geometryHelper.axisByEnum[axisEnum]
		return axis * deltaPosition:Dot(axis), partAxis * ((currentSize * sizeChange) - currentSize)
	end,
}

local function moveChildrenRecursive(deltaPosition: Vector3, part: BasePart)
	for _, child in part:GetChildren() do
		if child:IsA("BasePart") then
			moveChildrenRecursive(deltaPosition, child)
		end
	end

	part.Position += deltaPosition
end

local function scaleChildrenRecursive(
	axes: { types.AxisString },
	newSize: Vector3,
	newCFrame: CFrame,
	part: BasePart,
	changedList: { BasePart }
)
	for _, child in part:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(changedList, 1, child)
			local totalDeltaPosition = Vector3.zero
			local totalDeltaSize = Vector3.zero
			for _, axis: types.AxisString in axes do
				local constraint = child:GetAttribute(`{axis}Constraint`) or "Scale"
				local constraintType = geometryHelper.constraintMap[constraint]

				local scaleFunction = scaleFunctionsMap[constraintType]
				local axisEnum = geometryHelper.axisEnumByString[axis]
				local deltaPosition, deltaSize = scaleFunction(axisEnum, newCFrame, newSize, child)

				totalDeltaPosition += deltaPosition --geometryHelper.getCFrameAxis(newCFrame, axisEnum) * deltaPosition
				totalDeltaSize += deltaSize --geometryHelper.getCFrameAxis(child.CFrame, axisEnum) * deltaSize
			end

			if totalDeltaPosition.Magnitude < epsilon then
				totalDeltaPosition = Vector3.zero
			end

			if totalDeltaPosition == Vector3.zero and totalDeltaSize == Vector3.zero then
				continue
			elseif totalDeltaSize == Vector3.zero then
				moveChildrenRecursive(totalDeltaPosition, child)
			else
				scaleChildrenRecursive(
					axes,
					child.Size + totalDeltaSize,
					CFrame.new(child.Position + totalDeltaPosition),
					child,
					changedList
				)
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
		else
			print(newSize)
		end

		local deltaSize = newSize - currentSize
		local axis = geometryHelper.getAxisFromNormalId(face, CFrame.new())

		local newContainerSize = scalingPart.Size + axis:Abs() * deltaSize
		local newContainerCFrame = scalingPart.CFrame * CFrame.new(axis * deltaSize / 2)
		local axisName: types.AxisString = geometryHelper.axisNameByNormalIdMap[face]

		local changedList = { scalingPart }

		changeHistoryHelper.recordUndoChange(function()
			scaleChildrenRecursive({ axisName }, newContainerSize, newContainerCFrame, scalingPart, changedList)
		end)

		repeating.updateRepeatsFromSizeOrPositionChanges(changedList)

		currentSize = newSize
	end)

	janitor:Add(function()
		plugin:GetMouse().Icon = ""
	end)

	return janitor
end

function scaling.updateHandleAdornee()
	local selection = Selection:Get()

	if #selection == 0 then
		scalingHandles.Adornee = nil
		return
	end

	local part = selection[1]
	if part:IsA("BasePart") and part:GetAttribute("isContainer") then
		scalingHandles.Adornee = part
	else
		scalingHandles.Adornee = nil
	end
end

function scaling.toggleHandleVisibility()
	scalingHandles.Visible = not scalingHandles.Visible
end

return scaling
