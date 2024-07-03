local CoreGui = game:GetService("CoreGui")
local Selection = game:GetService("Selection")
local StarterGui = game:GetService("StarterGui")
local selectionDisplay = {}

local source = script.Parent
local geometryHelper = require(source.geometryHelper)

local selectionChangedConnection
local selectedChangedConnection
local selectedAttChangedConnection
local selectionBox
local xLineA, xLineB, yLineA, yLineB, zLineA, zLineB

local function initLine(color, name)
	local lineHandle = Instance.new("LineHandleAdornment")
	lineHandle.Name = name
	lineHandle.AlwaysOnTop = true
	lineHandle.Parent = StarterGui
	lineHandle.Thickness = 15
	lineHandle.Color3 = color

	return lineHandle
end

local function drawLine(line, start, finish)
	local adornee = line.Adornee
	line.CFrame = adornee.CFrame:ToObjectSpace(CFrame.lookAt(start, finish))
	line.Length = (start - finish).Magnitude
end

local function drawLineBetweenFaces(axis, line)
	local adornee = line.Adornee
	local parent = adornee.Parent

	local adorneeFace = geometryHelper.getFacePosition(adornee, axis)
	local parentFace = geometryHelper.getFacePosition(parent, axis)
	local adorneeFaceToParentFace = (parentFace - adorneeFace)
	local parentFaceFinsih = adorneeFace + adorneeFaceToParentFace:Dot(axis) * axis

	drawLine(line, adorneeFace, parentFaceFinsih)
end

local updateFunctionsMap = {
	Min = function(axisEnum: Enum.Axis, line: LineHandleAdornment)
		local parent = line.Adornee.Parent
		local axis = -geometryHelper.getCFrameAxis(parent.CFrame, axisEnum)
		drawLineBetweenFaces(axis, line)
	end,
	Max = function(axisEnum: Enum.Axis, line: LineHandleAdornment)
		local parent = line.Adornee.Parent
		local axis = geometryHelper.getCFrameAxis(parent.CFrame, axisEnum)
		drawLineBetweenFaces(axis, line)
	end,
	MinMax = function(axisEnum: Enum.Axis, lineA: LineHandleAdornment, lineB: LineHandleAdornment)
		local parent = lineA.Adornee.Parent
		local axis = geometryHelper.getCFrameAxis(parent.CFrame, axisEnum)
		drawLineBetweenFaces(axis, lineA)
		axis = -geometryHelper.getCFrameAxis(parent.CFrame, axisEnum)
		drawLineBetweenFaces(axis, lineB)
	end,
	Center = function(axisEnum: Enum.Axis, line: LineHandleAdornment)
		local adornee = line.Adornee
		local parent = adornee.Parent
		local axis = geometryHelper.getCFrameAxis(parent.CFrame, axisEnum)

		local adorneeToParentVector = (parent.Position - adornee.Position)

		local start = adornee.Position
		local finish = adornee.Position + adorneeToParentVector:Dot(axis) * axis

		drawLine(line, start, finish)
	end,
	Scale = function(axisEnum: Enum.Axis, line: LineHandleAdornment)
		local adornee = line.Adornee
		local parent = adornee.Parent
		local axis = geometryHelper.getCFrameAxis(parent.CFrame, axisEnum)

		local start = adornee.Position - (axis / 2)
		local finish = adornee.Position + (axis / 2)

		drawLine(line, start, finish)
	end,
}

local function updateLinesByAxis(axis: "x" | "y" | "z", selected: BasePart, lineA: LineHandleAdornment, lineB: LineHandleAdornment)
	local constraint = selected:GetAttribute(axis .. "Constraint") or "Scale"
	local constraintType = geometryHelper.constraintMap[constraint]

	if constraintType == "MinMax" then
		lineA.Adornee = selected
		lineB.Adornee = selected
		updateFunctionsMap[constraintType](Enum.Axis[axis:upper()], lineA, lineB)
	else
		lineA.Adornee = selected
		lineB.Adornee = nil :: any
		updateFunctionsMap[constraintType](Enum.Axis[axis:upper()], lineA)
	end
end

function update(selected)
	selectionBox.Adornee = selected.Parent

	updateLinesByAxis("x", selected, xLineA, xLineB)
	updateLinesByAxis("y", selected, yLineA, yLineB)
	updateLinesByAxis("z", selected, zLineA, zLineB)
end

function selectionDisplay.initializeHighlightContainer()
	selectionBox = Instance.new("SelectionBox")
	selectionBox.LineThickness = 0.02
	selectionBox.SurfaceTransparency = 1
	selectionBox.Parent = CoreGui
	selectionBox.Color3 = Color3.fromHex("#f69fd6")
	selectionBox.SurfaceColor3 = Color3.fromHex("#f69fd6")
	selectionBox.Visible = true

	xLineA = initLine(Color3.fromRGB(200, 75, 75), "xA")
	xLineB = initLine(Color3.fromRGB(200, 75, 75), "xB")
	yLineA = initLine(Color3.fromRGB(75, 200, 75), "yA")
	yLineB = initLine(Color3.fromRGB(75, 200, 75), "yB")
	zLineA = initLine(Color3.fromRGB(75, 75, 200), "zA")
	zLineB = initLine(Color3.fromRGB(75, 75, 200), "zB")

	selectionChangedConnection = Selection.SelectionChanged:Connect(function()
		if selectedChangedConnection then
			selectedChangedConnection:Disconnect()
			selectedChangedConnection = nil
			selectedAttChangedConnection:Disconnect()
			selectedAttChangedConnection = nil
		end

		local selection = Selection:Get()
		if
			#selection ~= 1
			or not (selection[1].Parent and selection[1].Parent:IsA("BasePart") and selection[1].Parent:GetAttribute("isContainer"))
		then
			-- highlight.Enabled = false
			selectionBox.Adornee = nil
			xLineA.Adornee = nil
			xLineB.Adornee = nil
			yLineA.Adornee = nil
			yLineB.Adornee = nil
			zLineA.Adornee = nil
			zLineB.Adornee = nil
			return
		end

		local selected = selection[1]
		update(selected)
		selectedChangedConnection = selected.Changed:Connect(function()
			update(selected)
		end)
		selectedAttChangedConnection = selected.AttributeChanged:Connect(function()
			update(selected)
		end)
	end)
end

function selectionDisplay.cleanup()
	selectionChangedConnection:Disconnect()
	selectionBox:Destroy()
	xLineA:Destroy()
	xLineB:Destroy()
	yLineA:Destroy()
	yLineB:Destroy()
	zLineA:Destroy()
	zLineB:Destroy()

	if selectedChangedConnection then
		selectedChangedConnection:Disconnect()
		selectedChangedConnection = nil
		selectedAttChangedConnection:Disconnect()
		selectedAttChangedConnection = nil
	end
end

return selectionDisplay
