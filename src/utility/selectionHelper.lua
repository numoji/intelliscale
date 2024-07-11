--!strict
local Selection = game:GetService("Selection")

local packages = script.Parent.Parent.Parent.Packages
local Janitor = require(packages.Janitor)

local utility = script.Parent
local realTransform = require(utility.realTransform)
local selectionHelper = {}

selectionHelper.jantior = Janitor.new()
local propertyAttributeJanitor = selectionHelper.jantior:Add(Janitor.new())
local partByFauxPart: { [BasePart]: BasePart } = {}

type Selection = { BasePart }
type PartOrSelection = BasePart & Selection

type f = (...any) -> any
type InvalidCallback = () -> ()

type ValidCallback = (Selection, Selection?) -> ()
type SingleValidCallback = (BasePart, BasePart?) -> ()
type CombinedValidCallback = (PartOrSelection, PartOrSelection?) -> ()
type BindingsDictionary = {
	invalid: { InvalidCallback },
	valid: { ValidCallback },
	changed: { ValidCallback },
	attChanged: { ValidCallback },
	single: {
		invalid: { InvalidCallback },
		valid: { SingleValidCallback },
		changed: { SingleValidCallback },
		attChanged: { SingleValidCallback },
	},
}

local contained: BindingsDictionary = {
	invalid = {},
	valid = {},
	changed = {},
	attChanged = {},
	single = {
		invalid = {},
		valid = {},
		changed = {},
		attChanged = {},
	},
}

local container: BindingsDictionary = {
	invalid = {},
	valid = {},
	changed = {},
	attChanged = {},
	single = {
		invalid = {},
		valid = {},
		changed = {},
		attChanged = {},
	},
}

local function createInserter<ValidCallbackType, InvalidCallbackType>(validArray: { ValidCallbackType }, invalidArray: { InvalidCallbackType })
	return function(validFunction: ValidCallbackType, invalidFunction: InvalidCallbackType)
		table.insert(validArray, validFunction)
		table.insert(invalidArray, invalidFunction)
		return function()
			for funcIndex, funcToRemove in validArray do
				if funcToRemove == validFunction then
					table.remove(validArray, funcIndex)
					break
				end
			end
			for funcIndex, funcToRemove in invalidArray do
				if funcToRemove == invalidFunction then
					table.remove(invalidArray, funcIndex)
					break
				end
			end
		end
	end
end

local function createSingleInserter<CallbackType>(callbackArray: { CallbackType })
	return function(callback: CallbackType)
		table.insert(callbackArray, callback)
		return function()
			for funcIndex, callbackToRemove in callbackArray do
				if callbackToRemove == callback then
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

selectionHelper.bindToAnyContainedAttributeChanged = createSingleInserter(contained.attChanged)
selectionHelper.bindToSingleContainedAttributeChanged = createSingleInserter(contained.single.attChanged)
selectionHelper.bindToAnyContainerAttributeChanged = createSingleInserter(container.attChanged)
selectionHelper.bindToSingleContainerAttributeChanged = createSingleInserter(container.single.attChanged)

type ValidatorOverload = ((Instance) -> boolean) & ((Selection) -> boolean)
local function createValidator(validateFunction: (Instance) -> boolean)
	local validator: ValidatorOverload = function(instanceOrSelection)
		if typeof(instanceOrSelection) == "Instance" then
			return validateFunction(instanceOrSelection)
		elseif typeof(instanceOrSelection) == "table" then
			for _, instance in instanceOrSelection do
				if not validateFunction(instance) then
					return false
				end
			end

			return true
		end

		return false
	end

	return validator
end

local isValidContained = createValidator(function(instance: Instance): boolean
	return instance:IsA("BasePart") and instance.Parent and instance.Parent:IsA("BasePart") and instance.Parent:GetAttribute("isContainer")
end)

local isValidContainer = createValidator(function(instance: Instance): boolean
	return instance:IsA("BasePart") and instance:GetAttribute("isContainer")
end)

local function isValidContainedOrContainer(instance: Instance): boolean
	return isValidContained(instance) or isValidContainer(instance)
end

local function alwaysValid(...: any?): boolean
	return true
end

--stylua: ignore
type CallInArrayOverload = 
	({InvalidCallback}, nil?, nil?) -> () 
	& ({ValidCallback}, Selection, Selection?) -> () 
	& ({SingleValidCallback}, BasePart, BasePart?) -> ()
local callInArray: CallInArrayOverload = function(callbackArray, selection, fauxSelection)
	for _, callbackFunc in callbackArray do
		callbackFunc(selection, fauxSelection)
	end
end

local function runAnyContainedChangeFunctions(selection: Selection, fauxSelection: Selection?)
	callInArray(contained.changed, selection, fauxSelection)
end

local function runAnyContainedAttChangeFunctions(selection: Selection, fauxSelection: Selection?)
	callInArray(contained.attChanged, selection, fauxSelection)
end

local function runAnyContainerChangeFunctions(selection: Selection, fauxSelection: Selection?)
	callInArray(container.changed, selection, fauxSelection)
