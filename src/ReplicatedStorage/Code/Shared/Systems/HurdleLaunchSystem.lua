-- HurdleLaunchSystem.lua — Drains Hurdle events (pushed by the Hurdle interaction chain's PushEvent
-- step) and applies the upward launch burst. Shared: runs on client (prediction) and server
-- (authority) — mirrors DashImpulseSystem/TackleLaunchSystem. Owns the HURDLING tag end-to-end.
--
-- HURDLING spans the WHOLE airborne arc — launch until the hurdler actually touches down. It's removed
-- when the character is IS_GROUNDED again (the real landing), NOT on a fixed timer: the timer is only a
-- SAFETY cap so a hurdle off the map can't leak HURDLING forever. This is what lets the LAND animation be
-- state-driven — HURDLING ending == landed, so the Hurdle action's recovery clip (Land) plays exactly on
-- touchdown (see AnimationConfig `recovery`), with NO velocity-edge sniffing in the locomotion layer.
-- It's rollback-safe: the removal is a stateless function of reconciled state (HURDLING + IS_GROUNDED),
-- so replay re-derives the landing; SERVER_HURDLE_WINDOW still anchors the tag across reconciliation.
--
-- HURDLING is also the tackle-immune window: the server-only TackleSweep node reads it to resolve a
-- hurdle-over (duo) instead of a takedown — so "immune the whole time you're airborne" falls out for free.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local EventTypes = require(ReplicatedStorage.Code.Shared.EventTypes)
local HurdleCalc = require(ReplicatedStorage.Code.Shared.HurdleCalc)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local HURDLE_WINDOW_TIMER = jecs.pair(components.TIMER, components.HURDLE_WINDOW)

-- Landed: the hurdler is grounded again → end the hurdle (the normal exit). Both terms in ONE :with
-- (jecs pitfall #8). This can't false-fire on the launch tick: this loop runs BEFORE the event drain
-- below, so HURDLING isn't set yet that tick, and next tick floor collision has already cleared
-- IS_GROUNDED (the launch gave upward velocity).
local groundedQuery = world:query():with(tags.HURDLING, tags.IS_GROUNDED):cached()
-- Safety cap: the timer ran out without ever landing (hurdled off the map) → end it anyway.
local expiredQuery = world:query():with(tags.HURDLING):without(HURDLE_WINDOW_TIMER):cached()

local function hurdleLaunchSystem()
	-- Normal exit: touched down. Clear the tag AND the timer together so SERVER_HURDLE_WINDOW goes 0
	-- (else reconciliation would re-add HURDLING on the next replay — same rule as every owned timer pair).
	for entity in groundedQuery do
		world:remove(entity, tags.HURDLING)
		world:remove(entity, HURDLE_WINDOW_TIMER)
	end

	for entity in expiredQuery do
		world:remove(entity, tags.HURDLING)
	end

	-- Fire: apply the upward burst and start the window timer (TimerSystem counts it down from here).
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
