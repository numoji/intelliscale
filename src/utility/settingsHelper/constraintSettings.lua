--!strict
local containerHelper = require(script.Parent.Parent.containerHelper)
local types = require(script.Parent.Parent.Parent.types)
local constraintSettings = {}

export type SingleSettingGroup = {
	x: types.ConstraintString?,
	y: types.ConstraintString?,
	z: types.ConstraintString?,
}

export type MultipleSettingGroups = {
	x: (types.ConstraintString | types.Mixed)?,
	y: (types.ConstraintString | types.Mixed)?,
	z: (types.ConstraintString | types.Mixed)?,
}

export type MixedDisplayOverride = {
	x: types.MixedDisplay?,
	y: types.MixedDisplay?,
	z: types.MixedDisplay?,
}

function constraintSettings.addAssignableAttributes(instance: Instance, assignableAttributesSet: types.AssignableAttributeSet)
	if containerHelper.isValidContained(instance) then
		assignableAttributesSet["xConstraint" :: "xConstraint"] = true
		assignableAttributesSet["yConstraint" :: "yConstraint"] = true
		assignableAttributesSet["zConstraint" :: "zConstraint"] = true
	end
end

function constraintSettings.getSettingGroup(part: BasePart): SingleSettingGroup?
	if not containerHelper.isValidContained(part) then
		return nil
	end

	local xConstraint = part:GetAttribute("xConstraint") or "Scale" :: types.ConstraintString
	local yConstraint = part:GetAttribute("yConstraint") or "Scale" :: types.ConstraintString
	local zConstraint = part:GetAttribute("zConstraint") or "Scale" :: types.ConstraintString

	return {
		x = xConstraint,
		y = yConstraint,
		z = zConstraint,
	}
end

return constraintSettings
