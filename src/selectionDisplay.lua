--!nonstrict
-- Has to be nonstrict cause cylinderhandle.Adornee can't be set to nil

local CoreGui = game:GetService("CoreGui")
local selectionDisplay = {}

local packages = script.Parent.Parent.Packages
local Janitor = require(packages.Janitor)

local source = script.Parent
local geometryHelper = require(source.utility.geometryHelper)
local selectionHelper = require(source.utility.selectionHelper)
local types = require(source.types)

local janitor = Janitor.new()

local function createCylinderHandle(color, parent)
	local cylinderHandle = janitor:Add(Instance.new("CylinderHandleAdornment"))
	cylinderHandle.AdornCullingMode = Enum.AdornCullingMode.Never
	cylinderHandle.Transparency = 0.1
	cylinderHandle.AlwaysOnTop = true
	cylinderHandle.Parent = parent
	cylinderHandle.Radius = 0.05
	cylinderHandle.InnerRadius = 0.001
	cylinderHandle.Angle = 360
	cylinderHandle.Color3 = color
	cylinderHandle.Archivable = false

	return cylinderHandle
end

local function createSelectionBox(color, parent)
	local selectionBox = janitor:Add(Instance.new("SelectionBox"))
	selectionBox.LineThickness = 0.02
	selectionBox.SurfaceTransparency = 0.95
	selectionBox.SurfaceColor3 = color
	selectionBox.Parent = parent
	selectionBox.Color3 = color
	selectionBox.Visible = true
	selectionBox.Archivable = false
	return selectionBox
end

local function drawCylinderInParentSpace(cylinder: CylinderHandleAdornment, start: Vector3, finish: Vector3)
	local adornee = cylinder.Adornee :: BasePart
	local parent = adornee.Parent :: BasePart

	cylinder.Height = (start - finish).Magnitude

	local rawCylinderCFrame = CFrame.lookAt(start, finish) * CFrame.new(0, 0, -cylinder.Height / 2)
	local parentSpaceCylinderCFrame = parent.CFrame * rawCylinderCFrame

	cylinder.CFrame = adornee.CFrame:ToObjectSpace(parentSpaceCylinderCFrame)
end

local function drawCylinderBetweenFaces(axisEnum: Enum.Axis, sign: number, cylinder: CylinderHandleAdornment)
	local axis = geometryHelper.axisByEnum[axisEnum]
	local adornee = cylinder.Adornee :: BasePart
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

	drawCylinderInParentSpace(cylinder, adorneeFacePosition, parentFacePosition)
end

type UpdateFunctionsMap = {
	[string]: (Enum.Axis, CylinderHandleAdornment, CylinderHandleAdornment) -> (),
}
local updateFunctionsMap: UpdateFunctionsMap = {
	Min = function(axisEnum: Enum.Axis, cylinder: CylinderHandleAdornment)
		drawCylinderBetweenFaces(axisEnum, -1, cylinder)
	end,
	Max = function(axisEnum: Enum.Axis, cylinder: CylinderHandleAdornment)
		drawCylinderBetweenFaces(axisEnum, 1, cylinder)
	end,
	MinMax = function(axisEnum: Enum.Axis, cylinderA: CylinderHandleAdornment, cylinderB: CylinderHandleAdornment)
		drawCylinderBetweenFaces(axisEnum, -1, cylinderA)
		drawCylinderBetweenFaces(axisEnum, 1, cylinderB)
	end,
	Center = function(axisEnum: Enum.Axis, cylinder: CylinderHandleAdornment)
		local axis = geometryHelper.axisByEnum[axisEnum]

		local adornee = cylinder.Adornee :: BasePart
		local parent = adornee.Parent :: BasePart

		local relativeCFrame = parent.CFrame:ToObjectSpace(adornee.CFrame)
		local positionInAxis = relativeCFrame.Position:Dot(axis)

		local start = relativeCFrame.Position
		local finish = relativeCFrame.Position - positionInAxis * axis

		drawCylinderInParentSpace(cylinder, start, finish)
	end,
	Scale = function(axisEnum: Enum.Axis, cylinder: CylinderHandleAdornment)
		local axis = geometryHelper.axisByEnum[axisEnum]

		local adornee = cylinder.Adornee :: BasePart
		local parent = adornee.Parent :: BasePart

		local relativeCFrame = parent.CFrame:ToObjectSpace(adornee.CFrame)

		local start = relativeCFrame.Position + axis / 2
		local finish = relativeCFrame.Position - axis / 2

		drawCylinderInParentSpace(cylinder, start, finish)
	end,
}

