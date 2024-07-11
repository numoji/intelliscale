--!strict
local packages = script.Parent.Parent.Parent.Packages
local React = require(packages.React)
local StudioComponents = require(packages.StudioComponents)

local components = script.Parent
local constraintsPanel = require(components.constraintsPanel)
local containerConversionButton = require(components.containerConversionButton)
local repeatsPanel = require(components.repeatsPanel)
local selectionSettingsPanel = require(components.selectionSettingsPanel)

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
		e(selectionSettingsPanel, { LayoutOrder = 3 }),
		e(containerConversionButton, { LayoutOrder = 4 }),
	})
end
