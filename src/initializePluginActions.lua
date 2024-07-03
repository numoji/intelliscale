--!strict
local Selection = game:GetService("Selection")
local packages = script.Parent.Parent.Packages
local Janitor = require(packages.Janitor)

local source = script.Parent
local scaling = require(source.scaling)
local selectionHelper = require(source.utility.selectionHelper)

local janitor = Janitor.new()

local function initializePluginActions(plugin)
	local toggleHandlesAction =
		plugin:CreatePluginAction("IntelliscaleToggleHandles", "Intelliscale: Toggle handles", "Toggles intelliscale scaling handles")

	janitor:Add(toggleHandlesAction.Triggered:Connect(scaling.toggleHandleVisibility))

	local selectContainerAction = plugin:CreatePluginAction(
		"intelliscaleSelectContainer",
		"Intelliscale: Select Contatiner",
		"Selects intelliscale container selected part is in"
	)

	janitor:Add(selectContainerAction.Triggered:Connect(function()
		local containedSelection = selectionHelper.getContainedSelection()

		if #containedSelection == 0 then
			return
		end

		local containerSelection = {}
		for _, containedInstance in containedSelection do
			table.insert(containerSelection, containedInstance.Parent)
		end

		Selection:Set(containerSelection)
	end))

	return janitor
end

return initializePluginActions
