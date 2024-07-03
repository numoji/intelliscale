--!strict
local PhysicsService = game:GetService("PhysicsService")
local Selection = game:GetService("Selection")
local containerHelper = {}

function containerHelper.registerCollisionGroup()
	PhysicsService:RegisterCollisionGroup("IntelliscaleUnselectable")
	PhysicsService:CollisionGroupSetCollidable("IntelliscaleUnselectable", "StudioSelectable", false)

	return function()
		PhysicsService:UnregisterCollisionGroup("IntelliscaleUnselectable")
	end
end

function containerHelper.makeContainer(model)
	local boundingBoxPart = Instance.new("Part")
	boundingBoxPart.Name = model.Name
	boundingBoxPart.Anchored = true
	boundingBoxPart.CanCollide = false

	local boundingBoxCFrame, boundingBoxSize = model:GetBoundingBox()
	boundingBoxPart.Size = boundingBoxSize
	boundingBoxPart.CFrame = boundingBoxCFrame
	boundingBoxPart.Transparency = 1
	boundingBoxPart.Parent = model.Parent

	for _, child in model:GetChildren() do
		child.Parent = boundingBoxPart
	end

	model.Parent = nil

	boundingBoxPart.CollisionGroup = "IntelliscaleUnselectable"
	boundingBoxPart:SetAttribute("isContainer", true)

	Selection:Set({ boundingBoxPart })
end

return containerHelper