end

local function runAnyContainerAttChangeFunctions(selection: Selection, fauxSelection: Selection?)
	callInArray(container.attChanged, selection, fauxSelection)
end

local function runSingleContainedChangeFunctions(selected: BasePart, fauxSelected: BasePart?)
	callInArray(contained.single.changed, selected, fauxSelected)
end

local function runSingleContainedAttChangeFunctions(selected: BasePart, fauxSelected: BasePart?)
	callInArray(contained.single.attChanged, selected, fauxSelected)
end

local function runSingleContainerChangeFunctions(selected: BasePart, fauxSelected: BasePart?)
	callInArray(container.single.changed, selected, fauxSelected)
end

local function runSingleContainerAttChangeFunctions(selected: BasePart, fauxSelected: BasePart?)
	callInArray(container.single.attChanged, selected, fauxSelected)
end

local function bindToInstanceChanged<CallbackArgumentType>(
	changeFunction: (CallbackArgumentType, CallbackArgumentType?) -> (),
	attChangeFunction: ((CallbackArgumentType, CallbackArgumentType?) -> ())?,
	validator: (CallbackArgumentType) -> boolean,
	listenedPart: BasePart,
	selection: CallbackArgumentType,
	fauxSelection: CallbackArgumentType?
)
	propertyAttributeJanitor:Add(listenedPart.Changed:Connect(function(propName)
		if validator(selection) then
			changeFunction(selection, fauxSelection)
		end
	end))

	propertyAttributeJanitor:Add(listenedPart.AttributeChanged:Connect(function(attName)
		if validator(selection) then
			changeFunction(selection, fauxSelection)

			if attChangeFunction then
				attChangeFunction(selection, fauxSelection)
			end
		end
	end))
end

local function bindToSelectedPartsChanged<CallbackArgumentType>(
	selection: Selection,
	fauxSelection: Selection?,
	validator: (Selection) -> boolean,
	changeFunction: (Selection, Selection?) -> (),
	attChangeFunction: ((Selection, Selection?) -> ())?
)
	for _, part in selection do
		bindToInstanceChanged(changeFunction, attChangeFunction, validator, part, selection, fauxSelection)
	end
end

local function createCaller(
	dictionary: BindingsDictionary,
	validator: ValidatorOverload,
	runAnyChange: ValidCallback,
	runSingleChange: SingleValidCallback,
	runAnyAttChange: ValidCallback,
	runSingleAttChange: SingleValidCallback
)
	return function(instance: Instance, fauxInstance: Instance?)
		if validator(instance) then
			local part = instance :: BasePart
			local fauxPart = fauxInstance :: BasePart?
			local selection: Selection = { part }
			local fauxSelection: Selection?
			if fauxPart then
				fauxSelection = { fauxPart }
			end

			callInArray(dictionary.valid, selection, fauxSelection)
			callInArray(dictionary.single.valid, part, fauxPart)

			bindToInstanceChanged(runAnyChange, runAnyAttChange, validator, part, selection, fauxSelection)
			bindToInstanceChanged(runSingleChange, runSingleAttChange, validator, part, part, fauxPart)
		else
			callInArray(dictionary.invalid)
			callInArray(dictionary.single.invalid)
		end
	end
end

local callContained = createCaller(
	contained,
	isValidContained,
	runAnyContainedChangeFunctions,
	runSingleContainedChangeFunctions,
	runAnyContainedAttChangeFunctions,
	runSingleContainedAttChangeFunctions
)
local callContainer = createCaller(
	container,
	isValidContainer,
	runAnyContainerChangeFunctions,
	runSingleContainerChangeFunctions,
	runAnyContainerAttChangeFunctions,
	runSingleContainerAttChangeFunctions
)

local function callAllInvalid()
	callInArray(contained.invalid)
	callInArray(contained.single.invalid)
	callInArray(container.invalid)
	callInArray(container.single.invalid)
end

function selectionHelper.getRealInstance(instance: Instance | BasePart): Instance | BasePart
	return partByFauxPart[instance :: BasePart] or instance
end

local function shouldFaux(part): boolean
	return realTransform.hasTransform(part)
		or part:FindFirstChildWhichIsA("BasePart") ~= nil
		or part:FindFirstChildWhichIsA("Folder") ~= nil
end

