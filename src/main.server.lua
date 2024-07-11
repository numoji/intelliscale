--!strict
local packages = script.Parent.Parent.Packages
local Janitor = require(packages.Janitor)
local React = require(packages.React)
local ReactRoblox = require(packages.ReactRoblox)
local StudioComponents = require(packages.StudioComponents)
local selectThrough = require(script.Parent.selectThrough)

local source = script.Parent
local changeCatcher = require(source.changeCatcher)
local containerHelper = require(source.utility.containerHelper)
local initializePluginActions = require(source.initializePluginActions)
local repeating = require(source.repeating)
local scaling = require(source.scaling)
local selectionDisplay = require(source.selectionDisplay)
local selectionHelper = require(source.utility.selectionHelper)
local settingsHelper = require(source.utility.settingsHelper)
local studioHandlesStalker = require(source.utility.studioHandlesStalker)

local widgetApp = require(source.components.widgetApp)

local janitor = Janitor.new()

janitor:Add(changeCatcher.initialize(plugin))
janitor:Add(containerHelper.registerCollisionGroup())
janitor:Add(initializePluginActions(plugin))
janitor:Add(repeating.initializeRepeating())
janitor:Add(scaling.initializeHandles(plugin))
janitor:Add(selectionDisplay.initializeHighlightContainer())
janitor:Add(selectionHelper.jantior)
janitor:Add(selectThrough.initialize())
janitor:Add(settingsHelper.stopListening)
janitor:Add(studioHandlesStalker.initialize())

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

task.wait()
task.wait()
selectionHelper.updateSelection()
