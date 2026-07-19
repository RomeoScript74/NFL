-- TackleSweep.lua — Hytale-swing-style node: RUNNING for the duration of the tackler's dive.
-- It sweeps for body contact (the same cylinder overlap character-collision uses) each tick
-- across the whole TACKLE_WINDOW_TICKS window (the tackler coasts forward the entire dive, so any tick
-- can connect). Contact is LAG-COMPENSATED: the runner is tested where the TACKLER SAW him (rewound by
-- ~the interp buffer), not his true position, so what-you-see-is-what-you-hit. A hit ends the dive early
-- with SUCCESS; running the window out with no contact FAILs with NO penalty (a clean miss is enough).
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
-- On timeout with no contact: just returns FAILURE — a clean miss has NO penalty (landing a tackle is
-- already hard enough). Consequences are only ever REQUESTED via events (StunSystem/FumbleSystem own
-- the actual state), per the layer rule that interactions never mutate ECS directly.

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
-- Lag comp: test the runner where the TACKLER SAW him, not where he truly is (what-you-see-is-what-you-
-- hit). Staleness = the interp buffer (how far behind the tackler renders remotes) + the tackler's
-- round-trip latency, so we rewind him by his velocity over that whole window — adapted PER TACKLER via
-- GetNetworkPing so a high-ping tackler rewinds more (fair) instead of one fixed value for everyone.
local INTERP_BUFFER = 0.15  -- fixed part: MUST match RemoteVisualInterpolator.BUFFER_DELAY
local PING_SCALE    = 1.0   -- fraction of the tackler's ping to add (ping≈RTT → 1.0). Lower if high-ping tackles over-reach, raise if they fall short

-- Runners that can be caught: CHARACTER, not braced, NOT mid-hurdle (the query IS the rules — "braced
-- can't be tackled", "a hurdling runner is immune, resolved as a hurdle-over below"). Both exclusions in
-- ONE :without call — chaining :without silently drops the first (jecs pitfall #8).
local candidateQuery = world:query(components.POSITION, components.VELOCITY, components.COLLIDER_RADIUS)
	:with(tags.CHARACTER):without(tags.BRACED, tags.HURDLING):cached()

-- Runners mid-hurdle: the tackle whiffs UNDER them (the duo). Separate query so the immune outcome is a
-- clean branch, not a has()-check in the loop body.
local hurdleQuery = world:query(components.POSITION, components.VELOCITY, components.COLLIDER_RADIUS)
	:with(tags.CHARACTER, tags.HURDLING):cached()

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

			-- Rewind window for THIS tackler: the interp buffer + his round-trip, so contact is tested
			-- where the runner was on the tackler's screen. Adapts per-tackler via ping (NPCs → buffer only).
			local playerEntity = world:target(tackler, components.OwnedBy)
			local player = playerEntity and world:get(playerEntity, components.PLAYER)
			local rewind = INTERP_BUFFER + (player and PING_SCALE * player:GetNetworkPing() or 0)

			-- Contact sweeps the whole dive window (the tackler coasts forward the whole time, so any tick
			-- can connect). The gate below is redundant with the node's lifetime but harmlessly bounds the sweep.
			if self._ticks <= TackleCalc.TACKLE_WINDOW_TICKS then
				local reach = radius + GRAB_REACH
				for runner, rpos, rvel, rradius in candidateQuery do
					if runner == tackler then continue end
					-- Lag comp: test where the TACKLER SAW him (rewound by the interp delay), not his true position.
					local seen = rpos - Vector3.new(rvel.X, 0, rvel.Z) * rewind
					if PhysicsCalc.separation(pos, reach, seen, rradius) ~= Vector3.zero then
						EventTypes.Fumble:push({ carrier = runner })
						EventTypes.Stun:push({ target = runner, duration = STUN_TICKS })
						ctx:setMeta("TargetEntity", runner)
						-- Do NOT stop the coast: the tackler DRIVES THROUGH the tackled runner and finishes
						-- the lunge (a tackle plows past, it doesn't halt on contact). The sweep still ends
						-- here (SUCCESS, no double-hit); TACKLING keeps coasting on its own timer.
						return SUCCESS
					end
				end

				-- Hurdle-over: a HURDLING runner in horizontal reach is IMMUNE — the tackle whiffs UNDER
				-- the vault (the duo). Resolve on HORIZONTAL position only: the vault's height is visual;
				-- the immune WINDOW (HURDLING, time) is what saves the runner, so a runner cleanly above the
				-- collision cylinder is still "here" for this check (which is exactly why separation() —
				-- with its vertical-clearance rule — is NOT used here). Same lag-comp rewind as above.
				-- The tackler is NOT stopped or stunned (he drives through, under the vault); the runner is
				-- untouched (keeps HURDLING + momentum). FAILURE ends the dive and short-circuits the Serial,
				-- so the Interrupt node after this one never runs — we leave the hurdler's action alone.
				for runner, rpos, rvel, rradius in hurdleQuery do
					if runner == tackler then continue end
					local seen = rpos - Vector3.new(rvel.X, 0, rvel.Z) * rewind
					local dx = pos.X - seen.X
					local dz = pos.Z - seen.Z
					local minDist = reach + rradius
					if dx * dx + dz * dz < minDist * minDist then
						-- Detected the hurdle-over. Do NOT stop or stun the tackler: he DRIVES THROUGH (dives
						-- under the vault), and his TACKLING coast carries him past — ending up BEHIND the
						-- hurdler, same as any other tackle now. FAILURE just ends the sweep here (the hurdler
						-- is immune, no hit) and short-circuits the Serial so Interrupt never runs. (Future: the
						-- duo co-animation / any recovery-stumble hooks in right here.)
						return FAILURE
					end
				end
			end

			-- Whiff: keep RUNNING through the WHOLE dive so its animation plays out, THEN stumble-stun —
			-- the contact window already closed above, so this is pure recovery/timing.
			-- Whiff: no self-stun. Hitting a runner is already hard, so a clean miss is punishment enough
			-- — just end the dive (the animation plays out), no penalty.
			if self._ticks >= TackleCalc.TACKLE_WINDOW_TICKS then
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
