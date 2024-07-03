local Selection = game:GetService("Selection")

local constraintSettingsChangedEvent = Instance.new("BindableEvent")
local repeatSettingsChangedEvent = Instance.new("BindableEvent")

local function isSelectionValid()
	local selection = Selection:Get()

	if #selection == 0 then
		return false
	end

	for _, instance in selection do
		if not instance:IsA("BasePart") then
			return false
		end
	end

	return true
end

local function updateConstraintSettingForSelection(axis)
	local attributeName = axis .. "Constraint"

	local selection = Selection:Get()
	if #selection == 1 then
		return selection[1]:GetAttribute(attributeName)
	else
		local constraint = selection[1]:GetAttribute(attributeName)
		local defaultOverride

		for i = 2, #selection do
			if selection[i]:GetAttribute(attributeName) ~= constraint then
				constraint = "~"
				defaultOverride = "[ Multiple ]"
			end
		end

		return constraint, defaultOverride
	end
end

local function updateAllConstraintSettingsForSelection()
	if not isSelectionValid() then
		constraintSettingsChangedEvent:Fire(false, {}, {})
		return
	end

	local xConstraint, xDefault = updateConstraintSettingForSelection("x")
	local yConstraint, yDefault = updateConstraintSettingForSelection("y")
	local zConstraint, zDefault = updateConstraintSettingForSelection("z")

	local constraints = {
		x = xConstraint,
		y = yConstraint,
		z = zConstraint,
	}

	local defaultOverrides = {
		x = xDefault,
		y = yDefault,
		z = zDefault,
	}

	constraintSettingsChangedEvent:Fire(true, constraints, defaultOverrides)
end

local function getRepeatSettings(instance, axis)
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

local function updateRepeatSettingForSelection(axis)
	local selection = Selection:Get()
	if #selection == 1 then
		local repeatSettings = getRepeatSettings(selection[1], axis)
		return repeatSettings, {}
	else
		local repeatSettings = getRepeatSettings(selection[1], axis)
		local defaultOverrides = {}

		for i = 2, #selection do
			local compareSettings = getRepeatSettings(selection[i], axis)

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

local function updateAllRepeatSettingsForSelection()
	if not isSelectionValid() then
		repeatSettingsChangedEvent:Fire(false, {}, {})
		return
	end

	local xRepeat, xDefault = updateRepeatSettingForSelection("x")
	local yRepeat, yDefault = updateRepeatSettingForSelection("y")
	local zRepeat, zDefault = updateRepeatSettingForSelection("z")

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

local selectionChangedConnection
local function connectHelper()
	selectionChangedConnection = Selection.SelectionChanged:Connect(function()
		updateAllConstraintSettingsForSelection()
		updateAllRepeatSettingsForSelection()
	end)
end
local function disconnectHelper()
	if selectionChangedConnection then
		selectionChangedConnection:Disconnect()
		selectionChangedConnection = nil
	end
end

local settingsHelper = {
	updateAllConstraintSettingsForSelection = updateAllConstraintSettingsForSelection,
	updateAllRepeatSettingsForSelection = updateAllRepeatSettingsForSelection,

	isSelectionValid = isSelectionValid,

	constraintSettingsChanged = constraintSettingsChangedEvent.Event,
	repeatSettingsChanged = repeatSettingsChangedEvent.Event,

	connect = connectHelper,
	disconnect = disconnectHelper,
}

return settingsHelper
