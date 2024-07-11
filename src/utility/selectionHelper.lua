--!strict
local Selection = game:GetService("Selection")

local packages = script.Parent.Parent.Parent.Packages
local Janitor = require(packages.Janitor)

local utility = script.Parent
local realTransform = require(utility.realTransform)
local selectionHelper = {}

selectionHelper.jantior = Janitor.new()
local propertyAttributeJanitor = selectionHelper.jantior:Add(Janitor.new())

type Selection = { Instance }
type PartOrSelection = BasePart & Selection

type f = (...any) -> any
type InvalidCallback = () -> ()

type ValidCallback = (Selection, Selection) -> ()
type SingleValidCallback = (BasePart, BasePart) -> ()
type CombinedValidCallback = (PartOrSelection, PartOrSelection) -> ()

type ChangedCallback = (Instance, Selection, Selection) -> ()
type SingleChangedCallback = (Instance, BasePart, BasePart) -> ()

type BindingsDictionary = {
	invalid: { InvalidCallback },
	valid: { ValidCallback },
	changed: { ChangedCallback },
	attChanged: { ChangedCallback },
	single: {
		invalid: { InvalidCallback },
		valid: { SingleValidCallback },
		changed: { SingleChangedCallback },
		attChanged: { SingleChangedCallback },
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

local either: BindingsDictionary = {
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
selectionHelper.bindToEitherSelection = createInserter(either.valid, either.invalid)
selectionHelper.bindToSingleEitherSelection = createInserter(either.single.valid, either.single.invalid)

selectionHelper.bindToAnyContainedChanged = createSingleInserter(contained.changed)
selectionHelper.bindToSingleContainedChanged = createSingleInserter(contained.single.changed)
selectionHelper.bindToAnyContainerChanged = createSingleInserter(container.changed)
selectionHelper.bindToSingleContainerChanged = createSingleInserter(container.single.changed)
selectionHelper.bindToAnyEitherChanged = createSingleInserter(either.changed)
selectionHelper.bindToSingleEitherChanged = createSingleInserter(either.single.changed)

selectionHelper.bindToAnyContainedAttributeChanged = createSingleInserter(contained.attChanged)
selectionHelper.bindToSingleContainedAttributeChanged = createSingleInserter(contained.single.attChanged)
selectionHelper.bindToAnyContainerAttributeChanged = createSingleInserter(container.attChanged)
selectionHelper.bindToSingleContainerAttributeChanged = createSingleInserter(container.single.attChanged)
selectionHelper.bindToAnyEitherAttributeChanged = createSingleInserter(either.attChanged)
selectionHelper.bindToSingleEitherAttributeChanged = createSingleInserter(either.single.attChanged)

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

local isValidContainedOrContainer = createValidator(function(instance: Instance): boolean
	return (
		instance:IsA("BasePart")
		and instance.Parent
		and instance.Parent:IsA("BasePart")
		and instance.Parent:GetAttribute("isContainer")
	) or (instance:IsA("BasePart") and instance:GetAttribute("isContainer"))
end)

--stylua: ignore
type CallInArrayOverload = 
	({InvalidCallback}, nil?, nil?) -> () 
	& ({ValidCallback}, Selection, Selection) -> () 
	& ({SingleValidCallback}, BasePart, BasePart) -> ()
	& ({ChangedCallback}, Instance, Selection, Selection) -> ()
	& ({SingleChangedCallback}, Instance, BasePart, BasePart) -> ()
local callInArray: CallInArrayOverload = function(callbackArray, selection, fauxSelection)
	for _, callbackFunc in callbackArray do
		callbackFunc(selection, fauxSelection)
	end
end

local propsToTriggerChanges = {
	Size = true,
	CFrame = true,
	Parent = true,
}

local function bindToInstanceChanged<CallbackArgumentType>(
	changeFunction: (Instance, CallbackArgumentType, CallbackArgumentType) -> (),
	attChangeFunction: (Instance, CallbackArgumentType, CallbackArgumentType) -> (),
	validator: (CallbackArgumentType) -> boolean,
	listenedInstance: Instance,
	selection: CallbackArgumentType,
	fauxSelection: CallbackArgumentType
)
	propertyAttributeJanitor:Add(listenedInstance.Changed:Connect(function(propName)
		if validator(selection) and propsToTriggerChanges[propName] then
			changeFunction(listenedInstance, selection, fauxSelection)
		end
	end))

	propertyAttributeJanitor:Add(listenedInstance.AttributeChanged:Connect(function(attName)
		if validator(selection) then
			changeFunction(listenedInstance, selection, fauxSelection)

			if attChangeFunction then
				attChangeFunction(listenedInstance, selection, fauxSelection)
			end
		end
	end))
end

type SelectionChangeFunction = (Instance, Selection, Selection) -> ()
type SingleChangeFunction = (Instance, BasePart, BasePart) -> ()
local function bindToSelectedPartsChanged<CallbackArgumentType>(
	selection: Selection,
	fauxSelection: Selection,
	validator: (Selection) -> boolean,
	dictionary: BindingsDictionary
)
	local changeFunction = function(changedInstance, selected, fauxSelected)
		callInArray(dictionary.changed, changedInstance, selected, fauxSelected)
	end :: SelectionChangeFunction

	local attChangeFunction = function(changedInstance, selected, fauxSelected)
		callInArray(dictionary.attChanged, changedInstance, selected, fauxSelected)
	end :: SelectionChangeFunction

	local wasBoundSet = {}
	for _, instance in selection do
		wasBoundSet[instance] = true
		bindToInstanceChanged(changeFunction, attChangeFunction, validator, instance, selection, fauxSelection)
	end

	for _, fauxInstance in fauxSelection do
		if not wasBoundSet[fauxInstance] then
			bindToInstanceChanged(changeFunction, attChangeFunction, validator, fauxInstance, selection, fauxSelection)
		end
	end
end

local function createCaller(dictionary: BindingsDictionary, validator: ValidatorOverload)
	local runAnyChange = function(changedInstance, selected, fauxSelected)
		callInArray(dictionary.changed, changedInstance, selected, fauxSelected)
	end :: SelectionChangeFunction

	local runAnyAttChange = function(changedInstance, selected, fauxSelected)
		callInArray(dictionary.attChanged, changedInstance, selected, fauxSelected)
	end :: SelectionChangeFunction

	local runSingleChange = function(changedInstance, selected, fauxSelected)
		callInArray(dictionary.single.changed, changedInstance, selected, fauxSelected)
	end :: SingleChangeFunction

	local runSingleAttChange = function(changedInstance, selected, fauxSelected)
		callInArray(dictionary.single.attChanged, changedInstance, selected, fauxSelected)
	end :: SingleChangeFunction

	return function(instance: Instance, fauxInstance: Instance)
		if validator(instance) then
			local part = instance :: BasePart
			local fauxPart = fauxInstance :: BasePart
			local selection: Selection = { part }
			local fauxSelection: Selection
			if fauxPart then
				fauxSelection = { fauxPart :: Instance }
			end

			callInArray(dictionary.valid, selection, fauxSelection)
			callInArray(dictionary.single.valid, part, fauxPart)

			bindToInstanceChanged(runAnyChange, runAnyAttChange, validator, part, selection, fauxSelection)
			bindToInstanceChanged(runSingleChange, runSingleAttChange, validator, part, part, fauxPart)
			bindToInstanceChanged(runAnyChange, runAnyAttChange, validator, fauxPart, selection, fauxSelection)
			bindToInstanceChanged(runSingleChange, runSingleAttChange, validator, fauxPart, part, fauxPart)
		else
			callInArray(dictionary.invalid)
			callInArray(dictionary.single.invalid)
		end
	end
end

local callContained = createCaller(contained, isValidContained)
local callContainer = createCaller(container, isValidContainer)
local callEither = createCaller(either, isValidContainedOrContainer)

local function callAllInvalid()
	callInArray(contained.invalid)
	callInArray(contained.single.invalid)
	callInArray(container.invalid)
	callInArray(container.single.invalid)
	callInArray(either.invalid)
	callInArray(either.single.invalid)
end

local partByFauxPart: { [BasePart]: BasePart } = {}
local fauxPartByPart: { [BasePart]: BasePart } = {}

function selectionHelper.getRealInstance(instance: Instance | BasePart): Instance | BasePart
	return partByFauxPart[instance :: BasePart] or instance
end

local useFauxSelection = false
local function shouldFaux(part): boolean
	return useFauxSelection
		and (
			realTransform.hasTransform(part)
			or part:FindFirstChildWhichIsA("BasePart") ~= nil
			or part:FindFirstChildWhichIsA("Folder") ~= nil
		)
end

local function clearFauxPart(part: BasePart)
	local fauxPart = fauxPartByPart[part]
	if fauxPart then
		fauxPart:Destroy()
		partByFauxPart[fauxPart] = nil
		fauxPartByPart[part] = nil
	end
end

local isChangingSelection = false
local mostRecentThread
local function getSelectionAndFauxSelection(): (Selection, Selection)
	local selection: Selection = {}
	local fauxSelection: Selection = {}
	local currentSelectedFauxPartsSet: { [BasePart]: BasePart } = {}

	local trimmedSelection = {}
	local inSelectionSet = {}
	-- trim duplicated from faux parts out of the selection
	for _, instance in Selection:Get() do
		local realInstance = selectionHelper.getRealInstance(instance)
		if inSelectionSet[realInstance] then
			continue
		end

		inSelectionSet[realInstance] = true

		local fauxPart = fauxPartByPart[realInstance :: BasePart]
		if fauxPart and shouldFaux(realInstance :: BasePart) then
			table.insert(trimmedSelection, fauxPart)
			continue
		elseif fauxPart and not shouldFaux(realInstance :: BasePart) then
			clearFauxPart(realInstance :: BasePart)
		end

		table.insert(trimmedSelection, realInstance :: BasePart)
	end

	for _, instance in trimmedSelection do
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
			if shouldFaux(realPart) then
				table.insert(fauxSelection, part)
				currentSelectedFauxPartsSet[part] = realPart
			else
				table.insert(fauxSelection, realPart)
			end
		elseif shouldFaux(part) then
			local fauxPart = Instance.new("Part")
			fauxPart.Archivable = false
			fauxPart.Anchored = true
			fauxPart.CanCollide = false
			fauxPart.Transparency = 1
			fauxPart.CollisionGroup = "IntelliscaleUnselectable"
			fauxPart.Parent = workspace.CurrentCamera

			fauxPart.Size, fauxPart.CFrame = realTransform.getSizeAndGlobalCFrame(part)

			partByFauxPart[fauxPart] = part
			fauxPartByPart[part] = fauxPart
			currentSelectedFauxPartsSet[fauxPart] = part
			table.insert(fauxSelection, fauxPart)
		else
			table.insert(fauxSelection, part)
		end
	end

	for fauxPart, part in partByFauxPart do
		if not currentSelectedFauxPartsSet[fauxPart] then
			clearFauxPart(part)
		end
	end

	isChangingSelection = true
	Selection:Set(fauxSelection)
	local thisThread
	thisThread = task.defer(function()
		if thisThread == mostRecentThread then
			isChangingSelection = false
		end
	end)
	mostRecentThread = thisThread

	return selection, fauxSelection
end

local function bindToAncestryOrAttributesChanged(selection: Selection, callback: () -> ())
	for _, part in selection do
		propertyAttributeJanitor:Add(part.AncestryChanged:Connect(function()
			callback()
		end))

		propertyAttributeJanitor:Add(part.AttributeChanged:Connect(function()
			callback()
		end))
	end
end

local cachedSelection: Selection, cachedFauxSelection: Selection
function selectionHelper.updateSelection()
	if isChangingSelection then
		return
	end

	propertyAttributeJanitor:Cleanup()

	local selection, fauxSelection = getSelectionAndFauxSelection()
	cachedSelection = selection
	cachedFauxSelection = fauxSelection

	if #selection == 0 then
		callAllInvalid()
	elseif #selection == 1 then
		local part = selection[1]
		local fauxPart = fauxSelection[1]
		callContained(part, fauxPart)
		callContainer(part, fauxPart)
		callEither(part, fauxPart)
	elseif #selection > 1 then
		callInArray(contained.single.invalid)
		callInArray(container.single.invalid)
		callInArray(either.single.invalid)

		local isValidContainedSelection = true
		local isValidContainerSelection = true
		local isValidEitherSelection = true

		for _, instance in selection do
			if not isValidContained(instance) then
				isValidContainedSelection = false
			end

			if not isValidContainer(instance) then
				isValidContainerSelection = false
			end

			if not isValidContainedOrContainer(instance) then
				isValidEitherSelection = false
			end

			if not isValidContainedSelection and not isValidContainerSelection then
				break
			end
		end

		if isValidContainedSelection then
			callInArray(contained.valid, selection, fauxSelection)
			bindToSelectedPartsChanged(selection, fauxSelection, isValidContained, contained)
		else
			callInArray(contained.invalid)
		end

		if isValidContainerSelection then
			callInArray(container.valid, selection, fauxSelection)
			bindToSelectedPartsChanged(selection, fauxSelection, isValidContainer, container)
		else
			callInArray(container.invalid)
		end

		if isValidEitherSelection then
			callInArray(container.valid, selection, fauxSelection)
			bindToSelectedPartsChanged(selection, fauxSelection, isValidContainedOrContainer, either)
		else
			callInArray(container.invalid)
		end
	end

	if #selection > 0 then
		local wasChangedThisFrame = false
		local didCallUpdate = false
		bindToAncestryOrAttributesChanged(selection, function()
			if isChangingSelection or wasChangedThisFrame or didCallUpdate then
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

					if fauxPartByPart[realPart] :: BasePart? ~= nil and not shouldFaux(realPart) then
						clearFauxPart(realPart)

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
					selectionHelper.updateSelection()
				end

				wasChangedThisFrame = false
			end)
		end)
	end
end

selectionHelper.toggleUseFauxSelection = function()
	useFauxSelection = not useFauxSelection
	selectionHelper.updateSelection()
end

local function createSelectionGetter(validator)
	return function()
		local selection, fauxSelection = cachedSelection, cachedFauxSelection

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

selectionHelper.getUnvalidatedSelection = function(): ({ Instance }, { Instance })
	return cachedSelection, cachedFauxSelection
end

selectionHelper.jantior:Add(function()
	for fauxPart, _ in partByFauxPart do
		fauxPart:Destroy()
	end
end)

selectionHelper.jantior:Add(Selection.SelectionChanged:Connect(selectionHelper.updateSelection))

selectionHelper.getContainedSelection = createSelectionGetter(isValidContained)
selectionHelper.getContainerSelection = createSelectionGetter(isValidContainer)
selectionHelper.getContainedAndContainerSelection = createSelectionGetter(isValidContainedOrContainer)

selectionHelper.isValidContained = isValidContained
selectionHelper.isValidContainer = isValidContainer
selectionHelper.isValidContainedOrContainer = isValidContainedOrContainer

return selectionHelper
