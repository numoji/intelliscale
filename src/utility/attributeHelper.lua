--!strict
local Players = game:GetService("Players")
local attributeHelper = {}

function attributeHelper.setAttribute(instance: Instance, attribute: string, value: any, shouldPrint: boolean?)
	instance:SetAttribute(attribute, value)

	if Players.LocalPlayer then
		instance:SetAttribute("_intelliscale_lastChangeBy", game.Players.LocalPlayer.UserId)
	else
		instance:SetAttribute("_intelliscale_lastChangeBy", nil)
	end

	-- if shouldPrint then
	-- 	local tb = debug.traceback()
	-- 	print(`{instance.Name}.{attribute} -> {value}`, tb)
	-- end
end

function attributeHelper.wasLastChangedByMe(instance: Instance)
	local lastChangedBy = instance:GetAttribute("_intelliscale_lastChangeBy")

	return if Players.LocalPlayer then lastChangedBy == game.Players.LocalPlayer.UserId else true
end

return attributeHelper
