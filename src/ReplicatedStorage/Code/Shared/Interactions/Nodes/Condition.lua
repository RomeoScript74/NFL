-- Condition.lua — Gate node. Checks tag or component presence at execute time.
-- Config: { Tag = "IS_GROUNDED" } or { HasComponent = "HEALTH" }
-- Optional: Invert = true to negate.
-- Returns SUCCESS if condition met, FAILURE otherwise.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local FAILURE = NodeRegistry.FAILURE
local SUCCESS = NodeRegistry.SUCCESS

NodeRegistry.register("Condition", function(config)
	return {
		Type = "Condition",
		execute = function(_self, ctx)
			local result = false
			if config.Tag then
				result = world:has(ctx.user, tags[config.Tag])
			elseif config.HasComponent then
				result = world:get(ctx.user, components[config.HasComponent]) ~= nil
			else
				result = true
			end
			if config.Invert then
				result = not result
			end
			return if result then SUCCESS else FAILURE
		end,
	}
end)

return nil
