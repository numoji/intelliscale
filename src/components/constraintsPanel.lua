--!strict
local React = require(script.Parent.Parent.Parent.Packages.React)
local StudioComponents = require(script.Parent.Parent.Parent.Packages.StudioComponents)

local constraintSettings = require(script.Parent.Parent.utility.settingsHelper.constraintSettings)
local settingsHelper = require(script.Parent.Parent.utility.settingsHelper)
local types = require(script.Parent.Parent.types)

local labeledSettingsPanel = require(script.Parent.labeledSettingsPanel)

local e = React.createElement

local minAndMaxNamesByAxis = {
	x = { "Left", "Right" },
	y = { "Top", "Bottom" },
	z = { "Front", "Back" },
}

function getConstraintSettingProps(
	axis: types.AxisString,
	settings: constraintSettings.MultipleSettingGroups?,
	overrides: constraintSettings.MixedDisplayOverride?
)
	local min = minAndMaxNamesByAxis[axis][1]
	local max = minAndMaxNamesByAxis[axis][2]

	return {
		Items = { min, max, `{min} and {max}`, "Center", "Scale" },
		Size = UDim2.new(1, 0, 0, StudioComponents.Constants.DefaultDropdownHeight),
		-- ClearButton = true,
		DefaultText = overrides and overrides[axis] or "None",
		SelectedItem = settings and settings[axis] or nil,
		OnItemSelected = settingsHelper.createAttributeSetter((axis .. "Constraint") :: types.SettingAttribute),
	}
end

type ConstraintsState = {
	disabled: boolean,
	settings: constraintSettings.MultipleSettingGroups?,
	overrides: constraintSettings.MixedDisplayOverride?,
}
return function(props)
	local layoutOrder = props.LayoutOrder

	local constraintsState: ConstraintsState, setConstraintState = React.useState({
		disabled = true,
		settings = {},
		overrides = {},
	} :: ConstraintsState)

	React.useEffect(function()
		local settingsChangedConnection = settingsHelper.selectionSettingsChanged:Connect(
			function(selectionSettings: settingsHelper.SelectionSettings?, displayOverrides: settingsHelper.DisplayOverrides?)
				local constraintSettings = selectionSettings and selectionSettings.constraintSettings
				local overrides = displayOverrides and displayOverrides.constraintSettings

				setConstraintState({
					disabled = constraintSettings == nil,
					settings = constraintSettings,
					overrides = overrides,
				})
			end
		)

		return function()
			settingsChangedConnection:Disconnect()
		end
	end, {})

	local settings = constraintsState.settings
	local overrides = constraintsState.overrides
	local disabled = constraintsState.disabled

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
					LabelText = "X Constraint",
					element = StudioComponents.Dropdown,
					props = getConstraintSettingProps("x", settings, overrides),
				},
				{
					LabelText = "Y Constraint",
					element = StudioComponents.Dropdown,
					props = getConstraintSettingProps("y", settings, overrides),
				},
				{
					LabelText = "Z Constraint",
					element = StudioComponents.Dropdown,
					props = getConstraintSettingProps("z", settings, overrides),
				},
			},
		}),
	})
end
