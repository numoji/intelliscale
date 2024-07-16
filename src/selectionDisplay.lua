--!strict
local CoreGui = game:GetService("CoreGui")
local selectionDisplay = {}

local Janitor = require(script.Parent.Parent.Packages.Janitor)

local constraintSettings = require(script.Parent.utility.settingsHelper.constraintSettings)
local containerHelper = require(script.Parent.utility.containerHelper)
local geometryHelper = require(script.Parent.utility.geometryHelper)
local selectionHelper = require(script.Parent.utility.selectionHelper)
local types = require(script.Parent.types)

local janitor = Janitor.new()

local function createCylinderHandle(color, parent)
	local cylinderHandle = Instance.new("CylinderHandleAdornment")
	cylinderHandle.AdornCullingMode = Enum.AdornCullingMode.Never
	cylinderHandle.Transparency = 0.1
	cylinderHandle.AlwaysOnTop = true
	cylinderHandle.Parent = parent
	cylinderHandle.Radius = 0.075
	cylinderHandle.InnerRadius = 0.001
	cylinderHandle.Angle = 360
	cylinderHandle.Color3 = color
	cylinderHandle.Archivable = false

	return cylinderHandle
end

local function createSelectionBox(color, parent)
	local selectionBox = Instance.new("SelectionBox")
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
	local constraintSettings = constraintSettings.getSettingGroup(selected)
	if not constraintSettings then
		cylinderA.Adornee = nil :: any
		cylinderB.Adornee = nil :: any
		return
	end

	local constraint = constraintSettings[axis]
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

function selectionDisplay.initialize()
	local screenGui = janitor:Add(Instance.new("ScreenGui"))
	screenGui.Parent = CoreGui
	screenGui.Name = "IntelliscaleConstraintVisualization"

	local adornmentJanitors = {}

	local function reconcileSelectionAdornments(selection, fauxSelection)
		local newSelectedSet = {}
		local containerSelectedSet = {}
		for _, instance in fauxSelection do
			if not instance:IsA("BasePart") then
				continue
			end

			local part = instance :: BasePart
			local realPart = selectionHelper.getRealInstance(part) :: BasePart

			if part ~= realPart then
				newSelectedSet[part] = true
				if not adornmentJanitors[part] then
					local fauxSelectionJanitor = Janitor.new()
					adornmentJanitors[part] = fauxSelectionJanitor
					local fauxSelectionBox = fauxSelectionJanitor:Add(createSelectionBox(Color3.fromHex("#6fff4f"), screenGui))
					fauxSelectionBox.Adornee = part
				end
			end

			if containerHelper.isValidContained(realPart) then
				newSelectedSet[realPart] = true
				if not adornmentJanitors[realPart] then
					local constraintJanitor = Janitor.new()
					adornmentJanitors[realPart] = constraintJanitor

					if not containerSelectedSet[realPart.Parent] then
						containerSelectedSet[realPart.Parent] = true
						local containerSelectionBox = constraintJanitor:Add(createSelectionBox(Color3.fromHex("#f34bff"), screenGui))
						containerSelectionBox.Adornee = realPart.Parent
					end

					local xCylinderA = constraintJanitor:Add(createCylinderHandle(Color3.fromRGB(255, 170, 0), screenGui), "Destroy", "xA")
					local xCylinderB = constraintJanitor:Add(createCylinderHandle(Color3.fromRGB(255, 170, 0), screenGui), "Destroy", "xB")
					local yCylinderA = constraintJanitor:Add(createCylinderHandle(Color3.fromRGB(0, 255, 170), screenGui), "Destroy", "yA")
					local yCylinderB = constraintJanitor:Add(createCylinderHandle(Color3.fromRGB(0, 255, 170), screenGui), "Destroy", "yB")
					local zCylinderA = constraintJanitor:Add(createCylinderHandle(Color3.fromRGB(170, 0, 255), screenGui), "Destroy", "zA")
					local zCylinderB = constraintJanitor:Add(createCylinderHandle(Color3.fromRGB(170, 0, 255), screenGui), "Destroy", "zB")

					updateCylindersByAxis("x", realPart, xCylinderA, xCylinderB)
					updateCylindersByAxis("y", realPart, yCylinderA, yCylinderB)
					updateCylindersByAxis("z", realPart, zCylinderA, zCylinderB)
				end
			end
		end

		for selectedPart, janitor in pairs(adornmentJanitors) do
			if not newSelectedSet[selectedPart] then
				janitor:Destroy()
				adornmentJanitors[selectedPart] = nil
			end
		end
	end

	local function updateCylinderAdornments(selection)
		for _, selectedPart in selection do
			local adornmentJanitor = adornmentJanitors[selectedPart]
			if not adornmentJanitor then
				continue
			end
			local xA = adornmentJanitor:Get("xA") :: CylinderHandleAdornment
			local xB = adornmentJanitor:Get("xB") :: CylinderHandleAdornment
			if xA and xB then
				updateCylindersByAxis("x", selectedPart, xA, xB)
			end
			local yA = adornmentJanitor:Get("yA") :: CylinderHandleAdornment
			local yB = adornmentJanitor:Get("yB") :: CylinderHandleAdornment
			if yA and yB then
				updateCylindersByAxis("y", selectedPart, yA, yB)
			end
			local zA = adornmentJanitor:Get("zA") :: CylinderHandleAdornment
			local zB = adornmentJanitor:Get("zB") :: CylinderHandleAdornment
			if zA and zB then
				updateCylindersByAxis("z", selectedPart, zA, zB)
			end
		end
	end

	selectionHelper.addSelectionChangeCallback(selectionHelper.callbackDicts.any, reconcileSelectionAdornments)

	selectionHelper.addPropertyChangeCallback(
		selectionHelper.callbackDicts.any,
		{ "Parent", "Size", "CFrame", "Attributes" },
		function(_, selection)
			updateCylinderAdornments(selection)
		end
	)

	janitor:Add(function()
		for selectedPart, adornmentJanitor in pairs(adornmentJanitors) do
			adornmentJanitor:Destroy()
			adornmentJanitors[selectedPart] = nil
		end
	end)

	return janitor
end

return selectionDisplay
