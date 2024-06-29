local source = script.Parent
local packages = script.Parent.Parent.Packages
local React = require(packages.React)
local ReactRoblox = require(packages.ReactRoblox)
local pluginContext = require(source.contexts.pluginContext)
local widgetApp = require(source.widgetApp)

local toolbar = plugin:CreateToolbar("Intelliscale")
local toggleWidgetButton = toolbar:CreateButton("Intelliscale", "Toggle widget", "")

local widget = plugin:CreateDockWidgetPluginGui(
	"Intelliscale",
	DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Left, false, false, 200, 200, 100, 100)
)
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
widget.Title = "Intelliscale"

widget:GetPropertyChangedSignal("Enabled"):Connect(function()
	if widget.Enabled then
		toggleWidgetButton:SetActive(true)
	else
		toggleWidgetButton:SetActive(false)
	end
end)

toggleWidgetButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

local root = ReactRoblox.createRoot(widget)

local function rootApp(_props)
	return React.createElement(pluginContext.Provider, {
		value = plugin,
	}, {
		React.createElement("ScreenGui", {
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, {
			React.createElement(widgetApp),
		}),
	})
end

root:render(React.createElement(rootApp, {
	plugin = plugin,
}))

plugin.Unloading:Connect(function()
	root:unmount()
end)
