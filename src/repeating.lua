--!strict
local packages = script.Parent.Parent.Packages
local Janitor = require(packages.Janitor)

local epsilon = 1e-4

local source = script.Parent
local attributeHelper = require(source.utility.attributeHelper)
local selectionHelper = require(source.utility.selectionHelper)
local settingsHelper = require(source.utility.settingsHelper)

local janitor = Janitor.new()

local repeating = {}

type CombinedRepeatSettings = {
	x: settingsHelper.RepeatSettings,
	y: settingsHelper.RepeatSettings,
	z: settingsHelper.RepeatSettings,
}

type CachedRepeatSettings = {
	size: Vector3?,
	relativeCFrame: CFrame?,
	combinedSettings: CombinedRepeatSettings,
}

local cachedRepeatSettings: { [BasePart]: CachedRepeatSettings } = {}

local blankSettings: CachedRepeatSettings = {
	combinedSettings = {
		x = {},
		y = {},
		z = {},
	},
}

local function getRepeatSettings(contained: BasePart): CachedRepeatSettings
	local xRepeatSettings = settingsHelper.getRepeatSettings(contained, "x")
	local yRepeatSettings = settingsHelper.getRepeatSettings(contained, "y")
	local zRepeatSettings = settingsHelper.getRepeatSettings(contained, "z")

	local size, relativeCFrame
	if xRepeatSettings.repeatKind or yRepeatSettings.repeatKind or zRepeatSettings.repeatKind then
		local parent = contained.Parent :: BasePart
		size = contained.Size
		relativeCFrame = parent.CFrame:ToObjectSpace(contained.CFrame)
	end

	return {
		size = size,
		relativeCFrame = relativeCFrame,
		combinedSettings = {
			x = xRepeatSettings,
			y = yRepeatSettings,
			z = zRepeatSettings,
		},
	}
end

local function getCachedRepeatSettings(contained: BasePart): CachedRepeatSettings
	local repeatsFolder = contained:FindFirstChild("__repeats_intelliscale_internal") :: Folder
	if not repeatsFolder then
		return blankSettings
	end

	local xRepeatSettings = settingsHelper.getRepeatSettings(repeatsFolder, "x")
	local yRepeatSettings = settingsHelper.getRepeatSettings(repeatsFolder, "y")
	local zRepeatSettings = settingsHelper.getRepeatSettings(repeatsFolder, "z")

	local size = repeatsFolder:GetAttribute("size") :: Vector3
	local relativeCFrame = repeatsFolder:GetAttribute("relativeCFrame") :: CFrame

	return {
		size = size,
		relativeCFrame = relativeCFrame,
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

function repeating.initializeRepeating()
	-- Refactor to only update here when the repeat settings change
	janitor:Add(selectionHelper.bindToAnyContainedChanged(function(containeds)
		for _, contained in containeds do
			if not attributeHelper.wasLastChangedByMe(contained) then
				continue
			end

			local cachedSettings = getCachedRepeatSettings(contained)
			local currentSettings = getRepeatSettings(contained)

			if deepEquals(cachedSettings, currentSettings) then
				continue
			end

			local diff = deepDifference(cachedSettings, currentSettings)

			-- If relative CFrame is different then
			---- If extents repeat then
			------ If position is different then
			-------- If stretch to fit then
			---------- Must recalculate size, & repeat amount in this axis
			-------- Otherwise if fixed size
			---------- Recalculate repeat amounts
			---------- If repeat amount is different then
			------------ Recreate repeats
			---------- Otherwise just reposition repeats
			---- If fixed amount repeat then
			------ Just move or rotate the repeats
		end
	end))
end

-- Handle position & size changes here
function repeating.updateRepeatsFromSizeOrPositionChanges(changedList)
	-- Iterate through the changedList and update repeats as necessary. Each
	-- time we update, we should climb the hierarchy up to the root container,
	-- and mark any repeats that need to be re-created due to their structure changing.
end

return repeating
