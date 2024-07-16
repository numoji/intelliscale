--!strict
local containerHelper = require(script.Parent.Parent.containerHelper)
local types = require(script.Parent.Parent.Parent.types)

local repeatSettings = {}

type ToExtentsSettingChildren = {
	stretchToFit: boolean,
}
type ToExtents = types.SettingWithChildren<"To Extents", ToExtentsSettingChildren>

type FixedAmountSettingChildren = {
	repeatAmountPositive: number,
	repeatAmountNegative: number,
}
type FixedAmount = types.SettingWithChildren<"Fixed Amount", FixedAmountSettingChildren>

export type SingleAxisSetting = ToExtents | FixedAmount

type MixedSettingsChildren = {
	stretchToFit: boolean | types.Mixed,
	repeatAmountPositive: number | types.Mixed,
	repeatAmountNegative: number | types.Mixed,
}
type Mixed = types.SettingWithChildren<types.Mixed, MixedSettingsChildren>
export type MultipleAxisSetting = ToExtents | FixedAmount | Mixed

export type SingleSettingGroup = {
	x: SingleAxisSetting?,
	y: SingleAxisSetting?,
	z: SingleAxisSetting?,
}

export type MultipleSettingGroups = {
	x: MultipleAxisSetting?,
	y: MultipleAxisSetting?,
	z: MultipleAxisSetting?,
}

export type MixedDisplayOverrideAxis = types.SettingWithChildren<types.MixedDisplay, {
	repeatAmountPositive: types.MixedDisplay?,
	repeatAmountNegative: types.MixedDisplay?,
	stretchToFit: types.MixedDisplay?,
}>
export type MixedDisplayOverride = {
	x: MixedDisplayOverrideAxis?,
	y: MixedDisplayOverrideAxis?,
	z: MixedDisplayOverrideAxis?,
}

function repeatSettings.getAxisRepeatSettings(instance: BasePart | Folder, axis: types.AxisString): SingleAxisSetting?
	local repeatKind = instance:GetAttribute(axis .. "RepeatKind")
	if repeatKind == "To Extents" then
		local axisSetting: SingleAxisSetting = {
			settingValue = "To Extents",
			childrenSettings = {
				stretchToFit = instance:GetAttribute(axis .. "StretchToFit") == true and true or false,
			},
		} :: SingleAxisSetting
		return axisSetting
	elseif repeatKind == "Fixed Amount" then
		return {
			settingValue = "Fixed Amount",
			childrenSettings = {
				repeatAmountPositive = instance:GetAttribute(axis .. "RepeatAmountPositive") or 0,
				repeatAmountNegative = instance:GetAttribute(axis .. "RepeatAmountNegative") or 0,
			},
		} :: SingleAxisSetting
	else
		return nil
	end
end

function repeatSettings.addAssignableAttributes(instance: Instance, assignableAttributesSet: types.AssignableAttributeSet)
	if containerHelper.isValidContained(instance) then
		assignableAttributesSet["xRepeatKind" :: "xRepeatKind"] = true
		assignableAttributesSet["xStretchToFit" :: "xStretchToFit"] = true
		assignableAttributesSet["xRepeatAmountPositive" :: "xRepeatAmountPositive"] = true
		assignableAttributesSet["xRepeatAmountNegative" :: "xRepeatAmountNegative"] = true
		assignableAttributesSet["yRepeatKind" :: "yRepeatKind"] = true
		assignableAttributesSet["yStretchToFit" :: "yStretchToFit"] = true
		assignableAttributesSet["yRepeatAmountPositive" :: "yRepeatAmountPositive"] = true
		assignableAttributesSet["yRepeatAmountNegative" :: "yRepeatAmountNegative"] = true
		assignableAttributesSet["zRepeatKind" :: "zRepeatKind"] = true
		assignableAttributesSet["zStretchToFit" :: "zStretchToFit"] = true
		assignableAttributesSet["zRepeatAmountPositive" :: "zRepeatAmountPositive"] = true
		assignableAttributesSet["zRepeatAmountNegative" :: "zRepeatAmountNegative"] = true
	end
end

function repeatSettings.getSettingGroup(instance: BasePart | Folder): SingleSettingGroup?
	local xRepeatSettings = repeatSettings.getAxisRepeatSettings(instance, "x")
	local yRepeatSettings = repeatSettings.getAxisRepeatSettings(instance, "y")
	local zRepeatSettings = repeatSettings.getAxisRepeatSettings(instance, "z")

	if xRepeatSettings or yRepeatSettings or zRepeatSettings then
		return {
			x = xRepeatSettings,
			y = yRepeatSettings,
			z = zRepeatSettings,
		}
	elseif containerHelper.isValidContained(instance) then
		return {}
	else
		return nil
	end