local function updateCylindersByAxis(
	axis: types.AxisString,
	selected: BasePart,
	cylinderA: CylinderHandleAdornment,
	cylinderB: CylinderHandleAdornment
)
	local constraint = selected:GetAttribute(axis .. "Constraint") or "Scale"
	local constraintType = geometryHelper.constraintMap[constraint]

	local axisEnum = geometryHelper.axisEnumByString[axis]

	if constraintType == "MinMax" then
		cylinderA.Adornee = selected
		cylinderB.Adornee = selected
	else
		cylinderA.Adornee = selected
		cylinderB.Adornee = nil :: any
	end

	updateFunctionsMap[constraintType](axisEnum, cylinderA, cylinderB)
end

function selectionDisplay.initializeHighlightContainer()
	local screenGui = janitor:Add(Instance.new("ScreenGui"))
	screenGui.Parent = CoreGui
	screenGui.Name = "IntelliscaleConstraintVisualization"

	local containerSelectionBox = createSelectionBox(Color3.fromHex("#f34bff"), screenGui)
	local fauxSelectionBox = createSelectionBox(Color3.fromHex("#6fff4f"), screenGui)

	local xCylinderA = createCylinderHandle(Color3.fromRGB(255, 90, 0), screenGui)
	local xCylinderB = createCylinderHandle(Color3.fromRGB(255, 90, 0), screenGui)
	local yCylinderA = createCylinderHandle(Color3.fromRGB(0, 255, 90), screenGui)
	local yCylinderB = createCylinderHandle(Color3.fromRGB(0, 255, 90), screenGui)
	local zCylinderA = createCylinderHandle(Color3.fromRGB(90, 0, 255), screenGui)
	local zCylinderB = createCylinderHandle(Color3.fromRGB(90, 0, 255), screenGui)

	local function update(selectedPart: BasePart, fauxPart: BasePart?)
		if selectionHelper.isValidContained(selectedPart) then
			containerSelectionBox.Adornee = selectedPart.Parent
			updateCylindersByAxis("x", selectedPart, xCylinderA, xCylinderB)
			updateCylindersByAxis("y", selectedPart, yCylinderA, yCylinderB)
			updateCylindersByAxis("z", selectedPart, zCylinderA, zCylinderB)
		else
			xCylinderA.Adornee = nil
			xCylinderB.Adornee = nil
			yCylinderA.Adornee = nil
			yCylinderB.Adornee = nil
			zCylinderA.Adornee = nil
			zCylinderB.Adornee = nil
			containerSelectionBox.Adornee = nil
		end

		if fauxPart and fauxPart ~= selectedPart then
			fauxSelectionBox.Adornee = fauxPart
		else
			fauxSelectionBox.Adornee = nil
		end
	end

	selectionHelper.bindToSingleEitherSelection(update, function()
		containerSelectionBox.Adornee = nil
		fauxSelectionBox.Adornee = nil
		xCylinderA.Adornee = nil
		xCylinderB.Adornee = nil
		yCylinderA.Adornee = nil
		yCylinderB.Adornee = nil
		zCylinderA.Adornee = nil
		zCylinderB.Adornee = nil
	end)

	selectionHelper.bindToSingleEitherChanged(function(changedInstance: Instance, selectedPart: BasePart, fauxPart: BasePart?)
		update(selectedPart, fauxPart)
	end)

	return janitor
end

return selectionDisplay
