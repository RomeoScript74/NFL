-- TriggerCooldown.lua — Starts the interaction's cooldown. Per the layer rule, it does NOT
-- mutate ECS directly: it reads the def's COOLDOWN_CONFIG and pushes a StartCooldown event.
-- CooldownStartSystem applies pair(COOLDOWN, CD_*) server-side; CooldownSystem ticks it down.
-- Config: { CooldownId = "CD_DASH" } — string key into components for the cooldown target entity.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local world = require(ReplicatedStorage.Code.Shared.World)
local EventTypes = require(ReplicatedStorage.Code.Shared.EventTypes)
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local SUCCESS = NodeRegistry.SUCCESS

NodeRegistry.register("TriggerCooldown", function(config)
	return {
		Type = "TriggerCooldown",
		execute = function(_self, ctx)
			local cdConfig = world:get(ctx.interactionDef, components.COOLDOWN_CONFIG)
			local cdEntity = components[config.CooldownId]
			if cdEntity and cdConfig and cdConfig.Duration then
				EventTypes.StartCooldown:push({
					user = ctx.user,
					cooldown = cdEntity,
					duration = cdConfig.Duration,
				})
			end
			return SUCCESS
		end,
	}
end)

return nil
