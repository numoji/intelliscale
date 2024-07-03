local Selection = game:GetService("Selection")
local source = script.Parent
local packages = script.Parent.Parent.Packages
local React = require(packages.React)
local StudioComponents = require(packages.StudioComponents)
local changeHistoryHelper = require(source.changeHistoryHelper)
local constraintsPanel = require(source.constraintsPanel)
local containerHelper = require(source.containerHelper)
local repeatsPanel = require(source.repeatsPanel)

local e = React.createElement

local function containerButton(_props)
	local selectedModel, setSelectedModel = React.useState(nil)
	local selectedContainer, setSelectedContainer = React.useState(nil)

	React.useEffect(function()
		local selectionChangedConnection = Selection.SelectionChanged:Connect(function()
			local selection = Selection:Get()
			if #selection == 1 and selection[1]:IsA("Model") then
				setSelectedModel(selection[1])
				setSelectedContainer(nil)
			elseif #selection == 1 and selection[1]:IsA("Part") and selection[1]:GetAttribute("isContainer") then
				setSelectedModel(nil)
				setSelectedContainer(selection[1])
			else
				setSelectedModel(nil)
				setSelectedContainer(nil)
			end
		end)

		return function()
			selectionChangedConnection:Disconnect()
		end
	end)

	if selectedModel then
		return e(StudioComponents.MainButton, {
			AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = 3,
			Text = "Convert to Container",
			OnActivated = function()
				changeHistoryHelper.recordUndoChange(function()
					containerHelper.makeContainer(selectedModel)
				end)
			end,
		})
	elseif selectedContainer then
		return e(StudioComponents.Button, {
			AutomaticSize = Enum.AutomaticSize.XY,
			LayoutOrder = 3,
			Text = "Dissolve Container",
			OnActivated = function()
				changeHistoryHelper.recordUndoChange(function()
					local kiddos = selectedContainer:GetChildren()

					for _, child in kiddos do
						child.Parent = selectedContainer.Parent
					end

					Selection:Set(kiddos)
					selectedContainer.Parent = nil
				end)
			end,
		})
	else
		return nil
	end
end

return function(_props)
	return e(StudioComponents.Background, {}, {
		e("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
		e(constraintsPanel, { LayoutOrder = 1 }),
		e(repeatsPanel, { LayoutOrder = 2 }),
		e(containerButton),
	})
end
