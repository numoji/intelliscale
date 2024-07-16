--!strict
local RunService = game:GetService("RunService")

local Janitor = require(script.Parent.Parent.Parent.Packages.Janitor)
local inspectPrint = require(script.Parent.inspectPrint)
local changeDeduplicator = {}

local janitor = Janitor.new()

type Scopes = {
	[string]: Scope,
}

type Scope = {
	[Instance]: InstanceScope,
}

type InstanceScope = {
	[string]: {
		value: any,
		age: number,
	},
}

local propertyScopes: Scopes = {}
local attributeScopes: Scopes = {}

local function createSetter(scopes: Scopes, setterFunc: (Instance, string, any) -> ())
	return function(scopeName: string, instance: Instance, propName: string, value: any, extraLevel: number?)
		-- inspectPrint(`{instance}.{propName} set in '{scopeName}'`, 3 + (extraLevel or 0))

		local scope: Scope = scopes[scopeName]
		if not scope then
			scope = {} :: Scope
			scopes[scopeName] = scope
		end

		local instanceScope: InstanceScope = scope[instance]
		if not instanceScope then
			instanceScope = {} :: InstanceScope
			scope[instance] = instanceScope
		end

		setterFunc(instance, propName, value)
		instanceScope[propName] = { value = value, age = 0 }
	end
end

local function createChangeDiffer(scopes: Scopes, getterFunc: (Instance, string) -> any)
	return function(scopeName: string, instance: Instance, propsToCheck: { string }?)
		local scope = scopes[scopeName]
		if not scope then
			return true
		end

		local instanceScope = scope[instance]
		if not instanceScope then
			return true
		end

		if not next(instanceScope) then
			return true
		end

		if propsToCheck then
			for _, propName in propsToCheck do
				local value = instanceScope[propName]
				if not value or value.value ~= getterFunc(instance, propName) then
					return true
				end
			end

			return false
		else
			for propName, value in instanceScope do
				if value.value ~= getterFunc(instance, propName) then
					return true
				end
			end

			return false
		end
	end
end

changeDeduplicator.setProp = createSetter(propertyScopes, function(instance: Instance, propName: string, value: any)
	-- if instance.Name == "zPart" then
	-- 	inspectPrint(`{instance}.{propName} set`, 3)
	-- end
	instance[propName] = value
end)

changeDeduplicator.isChanged = createChangeDiffer(propertyScopes, function(instance: Instance, propName: string)
	return instance[propName]
end)

changeDeduplicator.setAtt = createSetter(attributeScopes, function(instance: Instance, attName: string, value: any)
	instance:SetAttribute(attName, value)
end)

changeDeduplicator.isAttChanged = createChangeDiffer(attributeScopes, function(instance: Instance, attName: string)
	return instance:GetAttribute(attName)
end)

function changeDeduplicator.printScope(scopeName: string)
	print(`properties '{scopeName}': `, propertyScopes)
	print(`attributes '{scopeName}': `, attributeScopes)
end

local function stepScopes(scopes: Scopes)
	return function(scopeName: string)
		for _, scope in scopes do
			for instance, instanceScope in scope do
				local anyLeft = false
				for propName, value in instanceScope do
					value.age += 1
					if value.age >= 3 then
						instanceScope[propName] = nil
					else
						anyLeft = true
					end
				end
				if not anyLeft then
					scope[instance] = nil
				end
			end
		end
	end
end

function changeDeduplicator.initialize()
	janitor:Add(RunService.Heartbeat:Connect(function()
		stepScopes(propertyScopes)
		stepScopes(attributeScopes)
	end))

	return janitor
end

return changeDeduplicator
