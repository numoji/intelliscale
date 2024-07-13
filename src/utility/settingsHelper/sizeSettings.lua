--!strict
local containerHelper = require(script.Parent.Parent.containerHelper)
local repeatSettings = require(script.Parent.repeatSettings)
local types = require(script.Parent.Parent.Parent.types)

local sizeSettings = {}

export type SingleSettingGroup = {
	updateContinuous: boolean,
}

export type MultipleSettingGroups = {
	updateContinuous: boolean | types.Mixed,
}

type AssignableSizeAttributes = {
	updateContinuous: boolean?,
}

function sizeSettings.addAssignableAttributes(instance: Instance, assignableAttributesSet: types.AssignableAttributeSet)
	if containerHelper.doesContainAnyParts(instance) or repeatSettings.doesHaveToExtentsRepeatSettings(instance) then
		assignableAttributesSet["updateContinuous" :: "updateContinuous"] = true
	end
end

function sizeSettings.getSettingGroup(part: BasePart): SingleSettingGroup?
	if not (containerHelper.doesContainAnyParts(part) or repeatSettings.doesHaveToExtentsRepeatSettings(part)) then
		return nil
	end

	local value = part:GetAttribute("updateContinuous")
	local updateContinuous = if value == nil then true else value

	return {
		updateContinuous = updateContinuous,
	}
end

return sizeSettings
