local utility = script.Parent
local attributeHelper = require(utility.attributeHelper)

local realTransform = {}

local function cf(cf: CFrame?)
	if not cf then
		return "nil"
	end
	return `[{cf.X}, {cf.Y}, {cf.Z}]`
end

function clampSize(newSize)
	if newSize.X < 0.001 or newSize.Y < 0.001 or newSize.Z < 0.001 then
		return Vector3.new(math.max(newSize.X, 0.001), math.max(newSize.Y, 0.001), math.max(newSize.Z, 0.001))
	else
		return newSize
	end
end

-- Check --
function realTransform.hasTransform(part: BasePart): boolean
	return realTransform.hasSize(part) or realTransform.hasCFrame(part)
end

function realTransform.hasSize(part: BasePart): boolean
	return part:GetAttribute("__trueSize_intelliscale_internal") ~= nil
end

function realTransform.hasCFrame(part: BasePart): boolean
	return part:GetAttribute("__trueRelativeCFrame_intelliscale_internal") ~= nil
end

-- Get --
function realTransform.getRelativeCFrame(part: BasePart): CFrame
	local relativeCFrame = part:GetAttribute("__trueRelativeCFrame_intelliscale_internal") :: CFrame
	if not relativeCFrame then
		local parent = part.Parent :: BasePart
		relativeCFrame = parent.CFrame:ToObjectSpace(part.CFrame)
	end

	return relativeCFrame
end

function realTransform.getGlobalCFrame(part: BasePart, parentCFrame: CFrame?): CFrame
	local relativeCFrame = part:GetAttribute("__trueRelativeCFrame_intelliscale_internal") :: CFrame
	if relativeCFrame then
		if not parentCFrame then
			local parent = part.Parent :: BasePart
			parentCFrame = parent.CFrame
		end

		assert(parentCFrame, "Unable to get parent cframe")
		return parentCFrame * relativeCFrame
	else
		return part.CFrame
	end
end

function realTransform.getSize(part: BasePart): Vector3
	local size = part:GetAttribute("__trueSize_intelliscale_internal") :: Vector3
	if size then
		return size
	end

	return part.Size
end

function realTransform.getSizeAndRelativeCFrame(part: BasePart): (Vector3, CFrame)
	local size = realTransform.getSize(part)
	local relativeCFrame = realTransform.getRelativeCFrame(part)

	return size, relativeCFrame
end

function realTransform.getSizeAndGlobalCFrame(part: BasePart, parentCFrame: CFrame?): (Vector3, CFrame)
	local size = realTransform.getSize(part)
	local globalCFrame = realTransform.getGlobalCFrame(part, parentCFrame)

	return size, globalCFrame
end

-- Set --
function realTransform.setSize(part: BasePart, newSize: Vector3)
	local size = part:GetAttribute("__trueSize_intelliscale_internal") :: Vector3
	if size then
		attributeHelper.setAttribute(part, "__trueSize_intelliscale_internal", clampSize(newSize), true)
	else
		part.Size = newSize
	end
end

function realTransform.setRelativeCFrame(part: BasePart, newRelativeCFrame: CFrame, parentCFrame: CFrame?)
	local relativeCFrame = part:GetAttribute("__trueRelativeCFrame_intelliscale_internal") :: Vector3
	if relativeCFrame then
		attributeHelper.setAttribute(part, "__trueRelativeCFrame_intelliscale_internal", newRelativeCFrame, true)
	else
		if not parentCFrame then
			local parent = part.Parent :: BasePart
			parentCFrame = parent.CFrame
		end

		assert(parentCFrame, "Unable to get parent cframe")
		part.CFrame = parentCFrame * newRelativeCFrame
	end
end

function realTransform.setGlobalCFrame(part: BasePart, newGlobalCFrame: CFrame, parentCFrame: CFrame?)
	local relativeCFrame = part:GetAttribute("__trueRelativeCFrame_intelliscale_internal") :: Vector3
	if relativeCFrame then
		if not parentCFrame then
			local parent = part.Parent :: BasePart
			parentCFrame = parent.CFrame
		end
		assert(parentCFrame, "Unable to get parent cframe")
		local newRelativeCFrame = parentCFrame:ToObjectSpace(newGlobalCFrame)
		attributeHelper.setAttribute(part, "__trueRelativeCFrame_intelliscale_internal", newRelativeCFrame, true)
	else
		part.CFrame = newGlobalCFrame
	end
end

function realTransform.setSizeAndRelativeCFrame(part: BasePart, newSize: Vector3, newGlobalCFrame: CFrame, parentCFrame: CFrame?)
	realTransform.setSize(part, newSize)
	realTransform.setRelativeCFrame(part, newGlobalCFrame, parentCFrame)
end

function realTransform.setSizeAndGlobalCFrame(part: BasePart, newSize: Vector3, newGlobalCFrame: CFrame, parentCFrame: CFrame?)
	realTransform.setSize(part, newSize)
	realTransform.setGlobalCFrame(part, newGlobalCFrame, parentCFrame)
end

return realTransform
