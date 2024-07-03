local Selection = game:GetService("Selection")

local packages = script.Parent.Parent.Packages
local React = require(packages.React)
local StudioComponents = require(packages.StudioComponents)

local source = script.Parent
local changeHistoryHelper = require(source.changeHistoryHelper)
local labeledSettingsPanel = require(source.labeledSettingsPanel)
local settingsHelper = require(source.settingsHelper)

local e = React.createElement

local function setSelectionAttribute(attribute, value)
	changeHistoryHelper.recordUndoChange(function()
		for _, instance in Selection:Get() do
			if instance:IsA("BasePart") then
				instance:SetAttribute(attribute, value)
			end
		end
	end)
end

local function getSettingSetter(axis, settingName)
	return function(newValue)
		changeHistoryHelper.recordUndoChange(function()
			for _, instance in Selection:Get() do
				if instance:IsA("BasePart") then
					if newValue == nil then
						local currentValue = instance:GetAttribute(axis .. settingName)
						newValue = not currentValue
					end

					instance:SetAttribute(axis .. settingName, newValue)
					settingsHelper.updateAllRepeatSettingsForSelection()
				end
			end
		end)
	end
end

function repeatAxisSettings(props)
	local axis = props.axis
	local layoutOrder = props.LayoutOrder

	local repeatState, setRepeatState = React.useState({
		disabled = true,
		repeats = {},
		defaultOverrides = {},
	})

	React.useEffect(function()
		local repeatSettingsChangedConnection = settingsHelper.repeatSettingsChanged:Connect(
			function(isSelectionValid, repeats, defaultOverrides)
				setRepeatState({
					disabled = not isSelectionValid,
					repeats = repeats[axis] or {},
					defaultOverrides = defaultOverrides[axis] or {},
				})
			end
		)

		settingsHelper.updateAllRepeatSettingsForSelection()

		return function()
			repeatSettingsChangedConnection:Disconnect()
		end
	end)

	local repeats = repeatState.repeats
	local defaultOverrides = repeatState.defaultOverrides
	local disabled = repeatState.disabled

	local settingComponents: { any } = {}
	table.insert(settingComponents, {
		LabelText = "Repeat Kind",
		element = StudioComponents.Dropdown,
		props = {
			Items = { "To Extents", "Fixed Amount" },
			ClearButton = true,
			Size = UDim2.new(1, 0, 0, StudioComponents.Constants.DefaultDropdownHeight),
			DefaultText = defaultOverrides.repeatKind or "None",
			Disabled = disabled,
			SelectedItem = repeats.repeatKind,
			OnItemSelected = function(newItem)
				setSelectionAttribute(axis .. "RepeatKind", newItem)
				if newItem == nil then
					setSelectionAttribute(axis .. "StretchToFit", nil)
					setSelectionAttribute(axis .. "RepeatAmountPositive", nil)
					setSelectionAttribute(axis .. "RepeatAmountNegative", nil)
				end
			end,
		},
	})

	if repeats.showExtentsSettings then
		table.insert(settingComponents, {
			LabelText = "Stretch to Fit",
			element = StudioComponents.Checkbox,
			props = {
				Size = UDim2.new(1, 0, 0, StudioComponents.Constants.DefaultToggleHeight),
				Label = "",
				ButtonAlignment = Enum.HorizontalAlignment.Right,
				Value = if repeats.stretchToFit ~= "~" then repeats.stretchToFit or false else nil,
				Disabled = disabled,
				OnChanged = getSettingSetter(axis, "StretchToFit"),
			},
		})
	end

	if repeats.showFixedSettings then
		table.insert(settingComponents, {
			LabelText = "Amount +",
			element = StudioComponents.NumericInput,
			props = {
				Size = UDim2.new(1, 0, 0, StudioComponents.Constants.DefaultInputHeight),
				PlaceholderText = defaultOverrides.repeatAmountPositive,
				Value = if repeats.repeatAmountPositive ~= "~" then repeats.repeatAmountPositive or 0 else nil,
				Min = 0,
				Arrows = true,
				Disabled = disabled,
				OnValidChanged = getSettingSetter(axis, "RepeatAmountPositive"),
			},
		})

		table.insert(settingComponents, {
			LabelText = "Amount -",
			element = StudioComponents.NumericInput,
			props = {
				Size = UDim2.new(1, 0, 0, StudioComponents.Constants.DefaultInputHeight),
				PlaceholderText = defaultOverrides.repeatAmountPositive,
				Value = if repeats.repeatAmountNegative ~= "~" then repeats.repeatAmountNegative or 0 else nil,
				Min = -math.huge,
				Max = 0,
				Arrows = true,
				Disabled = disabled,
				OnValidChanged = getSettingSetter(axis, "RepeatAmountNegative"),
			},
		})
	end

	return e("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = layoutOrder,
	}, {
		e(StudioComponents.Label, {
			Text = `{string.upper(axis)} Repeat Settings`,
			Size = UDim2.new(1, 0, 0, 24),
			Position = UDim2.fromOffset(10, 0),
			TextColorStyle = repeatState.disabled and Enum.StudioStyleGuideColor.DimmedText or Enum.StudioStyleGuideColor.MainText,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 0,
		}),
		e(labeledSettingsPanel, {
			Position = UDim2.fromOffset(0, 24),
			settingComponents = settingComponents,
		}),
	})
end
repeatAxisSettings = React.memo(repeatAxisSettings)

local function repeatsPanel(props)
	return e("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0),
		LayoutOrder = props.LayoutOrder,
	}, {
		e("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 4),
		}),
		e(repeatAxisSettings, {
			axis = "x",
			LayoutOrder = 0,
		}),
		e(repeatAxisSettings, {
			axis = "y",
			LayoutOrder = 1,
		}),
		e(repeatAxisSettings, {
			axis = "z",
			LayoutOrder = 2,
		}),
	})
end

return repeatsPanel
