--!strict
local changeDeduplicator = require(script.Parent.utility.changeDeduplicator)
local constraintSettings = require(script.Parent.utility.settingsHelper.constraintSettings)
local containerHelper = require(script.Parent.utility.containerHelper)
local geometryHelper = require(script.Parent.utility.geometryHelper)
local mathUtil = require(script.Parent.utility.mathUtil)
local realTransform = require(script.Parent.utility.realTransform)
local repeatSettings = require(script.Parent.utility.settingsHelper.repeatSettings)
local types = require(script.Parent.types)

local scaling = {}

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

		local positionInAxis, sizeInAxis, relativeAxis, sign = geometryHelper.getPositionAndSizeInParentAxis(axis, partToScale)

		local maxPartEdge = positionInAxis + sizeInAxis / 2
		local minPartEdge = positionInAxis - sizeInAxis / 2
		local partSize = maxPartEdge - minPartEdge
		local partCenter = (maxPartEdge + minPartEdge) / 2

		local edgeDeltaPosition = sign * getDeltaPositionFromEdgeConstraint(axisEnum, partToScale, newParentSize)
		local newMaxPartEdge = maxPartEdge + edgeDeltaPosition
		local newMinPartEdge = minPartEdge - edgeDeltaPosition
		local newPartSize = newMaxPartEdge - newMinPartEdge
		local newPartCenter = (newMaxPartEdge + newMinPartEdge) / 2

		local deltaMovement = newPartCenter - partCenter
		local deltaSize = newPartSize - partSize

		return CFrame.new(deltaMovement * axis), deltaSize * relativeAxis
	end,
	Center = function()
		return CFrame.identity, Vector3.zero
	end,
	Scale = function(axisEnum, partToScale, newParentSize: Vector3)
		local axis = geometryHelper.axisByEnum[axisEnum]

		local positionInAxis, sizeInAxis, relativeAxis, sign = geometryHelper.getPositionAndSizeInParentAxis(axis, partToScale)

		local parent = partToScale.Parent :: BasePart
		local parentSizeScalar = math.abs(newParentSize:Dot(axis)) / math.abs(parent.Size:Dot(axis))

		local newSize = sizeInAxis * parentSizeScalar
		local newPosition = positionInAxis * parentSizeScalar

		local deltaMovement = newPosition - positionInAxis
		local deltaSize = newSize - sizeInAxis

		return CFrame.new(deltaMovement * axis), deltaSize * relativeAxis * sign
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

function scaling.scaleAttributeTransformsRecursive(instance: Instance, scalar: Vector3)
	if instance:IsA("BasePart") then
		local sizeAtt, cframeAtt = realTransform.getSizeAndRelativeCFrameAttributes(instance)
		if sizeAtt then
			realTransform.setSizeAttribute(instance, sizeAtt * scalar)
		end
		if cframeAtt then
			local newCFrame = CFrame.new(cframeAtt.Position * scalar) * cframeAtt.Rotation
			realTransform.setRelativeCFrameAttribute(instance, newCFrame)
		end
	end

	for _, child in instance:GetChildren() do
		scaling.scaleAttributeTransformsRecursive(child, scalar)
	end
end

function scaling.cframeRecursive(
	part: BasePart,
	deltaCFrame: CFrame?,
	shouldWriteToAttribute: boolean?,
	shouldMoveRepeats: boolean?,
	newParentCFrame: CFrame?,
	parentCFrame: CFrame?
)
	local currentCFrame = part.CFrame
	local shouldSetAttributeOnly = false
	if shouldWriteToAttribute and containerHelper.isValidContained(part) and realTransform.hasCFrame(part) then
		currentCFrame = realTransform.getGlobalCFrame(part, parentCFrame)

		local axes: { types.AxisString } = {}
		if deltaCFrame and mathUtil.fuzzyEq(deltaCFrame.Position.X, 0) then
			table.insert(axes, "x")
		end
		if deltaCFrame and mathUtil.fuzzyEq(deltaCFrame.Position.Y, 0) then
			table.insert(axes, "y")
		end
		if deltaCFrame and mathUtil.fuzzyEq(deltaCFrame.Position.Z, 0) then
			table.insert(axes, "z")
		end

		for _, axis: types.AxisString in axes do
			if shouldWriteToAttribute and repeatSettings.doesHaveStretchSettingsInAxis(part, axis) then
				shouldSetAttributeOnly = true
				continue
			end
		end
	end

	local newCFrame
	if deltaCFrame and not (parentCFrame and newParentCFrame) then
		newCFrame = currentCFrame * deltaCFrame
	else
		newCFrame = newParentCFrame * parentCFrame:ToObjectSpace(part.CFrame)
	end

	if shouldSetAttributeOnly then
		realTransform.setGlobalCFrame(part, newCFrame, newParentCFrame)
		return
	end

	for _, child in part:GetChildren() do
		if child:IsA("BasePart") then
			scaling.cframeRecursive(child, nil, false, true, newCFrame, currentCFrame)
		elseif child:IsA("Model") then
			local newModelCFrame = newCFrame * currentCFrame:ToObjectSpace(child.WorldPivot)
			child:PivotTo(newModelCFrame)
		elseif child:IsA("Folder") and shouldMoveRepeats then
			for _, folderChild in child:GetChildren() do
				if folderChild:IsA("BasePart") then
					scaling.cframeRecursive(folderChild, nil, false, true, newCFrame, currentCFrame)
				elseif folderChild:IsA("Model") then
					local newModelCFrame = newCFrame * currentCFrame:ToObjectSpace(folderChild.WorldPivot)
					folderChild:PivotTo(newModelCFrame)
				end
			end
		end
	end

	changeDeduplicator.setProp("scaling", part, "CFrame", newCFrame)
	if shouldWriteToAttribute then
		realTransform.setGlobalCFrame(part, newCFrame, newParentCFrame)
	end
