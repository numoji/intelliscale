local source = script.Parent
local packages = script.Parent.Parent.Packages
local React = require(packages.React)
local StudioComponents = require(packages.StudioComponents)
local constraintsPanel = require(source.constraintsPanel)

local e = React.createElement

return function(_props)
	return e(StudioComponents.Background, {}, {
		ConstraintsPanel = e(constraintsPanel),
	})
end
