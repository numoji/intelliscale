--!strict
local Janitor = require(script.Parent.Parent.Parent.Packages.Janitor)

local selectionHelper = require(script.Parent.selectionHelper)

local attributeHelper = require(script.Parent.attributeHelper)
local changeHistoryHelper = require(script.Parent.changeHistoryHelper)
local types = require(script.Parent.Parent.types)

local constraintSettings = require(script.constraintSettings)
local repeatSettings = require(script.repeatSettings)
local sizeSettings = require(script.sizeSettings)

local janitor = Janitor.new()
local selectionSettingsChanged = Instance.new("BindableEvent")

local settingsHelper = {}

settingsHelper.selectionSettingsChanged = selectionSettingsChanged.Event
settingsHelper.janitor = janitor

type Selection = types.Selection
type Mixed = types.Mixed

type AnyMultipleSettingsGroup =
	constraintSettings.MultipleSettingGroups
	| repeatSettings.MultipleSettingGroups
	| sizeSettings.MultipleSettingGroups

export type SelectionSettings = {
	constraintSettings: constraintSettings.MultipleSettingGroups?,
	repeatSettings: repeatSettings.MultipleSettingGroups?,
	sizeSettings: sizeSettings.MultipleSettingGroups?,
}

export type DisplayOverrides = {
	constraintSettings: constraintSettings.MixedDisplayOverride,
	repeatSettings: repeatSettings.MixedDisplayOverride,
}

local function CombineSettingsRecursive(settingsToCombine: { { [string]: any } }): ({ [string]: any }, { [string]: any }?)
	local combinedSettings: { [string]: any } = {}
	local displayOverrides: { [string]: any }

	for setting, value in settingsToCombine[1] do
		if type(value) ~= "table" or #settingsToCombine < 2 then
			combinedSettings[setting] = value
			continue
		end

		local subSettingsToCombine = { value }
		for i = 2, #settingsToCombine do
			local subSettings = settingsToCombine[i][setting]
			if subSettings then
				table.insert(subSettingsToCombine, subSettings)
			end
		end

		local combined, overrides = CombineSettingsRecursive(subSettingsToCombine)
		combinedSettings[setting] = combined
		if overrides then
			displayOverrides = displayOverrides or {}
			displayOverrides[setting] = overrides
		end
	end

	if #settingsToCombine < 2 then
		return combinedSettings
	end

	for i = 2, #settingsToCombine do
		local settings = settingsToCombine[i]
		-- If its a table it's already been recursively combined
		if type(settings) == "table" then
			continue
		end

		for setting, value in settings do
			if combinedSettings[setting] == nil then
				combinedSettings[setting] = value
			elseif combinedSettings[setting] ~= setting then
				combinedSettings[setting] = "~"
				displayOverrides = displayOverrides or {}
				displayOverrides[setting] = "[ Multiple ]"
			end
		end
	end

	return combinedSettings, displayOverrides
end

local function getSelectionSettings(selection): (SelectionSettings?, DisplayOverrides?)
	local settingsToCombine = {}
	for _, instance in selection do
		local constraintSetting = constraintSettings.getSettingGroup(instance)
		local repeatSetting = repeatSettings.getSettingGroup(instance)
		local sizeSetting = sizeSettings.getSettingGroup(instance)

		table.insert(settingsToCombine, {
			constraintSettings = constraintSetting,
			repeatSettings = repeatSetting,
			sizeSettings = sizeSetting,
		})
	end

	if #settingsToCombine == 0 then
		return nil, nil
	elseif #settingsToCombine == 1 then
		return settingsToCombine[1], nil
	else
		return CombineSettingsRecursive(settingsToCombine)
	end
end

local function updateSelectionSettings(selection: Selection)
	local selectionSettings, displayOverrides = getSelectionSettings(selection)
	selectionSettingsChanged:Fire(selectionSettings, displayOverrides)
end

local function clearSelectionSettings()
	selectionSettingsChanged:Fire()
end

function settingsHelper.listenForChanges()
	janitor:Add(
		selectionHelper.addSelectionChangeCallback(
			selectionHelper.callbackDicts.containerOrContained,
			updateSelectionSettings,
			clearSelectionSettings
		)
	)

	janitor:Add(
		selectionHelper.addPropertyChangeCallback(
			selectionHelper.callbackDicts.containerOrContained,
			{ "Attributes", "Parent" },
			function(_, selection)
				updateSelectionSettings(selection)
			end
		)
	)

	return janitor
end

settingsHelper.None = "__NONE__"
function settingsHelper.setSelectionAttributes(attributes: { [types.SettingAttribute]: any })
	changeHistoryHelper.recordUndoChange(function()
		local selection = selectionHelper.getUnvalidatedSelection()
		for _, instance in selection do
			local assignableAttributesSet = {}
			constraintSettings.addAssignableAttributes(instance, assignableAttributesSet)
			repeatSettings.addAssignableAttributes(instance, assignableAttributesSet)
			sizeSettings.addAssignableAttributes(instance, assignableAttributesSet)

			for attribute: types.SettingAttribute, value in attributes do
				if assignableAttributesSet[attribute] then
					value = if value == settingsHelper.None then nil else value
					attributeHelper.setAttribute(instance, attribute, value)
				end
			end
		end
	end)
end

function settingsHelper.setSelectionAttribute(attribute: types.SettingAttribute, value: any)
	changeHistoryHelper.recordUndoChange(function()
		local selection = selectionHelper.getUnvalidatedSelection()
		for _, instance in selection do
			local assignableAttributesSet = {}
			constraintSettings.addAssignableAttributes(instance, assignableAttributesSet)
			repeatSettings.addAssignableAttributes(instance, assignableAttributesSet)
			sizeSettings.addAssignableAttributes(instance, assignableAttributesSet)
			if assignableAttributesSet[attribute] then
				attributeHelper.setAttribute(instance, attribute, value)
			end
		end
	end)
end

function settingsHelper.createAttributeSetter(attribute: types.SettingAttribute)
	return function(value: any)
		settingsHelper.setSelectionAttribute(attribute, value)
	end
end

return settingsHelper
