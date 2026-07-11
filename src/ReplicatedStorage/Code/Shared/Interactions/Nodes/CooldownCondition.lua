-- CooldownCondition.lua — Gate: succeeds only if the interaction is off cooldown.
-- Reads the server-authoritative pair(COOLDOWN, CD_*) presence straight from ECS (the pair is
-- replicated to the owner). Present = on cooldown = FAILURE. Always succeeds for NPCs.
-- Config: { CooldownId = "CD_DASH" } — string key into components for the cooldown target entity.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local world = require(ReplicatedStorage.Code.Shared.World)
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local pair = jecs.pair
local FAILURE = NodeRegistry.FAILURE
local SUCCESS = NodeRegistry.SUCCESS

NodeRegistry.register("CooldownCondition", function(config)
	return {
		Type = "CooldownCondition",
		execute = function(_self, ctx)
			if ctx.chain.isNPC then return SUCCESS end

			local cdEntity = components[config.CooldownId]
			if cdEntity and world:has(ctx.user, pair(components.COOLDOWN, cdEntity)) then
				return FAILURE
			end
			return SUCCESS
		end,
	}
end)

return nil
