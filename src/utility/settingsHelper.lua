--!strict
local packages = script.Parent.Parent.Parent.Packages
local Janitor = require(packages.Janitor)

local source = script.Parent.Parent
local selectionHelper = require(source.utility.selectionHelper)
local types = require(source.types)

local janitor = Janitor.new()
local constraintSettingsChangedEvent = janitor:Add(Instance.new("BindableEvent"))
local repeatSettingsChangedEvent = janitor:Add(Instance.new("BindableEvent"))
local selectionSettingsChangedEvent = janitor:Add(Instance.new("BindableEvent"))

local settingsHelper = {}

settingsHelper.constraintSettingsChanged = constraintSettingsChangedEvent.Event
settingsHelper.repeatSettingsChanged = repeatSettingsChangedEvent.Event
settingsHelper.selectionSettingsChanged = selectionSettingsChangedEvent.Event
settingsHelper.janitor = janitor

type Selection = { Instance }

type Mixed = "~"

type XConstraint = "Left" | "Right" | "Left and Right" | "Center" | "Scale" | Mixed
type YConstraint = "Top" | "Bottom" | "Top and Bottom" | "Center" | "Scale" | Mixed
type ZConstraint = "Front" | "Back" | "Back and Front" | "Center" | "Scale" | Mixed

export type ConstraintSettings = {
	x: XConstraint?,
	y: YConstraint?,
	z: ZConstraint?,
}

type OverrideString = "[ Multiple ]"

export type ConstraintDefaultOverrides = {
	x: OverrideString?,
	y: OverrideString?,
	z: OverrideString?,
}

local function updateConstraintSettingForSelection(axis: types.AxisString, selection: Selection): (string?, OverrideString?)
	local attributeName = axis .. "Constraint"

	if #selection == 0 then
		return
	end

	if #selection == 1 then
		return selection[1]:GetAttribute(attributeName) :: string, nil
	else
		local constraint: string = selection[1]:GetAttribute(attributeName)
		local defaultOverride: OverrideString = nil

		for i = 2, #selection do
			if selection[i]:GetAttribute(attributeName) ~= constraint then
				constraint = "~"
				defaultOverride = "[ Multiple ]"
			end
		end

		return constraint, defaultOverride
	end
end

local function updateConstraintSettingsValid(selection)
	local XConstraint, xDefault = updateConstraintSettingForSelection("x", selection)
	local YConstraint, yDefault = updateConstraintSettingForSelection("y", selection)
	local ZConstraint, zDefault = updateConstraintSettingForSelection("z", selection)

	local constraints: ConstraintSettings = {
		x = XConstraint :: XConstraint,
		y = YConstraint :: YConstraint,
		z = ZConstraint :: ZConstraint,
	}

	local defaultOverrides: ConstraintDefaultOverrides = {
		x = xDefault :: OverrideString,
		y = yDefault :: OverrideString,
		z = zDefault :: OverrideString,
	}

	constraintSettingsChangedEvent:Fire(true, constraints, defaultOverrides)
end

local function updateConstraintSettingsInvalid()
	constraintSettingsChangedEvent:Fire(false, {}, {})
end

export type RepeatSettings = {
	repeatKind: ("To Extents" | "Fixed Amount")? | Mixed?,
	showExtentsSettings: boolean? | Mixed?,
	showFixedSettings: boolean? | Mixed?,
	stretchToFit: boolean? | Mixed?,
	repeatAmountPositive: number? | Mixed?,
	repeatAmountNegative: number? | Mixed?,
}

export type RepeatDefaultOverrides = {
	repeatKind: OverrideString?,
	showExtentsSettings: OverrideString?,
	showFixedSettings: OverrideString?,
	stretchToFit: OverrideString?,
	repeatAmountPositive: OverrideString?,
	repeatAmountNegative: OverrideString?,
}

settingsHelper.getRepeatSettings = function(instance: BasePart | Folder, axis: types.AxisString): RepeatSettings
	local repeatSettings = {}

	local repeatKind = instance:GetAttribute(axis .. "RepeatKind")
	repeatSettings.repeatKind = repeatKind
	if repeatKind == "To Extents" then
		repeatSettings.showExtentsSettings = true
		repeatSettings.stretchToFit = instance:GetAttribute(axis .. "StretchToFit") == true and true or false
		return repeatSettings
	elseif repeatKind == "Fixed Amount" then
		repeatSettings.showFixedSettings = true
		repeatSettings.repeatAmountPositive = instance:GetAttribute(axis .. "RepeatAmountPositive")
		repeatSettings.repeatAmountNegative = instance:GetAttribute(axis .. "RepeatAmountNegative")
		return repeatSettings
	else
		return repeatSettings
	end
