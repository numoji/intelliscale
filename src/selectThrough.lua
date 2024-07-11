--!strict
local packages = script.Parent.Parent.Packages
local Janitor = require(packages.Janitor)

local source = script.Parent
local selectionHelper = require(source.utility.selectionHelper)

local janitor = Janitor.new()

local selectThrough = {}

type SelectThroughSet = { [BasePart]: true }
local selectThroughSet: SelectThroughSet = {}

local cachedCollisionGroups: { [BasePart]: string } = {}

function addToSetRecursive(part: BasePart, set: SelectThroughSet)
	if selectionHelper.isValidContained(part) then
		addToSetRecursive(part.Parent :: BasePart, set)
	end

	if selectionHelper.isValidContainer(part) and part:GetAttribute("isContainer") then
		if not set[part] then
			set[part] = true
		end
	end
end

function selectThrough.initialize()
	janitor:Add(selectionHelper.bindToAnySelection(function(selection: { Instance }, fauxSelection: { Instance })
		local newSet: SelectThroughSet = {}

		for _, instance in ipairs(selection) do
			if instance:IsA("BasePart") then
				addToSetRecursive(instance, newSet)
			end
		end

		for part, _ in selectThroughSet do
			if not newSet[part] then
				if part.CollisionGroup == "IntelliscaleUnselectable" then
					part.CollisionGroup = cachedCollisionGroups[part]
				end
				cachedCollisionGroups[part] = nil
			end
		end

		for part, _ in newSet do
			if not selectThroughSet[part] then
				cachedCollisionGroups[part] = part.CollisionGroup
				part.CollisionGroup = "IntelliscaleUnselectable"
			end
		end

		selectThroughSet = newSet
	end))

	janitor:Add(function()
		for part, collisionGroup in cachedCollisionGroups do
			part.CollisionGroup = collisionGroup
		end
	end)

	return janitor
end

return selectThrough