end

function repeatSettings.doesHaveAnyRepeatSettings(instance: Instance)
	if not containerHelper.isValidContained(instance) then
		return false
	end

	local xRepeatKind = instance:GetAttribute("xRepeatKind")
	local yRepeatKind = instance:GetAttribute("yRepeatKind")
	local zRepeatKind = instance:GetAttribute("zRepeatKind")

	return xRepeatKind or yRepeatKind or zRepeatKind
end

function repeatSettings.doesHaveAnyRepeatSettingsInAxis(instance: Instance, axis: types.AxisString)
	if not containerHelper.isValidContained(instance) then
		return false
	end

	local repeatKind = instance:GetAttribute(axis .. "RepeatKind")
	return repeatKind
end

function repeatSettings.doesHaveToExtentsRepeatSettings(instance: Instance)
	if not containerHelper.isValidContained(instance) then
		return false
	end

	local xRepeatKind = instance:GetAttribute("xRepeatKind")
	local yRepeatKind = instance:GetAttribute("yRepeatKind")
	local zRepeatKind = instance:GetAttribute("zRepeatKind")

	return xRepeatKind == "To Extents" or yRepeatKind == "To Extents" or zRepeatKind == "To Extents"
end

function repeatSettings.doesHaveToExtentsRepeatSettingsInAxis(instance: Instance, axis: types.AxisString)
	if not containerHelper.isValidContained(instance) then
		return false
	end

	local repeatKind = instance:GetAttribute(axis .. "RepeatKind")
	return repeatKind == "To Extents"
end

function repeatSettings.doesHaveStretchSettings(instance: Instance)
	if not containerHelper.isValidContained(instance) then
		return false
	end

	local xRepeatKind = instance:GetAttribute("xRepeatKind")
	local yRepeatKind = instance:GetAttribute("yRepeatKind")
	local zRepeatKind = instance:GetAttribute("zRepeatKind")

	return (xRepeatKind == "To Extents" and instance:GetAttribute("xStretchToFit"))
		or (yRepeatKind == "To Extents" and instance:GetAttribute("yStretchToFit"))
		or (zRepeatKind == "To Extents" and instance:GetAttribute("zStretchToFit"))
end

function repeatSettings.doesHaveStretchSettingsInAxis(instance: Instance, axis: types.AxisString)
	if not containerHelper.isValidContained(instance) then
		return false
	end

	local repeatKind = instance:GetAttribute(axis .. "RepeatKind")
	return repeatKind == "To Extents" and instance:GetAttribute(axis .. "StretchToFit")
end

function repeatSettings.cacheSettings(repeatSettings: SingleSettingGroup, instance: Instance)
	if repeatSettings.x then
		instance:SetAttribute("xRepeatKind", repeatSettings.x.settingValue)
		if repeatSettings.x.settingValue == "To Extents" then
			instance:SetAttribute("xStretchToFit", repeatSettings.x.childrenSettings.stretchToFit)
		elseif repeatSettings.x.settingValue == "Fixed Amount" then
			instance:SetAttribute("xRepeatAmountPositive", repeatSettings.x.childrenSettings.repeatAmountPositive)
			instance:SetAttribute("xRepeatAmountNegative", repeatSettings.x.childrenSettings.repeatAmountNegative)
		end
	end
	if repeatSettings.y then
		instance:SetAttribute("yRepeatKind", repeatSettings.y.settingValue)
		if repeatSettings.y.settingValue == "To Extents" then
			instance:SetAttribute("yStretchToFit", repeatSettings.y.childrenSettings.stretchToFit)
		elseif repeatSettings.y.settingValue == "Fixed Amount" then
			instance:SetAttribute("yRepeatAmountPositive", repeatSettings.y.childrenSettings.repeatAmountPositive)
			instance:SetAttribute("yRepeatAmountNegative", repeatSettings.y.childrenSettings.repeatAmountNegative)
		end
	end
	if repeatSettings.z then
		instance:SetAttribute("zRepeatKind", repeatSettings.z.settingValue)
		if repeatSettings.z.settingValue == "To Extents" then
			instance:SetAttribute("zStretchToFit", repeatSettings.z.childrenSettings.stretchToFit)
		elseif repeatSettings.z.settingValue == "Fixed Amount" then
			instance:SetAttribute("zRepeatAmountPositive", repeatSettings.z.childrenSettings.repeatAmountPositive)
			instance:SetAttribute("zRepeatAmountNegative", repeatSettings.z.childrenSettings.repeatAmountNegative)
		end
	end
end

return repeatSettings
