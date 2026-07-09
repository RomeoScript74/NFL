-- TriggerCooldown.lua — Starts a cooldown timer on the interaction.
-- Config: { CooldownId = "CD_PASS" } — the pair target for COOLDOWN.
-- Reads COOLDOWN_CONFIG from the interaction definition entity.
-- Supports charge-based cooldowns (Charges > 0) and simple timers.
-- Sets both manager.cooldowns table AND pair(COOLDOWN, cdEntity) for CooldownSystem.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local world = require(ReplicatedStorage.Code.Shared.World)
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local pair = jecs.pair
local SUCCESS = NodeRegistry.SUCCESS

NodeRegistry.register("TriggerCooldown", function(config)
	return {
		Type = "TriggerCooldown",
		execute = function(_self, ctx)
			local cdConfig = world:get(ctx.interactionDef, components.COOLDOWN_CONFIG)
			local cdId = config.CooldownId or ctx.interactionDef
			local cdEntity = components[cdId]

			if cdConfig then
				local existing = ctx.manager.cooldowns[cdId]

				if cdConfig.Charges and cdConfig.Charges > 0 then
					if existing then
						existing.charges = math.max(0, (existing.charges or 0) - 1)
						if existing.charges <= 0 then
							existing.remaining = cdConfig.ChargeDuration or cdConfig.Duration
						end
					else
						ctx.manager.cooldowns[cdId] = {
							remaining = cdConfig.ChargeDuration or cdConfig.Duration,
							charges = cdConfig.Charges - 1,
							maxCharges = cdConfig.Charges,
							chargeDuration = cdConfig.ChargeDuration or cdConfig.Duration,
							baseDuration = cdConfig.Duration,
							interruptRecharge = cdConfig.InterruptRecharge or false,
						}
					end
				elseif cdConfig.Duration and cdConfig.Duration > 0 then
					ctx.manager.cooldowns[cdId] = { remaining = cdConfig.Duration }
				end
			end

			-- Set ECS pair so CooldownSystem ticks it every frame
			if cdEntity and cdConfig and cdConfig.Duration then
				world:set(ctx.user, pair(components.COOLDOWN, cdEntity), cdConfig.Duration)
			end

			return SUCCESS
		end,
	}
end)

return nil
