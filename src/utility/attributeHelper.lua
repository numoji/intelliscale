--!strict
local Players = game:GetService("Players")

local changeDeduplicator = require(script.Parent.changeDeduplicator)
local attributeHelper = {}

function attributeHelper.setAttribute(instance: Instance, attribute: string, value: any, extraLevel: number?, useDeduplicator: boolean?)
	if useDeduplicator then
		local callingName = debug.info(2 + (extraLevel or 0), "s"):match("%a+$")
		changeDeduplicator.setAtt(callingName, instance, attribute, value, extraLevel)
	else
		instance:SetAttribute(attribute, value)
	end

	if Players.LocalPlayer then
		instance:SetAttribute("_intelliscale_lastChangeBy", game.Players.LocalPlayer.UserId)
	else
		instance:SetAttribute("_intelliscale_lastChangeBy", nil)
	end
end

function attributeHelper.wasLastChangedByMe(instance: Instance)
	local lastChangedBy = instance:GetAttribute("_intelliscale_lastChangeBy")

	return if Players.LocalPlayer then lastChangedBy == game.Players.LocalPlayer.UserId else true
end

return attributeHelper
