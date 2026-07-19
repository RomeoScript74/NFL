-- HurdleLaunchSystem.lua — Pure event handler for the Hurdle interaction. Shared: runs on client
-- (prediction) and server (authority) — mirrors DashImpulseSystem/TackleLaunchSystem. Owns HURDLING.
--
-- The Hurdle CHAIN owns the whole timeline (launch → WaitUntilGrounded → land) and fires an event at
-- each beat; this system just applies them:
--   • Hurdle      → apply the upward launch + ADD HURDLING (+ a SAFETY-cap timer).
--   • HurdleLand  → the chain's WaitUntilGrounded detected the touchdown → REMOVE HURDLING.
-- HURDLING therefore spans the WHOLE airborne arc, which drives everything for free: it's the tackle-
-- immune window (server-only TackleSweep reads it), the collision exemption, AND — since it ends exactly
-- on landing — the trigger for the Land recovery clip (AnimationConfig `recovery`).
--
-- The chain now owning the grounded-detection (instead of a groundedQuery here) is why this needed the
-- rollback-native chains work: WaitUntilGrounded is a long RUNNING node whose state rolls back. The
-- HURDLE_WINDOW timer is now ONLY a safety cap — if the chain is interrupted before firing HurdleLand
-- (e.g. a rare mid-air stun freezes the dispatch), it stops HURDLING from leaking. SERVER_HURDLE_WINDOW
-- still anchors HURDLING across reconciliation + signals remotes (they don't run the chain).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local EventTypes = require(ReplicatedStorage.Code.Shared.EventTypes)
local HurdleCalc = require(ReplicatedStorage.Code.Shared.HurdleCalc)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local HURDLE_WINDOW_TIMER = jecs.pair(components.TIMER, components.HURDLE_WINDOW)

-- Safety cap: HURDLING outlived its timer without a HurdleLand (chain interrupted mid-air) → end it.
local expiredQuery = world:query():with(tags.HURDLING):without(HURDLE_WINDOW_TIMER):cached()

local function hurdleLaunchSystem()
	for entity in expiredQuery do
		world:remove(entity, tags.HURDLING)
	end

	-- Land beat: the chain's WaitUntilGrounded touched down. Clear the tag AND the timer together so
	-- SERVER_HURDLE_WINDOW goes 0 (else reconciliation would re-add HURDLING on the next replay — the
	-- standard owned-timer-pair rule).
	for _, entry in EventTypes.HurdleLand:drain() do
		local entity = entry.user
		if not world:contains(entity) then continue end
		world:remove(entity, tags.HURDLING)
		world:remove(entity, HURDLE_WINDOW_TIMER)
	end

	-- Launch beat: apply the upward burst + start HURDLING and its safety-cap timer.
	for _, entry in EventTypes.Hurdle:drain() do
		local entity = entry.user
		if not world:contains(entity) then continue end
		local vel = world:get(entity, components.VELOCITY)
		if not vel then continue end

		world:set(entity, components.VELOCITY, HurdleCalc.launchVelocity(vel))
		world:set(entity, HURDLE_WINDOW_TIMER, HurdleCalc.HURDLE_WINDOW_TICKS)
		world:add(entity, tags.HURDLING)
	end
end

return {
	name = "HurdleLaunchSystem",
	phase = pipelines.Phases.Impulse,
	system = hurdleLaunchSystem,
}
