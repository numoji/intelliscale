--!strict
local Selection = game:GetService("Selection")

local packages = script.Parent.Parent.Parent.Packages

local React = require(packages.React)
local StudioComponents = require(packages.StudioComponents)

local source = script.Parent.Parent
local attributeHelper = require(source.utility.attributeHelper)
local changeHistoryHelper = require(source.utility.changeHistoryHelper)
local selectionHelper = require(source.utility.selectionHelper)
local settingsHelper = require(source.utility.settingsHelper)
local types = require(source.types)

local components = script.Parent
local labeledSettingsPanel = require(components.labeledSettingsPanel)

local e = React.createElement

local minAndMaxNamesByAxis = {
	x = { "Left", "Right" },
	y = { "Top", "Bottom" },
	z = { "Front", "Back" },
}

function getConstraintSettingProps(
	axis: types.AxisString,
	disabled: boolean,
	constraints: settingsHelper.ConstraintSettings,
	defaultOverrides: settingsHelper.ConstraintDefaultOverrides
)
	local min = minAndMaxNamesByAxis[axis][1]
	local max = minAndMaxNamesByAxis[axis][2]

	return {
		Items = { min, max, `{min} and {max}`, "Center", "Scale" },
		Size = UDim2.new(1, 0, 0, StudioComponents.Constants.DefaultDropdownHeight),
		-- ClearButton = true,
		DefaultText = defaultOverrides[axis] or "None",
		Disabled = disabled,
		SelectedItem = constraints[axis] or (not disabled and "Scale" or nil),
		OnItemSelected = function(newItem)
			changeHistoryHelper.recordUndoChange(function()
				for _, instance in selectionHelper.getContainedAndContainerSelection() do
					if instance:IsA("BasePart") then
						attributeHelper.setAttribute(instance, axis .. "Constraint", newItem)
					end
				end
			end)
		end,
	}
end

return function(props)
	local layoutOrder = props.LayoutOrder

	local constraintsState, setConstraintState = React.useState({
		disabled = true,
		constraints = {},
		defaultOverrides = {},
	})

	React.useEffect(function()
		local constraintSettingsChangedConnection = settingsHelper.constraintSettingsChanged:Connect(
			function(isSelectionValid, constraints, defaultOverrides)
				setConstraintState({
					disabled = not isSelectionValid,
					constraints = constraints,
					defaultOverrides = defaultOverrides,
				})
			end
		)

		return function()
			constraintSettingsChangedConnection:Disconnect()
		end
	end, {})

	local disabled, constraints, defaultOverrides =
		constraintsState.disabled, constraintsState.constraints, constraintsState.defaultOverrides

	return e(labeledSettingsPanel, {
		LayoutOrder = layoutOrder,
		settingComponents = {
			{
				LabelText = "X Constraint",
				element = StudioComponents.Dropdown,
				props = getConstraintSettingProps("x", disabled, constraints, defaultOverrides),
			},
			{
				LabelText = "Y Constraint",
				element = StudioComponents.Dropdown,
				props = getConstraintSettingProps("y", disabled, constraints, defaultOverrides),
			},
			{
				LabelText = "Z Constraint",
				element = StudioComponents.Dropdown,
				props = getConstraintSettingProps("z", disabled, constraints, defaultOverrides),
			},
		},
	})
end
