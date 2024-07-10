--!strict
local packages = script.Parent.Parent.Packages
local Janitor = require(packages.Janitor)

local epsilon = 1e-4

local source = script.Parent
local attributeHelper = require(source.utility.attributeHelper)
local changeHistoryHelper = require(source.utility.changeHistoryHelper)
local realTransform = require(source.utility.realTransform)
local round = require(source.utility.round)
local scaling = require(source.scaling)
local selectionHelper = require(source.utility.selectionHelper)
local settingsHelper = require(source.utility.settingsHelper)
local types = require(source.types)

local janitor = Janitor.new()

local repeating = {}
repeating.isUpdatingFromAttributeChange = false

type RepeatRanges = {
	x: { min: number, max: number },
	y: { min: number, max: number },
	z: { min: number, max: number },
}
type CombinedRepeatSettings = {
	x: settingsHelper.RepeatSettings,
	y: settingsHelper.RepeatSettings,
	z: settingsHelper.RepeatSettings,
}

type RepeatVariables = {
	size: Vector3,
	relativeCFrame: CFrame,
	repeatRanges: RepeatRanges,
	combinedSettings: CombinedRepeatSettings,
	trueRelativeCFrame: CFrame?,
	trueSize: Vector3?,
}

local function getBlankVariables(sourcePart): RepeatVariables
	local parent = sourcePart.Parent :: BasePart
	return {
		combinedSettings = {
			x = {},
			y = {},
			z = {},
		},
		repeatRanges = {
			x = { min = 0, max = 0 },
			y = { min = 0, max = 0 },
			z = { min = 0, max = 0 },
		},
		size = sourcePart.Size,
		relativeCFrame = parent.CFrame:ToObjectSpace(sourcePart.CFrame),
	}
end

local function getCachedRepeatVariables(sourcePart: BasePart): RepeatVariables
	local repeatsFolder = sourcePart:FindFirstChild("__repeats_intelliscale_internal") :: Folder
	if not repeatsFolder then
		return getBlankVariables(sourcePart)
	end

	local xRepeatSettings = settingsHelper.getRepeatSettings(repeatsFolder, "x")
	local yRepeatSettings = settingsHelper.getRepeatSettings(repeatsFolder, "y")
	local zRepeatSettings = settingsHelper.getRepeatSettings(repeatsFolder, "z")

	local trueSize = repeatsFolder:GetAttribute("trueSize") :: Vector3
	local trueRelativeCFrame = repeatsFolder:GetAttribute("trueRelativeCFrame") :: CFrame
	local size = repeatsFolder:GetAttribute("size") :: Vector3
	local relativeCFrame = repeatsFolder:GetAttribute("relativeCFrame") :: CFrame

	local xMin = repeatsFolder:GetAttribute("xMin") :: number
	local xMax = repeatsFolder:GetAttribute("xMax") :: number
	local yMin = repeatsFolder:GetAttribute("yMin") :: number
	local yMax = repeatsFolder:GetAttribute("yMax") :: number
	local zMin = repeatsFolder:GetAttribute("zMin") :: number
	local zMax = repeatsFolder:GetAttribute("zMax") :: number

	local repeatRanges = {
		x = { min = xMin, max = xMax },
		y = { min = yMin, max = yMax },
		z = { min = zMin, max = zMax },
	}

	return {
		trueSize = trueSize,
		trueRelativeCFrame = trueRelativeCFrame,
		size = size,
		relativeCFrame = relativeCFrame,
		repeatRanges = repeatRanges,

		combinedSettings = {
			x = xRepeatSettings,
			y = yRepeatSettings,
			z = zRepeatSettings,
		},
	}
end

local function cframeFuzzyEq(a: CFrame, b: CFrame): boolean
	return a.Position:FuzzyEq(b.Position, epsilon)
		and a.LookVector:FuzzyEq(b.LookVector, epsilon)
		and a.UpVector:FuzzyEq(b.UpVector, epsilon)
		and a.RightVector:FuzzyEq(b.RightVector, epsilon)
end

