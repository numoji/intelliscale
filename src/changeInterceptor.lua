local packages = script.Parent.Parent.Packages
local Janitor = require(packages.Janitor)

local source = script.Parent
local selectionHelper = require(source.utility.selectionHelper)
local changeInterceptor = {}

local janitor = Janitor.new()

function changeInterceptor.initialize()
	return janitor
end

return changeInterceptor
