-- HoldToCharge.lua — Charge node. Accumulates hold time while the interaction's
-- input stays held, capped at MaxTime. On release it writes the normalized charge
-- (0..1) and raw hold time into context meta for a downstream PushEvent node, then
-- succeeds. The charge is measured here (server-side, in the chain runner) — never
-- sent from the client — so it is fully authoritative.
--
-- Config: { MaxTime = 1.5, MinTime = 0 }
--   RUNNING while held, SUCCESS on release, FAILURE if released before MinTime.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local FAILURE = NodeRegistry.FAILURE
local SUCCESS = NodeRegistry.SUCCESS
local RUNNING = NodeRegistry.RUNNING
local DT = 1 / 60

NodeRegistry.register("HoldToCharge", function(config)
	local maxTime = config.MaxTime or 1.5
	local minTime = config.MinTime or 0

	return {
		Type = "HoldToCharge",

		-- STATELESS: elapsed hold time lives in ctx:nodeState(self), not on the shared node.
		execute = function(self, ctx)
			local s = ctx:nodeState(self)
			s.elapsed = math.min((s.elapsed or 0) + DT, maxTime)

			-- inputReleased is set by InteractionDispatchSystem when the action's
			-- input flag drops. Until then, keep charging.
			if not ctx.chain.state.inputReleased then
				return RUNNING
			end

			if s.elapsed < minTime then
				return FAILURE
			end

			ctx:setMeta("Charge", s.elapsed / maxTime)
			ctx:setMeta("HoldTime", s.elapsed)
			return SUCCESS
		end,
	}
end)

return nil
