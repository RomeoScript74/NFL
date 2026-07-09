-- PushEvent.lua — Leaf node. Pushes a typed event into an EventQueue, bridging the
-- interaction layer to the ECS impulse systems. This is the ONLY way interactions
-- affect ECS state: they never call world:set/add/remove directly.
--
-- Config: { Queue = "Kick" } — key into the EventTypes queue table.
-- The entry carries the acting entity plus any Charge/HoldTime meta set upstream
-- (e.g. by HoldToCharge); those fields are nil for events that don't charge.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventTypes = require(ReplicatedStorage.Code.Shared.EventTypes)
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local SUCCESS = NodeRegistry.SUCCESS
local FAILURE = NodeRegistry.FAILURE

NodeRegistry.register("PushEvent", function(config)
	local queueName = config.Queue

	return {
		Type = "PushEvent",
		execute = function(_self, ctx)
			local queue = EventTypes[queueName]
			if not queue then
				warn("[PushEvent] Unknown queue: " .. tostring(queueName))
				return FAILURE
			end

			queue:push({
				user = ctx.user,
				target = ctx:getTargetEntity(),
				charge = ctx:getMeta("Charge"),
				holdTime = ctx:getMeta("HoldTime"),
			})

			return SUCCESS
		end,
	}
end)

return nil
