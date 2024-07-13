--!strict
local Selection = game:GetService("Selection")

local React = require(script.Parent.Parent.Parent.Packages.React)
local StudioComponents = require(script.Parent.Parent.Parent.Packages.StudioComponents)

local changeHistoryHelper = require(script.Parent.Parent.utility.changeHistoryHelper)
local containerHelper = require(script.Parent.Parent.utility.containerHelper)
local selectionHelper = require(script.Parent.Parent.utility.selectionHelper)

local e = React.createElement

local function containerConversionButton(props)
	local layoutOrder = props.LayoutOrder

	local selectedModel: Model?, setSelectedModel = React.useState(nil :: Model?)
	local selectedContainer: Part?, setSelectedContainer = React.useState(nil :: Part?)
	React.useEffect(function()
		return selectionHelper.addSelectionChangeCallback(selectionHelper.callbackDicts.singleAny, function(selected)
			if selected and selected:IsA("Model") then
				setSelectedModel(selected)
				setSelectedContainer(nil)
			elseif selected and selected:IsA("Part") and selected:GetAttribute("isContainer") then
				setSelectedModel(nil)
				setSelectedContainer(selected)
			else
				setSelectedModel(nil)
				setSelectedContainer(nil)
			end
		end)
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
