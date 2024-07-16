--!strict
local Selection = game:GetService("Selection")

local Janitor = require(script.Parent.Parent.Packages.Janitor)
local repeating = require(script.Parent.repeating)
local selectionHelper = require(script.Parent.utility.selectionHelper)

local pluginActions = {}

local janitor = Janitor.new()

local toggleFauxSelection
local selectContainerAction
local destroyUnparentedPartsAction

function pluginActions.initialize(plugin: Plugin)
	if not toggleFauxSelection then
		toggleFauxSelection =
			plugin:CreatePluginAction("IntelliscaleToggleFaux", "Intelliscale: Toggle faux selector", "Toggles intelliscale faux selector")
	end

	if not selectContainerAction then
		selectContainerAction = plugin:CreatePluginAction(
			"intelliscaleSelectContainer",
			"Intelliscale: Select Contatiner",
			"Selects intelliscale container selected part is in"
		)
	end

	if not destroyUnparentedPartsAction then
		destroyUnparentedPartsAction = plugin:CreatePluginAction(
			"intelliscaleDestroyUnparentedParts",
			"Intelliscale: Destroy unparented",
			"Destroys repeated parts & instances that were unparented but still have references saved in ChangeHistory preventing garbage collection"
		)
	end

	janitor:Add(toggleFauxSelection.Triggered:Connect(selectionHelper.toggleUseFauxSelection))

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

	janitor:Add(destroyUnparentedPartsAction.Triggered:Connect(repeating.destroyUnparentedRepeatInstances))

	return janitor
end

return pluginActions
