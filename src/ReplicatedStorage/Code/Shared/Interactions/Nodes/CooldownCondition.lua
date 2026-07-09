-- CooldownCondition.lua — Gate: succeeds only if cooldown is available.
-- Hytale spec: always succeeds for NPCs.
-- Config: { CooldownId = CD_PASS } — defaults to ctx.interactionDef if omitted.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local FAILURE = NodeRegistry.FAILURE
local SUCCESS = NodeRegistry.SUCCESS

NodeRegistry.register("CooldownCondition", function(config)
	return {
		Type = "CooldownCondition",
		execute = function(_self, ctx)
			if ctx.chain.isNPC then return SUCCESS end

			local cdId = config.CooldownId or ctx.interactionDef
			local cd = ctx.manager.cooldowns[cdId]
			if not cd then return SUCCESS end
			if cd.charges and cd.charges > 0 then return SUCCESS end
			return FAILURE
		end,
	}
end)

return nil
