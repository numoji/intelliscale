--!strict
local types = {}

export type AxisString = "x" | "y" | "z"
export type ConstraintString = "Min" | "Max" | "MinMax" | "Scale" | "Center"
export type Mixed = "~"
export type MixedDisplay = "[ Multiple ]"
export type NoneString = "None"
export type SettingWithChildren<SettingValue, ChildrenSettings> = {
	settingValue: SettingValue,
	childrenSettings: ChildrenSettings,
}
export type Selection = { Instance }

export type RepeatSettingAttribute =
	"xRepeatKind"
	| "xStretchToFit"
	| "xRepeatAmountPositive"
	| "xRepeatAmountNegative"
	| "yRepeatKind"
	| "yStretchToFit"
	| "yRepeatAmountPositive"
	| "yRepeatAmountNegative"
	| "zRepeatKind"
	| "zStretchToFit"
	| "zRepeatAmountPositive"
	| "zRepeatAmountNegative"

export type SizeSettingAttribute = "updateContinuous"
export type ConstraintSettingAttribute = "xConstraint" | "yConstraint" | "zConstraint"

export type SettingAttribute = RepeatSettingAttribute | SizeSettingAttribute | ConstraintSettingAttribute

export type AssignableAttributeSet = { [SettingAttribute]: boolean }

return types
