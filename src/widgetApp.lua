local source = script.Parent
local packages = script.Parent.Parent.Packages
local React = require(packages.React)
local StudioComponents = require(packages.StudioComponents)
local pluginContext = require(source.contexts.pluginContext)

return function(_props)
	-- Binding for selected object, or maybe useEffect test when selection changed and useState for selected object, in case we need to trigger rerenders for the sub components.

	return
end