end

local function updateRepeatSettingForSelection(axis: types.AxisString, selection: Selection): (RepeatSettings, RepeatDefaultOverrides)
	if #selection == 1 then
		local repeatSettings = settingsHelper.getRepeatSettings(selection[1] :: BasePart | Folder, axis)
		return repeatSettings, {}
	else
		local repeatSettings = settingsHelper.getRepeatSettings(selection[1] :: BasePart | Folder, axis)
		local defaultOverrides = {}

		for i = 2, #selection do
			local compareSettings = settingsHelper.getRepeatSettings(selection[i] :: BasePart | Folder, axis)

			for settingName, settingValue in compareSettings do
				if repeatSettings[settingName] and repeatSettings[settingName] ~= settingValue then
					repeatSettings[settingName] = "~"
					defaultOverrides[settingName] = "[ Multiple ]"
				elseif not repeatSettings[settingName] then
					repeatSettings[settingName] = settingValue
				end
			end
		end

		return repeatSettings, defaultOverrides
	end
end

local function updateRepeatSettingsValid(selection)
	local xRepeat, xDefault = updateRepeatSettingForSelection("x", selection)
	local yRepeat, yDefault = updateRepeatSettingForSelection("y", selection)
	local zRepeat, zDefault = updateRepeatSettingForSelection("z", selection)

	local repeats = {
		x = xRepeat,
		y = yRepeat,
		z = zRepeat,
	}

	local defaultOverrides = {
		x = xDefault,
		y = yDefault,
		z = zDefault,
	}

	repeatSettingsChangedEvent:Fire(true, repeats, defaultOverrides)
end

local function updateRepeatSettingsInvalid()
	repeatSettingsChangedEvent:Fire(false, {}, {})
end

export type SelectionSettings = {
	updateChildrenContinuously: boolean | Mixed,
}
local function updateSelectionSettingsForSelection(selection)
	local updateChildrenContinuously

	updateChildrenContinuously = selection[1]:GetAttribute("UpdateChildrenContinuously")

	if #selection > 1 then
		for i = 2, #selection do
			local thisUpdateChildrenContinuously = selection[i]:GetAttribute("UpdateChildrenContinuously")
			if thisUpdateChildrenContinuously ~= updateChildrenContinuously then
				updateChildrenContinuously = "~"
				break
			end
		end
	end

	return {
		updateChildrenContinuously = updateChildrenContinuously,
	}
end

local function updateSelectionSettingsValid(selection)
	local settings = updateSelectionSettingsForSelection(selection)
	selectionSettingsChangedEvent:Fire(true, settings)
end

local function updateSelectionSettingsInvalid()
	selectionSettingsChangedEvent:Fire(false, {})
end

function settingsHelper.listenForChanges()
	janitor:Add(selectionHelper.bindToContainedSelection(function(selection)
		updateConstraintSettingsValid(selection)
		updateRepeatSettingsValid(selection)
	end, function()
		updateConstraintSettingsInvalid()
		updateRepeatSettingsInvalid()
	end))

	janitor:Add(selectionHelper.bindToAnyContainedChanged(function()
		local containedSelection = selectionHelper.getContainedSelection()
		if #containedSelection == 0 then
			return
		end
		updateConstraintSettingsValid(containedSelection)
		updateRepeatSettingsValid(containedSelection)
	end))

	janitor:Add(selectionHelper.bindToContainerSelection(function(selection: Selection)
		updateSelectionSettingsValid(selection)
	end, function()
		updateSelectionSettingsInvalid()
	end))

	janitor:Add(selectionHelper.bindToAnyContainerChanged(function()
		local containerSelection = selectionHelper.getContainerSelection()
		if #containerSelection == 0 then
			return
		end
		updateSelectionSettingsValid(containerSelection)
	end))
end

function settingsHelper.stopListening()
	janitor:Cleanup()
end

return settingsHelper