local function deepEquals(a: any, b: any): boolean
	if typeof(a) == typeof(b) then
		if typeof(a) == "Vector3" and a:FuzzyEq(b, epsilon) then
			return true
		elseif typeof(a) == "CFrame" and cframeFuzzyEq(a, b) then
			return true
		elseif a == b then
			return true
		end
	end

	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end

	for key, value in a do
		if not deepEquals(value, b[key]) then
			return false
		end
	end

	for key, value in b do
		if not deepEquals(value, a[key]) then
			return false
		end
	end

	return true
end

local removed = "__REMOVED__"
local function deepDifference(a: any, b: any): any
	if typeof(a) == typeof(b) then
		if typeof(a) == "Vector3" and a:FuzzyEq(b, epsilon) then
			return nil
		elseif typeof(a) == "CFrame" and cframeFuzzyEq(a, b) then
			return nil
		elseif a == b then
			return nil
		end
	end

	if type(a) ~= "table" or type(b) ~= "table" then
		return b
	end

	local difference = {}
	for key, value in a do
		local bValue = b[key]
		if bValue == nil then
			difference[key] = removed
		else
			local subDifference = deepDifference(value, bValue)
			if subDifference ~= nil then
				difference[key] = subDifference
			end
		end
	end

	for key, value in pairs(b) do
		if a[key] == nil then
			difference[key] = value
		end
	end

	return next(difference) and difference or nil
end

local function usesStretchToFit(axisSettings)
	return axisSettings.repeatKind == "To Extents" and axisSettings.stretchToFit
end

