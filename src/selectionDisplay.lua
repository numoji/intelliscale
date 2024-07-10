--!nonstrict
-- Has to be nonstrict cause linehandle.Adornee can't be set to nil

local CoreGui = game:GetService("CoreGui")
local selectionDisplay = {}

local packages = script.Parent.Parent.Packages
local Janitor = require(packages.Janitor)

local source = script.Parent
local geometryHelper = require(source.utility.geometryHelper)
local selectionHelper = require(source.utility.selectionHelper)
local types = require(source.types)

local janitor = Janitor.new()

local function createLineHandle(color)
	local lineHandle = janitor:Add(Instance.new("LineHandleAdornment"))
	lineHandle.AlwaysOnTop = true
	lineHandle.Parent = CoreGui
	lineHandle.Thickness = 22
	lineHandle.Color3 = color
	lineHandle.Archivable = false

	return lineHandle
end

local function createSelectionBox(color)
	local selectionBox = janitor:Add(Instance.new("SelectionBox"))
	selectionBox.LineThickness = 0.02
	selectionBox.SurfaceTransparency = 1
	selectionBox.Parent = CoreGui
	selectionBox.Color3 = color
	selectionBox.Visible = true
	selectionBox.Archivable = false
	return selectionBox
end

local function drawLineInParentSpace(line: LineHandleAdornment, start: Vector3, finish: Vector3)
	local adornee = line.Adornee :: BasePart
	local parent = adornee.Parent :: BasePart

	local rawLineCFrame = CFrame.lookAt(start, finish)
	local parentSpaceLineCFrame = parent.CFrame * rawLineCFrame

	line.CFrame = adornee.CFrame:ToObjectSpace(parentSpaceLineCFrame)
	line.Length = (start - finish).Magnitude
end

local function drawLineBetweenFaces(axisEnum: Enum.Axis, sign: number, line: LineHandleAdornment)
	local axis = geometryHelper.axisByEnum[axisEnum]
	local adornee = line.Adornee :: BasePart
	local parent = adornee.Parent :: BasePart

	local relativeCFrame = parent.CFrame:ToObjectSpace(adornee.CFrame)
	local positionInAxis = relativeCFrame.Position:Dot(axis)

	local relativeAxis = relativeCFrame:VectorToObjectSpace(axis)
	local sizeInAxis = math.abs(adornee.Size:Dot(relativeAxis))
	local parentSizeInAxis = parent.Size:Dot(axis)

	local adorneeFaceOffsetInAxis = sizeInAxis * sign / 2
	local parentFaceOffsetInAxis = parentSizeInAxis * sign / 2 - positionInAxis

	local adorneeFacePosition = relativeCFrame.Position + adorneeFaceOffsetInAxis * axis
	local parentFacePosition = relativeCFrame.Position + parentFaceOffsetInAxis * axis

	drawLineInParentSpace(line, adorneeFacePosition, parentFacePosition)
end

type UpdateFunctionsMap = {
	[string]: (Enum.Axis, LineHandleAdornment, LineHandleAdornment) -> (),
}
local updateFunctionsMap: UpdateFunctionsMap = {
	Min = function(axisEnum: Enum.Axis, line: LineHandleAdornment)
		drawLineBetweenFaces(axisEnum, -1, line)
	end,
	Max = function(axisEnum: Enum.Axis, line: LineHandleAdornment)
		drawLineBetweenFaces(axisEnum, 1, line)
	end,
	MinMax = function(axisEnum: Enum.Axis, lineA: LineHandleAdornment, lineB: LineHandleAdornment)
		drawLineBetweenFaces(axisEnum, -1, lineA)
		drawLineBetweenFaces(axisEnum, 1, lineB)
	end,
	Center = function(axisEnum: Enum.Axis, line: LineHandleAdornment)
		local axis = geometryHelper.axisByEnum[axisEnum]

		local adornee = line.Adornee :: BasePart
		local parent = adornee.Parent :: BasePart

		local relativeCFrame = parent.CFrame:ToObjectSpace(adornee.CFrame)
		local positionInAxis = relativeCFrame.Position:Dot(axis)

		local start = relativeCFrame.Position
		local finish = relativeCFrame.Position - positionInAxis * axis

		drawLineInParentSpace(line, start, finish)
	end,
	Scale = function(axisEnum: Enum.Axis, line: LineHandleAdornment)
		local axis = geometryHelper.axisByEnum[axisEnum]

		local adornee = line.Adornee :: BasePart
		local parent = adornee.Parent :: BasePart

		local relativeCFrame = parent.CFrame:ToObjectSpace(adornee.CFrame)
		local relativeAxis = relativeCFrame:VectorToObjectSpace(axis)
		local sizeInAxis = math.abs(adornee.Size:Dot(relativeAxis))

		local start = relativeCFrame.Position + (sizeInAxis / 2 + 0.5) * axis
		local finish = relativeCFrame.Position - (sizeInAxis / 2 + 0.5) * axis

		drawLineInParentSpace(line, start, finish)
	end,
}

local function updateLinesByAxis(axis: types.AxisString, selected: BasePart, lineA: LineHandleAdornment, lineB: LineHandleAdornment)
	local constraint = selected:GetAttribute(axis .. "Constraint") or "Scale"
	local constraintType = geometryHelper.constraintMap[constraint]

	local axisEnum = geometryHelper.axisEnumByString[axis]

	if constraintType == "MinMax" then
		lineA.Adornee = selected
		lineB.Adornee = selected
	else
		lineA.Adornee = selected
		lineB.Adornee = nil :: any
	end

	updateFunctionsMap[constraintType](axisEnum, lineA, lineB)
end

function selectionDisplay.initializeHighlightContainer()
	local containerSelectionBox = createSelectionBox(Color3.fromHex("#f69fd6"))
	local repeatsFromSelectionBox = createSelectionBox(Color3.fromHex("#6fff4f"))

	local xLineA = createLineHandle(Color3.fromRGB(255, 90, 0))
	local xLineB = createLineHandle(Color3.fromRGB(255, 90, 0))
	local yLineA = createLineHandle(Color3.fromRGB(0, 255, 90))
	local yLineB = createLineHandle(Color3.fromRGB(0, 255, 90))
	local zLineA = createLineHandle(Color3.fromRGB(90, 0, 255))
	local zLineB = createLineHandle(Color3.fromRGB(90, 0, 255))

	local function update(selectedPart: BasePart)
		containerSelectionBox.Adornee = selectedPart.Parent

		local repeatsFrom = selectedPart:FindFirstChild("RepeatsFrom") :: ObjectValue

		if repeatsFrom and repeatsFrom:IsA("ObjectValue") then
			repeatsFromSelectionBox.Adornee = repeatsFrom.Value
		else
			repeatsFromSelectionBox.Adornee = nil
		end

		updateLinesByAxis("x", selectedPart, xLineA, xLineB)
		updateLinesByAxis("y", selectedPart, yLineA, yLineB)
		updateLinesByAxis("z", selectedPart, zLineA, zLineB)
	end

	selectionHelper.bindToSingleContainedSelection(update, function()
		containerSelectionBox.Adornee = nil
		repeatsFromSelectionBox.Adornee = nil
		xLineA.Adornee = nil
		xLineB.Adornee = nil
		yLineA.Adornee = nil
		yLineB.Adornee = nil
		zLineA.Adornee = nil
		zLineB.Adornee = nil
	end)
	selectionHelper.bindToSingleContainedChanged(update)

	return janitor
end

return selectionDisplay
