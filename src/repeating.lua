--!strict
local RunService = game:GetService("RunService")

local Janitor = require(script.Parent.Parent.Packages.Janitor)

local attributeHelper = require(script.Parent.utility.attributeHelper)
local changeHistoryHelper = require(script.Parent.utility.changeHistoryHelper)
local fuzzyDeepEquals = require(script.Parent.utility.fuzzyDeepEquals)
local mathUtil = require(script.Parent.utility.mathUtil)
local realTransform = require(script.Parent.utility.realTransform)
local repeatSettings = require(script.Parent.utility.settingsHelper.repeatSettings)
local scaling = require(script.Parent.scaling)
local selectionHelper = require(script.Parent.utility.selectionHelper)
local types = require(script.Parent.types)

local janitor = Janitor.new()

local repeating = {}
repeating.isUpdatingFromAttributeChange = false

type RepeatRanges = {
	x: { min: number, max: number }?,
	y: { min: number, max: number }?,
	z: { min: number, max: number }?,
}

type RepeatVariables = {
	displaySize: Vector3,
	displayRelativeCFrame: CFrame,
	repeatRanges: RepeatRanges?,
	repeatSettings: repeatSettings.SingleSettingGroup?,
	realRelativeCFrame: CFrame?,
	realSize: Vector3?,
}

local function getCachedRepeatVariables(sourcePart: BasePart): RepeatVariables
	local repeatsFolder = sourcePart:FindFirstChild("__repeats_intelliscale_internal") :: Folder
	if not repeatsFolder then
		local parent = sourcePart.Parent :: BasePart
		return {
			repeatSettings = {},
			displaySize = sourcePart.Size,
			displayRelativeCFrame = parent.CFrame:ToObjectSpace(sourcePart.CFrame),
		}
	end

	local repeatSettings = repeatSettings.getSettingGroup(repeatsFolder)

	local realSize = repeatsFolder:GetAttribute("realSize") :: Vector3
	local realRelativeCFrame = repeatsFolder:GetAttribute("realRelativeCFrame") :: CFrame
	local displaySize = repeatsFolder:GetAttribute("displaySize") :: Vector3
	local displayRelativeCFrame = repeatsFolder:GetAttribute("displayRelativeCFrame") :: CFrame

	local repeatRanges
	if repeatSettings then
		repeatRanges = {}
		if repeatSettings.x then
			repeatRanges.x = {
				min = (repeatsFolder:GetAttribute("xMin") :: number?) or 0,
				max = (repeatsFolder:GetAttribute("xMax") :: number?) or 0,
			}
		end
		if repeatSettings.y then
			repeatRanges.y = {
				min = (repeatsFolder:GetAttribute("yMin") :: number?) or 0,
				max = (repeatsFolder:GetAttribute("yMax") :: number?) or 0,
			}
		end
		if repeatSettings.z then
			repeatRanges.z = {
				min = (repeatsFolder:GetAttribute("zMin") :: number?) or 0,
				max = (repeatsFolder:GetAttribute("zMax") :: number?) or 0,
			}
		end
	end

	return {
		displaySize = displaySize,
		displayRelativeCFrame = displayRelativeCFrame,
		repeatRanges = repeatRanges,
		repeatSettings = repeatSettings,
		realSize = realSize,
		realRelativeCFrame = realRelativeCFrame,
	}
end

