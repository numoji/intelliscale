local scaling = {}

-- Create handles
-- Respond to handle drag events

scaling.initializePluginAction = function(plugin)
	local toggleHandlesAction = plugin:CreatePluginAction(
		"IntelliscaleToggleHandles",
		"Toggle Intelliscale handles",
		"Toggles intelliscale scaling handles"
	)

	toggleHandlesAction.Triggered:Connect(function()
		-- Toggle scaling Handles
	end)
end

return scaling
