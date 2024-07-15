--!strict
local Selection = game:GetService("Selection")

local Janitor = require(script.Parent.Parent.Parent.Packages.Janitor)
local containerHelper = require(script.Parent.containerHelper)
local realTransform = require(script.Parent.Parent.utility.realTransform)

local selectionHelper = {}

local janitor = Janitor.new()
local propertyAttributeJanitor = janitor:Add(Janitor.new())

type ChangedEventName = "Changed" | "AttributeChanged"
type Selection = { Instance }
type InvalidCallback = () -> ()
type ValidCallback = (BasePart, BasePart) -> () | (Selection, Selection) -> ()
type ChangedCallback = (Instance, BasePart, BasePart) -> () | (Instance, Selection, Selection) -> ()
type InternalChangedCallback = (string, Instance, BasePart, BasePart) -> () & (string, Instance, Selection, Selection) -> ()

type CallbackDictionary = {
	invalid: { InvalidCallback },
	valid: { ValidCallback },
	changed: { InternalChangedCallback },
	attChanged: { InternalChangedCallback },
}
type AnyCallbackDictionary = { valid: { ValidCallback }, changed: { InternalChangedCallback }, attChanged: { InternalChangedCallback } }

local function createCallbackDictionary(): CallbackDictionary
	return { invalid = {}, valid = {}, changed = {}, attChanged = {} }
end

local contained = createCallbackDictionary()
local singleContained = createCallbackDictionary()
local container = createCallbackDictionary()
local singleContainer = createCallbackDictionary()
local containerOrContained = createCallbackDictionary()
local singleContainerOrContained = createCallbackDictionary()
local any: AnyCallbackDictionary = { valid = {}, changed = {}, attChanged = {} }
local singleAny: AnyCallbackDictionary = { valid = {}, changed = {}, attChanged = {} }

selectionHelper.callbackDicts = {
	contained = contained,
	container = container,
	containerOrContained = containerOrContained,
	singleContained = singleContained,
	singleContainer = singleContainer,
	singleContainerOrContained = singleContainerOrContained,
	any = any,
	singleAny = singleAny,
}

local function createRemover(value: any, array: { any }): () -> ()
	return function()
		for i, v in array do
			if v == value then
				table.remove(array, i)
			end
		end
	end
end

--stylua: ignore
type AddSelectionChangeCallback = 
(CallbackDictionary, ValidCallback, InvalidCallback) -> () -> ()
& (AnyCallbackDictionary, ValidCallback, nil?) -> () -> ()
selectionHelper.addSelectionChangeCallback = function(
	callbackDict: CallbackDictionary & AnyCallbackDictionary,
	validCallback: ValidCallback,
	invalidCallback: InvalidCallback?
): () -> ()
	if callbackDict.valid then
		table.insert(callbackDict.valid, validCallback)
		local validRemover = createRemover(validCallback, callbackDict.valid)

		if invalidCallback ~= nil and callbackDict.invalid then
			table.insert(callbackDict.invalid, invalidCallback)
			local invalidRemover = createRemover(invalidCallback, callbackDict.invalid)
			return function()
				validRemover()
				invalidRemover()
			end
		elseif invalidCallback then
			error("Provided callback dictionary does not have a field for invalid callback functions.")
		end

		return validRemover
	end

	error("Provided callback dictionary does not have a field for valid callback functions.")
end :: AddSelectionChangeCallback

selectionHelper.addPropertyChangeCallback = function(
	callbackDict: { changed: { InternalChangedCallback } },
	properties: { string },
	changedCallback: ChangedCallback
): () -> ()
	local propertiesSet = {}
	for _, prop in properties do
		propertiesSet[prop] = true
	end

	local n = debug.info(1, "n")
	local s, l = debug.info(2, "sl")

	local internalChangedCallback: InternalChangedCallback = function(propName, changed, selection, fauxSelection)
		if propertiesSet[propName] then
			local fromString = `firing from {changed}.{propName} through {n} [{s:match("%a+$")}: {l}]`;
			(changedCallback :: (...any) -> ())(changed, selection, fauxSelection, fromString)
		end
	end :: InternalChangedCallback

	table.insert(callbackDict.changed, internalChangedCallback)

	return createRemover(internalChangedCallback, callbackDict.changed)
end

