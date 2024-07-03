--!strict
local packages = script.Parent.Parent.Packages
local Janitor = require(packages.Janitor)
local React = require(packages.React)
local ReactRoblox = require(packages.ReactRoblox)
local StudioComponents = require(packages.StudioComponents)

local source = script.Parent
local containerHelper = require(source.utility.containerHelper)
local initializePluginActions = require(source.initializePluginActions)
local scaling = require(source.scaling)
local selectionDisplay = require(source.selectionDisplay)
local selectionHelper = require(source.utility.selectionHelper)
local settingsHelper = require(source.utility.settingsHelper)

local widgetApp = require(source.components.widgetApp)

local janitor = Janitor.new()

janitor:Add(settingsHelper.stopListening)
janitor:Add(containerHelper.registerCollisionGroup())
janitor:Add(selectionDisplay.initializeHighlightContainer())
janitor:Add(scaling.initializeHandles(plugin))
janitor:Add(initializePluginActions(plugin))
janitor:Add(selectionHelper.jantior)

local toolbar = plugin:CreateToolbar("Intelliscale")
local toggleWidgetButton = toolbar:CreateButton("Intelliscale", "Toggle widget", "")

local widget = plugin:CreateDockWidgetPluginGui(
	"Intelliscale",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, false, false, 200, 200, 100, 100)
)
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
widget.Title = "Intelliscale"

function updateWidgetButton()
	if widget.Enabled then
		settingsHelper.listenForChanges()
		toggleWidgetButton:SetActive(true)
	else
		settingsHelper.stopListening()
		toggleWidgetButton:SetActive(false)
	end
end
updateWidgetButton()
widget:GetPropertyChangedSignal("Enabled"):Connect(updateWidgetButton)

toggleWidgetButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

local root = ReactRoblox.createRoot(widget)
root:render(React.createElement(StudioComponents.PluginProvider, { Plugin = plugin }, { React.createElement(widgetApp) }))

plugin.Unloading:Connect(function()
	root:unmount()
	janitor:Cleanup()
end)
