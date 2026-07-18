-- Wait.lua — Framework-timed delay. Succeeds immediately; the FRAMEWORK holds it for its RunTime
-- (seconds) before the chain advances — the node never counts ticks itself (that's the point, and how
-- Hytale does it: duration is data on the interaction, the framework times it). Put it between steps to
-- pause: `Serial { PushEvent{open}, Wait{RunTime=0.3}, PushEvent{fire} }`. Any data a later step needs
-- (a target, a charge) survives the wait because ctx meta lives on the chain (see InteractionSystem
-- buildContext), so pair it with SelectCarried/SelectNearby + PushEvent — no bespoke timing node.
--
-- RunTime is honored by every container the chain runs through: tickChain (top level) and Serial. (A Wait
-- inside a Parallel would need the same wiring there — not added until something needs it.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local SUCCESS = NodeRegistry.SUCCESS

NodeRegistry.register("Wait", function(_config)
	return {
		Type = "Wait",
		execute = function(_self, _ctx)
			return SUCCESS
		end,
	}
end)

return nil