-- Returns position relative to parent in the axis, size in the axis, and the range of repeats in the axis
local function getSizeAndPositionAndRepeatRangeInAxis(
	sourcePartSize: Vector3,
	sourcePartRelativeCFrame: CFrame,
	parentSize: Vector3,
	axis: Vector3,
	axisRepeatSettings: settingsHelper.RepeatSettings
): (Vector3, Vector3, number, number)
	local localAxis = sourcePartRelativeCFrame:VectorToObjectSpace(axis)
	local sizeInAxis = localAxis:Dot(sourcePartSize)
	local relativePositionInAxis = axis:Dot(sourcePartRelativeCFrame.Position)

	local parentCFrame = sourcePartRelativeCFrame:Inverse()

	local parentLocalAxis = parentCFrame:VectorToObjectSpace(axis)
	local parentSizeInAxis = parentLocalAxis:Dot(parentSize)

	if parentSizeInAxis < sizeInAxis then
		return sizeInAxis * localAxis, relativePositionInAxis * axis, 0, 0
	end

	local parentEdgePos = parentSizeInAxis / 2

	if not (axisRepeatSettings.repeatKind == "To Extents" and axisRepeatSettings.stretchToFit) then
		local halfSize = sizeInAxis / 2
		local rangeMin, rangeMax
		if axisRepeatSettings.repeatKind == "To Extents" then
			rangeMax = (parentEdgePos - halfSize - relativePositionInAxis) // sizeInAxis
			rangeMin = -((parentEdgePos - halfSize + relativePositionInAxis) // sizeInAxis)
		else
			rangeMax = (axisRepeatSettings.repeatAmountPositive :: number) or 0
			rangeMin = (axisRepeatSettings.repeatAmountNegative :: number) or 0
		end

		return sizeInAxis * localAxis, relativePositionInAxis * axis, rangeMax, rangeMin
	end

	local repeatsInAxis = parentSizeInAxis // sizeInAxis
	sizeInAxis = parentSizeInAxis / repeatsInAxis
	local halfSize = sizeInAxis / 2

	local roundOffset = repeatsInAxis % 2 == 0 and sizeInAxis / 2 or 0
	local roundedPositionInAxis = round(relativePositionInAxis - roundOffset, sizeInAxis) + roundOffset

	local rangeMax = round((parentEdgePos - halfSize - roundedPositionInAxis) / sizeInAxis, 1)
	local rangeMin = round((halfSize - parentEdgePos - roundedPositionInAxis) / sizeInAxis, 1)

	return sizeInAxis * localAxis, roundedPositionInAxis * axis, rangeMax, rangeMin
end

local function getSizeAndPositionAndRepeatRanges(
	sourcePart: BasePart,
	combinedSettings: CombinedRepeatSettings
): (Vector3, CFrame, RepeatRanges)
	local trueSize, trueRelativeCFrame = realTransform.getSizeAndRelativeCFrame(sourcePart)
	local parent = sourcePart.Parent :: BasePart
	local parentSize = parent.Size

	local xSize, xPosition, xRangeMax, xRangeMin =
		getSizeAndPositionAndRepeatRangeInAxis(trueSize, trueRelativeCFrame, parentSize, Vector3.xAxis, combinedSettings.x)
	local ySize, yPosition, yRangeMax, yRangeMin =
		getSizeAndPositionAndRepeatRangeInAxis(trueSize, trueRelativeCFrame, parentSize, Vector3.yAxis, combinedSettings.y)
	local zSize, zPosition, zRangeMax, zRangeMin =
		getSizeAndPositionAndRepeatRangeInAxis(trueSize, trueRelativeCFrame, parentSize, Vector3.zAxis, combinedSettings.z)

	local size = xSize + ySize + zSize
	local position = xPosition + yPosition + zPosition

	local relativeCFrame = CFrame.new(position) * parent.CFrame.Rotation:ToObjectSpace(sourcePart.CFrame.Rotation)

	local repeatRanges = {
		x = { min = xRangeMin, max = xRangeMax },
		y = { min = yRangeMin, max = yRangeMax },
		z = { min = zRangeMin, max = zRangeMax },
	}

	return size, relativeCFrame, repeatRanges
end

local function getCurrentRepeatVariables(sourcePart: BasePart): RepeatVariables
	local xRepeatSettings = settingsHelper.getRepeatSettings(sourcePart, "x")
	local yRepeatSettings = settingsHelper.getRepeatSettings(sourcePart, "y")
	local zRepeatSettings = settingsHelper.getRepeatSettings(sourcePart, "z")

	local trueSize, trueRelativeCFrame
	if xRepeatSettings.repeatKind or yRepeatSettings.repeatKind or zRepeatSettings.repeatKind then
		trueSize, trueRelativeCFrame = realTransform.getSizeAndRelativeCFrame(sourcePart)
	end

	local repeatVariables = {
		trueSize = trueSize,
		trueRelativeCFrame = trueRelativeCFrame,
		combinedSettings = {
			x = xRepeatSettings,
			y = yRepeatSettings,
			z = zRepeatSettings,
		},
	}

	local newSize, newRelativeCFrame, newRepeatRanges = getSizeAndPositionAndRepeatRanges(sourcePart, repeatVariables.combinedSettings)
	repeatVariables.size, repeatVariables.relativeCFrame, repeatVariables.repeatRanges = newSize, newRelativeCFrame, newRepeatRanges

	return repeatVariables :: RepeatVariables
end

local function givePartsUniqueIdentifiersRecursive(part: BasePart)
	local nameCounts = {}
	for _, child in part:GetChildren() do
		if child:IsA("BasePart") then
			local name = child.Name
			local count = nameCounts[name] or 0
			nameCounts[name] = count + 1
		end
	end

	for _, child in part:GetChildren() do
		if child:IsA("BasePart") then
			local name = child.Name
			local count = nameCounts[name]
			if count > 1 then
				attributeHelper.setAttribute(child, "__uniqueId_intelliscale_internal", name .. "_" .. count)
				givePartsUniqueIdentifiersRecursive(child)
			end
		end
	end
end

local function clearUniqueIdentifiersRecursive(part: BasePart)
	for _, child in part:GetChildren() do
		if child:IsA("BasePart") then
			attributeHelper.setAttribute(child, "__uniqueId_intelliscale_internal", nil)
			clearUniqueIdentifiersRecursive(child)
		end
	end
end

local function getPrevAndNewRepeatVariablesIfDifferent(sourcePart: BasePart): (boolean, RepeatVariables?, RepeatVariables?)
	local prevRepeatVariables = getCachedRepeatVariables(sourcePart)
	local newRepeatVariables = getCurrentRepeatVariables(sourcePart)

	-- First deep equals check filters out any parts that don't have any repeat settings at all
	if deepEquals(prevRepeatVariables, newRepeatVariables) then
		return false
	end

	-- Intialize new repeat stuff or cleanup old repeat stuff
	local repeatsFolder: Folder = sourcePart:FindFirstChild("__repeats_intelliscale_internal") :: Folder
	local blank = getBlankVariables(sourcePart)
	if deepEquals(prevRepeatVariables, blank) then
		givePartsUniqueIdentifiersRecursive(sourcePart)
		if sourcePart:FindFirstChild("__repeats_intelliscale_internal") then
			repeatsFolder = sourcePart:FindFirstChild("__repeats_intelliscale_internal") :: Folder
		else
			repeatsFolder = Instance.new("Folder")
			repeatsFolder.Name = "__repeats_intelliscale_internal"
			repeatsFolder.Parent = sourcePart
		end
		-- Create repeats folder
		-- Any other final initialization steps
	elseif deepEquals(newRepeatVariables, blank) then
		clearUniqueIdentifiersRecursive(sourcePart)
		repeatsFolder = sourcePart:FindFirstChild("__repeats_intelliscale_internal") :: Folder
		if repeatsFolder then
			repeatsFolder.Parent = nil -- Dont destroy cause undo history
		end
		-- Any other final cleanup steps
		return false
	end

	-- local prevRanges = prevRepeatVariables.repeatRanges
	local newRanges = newRepeatVariables.repeatRanges

	local usesStretchToFit = usesStretchToFit(newRepeatVariables.combinedSettings.x)
		or usesStretchToFit(newRepeatVariables.combinedSettings.y)
		or usesStretchToFit(newRepeatVariables.combinedSettings.z)

	if usesStretchToFit then
		-- Using getTrueSizeAndRelativeCFrame will allow us to cache the current
		-- size and relative cframe of the source part if they haven't yet been
		-- cached. This is useful sicne the true size and cframe will be
		-- overwritten later in this function by the stretch to fit
		-- functionality.
		local trueSize, trueRelativeCFrame = realTransform.getSizeAndRelativeCFrame(sourcePart)

		attributeHelper.setAttribute(repeatsFolder, "trueSize", trueSize)
		attributeHelper.setAttribute(repeatsFolder, "trueRelativeCFrame", trueRelativeCFrame)
		attributeHelper.setAttribute(sourcePart, "__trueSize_intelliscale_internal", trueSize, true)
		attributeHelper.setAttribute(sourcePart, "__trueRelativeCFrame_intelliscale_internal", trueRelativeCFrame, true)
	else
		if realTransform.hasTransform(sourcePart) then
			attributeHelper.setAttribute(repeatsFolder, "trueSize", nil)
			attributeHelper.setAttribute(repeatsFolder, "trueRelativeCFrame", nil)
			attributeHelper.setAttribute(sourcePart, "__trueSize_intelliscale_internal", nil, true)
			attributeHelper.setAttribute(sourcePart, "__trueRelativeCFrame_intelliscale_internal", nil, true)
		end
	end

	attributeHelper.setAttribute(repeatsFolder, "size", newRepeatVariables.size)
	attributeHelper.setAttribute(repeatsFolder, "relativeCFrame", newRepeatVariables.relativeCFrame)
	attributeHelper.setAttribute(repeatsFolder, "xMin", newRepeatVariables.repeatRanges.x.min)
	attributeHelper.setAttribute(repeatsFolder, "xMax", newRepeatVariables.repeatRanges.x.max)
	attributeHelper.setAttribute(repeatsFolder, "yMin", newRepeatVariables.repeatRanges.y.min)
	attributeHelper.setAttribute(repeatsFolder, "yMax", newRepeatVariables.repeatRanges.y.max)
	attributeHelper.setAttribute(repeatsFolder, "zMin", newRepeatVariables.repeatRanges.z.min)
	attributeHelper.setAttribute(repeatsFolder, "zMax", newRepeatVariables.repeatRanges.z.max)

	return true, prevRepeatVariables, newRepeatVariables
end

local function flattenInstanceHierarchyRecursive<InstanceType>(instance: InstanceType, newParent: Instance): InstanceType?
	if typeof(instance) ~= "Instance" then
		return
	end

	for _, child in instance:GetChildren() do
		if child:IsA("BasePart") or child:IsA("Folder") then
			flattenInstanceHierarchyRecursive(child, newParent)
			if instance.Parent ~= newParent and (child:IsA("BasePart") and child:GetAttribute("isContainer")) or child:IsA("Folder") then
				child:Destroy()
			else
				(child :: Instance).Parent = newParent
			end
		end
	end

	if instance:IsA("BasePart") then
		-- instance.CollisionGroup = "IntelliscaleUnselectable"
	end

	return instance
end

local function reconcileRepeats(
	sourcePart: BasePart,
	shouldRecreate: boolean?,
	prevRepeatRanges: RepeatRanges?,
	newRepeatRanges: RepeatRanges
)
	local repeatsFolder = sourcePart:FindFirstChild("__repeats_intelliscale_internal") :: Folder

	local newXMin, newXMax = newRepeatRanges.x.min, newRepeatRanges.x.max
	local newYMin, newYMax = newRepeatRanges.y.min, newRepeatRanges.y.max
	local newZMin, newZMax = newRepeatRanges.z.min, newRepeatRanges.z.max

	if shouldRecreate then
		repeatsFolder:ClearAllChildren()
	end

	local flatSource: Instance
	local hasFlatBeenUsed = false
	if #sourcePart:GetChildren() > 1 then
		if repeatsFolder:GetChildren()[1] then
			hasFlatBeenUsed = true
			flatSource = repeatsFolder:GetChildren()[1]
		else
			flatSource = Instance.new("Model");
			(flatSource :: Model).PrimaryPart = flattenInstanceHierarchyRecursive(sourcePart:Clone(), flatSource)
		end
	else
		flatSource = sourcePart:Clone()
		-- (flatSource :: BasePart).CollisionGroup = "IntelliscaleUnselectable"
		if #flatSource:GetChildren() > 0 then
			flatSource:GetChildren()[1]:Destroy()
		end
	end

	local parent = sourcePart.Parent :: BasePart
	local relativeCFrame = parent.CFrame:ToObjectSpace(sourcePart.CFrame)

	if prevRepeatRanges then
		local prevXMin, prevXMax = prevRepeatRanges.x.min, prevRepeatRanges.x.max
		local prevYMin, prevYMax = prevRepeatRanges.y.min, prevRepeatRanges.y.max
		local prevZMin, prevZMax = prevRepeatRanges.z.min, prevRepeatRanges.z.max

		for x = prevXMin, prevXMax do
			for y = prevYMin, prevYMax do
				for z = prevZMin, prevZMax do
					if x < newXMin or x > newXMax or y < newYMin or y > newYMax or z < newZMin or z > newZMax then
						local repeatName = string.format("%d_%d_%d", x, y, z)
						local repeatInstance = repeatsFolder:FindFirstChild(repeatName)
						if repeatInstance then
							repeatInstance.Parent = nil -- Dont destroy cause le undo history :D
						end
					end
				end
			end
		end
	end

	local xAxis = relativeCFrame:VectorToObjectSpace(Vector3.xAxis)
	local yAxis = relativeCFrame:VectorToObjectSpace(Vector3.yAxis)
	local zAxis = relativeCFrame:VectorToObjectSpace(-Vector3.zAxis)

	local xOffset = xAxis:Dot(sourcePart.Size) * xAxis
	local yOffset = yAxis:Dot(sourcePart.Size) * yAxis
	local zOffset = zAxis:Dot(sourcePart.Size) * zAxis

	for x = newXMin, newXMax do
		for y = newYMin, newYMax do
			for z = newZMin, newZMax do
				if x == 0 and y == 0 and z == 0 then
					continue
				end

				local repeatName = string.format("%d_%d_%d", x, y, z)
				local repeatInstance = repeatsFolder:FindFirstChild(repeatName)

				if not repeatInstance then
					if hasFlatBeenUsed then
						repeatInstance = flatSource:Clone()
					else
						hasFlatBeenUsed = true
						repeatInstance = flatSource
					end
				end

				assert(repeatInstance, "No repeat instance")
				repeatInstance.Name = repeatName
				repeatInstance.Parent = repeatsFolder

				local cf = sourcePart.CFrame * CFrame.new(xOffset * x + yOffset * y + zOffset * z)
				if repeatInstance:IsA("BasePart") then
					repeatInstance.CFrame = cf
				elseif repeatInstance:IsA("Model") then
					repeatInstance:PivotTo(cf)
				end
			end
		end
	end
end

function updateRepeat(sourcePart: BasePart)
	if not attributeHelper.wasLastChangedByMe(sourcePart) then
		return
	end

	local isDifferent, prevRepeatVariables_, newRepeatVariables_ = getPrevAndNewRepeatVariablesIfDifferent(sourcePart)
	local prev = prevRepeatVariables_ :: RepeatVariables
	local new = newRepeatVariables_ :: RepeatVariables
	if not isDifferent then
		return
	end

	local parent = sourcePart.Parent :: BasePart

	local prevRelativeCFrame = prev.relativeCFrame :: CFrame
	local newRelativeCFrame = new.relativeCFrame :: CFrame
	local partRelativeCFrame = parent.CFrame:ToObjectSpace(sourcePart.CFrame)
	local shouldUpdateRotation = not cframeFuzzyEq(newRelativeCFrame.Rotation, partRelativeCFrame.Rotation)
	local didRotationChange = shouldUpdateRotation or not cframeFuzzyEq(newRelativeCFrame.Rotation, prevRelativeCFrame.Rotation)

	local shouldUpdatePosition = not newRelativeCFrame.Position:FuzzyEq(partRelativeCFrame.Position, epsilon)

	local newSize = new.size :: Vector3
	local prevSize = prev.size :: Vector3
	local shouldUpdateSize = sourcePart.Size ~= newSize
	local didSizeChange = shouldUpdateSize or not newSize:FuzzyEq(prevSize, epsilon)

	local shouldUpdateRanges = not deepEquals(prev.repeatRanges, new.repeatRanges)

	-- Size changes include rotation & position changes, and rotation changes
	-- include position changes. So its safe for this logic to be exclusive.
	if shouldUpdateSize then
		local newCFrame = parent.CFrame * newRelativeCFrame
		local changedList = {}

		local axes: { types.AxisString } = {}

		if usesStretchToFit(new.combinedSettings.x) then
			table.insert(axes, "x")
		end
		if usesStretchToFit(new.combinedSettings.y) then
			table.insert(axes, "y")
		end
		if usesStretchToFit(new.combinedSettings.z) then
			table.insert(axes, "z")
		end

		print("--> doing deferred scaling")
		scaling.moveAndScaleChildrenRecursive(sourcePart, new.size, newCFrame, axes, changedList)

		for _, changedPart in changedList do
			updateRepeat(changedPart)
		end
	elseif shouldUpdateRotation or shouldUpdatePosition then
		local deltaCFrame = partRelativeCFrame:ToObjectSpace(newRelativeCFrame)
		print("--> doing deferred moving")
		scaling.cframeChildrenRecursive(sourcePart, deltaCFrame)
	end

	if shouldUpdateRanges or didSizeChange or didRotationChange then
		local shouldRecreate = didSizeChange
		reconcileRepeats(sourcePart, shouldRecreate, prev.repeatRanges, new.repeatRanges :: RepeatRanges)
	end
end

function repeating.initializeRepeating()
	janitor:Add(selectionHelper.bindToAnyContainedAttributeChanged(function()
		if repeating.isUpdatingFromAttributeChange then
			return
		end

		repeating.isUpdatingFromAttributeChange = true

		local containedSelection = selectionHelper.getContainedSelection()

		changeHistoryHelper.recordUndoChange(function()
			for _, contained in containedSelection do
				updateRepeat(contained)
			end
		end)

		task.defer(function()
			repeating.isUpdatingFromAttributeChange = false
		end)
	end))

	janitor:Add(scaling.partScaledWithHandles:Connect(function(updatedParts)
		changeHistoryHelper.recordUndoChange(function()
			for _, part in updatedParts do
				if selectionHelper.isValidContained(part) then
					print(`----- handling deferred update for {part} ------`)
					updateRepeat(part)
				end
			end
		end)
	end))

	return janitor
end

return repeating
