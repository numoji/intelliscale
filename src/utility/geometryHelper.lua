--!strict
local types = require(script.Parent.Parent.types)

local geometryHelper = {}

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

function geometryHelper.getSizeInAxis(axis: Vector3, cf: CFrame, size: Vector3): (number, number)
	local rotatedAxis = cf:VectorToObjectSpace(axis)
	local sizeInAxis = size:Dot(rotatedAxis)
	local absSizeInAxis = math.abs(sizeInAxis)
	return absSizeInAxis, math.sign(sizeInAxis)
end

function geometryHelper.getPositionAndSizeInParentAxis(axis: Vector3, part: BasePart)
	local parent = part.Parent :: BasePart
	local relativeCFrame = parent.CFrame:ToObjectSpace(part.CFrame)
	local positionInAxis = relativeCFrame.Position:Dot(axis)

	local relativeAxis = relativeCFrame:VectorToObjectSpace(axis)
	local sizeInAxis = math.abs(part.Size:Dot(relativeAxis))
	local sign = math.sign(part.Size:Dot(relativeAxis))

	return positionInAxis, sizeInAxis, relativeAxis, sign
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
} :: { [string]: types.ConstraintString }

geometryHelper.axisNameByNormalIdMap = {
	[Enum.NormalId.Left] = "x",
	[Enum.NormalId.Right] = "x",
	[Enum.NormalId.Top] = "y",
	[Enum.NormalId.Bottom] = "z",
	[Enum.NormalId.Front] = "z",
	[Enum.NormalId.Back] = "z",
} :: { [Enum.NormalId]: types.AxisString }

geometryHelper.axisEnumByNormalIdMap = {
	[Enum.NormalId.Left] = Enum.Axis.X,
	[Enum.NormalId.Right] = Enum.Axis.X,
	[Enum.NormalId.Top] = Enum.Axis.Y,
	[Enum.NormalId.Bottom] = Enum.Axis.Y,
	[Enum.NormalId.Front] = Enum.Axis.Z,
	[Enum.NormalId.Back] = Enum.Axis.Z,
} :: { [Enum.NormalId]: Enum.Axis }

geometryHelper.axisByEnum = {
	[Enum.Axis.X] = Vector3.xAxis,
	[Enum.Axis.Y] = Vector3.yAxis,
	[Enum.Axis.Z] = Vector3.zAxis,
} :: { [Enum.Axis]: Vector3 }

geometryHelper.axisEnumByString = {
	x = Enum.Axis.X,
	y = Enum.Axis.Y,
	z = Enum.Axis.Z,
} :: { [types.AxisString]: Enum.Axis }

return geometryHelper
