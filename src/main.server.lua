--!strict
local Players = game:GetService("Players")

local Janitor = require(script.Parent.Parent.Packages.Janitor)
local React = require(script.Parent.Parent.Packages.React)
local ReactRoblox = require(script.Parent.Parent.Packages.ReactRoblox)
local StudioComponents = require(script.Parent.Parent.Packages.StudioComponents)
local selectThrough = require(script.Parent.selectThrough)

local changeCatcher = require(script.Parent.changeCatcher)
local pluginActions = require(script.Parent.pluginActions)
local repeating = require(script.Parent.repeating)
local selectionDisplay = require(script.Parent.selectionDisplay)
local selectionHelper = require(script.Parent.utility.selectionHelper)
local settingsHelper = require(script.Parent.utility.settingsHelper)
local studioHandlesStalker = require(script.Parent.utility.studioHandlesStalker)

local widgetApp = require(script.Parent.components.widgetApp)

local janitor = Janitor.new()

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
		janitor:Add(changeCatcher.initialize(plugin), "Cleanup")
		janitor:Add(pluginActions.initialize(plugin), "Cleanup")
		janitor:Add(repeating.initialize(), "Cleanup")
		janitor:Add(selectionDisplay.initialize(), "Cleanup")
		janitor:Add(selectionHelper.initialize(), "Cleanup")
		janitor:Add(selectThrough.initialize())
		janitor:Add(settingsHelper.listenForChanges(), "Cleanup")
		janitor:Add(studioHandlesStalker.initialize(), "Cleanup")
		toggleWidgetButton:SetActive(true)
	else
		janitor:Cleanup()
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

local function cleanup()
	root:unmount()
	janitor:Cleanup()
end

plugin.Unloading:Connect(cleanup)

if not Players.LocalPlayer then
	game:BindToClose(cleanup)
else
end

task.wait()
task.wait()
selectionHelper.updateSelection()
