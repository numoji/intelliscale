--!strict
local Selection = game:GetService("Selection")

local packages = script.Parent.Parent.Parent.Packages
local React = require(packages.React)
local StudioComponents = require(packages.StudioComponents)

local source = script.Parent.Parent
local changeHistoryHelper = require(source.utility.changeHistoryHelper)
local containerHelper = require(source.utility.containerHelper)

local e = React.createElement

local function containerConversionButton(props)
	local layoutOrder = props.LayoutOrder

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
	end, {})

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
			LayoutOrder = layoutOrder,
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

return containerConversionButton
