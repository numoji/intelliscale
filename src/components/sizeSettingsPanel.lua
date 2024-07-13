--!strict
local React = require(script.Parent.Parent.Parent.Packages.React)
local StudioComponents = require(script.Parent.Parent.Parent.Packages.StudioComponents)

local settingsHelper = require(script.Parent.Parent.utility.settingsHelper)
local sizeSettings = require(script.Parent.Parent.utility.settingsHelper.sizeSettings)

local labeledSettingsPanel = require(script.Parent.labeledSettingsPanel)

local e = React.createElement

type SelectionState = {
	disabled: boolean,
	settings: sizeSettings.MultipleSettingGroups?,
}

local function sizeSelectionPanel(props)
	local layoutOrder = props.LayoutOrder

	local sizeState: SelectionState, setSelectionSettingsState = React.useState({
		disabled = true,
		settings = nil :: sizeSettings.MultipleSettingGroups?,
	} :: SelectionState)

	React.useEffect(function()
		local selectionSettingsChangedConnection = settingsHelper.selectionSettingsChanged:Connect(
			function(selectionSettings: settingsHelper.SelectionSettings?)
				local sizeSettings = selectionSettings and selectionSettings.sizeSettings

				setSelectionSettingsState({
					disabled = sizeSettings == nil,
					settings = sizeSettings,
				})
			end
		)

		return function()
			selectionSettingsChangedConnection:Disconnect()
		end
	end, {})

	local settings = sizeState.settings
	local disabled = sizeState.disabled

	return e("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = layoutOrder,
		Visible = not disabled,
	}, {
		e(labeledSettingsPanel, {
			LayoutOrder = layoutOrder,
			Visible = not disabled,
			settingComponents = {
				{
					LabelText = "Update Continuous",
					element = StudioComponents.Checkbox,
					props = {
						Size = UDim2.new(1, 0, 0, StudioComponents.Constants.DefaultToggleHeight),
						Label = "",
						ButtonAlignment = Enum.HorizontalAlignment.Right,
						Value = if settings and settings.updateContinuous ~= "~" then settings.updateContinuous else nil,
						OnChanged = function()
							settingsHelper.setSelectionAttribute(
								"updateContinuous",
								if settings and settings.updateContinuous ~= "~" then not settings.updateContinuous else false
							)
						end,
					},
				},
			},
		}),
	})
end

return sizeSelectionPanel