local function getSelectionAndFauxSelection(): (Selection, Selection, boolean)
	local selection: Selection = {}
	local fauxSelection: Selection = {}
	local currentSelectedFauxPartsSet: { [BasePart]: BasePart } = {}

	local shouldSelectFauxParts = false

	for _, instance in Selection:Get() do
		local realInstance = selectionHelper.getRealInstance(instance)
		table.insert(selection, realInstance :: BasePart)

		if not (isValidContainedOrContainer(realInstance) and instance:IsA("BasePart") and realInstance:IsA("BasePart")) then
			table.insert(fauxSelection, instance)
			continue
		end

		local part = instance
		local realPart = realInstance

		-- If the selected part is a faux part, then add it to the faux
		-- selection. If the selected part is a real part, but it has true size
		-- & true relative cframe attributes, then create a faux part for it.

		if realPart ~= part then
			table.insert(fauxSelection, part)
			currentSelectedFauxPartsSet[part] = realPart
			continue
		elseif shouldFaux(part) then
			shouldSelectFauxParts = true

			local fauxPart = Instance.new("Part")
			fauxPart.Anchored = true
			fauxPart.CanCollide = false
			fauxPart.Transparency = 1
			fauxPart.CollisionGroup = "IntelliscaleUnselectable"
			fauxPart.Parent = workspace.CurrentCamera

			fauxPart.Size, fauxPart.CFrame = realTransform.getSizeAndGlobalCFrame(part)

			partByFauxPart[fauxPart] = part
			currentSelectedFauxPartsSet[fauxPart] = part
			table.insert(fauxSelection, fauxPart)
			continue
		end

		table.insert(fauxSelection, part)
	end

	for fauxPart, part in partByFauxPart do
		if not currentSelectedFauxPartsSet[fauxPart] then
			fauxPart:Destroy()
			partByFauxPart[fauxPart] = nil
		end
	end

	return selection, fauxSelection, shouldSelectFauxParts
end

local isChangingSelection = false
function updateSelection()
	if isChangingSelection then
		return
	end

	local selection, fauxSelection, shouldSelectFauxParts = getSelectionAndFauxSelection()
	if shouldSelectFauxParts then
		isChangingSelection = true
		Selection:Set(fauxSelection)
		task.defer(function()
			isChangingSelection = false
		end)
	end

	propertyAttributeJanitor:Cleanup()

	if #selection == 0 then
		callAllInvalid()
	elseif #selection == 1 then
		local part = selection[1]
		local fauxPart = fauxSelection[1]
		callContained(part, fauxPart)
		callContainer(part, fauxPart)
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
			callInArray(contained.valid, selection, fauxSelection)
			bindToSelectedPartsChanged(
				selection,
				fauxSelection,
				isValidContained,
				runAnyContainedChangeFunctions,
				runAnyContainedAttChangeFunctions
			)
		else
			callInArray(contained.invalid)
		end

		if isValidContainerSelection then
			callInArray(container.valid, selection, fauxSelection)
			bindToSelectedPartsChanged(
				selection,
				fauxSelection,
				isValidContainer,
				runAnyContainerChangeFunctions,
				runAnyContainerAttChangeFunctions
			)
		else
			callInArray(container.invalid)
		end
	end

	if #selection > 0 then
		local wasChangedThisFrame = false
		local didCallUpdate = false
		bindToSelectedPartsChanged(selection, fauxSelection, alwaysValid, function(selection, fauxSelection)
			if not fauxSelection or isChangingSelection or wasChangedThisFrame or didCallUpdate then
				return
			end

			wasChangedThisFrame = true

			task.defer(function()
				local shouldChangeSelection = false
				for i, instance in fauxSelection do
					local realInstance = selectionHelper.getRealInstance(instance)
					if instance == realInstance then
						continue
					end

					local part = instance :: BasePart
					local realPart = realInstance :: BasePart

					if not realTransform.hasTransform(realPart) then
						part:Destroy()
						partByFauxPart[part] = nil

						table.remove(fauxSelection, i)
						table.insert(fauxSelection, i, realPart)

						shouldChangeSelection = true
					end
				end

				if shouldChangeSelection then
					isChangingSelection = true
					Selection:Set(fauxSelection)
					task.defer(function()
						isChangingSelection = false
					end)
				elseif not isChangingSelection then
					didCallUpdate = true
					updateSelection()
				end

				wasChangedThisFrame = false
			end)
		end, function() end)
	end
end

selectionHelper.jantior:Add(Selection.SelectionChanged:Connect(updateSelection))

local function createSelectionGetter(validator)
	return function()
		local selection, fauxSelection = getSelectionAndFauxSelection()

		if #selection == 1 and validator(selection[1]) then
			return selection, fauxSelection
		elseif #selection > 1 then
			local isValidSelection = true

			for _, instance in selection do
				if not validator(instance) then
					isValidSelection = false
					break
				end
			end

			if isValidSelection then
				return selection, fauxSelection
			end
		end

		return {}, {}
	end
end

selectionHelper.jantior:Add(function()
	for fauxPart, _ in partByFauxPart do
		fauxPart:Destroy()
	end
end)

selectionHelper.getContainedSelection = createSelectionGetter(isValidContained)
selectionHelper.getContainerSelection = createSelectionGetter(isValidContainer)
selectionHelper.getContainedAndContainerSelection = createSelectionGetter(isValidContainedOrContainer)
selectionHelper.updateSelection = updateSelection

selectionHelper.isValidContained = isValidContained
selectionHelper.isValidContainer = isValidContainer
selectionHelper.isValidContainedOrContainer = isValidContainedOrContainer

return selectionHelper
