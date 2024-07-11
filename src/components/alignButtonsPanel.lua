--!strict
local packages = script.Parent.Parent.Parent.Packages
local React = require(packages.React)
local StudioComponents = require(packages.StudioComponents)

local source = script.Parent.Parent
local changeHistoryHelper = require(source.utility.changeHistoryHelper)
local geometryHelper = require(source.utility.geometryHelper)
local realTransform = require(source.utility.realTransform)
local selectionHelper = require(source.utility.selectionHelper)

local e = React.createElement

local function positionAlongParentAxis(part: BasePart, axisEnum: Enum.Axis, alpha: number)
	local axis = geometryHelper.axisByEnum[axisEnum]

	local parent = part.Parent :: BasePart
	local size, cframe = realTransform.getSizeAndGlobalCFrame(part)

	local relativeCFrame = parent.CFrame:ToObjectSpace(cframe)
	local positionInAxis = relativeCFrame.Position:Dot(axis)

	local relativeAxis = relativeCFrame:VectorToObjectSpace(axis)
	local sizeInAxis = math.abs(size:Dot(relativeAxis))

	local parentSizeInAxis = parent.Size:Dot(axis)

	local rangeInAxis = (parentSizeInAxis - sizeInAxis) / 2
	local neutralPos = relativeCFrame.Position - (positionInAxis * axis)

	local newPosition = neutralPos + (rangeInAxis * alpha * axis)
	local sign = math.sign(alpha)

	local offset = rangeInAxis - (sign * positionInAxis)
	if offset <= 0 and offset ~= -sizeInAxis then
		newPosition += sizeInAxis * axis * sign
	end

	realTransform.setGlobalCFrame(part, (parent.CFrame * CFrame.new(newPosition)) * cframe.Rotation)
end

local function buttonsRow(props)
	local row: number = props.Row
	local buttonLabels = props.buttonLabels
	local positionAlphas = props.positionAlphas
	local selectedPart = props.selectedPart
	local axisEnum = props.axisEnum

	local buttons = {}
	for i = 1, 3 do
		table.insert(
			buttons,
			e(StudioComponents.Button, {
				Text = buttonLabels[i],
				Size = UDim2.new(0, 24, 0, 24),
				LayoutOrder = row * 3 + i,
				OnActivated = function()
					changeHistoryHelper.recordUndoChange(function()
						positionAlongParentAxis(selectedPart, axisEnum, positionAlphas[i])
					end)
				end,
			})
		)
	end

	return e(React.Fragment, {}, buttons)
end

local function alignButtonsPanel(props)
	local layoutOrder = props.LayoutOrder

	local selectedPart: BasePart?, setSelectedPart = React.useState(nil :: BasePart?)
	React.useEffect(function()
		return selectionHelper.bindToSingleContainedSelection(function(selected)
			setSelectedPart(selected)
		end, function()
			setSelectedPart(nil)
		end)
	end, {})

	return e("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.fromScale(1, 0),
		LayoutOrder = layoutOrder,
		Visible = selectedPart ~= nil,
	}, {
		e("UIGridLayout", {
			CellSize = UDim2.new(0, 60, 0, 30),
			CellPadding = UDim2.new(0, 8, 0, 8),
			FillDirection = Enum.FillDirection.Horizontal,
			FillDirectionMaxCells = 3,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),

		e("UIPadding", {
			PaddingTop = UDim.new(0, 8),
			PaddingBottom = UDim.new(0, 8),
		}),

		e(buttonsRow, {
			axisEnum = Enum.Axis.X,
			buttonLabels = { "Left", "X Center", "Right" },
			positionAlphas = { -1, 0, 1 },
			Row = 0,
			selectedPart = selectedPart,
		}),
		e(buttonsRow, {
			axisEnum = Enum.Axis.Y,
			buttonLabels = { "Top", "Y Center", "Bottom" },
			positionAlphas = { 1, 0, -1 },
			Row = 1,
			selectedPart = selectedPart,
		}),
		e(buttonsRow, {
			axisEnum = Enum.Axis.Z,
			buttonLabels = { "Front", "Z Center", "Back" },
			positionAlphas = { -1, 0, 1 },
			Row = 2,
			selectedPart = selectedPart,
		}),
	})
end

return alignButtonsPanel
