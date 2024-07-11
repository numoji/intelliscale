--!strict
local packages = script.Parent.Parent.Parent.Packages
local React = require(packages.React)
local StudioComponents = require(packages.StudioComponents)

local source = script.Parent.Parent
local attributeHelper = require(source.utility.attributeHelper)
local changeHistoryHelper = require(source.utility.changeHistoryHelper)
local selectionHelper = require(source.utility.selectionHelper)
local settingsHelper = require(source.utility.settingsHelper)

local components = script.Parent
local labeledSettingsPanel = require(components.labeledSettingsPanel)

local e = React.createElement

local function getSettingSetter(settingName: string)
	return function(newValue)
		changeHistoryHelper.recordUndoChange(function()
			for _, instance in selectionHelper.getContainedAndContainerSelection() do
				if newValue == nil then
					local currentValue = instance:GetAttribute(settingName)
					newValue = not currentValue
				end

				attributeHelper.setAttribute(instance, settingName, newValue)
			end
		end)
	end
end

type SelectionSettings = settingsHelper.SelectionSettings
type SelectionState = {
	disabled: boolean,
	selectionSettings: SelectionSettings,
}

local function selectionSettingsPanel(props)
	local layoutOrder = props.LayoutOrder

	local selectionSettingsState: SelectionState, setSelectionSettingsState = React.useState({
		disabled = true,
		selectionSettings = {} :: SelectionSettings,
	})

	React.useEffect(function()
		local selectionSettingsChangedConnection = settingsHelper.selectionSettingsChanged:Connect(
			function(isSelectionValid, selectionSettings)
				setSelectionSettingsState({
					disabled = not isSelectionValid,
					selectionSettings = selectionSettings :: SelectionSettings,
				})
			end
		)

		return function()
			selectionSettingsChangedConnection:Disconnect()
		end
	end)

	local selectionSettings = selectionSettingsState.selectionSettings
	local disabled = selectionSettingsState.disabled

	return e(labeledSettingsPanel, {
		LayoutOrder = layoutOrder,
		settingComponents = {
			{
				LabelText = "Update Children Continuously",
				element = StudioComponents.Checkbox,
				props = {
					Size = UDim2.new(1, 0, 0, StudioComponents.Constants.DefaultToggleHeight),
					Label = "",
					ButtonAlignment = Enum.HorizontalAlignment.Right,
					Value = if selectionSettings.updateChildrenContinuously ~= "~"
						then selectionSettings.updateChildrenContinuously or false
						else nil,
					Disabled = disabled,
					OnChanged = getSettingSetter("UpdateChildrenContinuously"),
				},
			},
		},
	})
end

return selectionSettingsPanel