selectionHelper.addAttributeChangeCallback = function(
	callbackDict: { attChanged: { InternalChangedCallback } },
	attributes: { string },
	changedCallback: ChangedCallback
): () -> ()
	local attributesSet = {}
	for _, attribute in attributes do
		attributesSet[attribute] = true
	end

	-- local n = debug.info(1, "n")
	-- local s, l = debug.info(2, "sl")

	local internalChangedCallback: InternalChangedCallback = function(attribute, changed, selection, fauxSelection)
		if attributesSet[attribute] then
			-- print(`firing from {changed}.{attribute} through {n} [{s:match("%a+$")}: {l}]`);
			(changedCallback :: (...any) -> ())(changed, selection, fauxSelection)
		end
	end :: InternalChangedCallback

	table.insert(callbackDict.attChanged, internalChangedCallback)
	return createRemover(internalChangedCallback, callbackDict.attChanged)
end

type Validator = ((Instance) -> boolean) & ((Selection) -> boolean)
local function createSelectionValidator(validateFunction: (Instance) -> boolean)
	local validator: Validator = function(instanceOrSelection)
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

local isValidContained = createSelectionValidator(containerHelper.isValidContained)
local isValidContainer = createSelectionValidator(containerHelper.isValidContainer)
local isValidContainedOrContainer = createSelectionValidator(containerHelper.isValidContainedOrContainer)
local alwaysValid: Validator = function(...)
	return true
end

--stylua: ignore
type CallInArray = ({ InvalidCallback }) -> ()
& ({ ValidCallback }, BasePart, BasePart) -> ()
& ({ ValidCallback }, Selection, Selection) -> ()
& ({ InternalChangedCallback }, string, Instance, BasePart, BasePart) -> () 
& ({ InternalChangedCallback }, string, Instance, Selection, Selection) -> ()
local callInArray: CallInArray = function(callbackArray, ...)
	for _, callbackFunc in callbackArray do
		callbackFunc(...)
	end
end

--stylua: ignore
type BindCallbacksToInstanceChanged = 
(Instance, ChangedEventName, Validator, { InternalChangedCallback }, BasePart, BasePart) -> () 
& (Instance, ChangedEventName, Validator, { InternalChangedCallback }, Selection, Selection) -> ()
local bindCallbacksToInstanceChanged = function(
	listenedInstance,
	changedEventName,
	validator,
	changedCallbacks,
	selectionToPass,
	fauxSelectionToPass
)
	local changedEvent = (listenedInstance :: Instance)[changedEventName] :: RBXScriptSignal

	propertyAttributeJanitor:Add(changedEvent:Connect(function(propName)
		callInArray(changedCallbacks, propName, listenedInstance, selectionToPass, fauxSelectionToPass)
	end))
end :: BindCallbacksToInstanceChanged

local bindCallbacksToInstancesChanged = function(
	selection: Selection,
	fauxSelection: Selection,
	validator: Validator,
	changedCallbacks: { InternalChangedCallback },
	changedEventName: ChangedEventName
)
	local boundInstanceSet = {}
	for _, instance in selection do
		boundInstanceSet[instance] = true
		bindCallbacksToInstanceChanged(instance, changedEventName, validator, changedCallbacks, selection, fauxSelection)
	end

	for _, fauxInstance in fauxSelection do
		if boundInstanceSet[fauxInstance] then
			continue
		end

		bindCallbacksToInstanceChanged(fauxInstance, changedEventName, validator, changedCallbacks, selection, fauxSelection)
	end
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
			-- fauxPart.CollisionGroup = "IntelliscaleUnselectable"
			fauxPart.Parent = workspace.CurrentCamera
			fauxPart.Name = "FauxPart"

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

selectionHelper.fauxPartByPart = fauxPartByPart

--stylua: ignore
type CreateCaller = 
(CallbackDictionary, CallbackDictionary, Validator) -> (Instance?, Instance?) -> () 
& (AnyCallbackDictionary, AnyCallbackDictionary, nil?) -> (Instance?, Instance?) -> ()
local createCaller = function(
	callbackDict: CallbackDictionary & AnyCallbackDictionary,
	singleCallbackDict: CallbackDictionary & AnyCallbackDictionary,
	validator: Validator?
): (Instance?, Instance?) -> ()
	local isValid = validator or alwaysValid
	return function(instance: Instance?, fauxInstance: Instance?)
		if (not validator or not instance) or validator(instance) then
			local part = instance :: BasePart?
			local fauxPart = fauxInstance :: BasePart?
			local selection = (instance and { instance }) or ({} :: Selection)
			local fauxSelection = (fauxInstance and { fauxInstance }) or ({} :: Selection)

			callInArray(callbackDict.valid, selection, fauxSelection)
			callInArray(singleCallbackDict.valid, part :: BasePart, fauxPart :: BasePart)

			if part and fauxPart then
				bindCallbacksToInstanceChanged(part, "Changed", isValid, callbackDict.changed, selection, fauxSelection)
				bindCallbacksToInstanceChanged(fauxPart, "Changed", isValid, callbackDict.changed, selection, fauxSelection)
				bindCallbacksToInstanceChanged(part, "Changed", isValid, singleCallbackDict.changed, part, fauxPart)
				bindCallbacksToInstanceChanged(fauxPart, "Changed", isValid, singleCallbackDict.changed, part, fauxPart)

				bindCallbacksToInstanceChanged(part, "AttributeChanged", isValid, callbackDict.attChanged, selection, fauxSelection)
				bindCallbacksToInstanceChanged(part, "AttributeChanged", isValid, singleCallbackDict.attChanged, part, fauxPart)
			end
		elseif validator and callbackDict.invalid then
			callInArray(callbackDict.invalid)
			callInArray(callbackDict.invalid)
		end
	end
