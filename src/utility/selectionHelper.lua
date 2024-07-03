--!strict
local Selection = game:GetService("Selection")

local packages = script.Parent.Parent.Parent.Packages
local Janitor = require(packages.Janitor)
local selectionHelper = {}

selectionHelper.jantior = Janitor.new()
local propertyAttributeJanitor = selectionHelper.jantior:Add(Janitor.new())

local contained = {
	valid = {},
	invalid = {},
	changed = {},
	single = {
		valid = {},
		invalid = {},
		changed = {},
	},
}

local container = {
	valid = {},
	invalid = {},
	changed = {},
	single = {
		valid = {},
		invalid = {},
		changed = {},
	},
}

local function createInserter(validArray: { any }, invalidArray: { any })
	return function(validFunction, invalidFunction)
		table.insert(validArray, validFunction)
		table.insert(invalidArray, invalidFunction)
		return function()
			for funcIndex, func in validArray do
				if func == validFunction then
					table.remove(validArray, funcIndex)
					break
				end
			end
			for funcIndex, func in invalidArray do
				if func == invalidFunction then
					table.remove(invalidArray, funcIndex)
					break
				end
			end
		end
	end
end

local function createSingleInserter(array: { any })
	return function(func)
		table.insert(array, func)
		return function()
			for funcIndex, func in array do
				if func == func then
					table.remove(table, funcIndex)
					break
				end
			end
		end
	end
end

selectionHelper.bindToContainedSelection = createInserter(contained.valid, contained.invalid)
selectionHelper.bindToSingleContainedSelection = createInserter(contained.single.valid, contained.single.invalid)
selectionHelper.bindToContainerSelection = createInserter(container.valid, container.invalid)
selectionHelper.bindToSingleContainerSelection = createInserter(container.single.valid, container.single.invalid)

selectionHelper.bindToAnyContainedChanged = createSingleInserter(contained.changed)
selectionHelper.bindToSingleContainedChanged = createSingleInserter(contained.single.changed)
selectionHelper.bindToAnyContainerChanged = createSingleInserter(container.changed)
selectionHelper.bindToSingleContainerChanged = createSingleInserter(container.single.changed)

local function isValidContained(instance)
	return instance:IsA("BasePart") and instance.Parent:IsA("BasePart") and instance.Parent:GetAttribute("isContainer")
end

local function isValidContainer(instance)
	return instance:IsA("BasePart") and instance:GetAttribute("isContainer")
end

local function callInArray(array, ...)
	for _, func in array do
		func(...)
	end
end

local function runAnyContainedChangeFunctions(...)
	callInArray(contained.changed, ...)
end

local function runSingleContainedChangeFunctions(...)
	callInArray(contained.single.changed, ...)
end

local function runAnyContainerChangeFunctions(...)
	callInArray(container.changed, ...)
end

local function runSingleContainerChangeFunctions(...)
	callInArray(container.single.changed, ...)
end

local function bindToInstanceChange(instance: BasePart, func: (b: BasePart | { BasePart }) -> any, selection: { BasePart }?)
	local callWithInstanceOrSelection = function()
		func(selection or instance)
	end
	propertyAttributeJanitor:Add(instance.Changed:Connect(callWithInstanceOrSelection))
	propertyAttributeJanitor:Add(instance.AttributeChanged:Connect(callWithInstanceOrSelection))
end

local function bindToInstancesChange(instances, func)
	for _, instance in instances do
		bindToInstanceChange(instance, func, instances)
	end
end

local function createCaller(array, validator, runAnyChange, runSingleChange)
	return function(instance)
		if validator(instance) then
			callInArray(array.valid, { instance })
			callInArray(array.single.valid, instance)
			bindToInstanceChange(instance, runAnyChange, { instance })
			bindToInstanceChange(instance, runSingleChange)
		else
			callInArray(array.invalid, { instance })
			callInArray(array.single.invalid, instance)
		end
	end
end

local callContained = createCaller(contained, isValidContained, runAnyContainedChangeFunctions, runSingleContainedChangeFunctions)
local callContainer = createCaller(container, isValidContainer, runAnyContainerChangeFunctions, runSingleContainerChangeFunctions)

local function callAllInvalid()
	callInArray(contained.invalid)
	callInArray(contained.single.invalid)
	callInArray(container.invalid)
	callInArray(container.single.invalid)
end

selectionHelper.jantior:Add(Selection.SelectionChanged:Connect(function()
	local selection = Selection:Get()
	propertyAttributeJanitor:Cleanup()

	if #selection == 0 then
		callAllInvalid()
	elseif #selection == 1 then
		local instance = selection[1]
		callContained(instance)
		callContainer(instance)
	elseif #selection > 1 then
		callInArray(contained.single.invalid)
		callInArray(container.single.invalid)

		local isValidContainedSelection = true
		local isValidContainerSelection = true

		for _, instance in selection do
			if not isValidContained(instance) then
				isValidContainedSelection = false
			end

			if not isValidContainer(instance) then
				isValidContainerSelection = false
			end

			if not isValidContainedSelection and not isValidContainerSelection then
				break
			end
		end

		if isValidContainedSelection then
			callInArray(contained.valid, selection)
			bindToInstancesChange(selection, runAnyContainedChangeFunctions)
		else
			callInArray(contained.invalid)
		end

		if isValidContainerSelection then
			callInArray(container.valid, selection)
			bindToInstancesChange(selection, runAnyContainerChangeFunctions)
		else
			callInArray(container.invalid)
		end
	end
end))

local function createSelectionGetter(validator)
	return function()
		local selection = Selection:Get()

		if #selection == 1 and validator(selection[1]) then
			return selection
		elseif #selection > 1 then
			local isValidSelection = true

			for _, instance in selection do
				if not validator(instance) then
					isValidSelection = false
					break
				end
			end

			if isValidSelection then
				return selection
			end
		end

		return {}
	end
end

selectionHelper.getContainedSelection = createSelectionGetter(isValidContained)
selectionHelper.getContainerSelection = createSelectionGetter(isValidContainer)

return selectionHelper
