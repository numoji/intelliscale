--!strict
local Selection = game:GetService("Selection")
local containerHelper = {}

function containerHelper.isValidContainer(instance: Instance)
	return instance:IsA("BasePart")
end

function containerHelper.isValidContained(instance: Instance)
	return instance:IsA("BasePart") and instance.Parent ~= nil and instance.Parent:IsA("BasePart")
end

function containerHelper.isValidContainedOrContainer(instance: Instance)
	return containerHelper.isValidContainer(instance) or containerHelper.isValidContained(instance)
end

function containerHelper.doesContainAnyParts(instance: Instance)
	return instance:IsA("BasePart") and instance:FindFirstChildWhichIsA("BasePart") ~= nil
end

function containerHelper.makeContainer(model: Model)
	local boundingBoxPart = Instance.new("Part")
	if model.Name == "Model" then
		boundingBoxPart.Name = "Container"
	else
		boundingBoxPart.Name = model.Name
	end
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

	boundingBoxPart:SetAttribute("isContainer", true)

	Selection:Set({ boundingBoxPart })
end

return containerHelper
