-- TackleSweep.lua — Hytale-swing-style node: RUNNING for the duration of the tackler's dive,
-- sweeping for body contact each tick (the same cylinder overlap character-collision uses), and
-- branching to a different outcome depending on whether contact happened before the window ran out.
-- Replaces a bespoke tag-driven ECS system with the framework's native multi-tick RUNNING pattern
-- (mirrors HoldToCharge's self._elapsed-across-ticks shape).
--
-- SERVER-ONLY, structurally: interactions predict a character's own body, never the outcome of
-- hitting another entity. This node is registered with `side = "server"` in the Tackle chain def
-- (see Prefabs.lua) — NodeRegistry.isSkipped is checked by every container (Serial/Parallel) before
-- calling a child's execute, so the client's copy of the chain never calls this node's execute at
-- all. The node itself carries no realm-awareness.
--
-- On contact: pushes Fumble{carrier} + Stun{target,duration} on the runner (drop the ball, freeze —
-- two independent consequences this hit happens to cause, not one fused effect), sets the runner as
-- ctx:getTargetEntity() for the Interrupt node right after this one in the SAME Serial (same tick,
-- same ctx — cancelling the runner's own in-progress action is its own composable step, not something
-- this node does itself; see Interrupt.lua), returns SUCCESS.
-- On timeout with no contact: pushes Stun{target,duration} on the tackler himself (the whiff
-- stumble), returns FAILURE. Either way this node — not a separate system — decides; it still only
-- REQUESTS the consequence via events (StunSystem/FumbleSystem own the actual state), per the layer
-- rule that interactions never mutate ECS directly.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local PhysicsCalc = require(ReplicatedStorage.Code.Shared.PhysicsCalc)
local TackleCalc = require(ReplicatedStorage.Code.Shared.TackleCalc)
local EventTypes = require(ReplicatedStorage.Code.Shared.EventTypes)
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local SUCCESS = NodeRegistry.SUCCESS
local FAILURE = NodeRegistry.FAILURE
local RUNNING = NodeRegistry.RUNNING

-- Server-only resolve tuning — this node's own data, not in shared TackleCalc: TackleSweep is the sole
-- consumer and never runs on the client (side="server"), so there is no cross-realm value to keep in
-- sync. (The coast/contact window TACKLE_WINDOW_TICKS DOES stay in TackleCalc — the client predicts
-- that window too, so it must match.)
local STUN_TICKS = 60      -- ticks of STUNNED on the loser of the exchange (~1.0s @60Hz)
local GRAB_REACH = 1.0     -- studs added to the tackler's collider radius: body + this reach must
                           -- overlap a runner to connect (same cylinder test as character collision)
local LEAD_SECONDS = 0.12  -- favor-the-runner: contact tested against the runner led forward by his
                           -- velocity this far, projecting a fast runner out of the dive's path

-- Runners that can be caught: CHARACTER, not braced (the query IS the "braced can't be tackled" rule).
local candidateQuery = world:query(components.POSITION, components.VELOCITY, components.COLLIDER_RADIUS)
	:with(tags.CHARACTER):without(tags.BRACED):cached()

NodeRegistry.register("TackleSweep", function(_config)
	return {
		Type = "TackleSweep",
		_ticks = 0,

		execute = function(self, ctx)
			self._ticks = self._ticks + 1

			local tackler = ctx.user
			local pos = world:get(tackler, components.POSITION)
			local radius = world:get(tackler, components.COLLIDER_RADIUS)
			if not pos or not radius then return FAILURE end

			local reach = radius + GRAB_REACH
			for runner, rpos, rvel, rradius in candidateQuery do
				if runner == tackler then continue end
				-- Favor the runner: test against where he's HEADING, not where he is now.
				local led = rpos + Vector3.new(rvel.X, 0, rvel.Z) * LEAD_SECONDS
				if PhysicsCalc.separation(pos, reach, led, rradius) ~= Vector3.zero then
					EventTypes.Fumble:push({ carrier = runner })
					EventTypes.Stun:push({ target = runner, duration = STUN_TICKS })
					ctx:setMeta("TargetEntity", runner)
					-- Stop the coast NOW — otherwise the tackler keeps sliding through the now-stunned
					-- target for the rest of the dive window (TACKLING's ambient-collision exemption
					-- would let them fully overlap it).
					EventTypes.TackleLand:push({ entity = tackler })
					return SUCCESS
				end
			end

			if self._ticks >= TackleCalc.TACKLE_WINDOW_TICKS then
				EventTypes.Stun:push({ target = tackler, duration = STUN_TICKS })
				return FAILURE
			end

			return RUNNING
		end,

		reset = function(self)
			self._ticks = 0
		end,
	}
end)

return nil
