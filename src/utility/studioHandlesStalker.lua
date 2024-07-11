--!strict
local CoreGui = game:GetService("CoreGui")
local packages = script.Parent.Parent.Parent.Packages
local Janitor = require(packages.Janitor)

local studioHandlesStalker = {}
local janitor = Janitor.new()

local anyHandleMouseDownEvent = Instance.new("BindableEvent")
local anyHandleMouseUpEvent = Instance.new("BindableEvent")

studioHandlesStalker.handlesPressed = anyHandleMouseDownEvent.Event
studioHandlesStalker.handlesReleased = anyHandleMouseUpEvent.Event

local function bindRemovingToJanitor(instance: Instance, janitor: typeof(Janitor.new()), parentJanitor: typeof(Janitor.new()))
	janitor:Add(instance.AncestryChanged:Connect(function(_, parent)
		task.defer(function()
			if not instance:IsDescendantOf(CoreGui) and janitor.Cleanup then
				janitor:Cleanup()
			end
		end)
	end))
	janitor:Add(instance.Destroying:Connect(function()
		task.defer(function()
			if janitor.Cleanup then
				janitor:Cleanup()
			end
		end)
	end))

	janitor:Add(function()
		if parentJanitor.RemoveNoClean then
			parentJanitor:RemoveNoClean(janitor)
		end
	end)
	parentJanitor:Add(janitor, nil, janitor)
end

function setUpHandleListener(draggerUi: Folder)
	local draggerUiJanitor = Janitor.new()

	draggerUiJanitor:Add(draggerUi.ChildAdded:Connect(function(container: Instance)
		if container.Name == "DraggerUI" then
			anyHandleMouseDownEvent:Fire()
			local containerJanitor = Janitor.new()
			containerJanitor:Add(function()
				anyHandleMouseUpEvent:Fire()
			end)
			bindRemovingToJanitor(container, containerJanitor, draggerUiJanitor)
		end
	end))

	bindRemovingToJanitor(draggerUi, draggerUiJanitor, janitor)

	return draggerUiJanitor
end

function studioHandlesStalker.initialize()
	janitor:Add(CoreGui.ChildAdded:Connect(function(child)
		if child.Name == "DraggerUI" then
			janitor:Add(child)
			setUpHandleListener(child)
		end
	end))

	local draggerUi = CoreGui:FindFirstChild("DraggerUI")
	if draggerUi then
		setUpHandleListener(draggerUi)
	end

	return janitor
end

return studioHandlesStalker
