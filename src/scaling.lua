--!strict
local CoreGui = game:GetService("CoreGui")
local Selection = game:GetService("Selection")

local geometryHelper = require(script.Parent.geometryHelper)
local scaling = {}

-- Create handles
-- Respond to handle drag events

local selectionChangedConnection
local scalingHandles

local function getDeltaMovementInAxis(axis: Vector3, newContainerCFrame: CFrame, newContainerSize: Vector3, partToScale: BasePart)
	local currentParentFacePosition = geometryHelper.getFacePosition(partToScale.Parent :: BasePart, axis)
	local newParentFacePosition = geometryHelper.getFacePositionFromSizeAndCFrame(newContainerSize, newContainerCFrame, axis)

	local offset = newParentFacePosition - currentParentFacePosition
	local delta = offset:Dot(axis)

	return delta
end

local function getLocalSpaceFaceComponent(axisEnum: Enum.Axis, sign: number, part: BasePart): number
	local parent = part.Parent :: BasePart
	local axis = geometryHelper.getCFrameAxis(parent.CFrame, axisEnum) * sign
	local localSpaceFacePosition = parent.CFrame:VectorToObjectSpace(geometryHelper.getFacePosition(part, axis))
	return geometryHelper.getPositionComponent(axisEnum, localSpaceFacePosition)
end

type ScaleFunctionsMap = {
	[string]: (
		axisEnum: Enum.Axis,
		newContainerCFrame: CFrame,
		newContainerSize: Vector3,
		partToScale: BasePart
	) -> (number, number),
}
local scaleFunctionsMap: ScaleFunctionsMap = {
	Min = function(axisEnum: Enum.Axis, newContainerCFrame: CFrame, newContainerSize: Vector3, partToScale: BasePart)
		local axis = -geometryHelper.getCFrameAxis(newContainerCFrame, axisEnum)
		return -getDeltaMovementInAxis(axis, newContainerCFrame, newContainerSize, partToScale), 0
	end,
	Max = function(axisEnum: Enum.Axis, newContainerCFrame: CFrame, newContainerSize: Vector3, partToScale: BasePart)
		local axis = geometryHelper.getCFrameAxis(newContainerCFrame, axisEnum)
		return getDeltaMovementInAxis(axis, newContainerCFrame, newContainerSize, partToScale), 0
	end,
	MinMax = function(axisEnum: Enum.Axis, newContainerCFrame: CFrame, newContainerSize: Vector3, partToScale: BasePart)
		local positiveAxis = geometryHelper.getCFrameAxis(newContainerCFrame, axisEnum)
		local negativeAxis = -positiveAxis

		local currentMax = getLocalSpaceFaceComponent(axisEnum, 1, partToScale)
		local currentMin = getLocalSpaceFaceComponent(axisEnum, -1, partToScale)

		local newPartMax = currentMax + getDeltaMovementInAxis(positiveAxis, newContainerCFrame, newContainerSize, partToScale)
		local newPartMin = currentMin - getDeltaMovementInAxis(negativeAxis, newContainerCFrame, newContainerSize, partToScale)
	end,
	Center = function(axisEnum: Enum.Axis, newContainerCFrame: CFrame, newContainerSize: Vector3, partToScale: BasePart) end,
	Scale = function(axisEnum: Enum.Axis, newContainerCFrame: CFrame, newContainerSize: Vector3, partToScale: BasePart) end,
}

scaling.initializePluginActions = function(plugin)
	scalingHandles = Instance.new("Handles")
	scalingHandles.Color3 = Color3.fromHex("#f69fd6")
	scalingHandles.Style = Enum.HandlesStyle.Resize
	scalingHandles.Visible = false
	scalingHandles.Parent = CoreGui
	scalingHandles.Transparency = 0.5

	local mouse = plugin:GetMouse()

	local toggleHandlesAction =
		plugin:CreatePluginAction("IntelliscaleToggleHandles", "Intelliscale: Toggle handles", "Toggles intelliscale scaling handles")

	toggleHandlesAction.Triggered:Connect(function()
		scalingHandles.Visible = not scalingHandles.Visible
	end)

	Selection.SelectionChanged:Connect(function()
		local selection = Selection:Get()

		if #selection == 0 then
			scalingHandles.Adornee = nil
			return
		end

		local part = selection[1]
		if part:IsA("BasePart") and part:GetAttribute("isContainer") then
			scalingHandles.Adornee = part
		end
	end)

	local selectContainerAction = plugin:CreatePluginAction(
		"intelliscaleSelectContainer",
		"Intelliscale: Select Contatiner",
		"Selects intelliscale container selected part is in"
	)

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

	scalingHandles.MouseButton1Down:Connect(function()
		isMouseDown = true
		mouse.Icon = "rbxasset://SystemCursors/ClosedHand"
	end)

	scalingHandles.MouseButton1Up:Connect(function()
		isMouseDown = false
		mouse.Icon = enterIcon
	end)

	scalingHandles.MouseDrag:Connect(function(face: Enum.NormalId, distance: number) end)

	selectContainerAction.Triggered:Connect(function()
		local selection = Selection:Get()

		if #selection == 0 then
			return
		end

		local newSelection = {}
		for _, instance in selection do
			if instance:IsA("BasePart") and instance.Parent:IsA("BasePart") and instance.Parent:GetAttribute("isContainer") then
				table.insert(newSelection, instance.Parent)
			end
		end

		Selection:Set(newSelection)
	end)
end

scaling.cleanup = function()
	if selectionChangedConnection then
		selectionChangedConnection:Disconnect()
		selectionChangedConnection = nil
	end

	if scalingHandles then
		scalingHandles:Destroy()
		scalingHandles = nil
	end
end

return scaling
