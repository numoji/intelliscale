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
	lineHandle.Thickness = 15
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

local function drawLine(line: LineHandleAdornment, start: Vector3, finish: Vector3)
	local adornee = line.Adornee :: BasePart
	line.CFrame = adornee.CFrame:ToObjectSpace(CFrame.lookAt(start, finish))
	line.Length = (start - finish).Magnitude
end

local function drawLineBetweenFaces(axis, line)
	local adornee = line.Adornee :: BasePart
	local parent = adornee.Parent :: BasePart

	local adorneeFace = geometryHelper.getFacePosition(adornee, axis)
	local parentFace = geometryHelper.getFacePosition(parent, axis)
	local adorneeFaceToParentFace = (parentFace - adorneeFace)
	local parentFaceFinsih = adorneeFace + adorneeFaceToParentFace:Dot(axis) * axis

	drawLine(line, adorneeFace, parentFaceFinsih)
end

local updateFunctionsMap = {
	Min = function(axisEnum: Enum.Axis, line: LineHandleAdornment)
		local parent = line.Adornee.Parent :: BasePart
		local axis = -geometryHelper.getCFrameAxis(parent.CFrame, axisEnum)
		drawLineBetweenFaces(axis, line)
	end,
	Max = function(axisEnum: Enum.Axis, line: LineHandleAdornment)
		local parent = line.Adornee.Parent :: BasePart
		local axis = geometryHelper.getCFrameAxis(parent.CFrame, axisEnum)
		drawLineBetweenFaces(axis, line)
	end,
	MinMax = function(axisEnum: Enum.Axis, lineA: LineHandleAdornment, lineB: LineHandleAdornment)
		local parent = lineA.Adornee.Parent :: BasePart
		local axis = geometryHelper.getCFrameAxis(parent.CFrame, axisEnum)
		drawLineBetweenFaces(axis, lineA)
		axis = -geometryHelper.getCFrameAxis(parent.CFrame, axisEnum)
		drawLineBetweenFaces(axis, lineB)
	end,
	Center = function(axisEnum: Enum.Axis, line: LineHandleAdornment)
		local adornee = line.Adornee :: BasePart
		local parent = adornee.Parent :: BasePart
		local axis = geometryHelper.getCFrameAxis(parent.CFrame, axisEnum)

		local adorneeToParentVector = (parent.Position - adornee.Position)

		local start = adornee.Position
		local finish = adornee.Position + adorneeToParentVector:Dot(axis) * axis

		drawLine(line, start, finish)
	end,
	Scale = function(axisEnum: Enum.Axis, line: LineHandleAdornment)
		local adornee = line.Adornee :: BasePart
		local parent = adornee.Parent :: BasePart
		local axis = geometryHelper.getCFrameAxis(parent.CFrame, axisEnum)

		local start = adornee.Position - (axis / 2)
		local finish = adornee.Position + (axis / 2)

		drawLine(line, start, finish)
	end,
}

local function updateLinesByAxis(axis: types.AxisString, selected: BasePart, lineA: LineHandleAdornment, lineB: LineHandleAdornment)
	local constraint = selected:GetAttribute(axis .. "Constraint") or "Scale"
	local constraintType = geometryHelper.constraintMap[constraint]

	local axisEnum = geometryHelper.axisEnumByString[axis]

	if constraintType == "MinMax" then
		lineA.Adornee = selected
		lineB.Adornee = selected
		updateFunctionsMap[constraintType](axisEnum, lineA, lineB)
	else
		lineA.Adornee = selected
		lineB.Adornee = nil :: any
		updateFunctionsMap[constraintType](axisEnum, lineA)
	end
end

function selectionDisplay.initializeHighlightContainer()
	local containerSelectionBox = createSelectionBox(Color3.fromHex("#f69fd6"))
	local repeatsFromSelectionBox = createSelectionBox(Color3.fromHex("#6fff4f"))

	local xLineA = createLineHandle(Color3.fromRGB(200, 75, 75))
	local xLineB = createLineHandle(Color3.fromRGB(200, 75, 75))
	local yLineA = createLineHandle(Color3.fromRGB(75, 200, 75))
	local yLineB = createLineHandle(Color3.fromRGB(75, 200, 75))
	local zLineA = createLineHandle(Color3.fromRGB(75, 75, 200))
	local zLineB = createLineHandle(Color3.fromRGB(75, 75, 200))

	local function update(selected: BasePart)
		containerSelectionBox.Adornee = selected.Parent

		local repeatsFrom = selected:FindFirstChild("RepeatsFrom") :: ObjectValue

		if repeatsFrom and repeatsFrom:IsA("ObjectValue") then
			repeatsFromSelectionBox.Adornee = repeatsFrom.Value
		else
			repeatsFromSelectionBox.Adornee = nil
		end

		updateLinesByAxis("x", selected, xLineA, xLineB)
		updateLinesByAxis("y", selected, yLineA, yLineB)
		updateLinesByAxis("z", selected, zLineA, zLineB)
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
