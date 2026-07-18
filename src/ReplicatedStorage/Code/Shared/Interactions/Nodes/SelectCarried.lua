-- SelectCarried.lua — Target node: selects the ball the acting entity is carrying.
-- Reads the pair(CARRIES, ball) relation (set on the carrier by GrabSystem) and stores the
-- ball as the context target. Returns FAILURE if the entity isn't carrying anything, which
-- aborts the surrounding Serial — i.e. "you can't throw what you aren't holding". Mirror of
-- SelectNearby, but the target is the held ball instead of a nearby one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local world = require(ReplicatedStorage.Code.Shared.World)
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local FAILURE = NodeRegistry.FAILURE
local SUCCESS = NodeRegistry.SUCCESS

NodeRegistry.register("SelectCarried", function(_config)
	return {
		Type = "SelectCarried",
		execute = function(_self, ctx)
			local ball = world:target(ctx.user, components.CARRIES)
			if not ball or not world:contains(ball) then
				return FAILURE
			end

			ctx:setMeta("TargetEntity", ball)
			return SUCCESS
		end,
	}
end)

return nil
