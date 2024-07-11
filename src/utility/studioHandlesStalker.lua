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

	local wasFreeDragging = false
	local function reconcileIsFreeDragging()
		local outline = draggerUi:FindFirstChild("Outline")
		local boundingBox = draggerUi:FindFirstChild("BoundingBox")
		local onTop = draggerUi:FindFirstChild("OnTop")
		local snapTo = draggerUi:FindFirstChild("SnapTo")
		local underneath = draggerUi:FindFirstChild("Underneath")

		local isFreeDragging = outline == nil and boundingBox == nil and onTop ~= nil and snapTo ~= nil and underneath ~= nil

		if isFreeDragging and not wasFreeDragging then
			print("free dragging")
			anyHandleMouseDownEvent:Fire()
		elseif not isFreeDragging and wasFreeDragging then
			print("stopped dragging ")
			anyHandleMouseUpEvent:Fire()
		end

		wasFreeDragging = isFreeDragging
	end

	draggerUiJanitor:Add(function()
		if wasFreeDragging then
			anyHandleMouseUpEvent:Fire()
		end
	end)

	draggerUiJanitor:Add(draggerUi.ChildAdded:Connect(function(child: Instance)
		if child.Name == "DraggerUI" then
			anyHandleMouseDownEvent:Fire()
			local containerJanitor = Janitor.new()
			containerJanitor:Add(function()
				anyHandleMouseUpEvent:Fire()
			end)
			bindRemovingToJanitor(child, containerJanitor, draggerUiJanitor)
		end

		reconcileIsFreeDragging()
	end))

	draggerUiJanitor:Add(draggerUi.ChildRemoved:Connect(reconcileIsFreeDragging))

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
