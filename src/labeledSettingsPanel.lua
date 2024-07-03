local packages = script.Parent.Parent.Packages
local React = require(packages.React)
local StudioComponents = require(packages.StudioComponents)

local e = React.createElement

function settingLabel(props)
	local text = props.Text
	local textColorStyle = props.TextColorStyle
	local layoutOrder = props.LayoutOrder
	local size = props.Size and UDim2.new(1, 0, 0, props.Size.Y.Offset) or nil

	return e(StudioComponents.Label, {
		Text = text,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = size,
		TextColorStyle = textColorStyle,
		LayoutOrder = layoutOrder,
	})
end

type settingComponentEntry = {
	LabelText: string,
	element: () -> any,
	props: { [string]: any },
}

type settingComponents = { settingComponentEntry }

function labeledSettingsPanel(props)
	local settingComponents: settingComponents = props.settingComponents
	local defaultSplit = props.defaultSplit or 0.25
	local paddingTop = props.paddingTop or 2
	local paddingBottom = props.paddingBottom or 2
	local listPadding = props.listPadding or 2
	local position = props.Position
	local layoutOrder = props.LayoutOrder
	local splitterDivision, setSplitterDivision = React.useState(defaultSplit)
	local contentHeight = paddingTop + paddingBottom

	local side0 = {
		e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 2),
		}),
		e("UIPadding", {
			PaddingTop = UDim.new(0, paddingTop),
			PaddingBottom = UDim.new(0, paddingBottom),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
		}),
	}
	local side1 = {
		e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, listPadding),
		}),
		e("UIPadding", {
			PaddingTop = UDim.new(0, paddingTop),
			PaddingBottom = UDim.new(0, paddingBottom),
		}),
	}

	for i, settingComponent in settingComponents do
		local componentProps = settingComponent.props
		contentHeight += componentProps.Size.Y.Offset + if i > 1 then listPadding else 0

		table.insert(
			side0,
			e(settingLabel, {
				Text = settingComponent.LabelText,
				TextColorStyle = componentProps.Disabled and Enum.StudioStyleGuideColor.DimmedText or Enum.StudioStyleGuideColor.MainText,
				Size = componentProps.Size,
				LayoutOrder = i,
			})
		)

		settingComponent.props.LayoutOrder = i
		table.insert(side1, e(settingComponent.element, settingComponent.props))
	end

	return e(StudioComponents.Splitter, {
		LayoutOrder = layoutOrder,
		Position = position,
		Size = UDim2.new(1, 0, 0, contentHeight),
		Alpha = splitterDivision,
		OnChanged = setSplitterDivision,
	}, {
		Side0 = e(React.Fragment, {}, side0),
		Side1 = e(React.Fragment, {}, side1),
	})
end

return labeledSettingsPanel
