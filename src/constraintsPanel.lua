local Selection = game:GetService("Selection")

local packages = script.Parent.Parent.Packages
local React = require(packages.React)
local StudioComponents = require(packages.StudioComponents)

local e = React.createElement

return function(_props)
	local constraintValues, setConstraintValues = React.useState(nil)

	local updateConstraintValues = React.useCallback(function()
		local selection = Selection:Get()

		if #selection == 1 and (selection[1]:IsA("BasePart") or selection[1]:IsA("Model")) then
			print("1 selection")
			setConstraintValues({
				xConstraint = selection[1]:GetAttribute("xConstraint"),
				yConstraint = selection[1]:GetAttribute("yConstraint"),
				zConstraint = selection[1]:GetAttribute("zConstraint"),
			})
			return
		elseif #selection > 1 and (selection[1]:IsA("BasePart") or selection[1]:IsA("Model")) then
			print(`{#selection} selections`)
			local xConstraint = selection[1]:GetAttribute("xConstraint")
			local yConstraint = selection[1]:GetAttribute("yConstraint")
			local zConstraint = selection[1]:GetAttribute("zConstraint")
			local xDefault = "None"
			local zDefault = "None"
			local yDefault = "None"

			for i = 2, #selection do
				if not (selection[1]:IsA("BasePart") or selection[1]:IsA("Model")) then
					setConstraintValues(nil)
					return
				end

				if selection[i]:GetAttribute("xConstraint") ~= xConstraint then
					xConstraint = "~"
					xDefault = "[ Multiple ]"
				end

				if selection[i]:GetAttribute("yConstraint") ~= yConstraint then
					yConstraint = "~"
					yDefault = "[ Multiple ]"
				end

				if selection[i]:GetAttribute("zConstraint") ~= zConstraint then
					zConstraint = "~"
					zDefault = "[ Multiple ]"
				end
			end

			setConstraintValues({
				xConstraint = xConstraint,
				yConstraint = yConstraint,
				zConstraint = zConstraint,
				xDefault = xDefault,
				yDefault = yDefault,
				zDefault = zDefault,
			})
			return
		end

		setConstraintValues(nil)
	end)

	React.useEffect(function()
		local selectionChanged = Selection.SelectionChanged:Connect(function()
			updateConstraintValues()
		end)

		return function()
			selectionChanged:Disconnect()
		end
	end, {})

	local disabled = constraintValues == nil
	local xConstraint = constraintValues and constraintValues.xConstraint or nil
	local yConstraint = constraintValues and constraintValues.yConstraint or nil
	local zConstraint = constraintValues and constraintValues.zConstraint or nil
	local xDefault = constraintValues and constraintValues.xDefault or "None"
	local yDefault = constraintValues and constraintValues.yDefault or "None"
	local zDefault = constraintValues and constraintValues.zDefault or "None"

	return e(React.Fragment, {}, {
		e(StudioComponents.Dropdown, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, -StudioComponents.Constants.DefaultDropdownHeight * 1.2),
			ClearButton = true,
			DefaultText = xDefault,
			Items = { "Left", "Right", "Left and Right", "Center", "Scale" },
			SelectedItem = xConstraint,
			Disabled = disabled,
			OnItemSelected = function(newItem)
				for _, instance in Selection:Get() do
					if instance:IsA("BasePart") or instance:IsA("Model") then
						instance:SetAttribute("xConstraint", newItem)
						updateConstraintValues()
					end
				end
			end,
		}),
		e(StudioComponents.Dropdown, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Items = { "Top", "Bottom", "Top and Bottom", "Center", "Scale" },
			ClearButton = true,
			DefaultText = yDefault,
			Disabled = disabled,
			SelectedItem = yConstraint,
			OnItemSelected = function(newItem)
				for _, instance in Selection:Get() do
					if instance:IsA("BasePart") or instance:IsA("Model") then
						instance:SetAttribute("yConstraint", newItem)
						updateConstraintValues()
					end
				end
			end,
		}),
		e(StudioComponents.Dropdown, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, StudioComponents.Constants.DefaultDropdownHeight * 1.2),
			Items = { "Front", "Back", "Front and Back", "Center", "Scale" },
			ClearButton = true,
			DefaultText = zDefault,
			Disabled = disabled,
			SelectedItem = zConstraint,
			OnItemSelected = function(newItem)
				for _, instance in Selection:Get() do
					if instance:IsA("BasePart") or instance:IsA("Model") then
						instance:SetAttribute("zConstraint", newItem)
						updateConstraintValues()
					end
				end
			end,
		}),
	})
end
