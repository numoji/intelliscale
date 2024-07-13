--!strict
local PhysicsService = game:GetService("PhysicsService")

local Janitor = require(script.Parent.Parent.Packages.Janitor)
local containerHelper = require(script.Parent.utility.containerHelper)
local selectionHelper = require(script.Parent.utility.selectionHelper)

local janitor = Janitor.new()

local selectThrough = {}

type SelectThroughSet = { [BasePart]: true }
local selectThroughSet: SelectThroughSet = {}

local cachedCollisionGroups: { [BasePart]: string } = {}

function addToSetRecursive(part: BasePart, set: SelectThroughSet)
	if containerHelper.isValidContained(part) then
		addToSetRecursive(part.Parent :: BasePart, set)
	end

	if containerHelper.isValidContainer(part) and part:GetAttribute("isContainer") then
		if not set[part] then
			set[part] = true
		end
	end
end

function selectThrough.initialize()
	PhysicsService:RegisterCollisionGroup("IntelliscaleUnselectable")

	if not PhysicsService:IsCollisionGroupRegistered("StudioSelectable") then
		PhysicsService:RegisterCollisionGroup("StudioSelectable")
	end

	PhysicsService:CollisionGroupSetCollidable("IntelliscaleUnselectable", "StudioSelectable", false)

	janitor:Add(
		selectionHelper.addSelectionChangeCallback(
			selectionHelper.callbackDicts.any,
			function(selection: { Instance }, fauxSelection: { Instance })
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
			end
		)
	)

	return function()
		for part, collisionGroup in cachedCollisionGroups do
			part.CollisionGroup = collisionGroup
		end

		PhysicsService:UnregisterCollisionGroup("IntelliscaleUnselectable")
		janitor:Cleanup()
	end
end

return selectThrough
