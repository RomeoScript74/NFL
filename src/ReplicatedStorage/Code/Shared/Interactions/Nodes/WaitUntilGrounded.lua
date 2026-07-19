-- WaitUntilGrounded.lua — RUNNING until the character has LEFT the ground and returned to it (i.e. an
-- airborne arc has completed with a landing). SUCCESS on that landing, RUNNING otherwise.
--
-- This is a genuinely LONG predicted node (holds RUNNING for the whole airborne arc), which is only
-- safe because chain execution state now rolls back with reconciliation — its `airborne` latch lives in
-- ctx:nodeState(self) (per-chain scratch), so a mid-arc reconciliation restores + replays it correctly.
-- It's the hurdle chain's way of OWNING its whole timeline: launch → wait-until-grounded → land beat,
-- instead of a separate ECS system sniffing the grounded transition.
--
-- Launch-tick guard: on the tick the launch fires, the character is still IS_GROUNDED (floor collision
-- runs later in the tick than this node's Combat phase), so we must NOT succeed immediately — the
-- `airborne` latch requires having actually left the ground first. Deterministic (reads only the
-- reconciled IS_GROUNDED tag), so it reproduces identically on replay and on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local SUCCESS = NodeRegistry.SUCCESS
local RUNNING = NodeRegistry.RUNNING

NodeRegistry.register("WaitUntilGrounded", function(_config)
	return {
		Type = "WaitUntilGrounded",

		execute = function(self, ctx)
			local s = ctx:nodeState(self)
			if not world:has(ctx.user, tags.IS_GROUNDED) then
				s.airborne = true  -- left the ground
				return RUNNING
			end
			-- Grounded: only a landing if we've already been airborne (else it's the launch tick).
			if s.airborne then
				return SUCCESS
			end
			return RUNNING
		end,
	}
end)

return nil
