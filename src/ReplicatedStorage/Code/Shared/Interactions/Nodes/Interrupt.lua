-- Interrupt.lua — Leaf node. Cancels ctx:getTargetEntity()'s in-progress interaction, by pushing
-- EventTypes.Interrupt (InterruptSystem owns the actual manager.active clear — interactions only
-- ever affect ECS through events here, no exceptions, even for same-subsystem changes like this one).
--
-- Deliberately a STANDALONE node, not fused into whatever node found the target (e.g. TackleSweep) —
-- mirrors Hytale's InterruptInteraction being its own composable type. A future ability can deal
-- damage without interrupting, or interrupt without dealing damage, by composing this node in or not,
-- independently of whatever else it's doing.
--
-- SERVER-ONLY (side="server" in the chain def): resolves a cross-entity consequence — what happens
-- to ANOTHER character — never predicted, same reasoning as TackleSweep.
--
-- Expects a preceding node in the SAME Serial (same tick, same ctx — ctx._meta does not survive a
-- tick boundary) to have called ctx:setMeta("TargetEntity", entity).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventTypes = require(ReplicatedStorage.Code.Shared.EventTypes)
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local SUCCESS = NodeRegistry.SUCCESS
local FAILURE = NodeRegistry.FAILURE

NodeRegistry.register("Interrupt", function(_config)
	return {
		Type = "Interrupt",
		execute = function(_self, ctx)
			local target = ctx:getTargetEntity()
			if not target then return FAILURE end

			EventTypes.Interrupt:push({ target = target })
			return SUCCESS
		end,
	}
end)

return nil
