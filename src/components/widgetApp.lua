--!strict
local React = require(script.Parent.Parent.Parent.Packages.React)
local StudioComponents = require(script.Parent.Parent.Parent.Packages.StudioComponents)

local alignButtonsPanel = require(script.Parent.alignButtonsPanel)
local constraintsPanel = require(script.Parent.constraintsPanel)
local containerConversionButton = require(script.Parent.containerConversionButton)
local repeatsPanel = require(script.Parent.repeatsPanel)
local sizeSettingsPanel = require(script.Parent.sizeSettingsPanel)

local e = React.createElement

return function(_props)
	return e(StudioComponents.Background, {}, {
		e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		e(constraintsPanel, { LayoutOrder = 1 }),
		e(repeatsPanel, { LayoutOrder = 2 }),
		e(sizeSettingsPanel, { LayoutOrder = 3 }),
		e(alignButtonsPanel, { LayoutOrder = 4 }),
		e(containerConversionButton, { LayoutOrder = 5 }),
	})
end
