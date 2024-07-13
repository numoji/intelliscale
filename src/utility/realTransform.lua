local attributeHelper = require(script.Parent.attributeHelper)
local changeDeduplicator = require(script.Parent.changeDeduplicator)
local realTransform = {}

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
	return part:GetAttribute("realSize") ~= nil
end

function realTransform.hasCFrame(part: BasePart): boolean
	return part:GetAttribute("realRelativeCFrame") ~= nil
end

-- Get --
function realTransform.getRelativeCFrame(part: BasePart): CFrame
	local relativeCFrame = part:GetAttribute("realRelativeCFrame") :: CFrame
	if not relativeCFrame then
		local parent = part.Parent :: BasePart
		relativeCFrame = parent.CFrame:ToObjectSpace(part.CFrame)
	end

	return relativeCFrame
end

function realTransform.getGlobalCFrame(part: BasePart, parentCFrame: CFrame?): CFrame
	local relativeCFrame = part:GetAttribute("realRelativeCFrame") :: CFrame
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
	local size = part:GetAttribute("realSize") :: Vector3
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

function realTransform.getSizeAndRelativeCFrameAttributes(instance: Instance)
	local relativeCFrame = instance:GetAttribute("realRelativeCFrame") :: CFrame?
	local size = instance:GetAttribute("realSize") :: Vector3?

	return size, relativeCFrame
end

-- Set --
function realTransform.setSize(part: BasePart, newSize: Vector3, extraLevel: number?)
	local size = part:GetAttribute("realSize") :: Vector3
	if size then
		-- inspectPrint(`{part.Name} set size att`, 2 + (extraLevel or 0))
		attributeHelper.setAttribute(part, "realSize", clampSize(newSize), 1 + (extraLevel or 0), true)
	else
		-- inspectPrint(`{part.Name} set size prop`, 2 + (extraLevel or 0))
		part.Size = newSize
	end
end

function realTransform.setRelativeCFrame(part: BasePart, newRelativeCFrame: CFrame, parentCFrame: CFrame?, extraLevel: number?)
	local relativeCFrame = part:GetAttribute("realRelativeCFrame") :: Vector3
	if relativeCFrame then
		-- inspectPrint(`{part.Name} set cf att`, 2 + (extraLevel or 0))
		attributeHelper.setAttribute(part, "realRelativeCFrame", newRelativeCFrame, 1 + (extraLevel or 0), true)
	else
		if not parentCFrame then
			local parent = part.Parent :: BasePart
			parentCFrame = parent.CFrame
		end

		assert(parentCFrame, "Unable to get parent cframe")
		local callingScript = debug.info(2 + (extraLevel or 0), "s"):match("%a+$")
		changeDeduplicator.setProp(callingScript, part, "CFrame", newRelativeCFrame)
	end
end

function realTransform.setGlobalCFrame(part: BasePart, newGlobalCFrame: CFrame, parentCFrame: CFrame?, extraLevel: number?)
	local relativeCFrame = part:GetAttribute("realRelativeCFrame") :: Vector3
	if relativeCFrame then
		if not parentCFrame then
			local parent = part.Parent :: BasePart
			parentCFrame = parent.CFrame
		end
		assert(parentCFrame, "Unable to get parent cframe")
		local newRelativeCFrame = parentCFrame:ToObjectSpace(newGlobalCFrame)
		-- inspectPrint(`{part.Name} set cf att`, 2 + (extraLevel or 0))
		attributeHelper.setAttribute(part, "realRelativeCFrame", newRelativeCFrame, 1 + (extraLevel or 0), true)
	else
		-- inspectPrint(`{part.Name} set cf prop`, 2 + (extraLevel or 0))

		local callingScript = debug.info(2 + (extraLevel or 0), "s"):match("%a+$")
		changeDeduplicator.setProp(callingScript, part, "CFrame", newGlobalCFrame)
	end
end

function realTransform.setSizeAndRelativeCFrame(part: BasePart, newSize: Vector3, newGlobalCFrame: CFrame, parentCFrame: CFrame?)
	realTransform.setSize(part, newSize, 1)
	realTransform.setRelativeCFrame(part, newGlobalCFrame, parentCFrame, 1)
end

function realTransform.setSizeAndGlobalCFrame(part: BasePart, newSize: Vector3, newGlobalCFrame: CFrame, parentCFrame: CFrame?)
	realTransform.setSize(part, newSize, 1)
	realTransform.setGlobalCFrame(part, newGlobalCFrame, parentCFrame, 1)
end

function realTransform.setRelativeCFrameAttribute(part: BasePart, newRelativeCFrame: CFrame?, extraLevel: number?)
	-- inspectPrint(`{part.Name} set cf att`, 2 + (extraLevel or 0))
	attributeHelper.setAttribute(part, "realRelativeCFrame", newRelativeCFrame, 1 + (extraLevel or 0), true)
end

function realTransform.setSizeAttribute(part: BasePart, newSize: Vector3?, extraLevel: number?)
	-- inspectPrint(`{part.Name} set size att`, 2 + (extraLevel or 0))
	attributeHelper.setAttribute(part, "realSize", newSize, 1 + (extraLevel or 0), true)
end

function realTransform.setSizeAndRelativeCFrameAttributes(
	instance: Instance,
	newSize: Vector3?,
	newRelativeCFrame: CFrame?,
	extraLevel: number?
)
	attributeHelper.setAttribute(instance, "realSize", newSize, 1, true)
	attributeHelper.setAttribute(instance, "realRelativeCFrame", newRelativeCFrame, 1, true)
end

return realTransform