-- Returns position relative to parent in the axis, size in the axis, and the range of repeats in the axis
local function getSizeAndPositionAndRepeatRangeInAxis(
	realSize: Vector3,
	realRelativeCFrame: CFrame,
	parentSize: Vector3,
	axis: Vector3,
	axisRepeatSettings: repeatSettings.SingleAxisSetting?
): (Vector3, Vector3, number?, number?)
	local positionInAxis = realRelativeCFrame.Position:Dot(axis)
	local relativeAxis = realRelativeCFrame:VectorToObjectSpace(axis)
	local sizeInAxis = math.abs(realSize:Dot(relativeAxis))
	local sign = math.sign(realSize:Dot(relativeAxis))
	local parentSizeInAxis = parentSize:Dot(axis)

	if axisRepeatSettings == nil then
		return sizeInAxis * relativeAxis * sign, positionInAxis * axis
	end

	if parentSizeInAxis < sizeInAxis or (parentSizeInAxis / 2 + mathUtil.epsilon) < (math.abs(positionInAxis) + sizeInAxis / 2) then
		return sizeInAxis * relativeAxis * sign, positionInAxis * axis, 0, 0
	end

	local parentEdgePos = parentSizeInAxis / 2

	if not (axisRepeatSettings.settingValue == "To Extents" and axisRepeatSettings.childrenSettings.stretchToFit) then
		local halfSize = sizeInAxis / 2
		local rangeMin, rangeMax
		if axisRepeatSettings.settingValue == "To Extents" then
			rangeMax = (parentEdgePos - halfSize - positionInAxis) // sizeInAxis
			rangeMin = -((parentEdgePos - halfSize + positionInAxis) // sizeInAxis)
		else
			rangeMax = axisRepeatSettings.childrenSettings.repeatAmountPositive :: number
			rangeMin = axisRepeatSettings.childrenSettings.repeatAmountNegative :: number
		end

		return sizeInAxis * relativeAxis * sign, positionInAxis * axis, rangeMax, rangeMin
	end

	local repeatsInAxis = parentSizeInAxis // sizeInAxis
	sizeInAxis = parentSizeInAxis / repeatsInAxis
	local halfSize = sizeInAxis / 2

	local roundOffset = repeatsInAxis % 2 == 0 and sizeInAxis / 2 or 0
	local roundedPositionInAxis = mathUtil.round(positionInAxis - roundOffset, sizeInAxis) + roundOffset

	local rangeMax = mathUtil.round((parentEdgePos - halfSize - roundedPositionInAxis) / sizeInAxis, 1)
	local rangeMin = mathUtil.round((halfSize - parentEdgePos - roundedPositionInAxis) / sizeInAxis, 1)

	return sizeInAxis * relativeAxis * sign, roundedPositionInAxis * axis, rangeMax, rangeMin
end

local function getSizeAndPositionAndRepeatRanges(
	sourcePart: BasePart,
	repeatSettings: repeatSettings.SingleSettingGroup?
): (Vector3, CFrame, RepeatRanges?)
	local repeatRanges: RepeatRanges
	local parent = sourcePart.Parent :: BasePart
	local realSize, realRelativeCFrame = realTransform.getSizeAndRelativeCFrame(sourcePart)

	if repeatSettings and next(repeatSettings) then
		local parentSize = parent.Size

		local xSize, xPosition, xRangeMax, xRangeMin =
			getSizeAndPositionAndRepeatRangeInAxis(realSize, realRelativeCFrame, parentSize, Vector3.xAxis, repeatSettings.x)
		local ySize, yPosition, yRangeMax, yRangeMin =
			getSizeAndPositionAndRepeatRangeInAxis(realSize, realRelativeCFrame, parentSize, Vector3.yAxis, repeatSettings.y)
		local zSize, zPosition, zRangeMax, zRangeMin =
			getSizeAndPositionAndRepeatRangeInAxis(realSize, realRelativeCFrame, parentSize, Vector3.zAxis, repeatSettings.z)

		local displaySize = xSize + ySize + zSize
		local position = xPosition + yPosition + zPosition

		local displayRelativeCFrame = CFrame.new(position) * realRelativeCFrame.Rotation

		if xRangeMax and xRangeMin then
			repeatRanges = repeatRanges or {}
			repeatRanges.x = { min = xRangeMin, max = xRangeMax }
		end
		if yRangeMax and yRangeMin then
			repeatRanges = repeatRanges or {}
			repeatRanges.y = { min = yRangeMin, max = yRangeMax }
		end
		if zRangeMax and zRangeMin then
			repeatRanges = repeatRanges or {}
			repeatRanges.z = { min = zRangeMin, max = zRangeMax }
		end

		return displaySize, displayRelativeCFrame, repeatRanges
	end

	return realSize, realRelativeCFrame, nil
end

local function axisHasStretchToFitSettings(axisSettings: repeatSettings.SingleAxisSetting?)
	return axisSettings and axisSettings.settingValue == "To Extents" and axisSettings.childrenSettings.stretchToFit
end

local function hasStretchToFitSettings(repeatSettings: repeatSettings.SingleSettingGroup)
	return axisHasStretchToFitSettings(repeatSettings.x)
		or axisHasStretchToFitSettings(repeatSettings.y)
		or axisHasStretchToFitSettings(repeatSettings.z)
end

local function flattenInstanceHierarchyRecursive<InstanceType>(instance: InstanceType, newParent: Instance): InstanceType?
	if typeof(instance) ~= "Instance" then
		return
	end

	for _, child in instance:GetChildren() do
		flattenInstanceHierarchyRecursive(child, newParent)
	end

	if instance:IsA("BasePart") then
		instance.CollisionGroup = "IntelliscaleUnselectable"
		instance.Parent = newParent
	elseif instance:IsA("Folder") or instance:IsA("Model") then
		instance:Destroy()
	end

	return instance
end

local function reconcileRepeats(
	sourcePart: BasePart,
	shouldRecreate: boolean,
	prevRepeatRanges: RepeatRanges?,
	newRepeatRanges: RepeatRanges
)
	local repeatsFolder = sourcePart:FindFirstChild("__repeats_intelliscale_internal") :: Folder

	local newXMin, newXMax = 0, 0
	if newRepeatRanges.x then
		newXMin, newXMax = newRepeatRanges.x.min, newRepeatRanges.x.max
	end

	local newYMin, newYMax = 0, 0
	if newRepeatRanges.y then
		newYMin, newYMax = newRepeatRanges.y.min, newRepeatRanges.y.max
	end

	local newZMin, newZMax = 0, 0
	if newRepeatRanges.z then
		newZMin, newZMax = newRepeatRanges.z.min, newRepeatRanges.z.max
	end

	if shouldRecreate then
		repeatsFolder:ClearAllChildren()
	end

	local flatSource: Instance
	local hasFlatBeenUsed = false
	if sourcePart:FindFirstChildWhichIsA("BasePart") then
		if repeatsFolder:GetChildren()[1] then
			hasFlatBeenUsed = true
			flatSource = repeatsFolder:GetChildren()[1]
		else
			flatSource = Instance.new("Model");
			(flatSource :: Model).PrimaryPart = flattenInstanceHierarchyRecursive(sourcePart:Clone(), flatSource)
		end
	else
		flatSource = sourcePart:Clone()
		local flatRepeats = flatSource:FindFirstChild("__repeats_intelliscale_internal") :: Folder;
		(flatSource :: BasePart).CollisionGroup = "IntelliscaleUnselectable"
		if flatRepeats then
			flatRepeats:Destroy()
		end
	end

	local parent = sourcePart.Parent :: BasePart
	local relativeCFrame = parent.CFrame:ToObjectSpace(sourcePart.CFrame)

	if prevRepeatRanges then
		local prevXMin, prevXMax = 0, 0
		if prevRepeatRanges.x then
			prevXMin, prevXMax = prevRepeatRanges.x.min, prevRepeatRanges.x.max
		end

		local prevYMin, prevYMax = 0, 0
		if prevRepeatRanges.y then
			prevYMin, prevYMax = prevRepeatRanges.y.min, prevRepeatRanges.y.max
		end

		local prevZMin, prevZMax = 0, 0
		if prevRepeatRanges.z then
			prevZMin, prevZMax = prevRepeatRanges.z.min, prevRepeatRanges.z.max
		end

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

	local size = sourcePart.Size

	local xAxis = relativeCFrame:VectorToObjectSpace(Vector3.xAxis)
	local yAxis = relativeCFrame:VectorToObjectSpace(Vector3.yAxis)
	local zAxis = relativeCFrame:VectorToObjectSpace(Vector3.zAxis)

	local xOffset = math.abs(size:Dot(xAxis)) * xAxis
	local yOffset = math.abs(size:Dot(yAxis)) * yAxis
	local zOffset = math.abs(size:Dot(zAxis)) * zAxis

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

				local cf = sourcePart.CFrame * CFrame.new(xOffset * x + yOffset * y + zOffset * z) --* relativeCFrame.Rotation
				if repeatInstance:IsA("BasePart") then
					repeatInstance.CFrame = cf
				elseif repeatInstance:IsA("Model") then
					repeatInstance:PivotTo(cf)
				end
			end
		end
	end
end

local changesLastFrame = 0
local changesInFrame = 0
function repeating.updateRepeat(sourcePart: BasePart)
	if not attributeHelper.wasLastChangedByMe(sourcePart) then
		return
	end

	changesInFrame += 1
	if changesInFrame > 10 or changesLastFrame > 10 then
		error("No more  repeat changes this frame, hung too long.")
		return
	end

	local prev = getCachedRepeatVariables(sourcePart)

	local newRepeatSettings = repeatSettings.getSettingGroup(sourcePart)
	local newRealSize, newRealRelativeCFrame = realTransform.getSizeAndRelativeCFrameAttributes(sourcePart)
	local newDisplaySize, newDisplayRelativeCFrame, newRepeatRanges = getSizeAndPositionAndRepeatRanges(sourcePart, newRepeatSettings)

	local new: RepeatVariables = {
		displaySize = newDisplaySize,
		displayRelativeCFrame = newDisplayRelativeCFrame,
		repeatRanges = newRepeatRanges,
		repeatSettings = newRepeatSettings,
		realRelativeCFrame = newRealSize,
		realSize = newRealRelativeCFrame,
	}

	local prevHasRepeatSettings = prev.repeatSettings and next(prev.repeatSettings)
	local newHasRepeatSettings = new.repeatSettings and next(new.repeatSettings)

	if (not prevHasRepeatSettings and not newHasRepeatSettings) or fuzzyDeepEquals(prev, new) then
		return
	end

	-- Intialize new repeat stuff or cleanup old repeat stuff
	local repeatsFolder: Folder = sourcePart:FindFirstChild("__repeats_intelliscale_internal") :: Folder
	if not (prev.repeatSettings and next(prev.repeatSettings)) then
		if sourcePart:FindFirstChild("__repeats_intelliscale_internal") then
			repeatsFolder = sourcePart:FindFirstChild("__repeats_intelliscale_internal") :: Folder
		else
			repeatsFolder = Instance.new("Folder")
			repeatsFolder.Name = "__repeats_intelliscale_internal"
			repeatsFolder.Parent = sourcePart
		end
	end

	if newRepeatSettings and hasStretchToFitSettings(newRepeatSettings) then
		local realSize, realRelativeCFrame = realTransform.getSizeAndRelativeCFrame(sourcePart)
		realTransform.setSizeAndRelativeCFrameAttributes(sourcePart, realSize, realRelativeCFrame)
		realTransform.setSizeAndRelativeCFrameAttributes(repeatsFolder, realSize, realRelativeCFrame)
	else
		if realTransform.hasTransform(sourcePart) then
			realTransform.setSizeAndRelativeCFrameAttributes(sourcePart, nil, nil)
			realTransform.setSizeAndRelativeCFrameAttributes(repeatsFolder, nil, nil)
		end
	end

	local parent = sourcePart.Parent :: BasePart

	local prevDisplayRelativeCFrame = prev.displayRelativeCFrame :: CFrame
	local partRelativeCFrame = parent.CFrame:ToObjectSpace(sourcePart.CFrame)
	local shouldUpdateRotation = not mathUtil.cframeFuzzyEq(newDisplayRelativeCFrame.Rotation, prevDisplayRelativeCFrame.Rotation)
	local didRotationChange = shouldUpdateRotation
		or not mathUtil.cframeFuzzyEq(newDisplayRelativeCFrame.Rotation, prevDisplayRelativeCFrame.Rotation)

	local shouldUpdatePosition = not newDisplayRelativeCFrame.Position:FuzzyEq(partRelativeCFrame.Position, mathUtil.epsilon)

	local prevDisplaySize = prev.displaySize :: Vector3
	local shouldUpdateSize = sourcePart.Size ~= newDisplaySize
	local didSizeChange = shouldUpdateSize or not newDisplaySize:FuzzyEq(prevDisplaySize, mathUtil.epsilon)

	local shouldUpdateRanges = not fuzzyDeepEquals(prev.repeatRanges, new.repeatRanges)

	-- Reposition the source part if necessary
	if shouldUpdateSize then
		local newCFrame = parent.CFrame * newDisplayRelativeCFrame
		local changedList = {}

		local axes: { types.AxisString } = {}

		if not mathUtil.fuzzyEq(newDisplaySize.X, prevDisplaySize.X) then
			table.insert(axes, "x")
		end
		if not mathUtil.fuzzyEq(newDisplaySize.Y, prevDisplaySize.Y) then
			table.insert(axes, "y")
		end
		if not mathUtil.fuzzyEq(newDisplaySize.Z, prevDisplaySize.Z) then
			table.insert(axes, "z")
		end

		scaling.moveAndScaleChildrenRecursive(sourcePart, newDisplaySize, newCFrame, axes, changedList)

		for _, changedPart in changedList do
			repeating.updateRepeat(changedPart)
		end
	elseif shouldUpdateRotation or shouldUpdatePosition then
		local deltaCFrame = partRelativeCFrame:ToObjectSpace(newDisplayRelativeCFrame)
		scaling.cframeRecursive(sourcePart, deltaCFrame, false, true)
	end

	-- If we've cleared all repeat settings, remove the repeats folder.
	-- Otherwise, update the cached variables on the folder and reconcile the
	-- repeated objects, if necessary.
	if not (newRepeatSettings and next(newRepeatSettings :: { [string]: any })) then
		repeatsFolder = sourcePart:FindFirstChild("__repeats_intelliscale_internal") :: Folder
		if repeatsFolder then
			repeatsFolder.Parent = nil
		end
	else
		attributeHelper.setAttribute(repeatsFolder, "displaySize", newDisplaySize)
		attributeHelper.setAttribute(repeatsFolder, "displayRelativeCFrame", newDisplayRelativeCFrame)

		if newRepeatRanges and newRepeatRanges.x then
			attributeHelper.setAttribute(repeatsFolder, "xMin", newRepeatRanges.x.min)
			attributeHelper.setAttribute(repeatsFolder, "xMax", newRepeatRanges.x.max)
		else
			attributeHelper.setAttribute(repeatsFolder, "xMin", nil)
			attributeHelper.setAttribute(repeatsFolder, "xMax", nil)
		end

		if newRepeatRanges and newRepeatRanges.y then
			attributeHelper.setAttribute(repeatsFolder, "yMin", newRepeatRanges.y.min)
			attributeHelper.setAttribute(repeatsFolder, "yMax", newRepeatRanges.y.max)
		else
			attributeHelper.setAttribute(repeatsFolder, "yMin", nil)
			attributeHelper.setAttribute(repeatsFolder, "yMax", nil)
		end

		if newRepeatRanges and newRepeatRanges.z then
			attributeHelper.setAttribute(repeatsFolder, "zMin", newRepeatRanges.z.min)
			attributeHelper.setAttribute(repeatsFolder, "zMax", newRepeatRanges.z.max)
		else
			attributeHelper.setAttribute(repeatsFolder, "zMin", nil)
			attributeHelper.setAttribute(repeatsFolder, "zMax", nil)
		end

		repeatSettings.cacheSettings(newRepeatSettings, repeatsFolder)

		if shouldUpdateRanges or didSizeChange or didRotationChange then
			local shouldRecreate = didSizeChange
			reconcileRepeats(sourcePart, shouldRecreate, prev.repeatRanges, new.repeatRanges :: RepeatRanges)
		end
	end
end

function repeating.getFolder(part: BasePart)
	return part:FindFirstChild("__repeats_intelliscale_internal") :: Folder
end

function repeating.initialize()
	local repeatingAttributes = {
		"xRepeatKind",
		"xStretchToFit",
		"xRepeatAmountPositive",
		"xRepeatAmountNegative",
		"yRepeatKind",
		"yStretchToFit",
		"yRepeatAmountPositive",
		"yRepeatAmountNegative",
		"zRepeatKind",
		"zStretchToFit",
		"zRepeatAmountPositive",
		"zRepeatAmountNegative",
	}

	janitor:Add(selectionHelper.addAttributeChangeCallback(selectionHelper.callbackDicts.contained, repeatingAttributes, function()
		if repeating.isUpdatingFromAttributeChange then
			return
		end

		repeating.isUpdatingFromAttributeChange = true

		local containedSelection = selectionHelper.getContainedSelection()

		changeHistoryHelper.recordUndoChange(function()
			for _, contained in containedSelection do
				repeating.updateRepeat(contained :: BasePart)
			end
		end)

		task.defer(function()
			repeating.isUpdatingFromAttributeChange = false
		end)
	end))

	janitor:Add(RunService.Heartbeat:Connect(function()
		changesLastFrame = changesInFrame
		changesInFrame = 0
	end))

	return janitor
end

return repeating
