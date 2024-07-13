--!strict
local React = require(script.Parent.Parent.Parent.Packages.React)
local StudioComponents = require(script.Parent.Parent.Parent.Packages.StudioComponents)

local repeatSettings = require(script.Parent.Parent.utility.settingsHelper.repeatSettings)
local settingsHelper = require(script.Parent.Parent.utility.settingsHelper)
local types = require(script.Parent.Parent.types)

local labeledSettingsPanel = require(script.Parent.labeledSettingsPanel)

local e = React.createElement

type RepeatState = {
	disabled: boolean,
	settings: repeatSettings.MultipleSettingGroups?,
	overrides: repeatSettings.MixedDisplayOverride?,
}

local function addLabeledSettingComponents(
	axis: types.AxisString,
	axisSettings: repeatSettings.MultipleAxisSetting?,
	axisOverrides: repeatSettings.MixedDisplayOverrideAxis?,
	components: { any }
)
	table.insert(components, {
		LabelText = string.upper(axis) .. " Repeat Kind",
		element = StudioComponents.Dropdown,
		props = {
			Items = { "To Extents", "Fixed Amount" },
			ClearButton = true,
			Size = UDim2.new(1, 0, 0, StudioComponents.Constants.DefaultDropdownHeight),
			DefaultText = axisOverrides and axisOverrides.settingValue or "None",
			SelectedItem = axisSettings and axisSettings.settingValue,
			OnItemSelected = function(newItem)
				if newItem == nil then
					settingsHelper.setSelectionAttributes({
						[(axis .. "RepeatKind") :: types.SettingAttribute] = settingsHelper.None,
						[(axis .. "StretchToFit") :: types.SettingAttribute] = settingsHelper.None,
						[(axis .. "RepeatAmountPositive") :: types.SettingAttribute] = settingsHelper.None,
						[(axis .. "RepeatAmountNegative") :: types.SettingAttribute] = settingsHelper.None,
					})
				else
					settingsHelper.setSelectionAttribute((axis .. "RepeatKind") :: types.SettingAttribute, newItem)
				end
			end,
		},
	})

	if not axisSettings then
		return components
	end

	if axisSettings.settingValue == "To Extents" or axisSettings.settingValue == "~" then
		table.insert(components, {
			LabelText = "Stretch to Fit",
			element = StudioComponents.Checkbox,
			props = {
				Size = UDim2.new(1, 0, 0, StudioComponents.Constants.DefaultToggleHeight),
				Label = "",
				ButtonAlignment = Enum.HorizontalAlignment.Right,
				Value = if axisSettings.settingValue ~= "~" then axisSettings.childrenSettings.stretchToFit else nil,
				OnChanged = function()
					settingsHelper.setSelectionAttribute(
						(axis .. "StretchToFit") :: types.SettingAttribute,
						if axisSettings.settingValue ~= "~" then not axisSettings.childrenSettings.stretchToFit else false
					)
				end,
			},
		})
	end

	if axisSettings.settingValue == "Fixed Amount" or axisSettings.settingValue == "~" then
		table.insert(components, {
			LabelText = string.upper(axis) .. "+",
			element = StudioComponents.NumericInput,
			props = {
				Size = UDim2.new(1, 0, 0, StudioComponents.Constants.DefaultInputHeight),
				PlaceholderText = if axisSettings.childrenSettings.repeatAmountPositive == "~" then "-" else nil,
				Value = if axisSettings.childrenSettings.repeatAmountPositive ~= "~"
					then axisSettings.childrenSettings.repeatAmountPositive
					else nil,
				Min = 0,
				Arrows = true,
				OnValidChanged = settingsHelper.createAttributeSetter((axis .. "RepeatAmountPositive") :: types.SettingAttribute),
			},
		})

		table.insert(components, {
			LabelText = string.upper(axis) .. "-",
			element = StudioComponents.NumericInput,
			props = {
				Size = UDim2.new(1, 0, 0, StudioComponents.Constants.DefaultInputHeight),
				PlaceholderText = if axisSettings.childrenSettings.repeatAmountPositive == "~" then "-" else nil,
				Value = if axisSettings.childrenSettings.repeatAmountNegative ~= "~"
					then axisSettings.childrenSettings.repeatAmountNegative
					else nil,
				Min = -math.huge,
				Max = 0,
				Arrows = true,
				OnValidChanged = settingsHelper.createAttributeSetter((axis .. "RepeatAmountNegative") :: types.SettingAttribute),
			},
		})
	end

	return components
end

function repeatsPanel(props)
	local layoutOrder = props.LayoutOrder

	local repeatState: RepeatState, setRepeatState = React.useState({
		disabled = true,
		settings = nil,
		overrides = nil,
	} :: RepeatState)

	React.useEffect(function()
		local settingsChangedConnection = settingsHelper.selectionSettingsChanged:Connect(
			function(selectionSettings: settingsHelper.SelectionSettings?, displayOverrides: settingsHelper.DisplayOverrides?)
				local repeatSettings = selectionSettings and selectionSettings.repeatSettings
				local overrides = displayOverrides and displayOverrides.repeatSettings

				local state: RepeatState = {
					disabled = repeatSettings == nil,
					settings = repeatSettings,
					overrides = overrides,
				}

				setRepeatState(state)
			end
		)

		return function()
			settingsChangedConnection:Disconnect()
		end
	end, {})

	local disabled = repeatState.disabled
	local settings = repeatState.settings
	local overrides = repeatState.overrides

	local settingComponents: { any } = {}
	addLabeledSettingComponents("x", settings and settings.x, overrides and overrides.x or nil, settingComponents)
	addLabeledSettingComponents("y", settings and settings.y, overrides and overrides.y or nil, settingComponents)
	addLabeledSettingComponents("z", settings and settings.z, overrides and overrides.z or nil, settingComponents)

	return e("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = layoutOrder,
		Visible = not disabled,
	}, {
		e(labeledSettingsPanel, {
			Position = UDim2.fromOffset(0, 0),
			settingComponents = settingComponents,
		}),
	})
end
repeatsPanel = React.memo(repeatsPanel)

return repeatsPanel
