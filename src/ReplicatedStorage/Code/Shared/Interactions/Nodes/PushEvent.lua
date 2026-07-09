-- PushEvent.lua — Pushes data into an EventQueue channel.
-- Config: { Queue = "Kick", ForwardMeta = true }
-- If ForwardMeta, copies ctx._meta into payload.meta.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventQueues = require(ReplicatedStorage.Code.Shared.EventTypes)
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local SUCCESS = NodeRegistry.SUCCESS

NodeRegistry.register("PushEvent", function(config)
	return {
		Type = "PushEvent",
		execute = function(_self, ctx)
			local queue = EventQueues[config.Queue]
			if not queue then return SUCCESS end

			local payload = {
				entity = ctx.user,
			}

			if config.ForwardMeta and ctx._meta then
				payload.meta = table.clone(ctx._meta)
			end

			queue:push(payload)
			return SUCCESS
		end,
	}
end)

return nil
