local source = script.Parent
local packages = script.Parent.Parent.Packages
local React = require(packages.React)
local ReactRoblox = require(packages.ReactRoblox)
local widgetApp = require(source.widgetApp)

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
		toggleWidgetButton:SetActive(true)
	else
		toggleWidgetButton:SetActive(false)
	end
end
updateWidgetButton()
widget:GetPropertyChangedSignal("Enabled"):Connect(updateWidgetButton)

toggleWidgetButton.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

local root = ReactRoblox.createRoot(widget)
root:render(React.createElement(widgetApp))

plugin.Unloading:Connect(function()
	root:unmount()
end)