end

function scaling.updateChildrenCFrames(instance: Instance, newParentCFrame: CFrame, parentCFrame: CFrame)
	for _, child in instance:GetChildren() do
		if child:IsA("BasePart") then
			local newCFrame = newParentCFrame * parentCFrame:ToObjectSpace(child.CFrame)
			local currentCFrame = child.CFrame

			scaling.cframeRecursive(child, nil, false, true, newCFrame, currentCFrame)
		elseif child:IsA("Folder") then
			for _, folderChild in child:GetChildren() do
				if folderChild:IsA("BasePart") then
					scaling.cframeRecursive(folderChild, nil, false, true, newParentCFrame, parentCFrame)
				end
			end
		end
	end
end

function scaling.moveAndScaleChildrenRecursive(
	part: BasePart,
	newSize: Vector3,
	newCFrame: CFrame,
	axes: { types.AxisString },
	updateRepeatList: { BasePart },
	shouldWriteToAttribute: boolean?,
	newParentCFrame: CFrame?
)
	for _, axis: types.AxisString in axes do
		if shouldWriteToAttribute and repeatSettings.doesHaveStretchSettingsInAxis(part, axis) then
			realTransform.setSizeAndGlobalCFrame(part, newSize, newCFrame, newParentCFrame)
			return
		end
	end

	for _, child in part:GetChildren() do
		if child:IsA("BasePart") then
			local totalRelativeDeltaCFrame = CFrame.identity
			local totalDeltaSize = Vector3.zero
			for _, axis: types.AxisString in axes do
				local constraintSettings = constraintSettings.getSettingGroup(child) :: constraintSettings.SingleSettingGroup
				local constraint = constraintSettings[axis]
				local constraintType: types.ConstraintString = geometryHelper.constraintMap[constraint]

				local scaleFunction = scaleFunctionsMap[constraintType]
				local axisEnum = geometryHelper.axisEnumByString[axis]
				local relativeDeltaCFrame, deltaSize = scaleFunction(axisEnum, child, newSize)

				totalRelativeDeltaCFrame *= relativeDeltaCFrame
				totalDeltaSize += deltaSize
			end

			if mathUtil.fuzzyEq(totalRelativeDeltaCFrame.Position.Magnitude, mathUtil.epsilon) then
				totalRelativeDeltaCFrame = CFrame.identity
			end

			local size, relativeCFrame = realTransform.getSizeAndRelativeCFrame(child)
			local childCFrame = part.CFrame * relativeCFrame
			local newChildCFrame = newCFrame * totalRelativeDeltaCFrame * relativeCFrame
			local newChildSize = size + totalDeltaSize

			if repeatSettings.doesHaveAnyRepeatSettings(child) then
				table.insert(updateRepeatList, 1, child)
			end

			if totalDeltaSize == Vector3.zero then
				scaling.cframeRecursive(child, childCFrame:ToObjectSpace(newChildCFrame), true, true, newCFrame)
			else
				scaling.moveAndScaleChildrenRecursive(child, newChildSize, newChildCFrame, axes, updateRepeatList, true, newCFrame)
			end
		end
	end

	changeDeduplicator.setProp("scaling", part, "Size", newSize)
	changeDeduplicator.setProp("scaling", part, "CFrame", newCFrame)
	if shouldWriteToAttribute then
		realTransform.setSizeAndGlobalCFrame(part, newSize, newCFrame, newParentCFrame)
	end
end

return scaling
