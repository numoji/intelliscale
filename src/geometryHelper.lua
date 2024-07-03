local geometryHelper = {}

function geometryHelper.getFacePosition(part: BasePart, axis: Vector3)
	local cf: CFrame = part.CFrame
	local halfSize = part.Size / 2
	local xOffset = cf.RightVector:Dot(axis) * halfSize.X
	local yOffset = cf.UpVector:Dot(axis) * halfSize.Y
	local zOffset = cf.LookVector:Dot(axis) * halfSize.Z

	return part.Position + Vector3.new(xOffset, yOffset, zOffset)
end

function geometryHelper.getFacePositionFromSizeAndCFrame(size: Vector3, cf: CFrame, axis: Vector3)
	local halfSize = size / 2
	local xOffset = cf.RightVector:Dot(axis) * halfSize.X
	local yOffset = cf.UpVector:Dot(axis) * halfSize.Y
	local zOffset = cf.LookVector:Dot(axis) * halfSize.Z

	return cf.Position + Vector3.new(xOffset, yOffset, zOffset)
end

function geometryHelper.getCFrameAxis(cf: CFrame, axisEnum: Enum.Axis)
	if axisEnum == Enum.Axis.X then
		return cf.RightVector
	elseif axisEnum == Enum.Axis.Y then
		return cf.UpVector
	elseif axisEnum == Enum.Axis.Z then
		return cf.LookVector
	else
		error("Invalid axis enum")
	end
end

function geometryHelper.getCFrameAxisZPositive(cf: CFrame, axisEnum: Enum.Axis)
	if axisEnum == Enum.Axis.X then
		return cf.RightVector
	elseif axisEnum == Enum.Axis.Y then
		return cf.UpVector
	elseif axisEnum == Enum.Axis.Z then
		return -cf.LookVector
	else
		error("Invalid axis enum")
	end
end

function geometryHelper.getComponent(axisEnum: Enum.Axis, vector: Vector3)
	if axisEnum == Enum.Axis.X then
		return vector.X
	elseif axisEnum == Enum.Axis.Y then
		return vector.Y
	elseif axisEnum == Enum.Axis.Z then
		return vector.Z
	else
		error("Invalid axis enum")
	end
end

function geometryHelper.getAxisFromNormalId(normalId: Enum.NormalId, cf: CFrame)
	if normalId == Enum.NormalId.Left then
		return -cf.RightVector
	elseif normalId == Enum.NormalId.Right then
		return cf.RightVector
	elseif normalId == Enum.NormalId.Top then
		return cf.UpVector
	elseif normalId == Enum.NormalId.Bottom then
		return -cf.UpVector
	elseif normalId == Enum.NormalId.Front then
		return cf.LookVector
	elseif normalId == Enum.NormalId.Back then
		return -cf.LookVector
	else
		error("Invalid normalId")
	end
end

geometryHelper.constraintMap = {
	Left = "Min",
	Right = "Max",
	["Left and Right"] = "MinMax",
	Top = "Max",
	Bottom = "Min",
	["Top and Bottom"] = "MinMax",
	Front = "Min",
	Back = "Max",
	["Front and Back"] = "MinMax",
	Scale = "Scale",
	Center = "Center",
}

geometryHelper.axisNameByNormalIdMap = {
	[Enum.NormalId.Left] = "x",
	[Enum.NormalId.Right] = "x",
	[Enum.NormalId.Top] = "y",
	[Enum.NormalId.Bottom] = "y",
	[Enum.NormalId.Front] = "z",
	[Enum.NormalId.Back] = "z",
}

geometryHelper.axisEnumByNormalIdMap = {
	[Enum.NormalId.Left] = Enum.Axis.X,
	[Enum.NormalId.Right] = Enum.Axis.X,
	[Enum.NormalId.Top] = Enum.Axis.Y,
	[Enum.NormalId.Bottom] = Enum.Axis.Y,
	[Enum.NormalId.Front] = Enum.Axis.Z,
	[Enum.NormalId.Back] = Enum.Axis.Z,
}

geometryHelper.axisByEnum = {
	[Enum.Axis.X] = Vector3.xAxis,
	[Enum.Axis.Y] = Vector3.yAxis,
	[Enum.Axis.Z] = Vector3.zAxis,
}

return geometryHelper