end :: CreateCaller

local callContained = createCaller(contained, singleContained, isValidContained)
local callContainer = createCaller(container, singleContainer, isValidContainer)
local callContainerOrContained = createCaller(containerOrContained, singleContainerOrContained, isValidContainedOrContainer)
local callAny = createCaller(any, singleAny)

local function callSingleInvalid()
	callInArray(singleContained.invalid)
	callInArray(singleContainer.invalid)
	callInArray(singleContainerOrContained.invalid)
end

local function callAllInvalid()
	callSingleInvalid()
	callInArray(contained.invalid)
	callInArray(container.invalid)
	callInArray(containerOrContained.invalid)
end

local cachedSelection: Selection, cachedFauxSelection: Selection
local function shouldUpdateSelectionToRefreshFauxParts(): boolean
	local checkedSet = {}
	for _, instance in cachedSelection do
		checkedSet[instance] = true
		if instance:IsA("BasePart") and shouldFaux(instance) and not fauxPartByPart[instance] then
			return true
		end
	end
	for _, instance in cachedFauxSelection do
		if checkedSet[instance] then
			continue
		end

		local partByFaux = partByFauxPart[instance :: BasePart]

		if instance:IsA("BasePart") and partByFaux and not shouldFaux(partByFaux) then
			return true
		end
	end

	return false
end

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

		callAny(nil, nil)
	elseif #selection == 1 then
		local part = selection[1]
		local fauxPart = fauxSelection[1]
		callContained(part, fauxPart)
		callContainer(part, fauxPart)
		callContainerOrContained(part, fauxPart)
		callAny(part, fauxPart)
	elseif #selection > 1 then
		callSingleInvalid()
		callInArray(any.valid, selection, fauxSelection)

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
			bindCallbacksToInstancesChanged(selection, fauxSelection, isValidContained, contained.changed, "Changed")
			bindCallbacksToInstancesChanged(selection, fauxSelection, isValidContained, contained.attChanged, "AttributeChanged")
		else
			callInArray(contained.invalid)
		end

		if isValidContainerSelection then
			callInArray(container.valid, selection, fauxSelection)
			bindCallbacksToInstancesChanged(selection, fauxSelection, isValidContainer, container.changed, "Changed")
			bindCallbacksToInstancesChanged(selection, fauxSelection, isValidContainer, container.attChanged, "AttributeChanged")
		else
			callInArray(container.invalid)
		end

		if isValidEitherSelection then
			callInArray(containerOrContained.valid, selection, fauxSelection)
			bindCallbacksToInstancesChanged(selection, fauxSelection, isValidContainedOrContainer, containerOrContained.changed, "Changed")
			bindCallbacksToInstancesChanged(
				selection,
				fauxSelection,
				isValidContainedOrContainer,
				containerOrContained.attChanged,
				"AttributeChanged"
			)
		else
			callInArray(containerOrContained.invalid)
		end
	end

	if #selection > 0 then
		-- bindFauxPartTransformsToRealParts()
		local didCallUpdate = false
		bindToAncestryOrAttributesChanged(selection, function()
			if didCallUpdate then
				return
			end

			if shouldUpdateSelectionToRefreshFauxParts() then
				selectionHelper.updateSelection()
			end
		end)
	end
end

selectionHelper.toggleUseFauxSelection = function()
	useFauxSelection = not useFauxSelection
	if shouldUpdateSelectionToRefreshFauxParts() then
		selectionHelper.updateSelection()
	end
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

function selectionHelper.initialize()
	janitor:Add(Selection.SelectionChanged:Connect(selectionHelper.updateSelection))

	janitor:Add(function()
		for fauxPart, _ in partByFauxPart do
			fauxPart:Destroy()
		end
	end)

	return janitor
end

selectionHelper.getContainedSelection = createSelectionGetter(isValidContained)
selectionHelper.getContainerSelection = createSelectionGetter(isValidContainer)
selectionHelper.getContainedAndContainerSelection = createSelectionGetter(isValidContainedOrContainer)

return selectionHelper
