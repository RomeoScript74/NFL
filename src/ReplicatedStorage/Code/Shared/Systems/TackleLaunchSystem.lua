-- TackleLaunchSystem.lua — Drains Tackle events (pushed by the Tackle interaction chain's PushEvent
-- step) and applies the forward launch burst. Shared: runs on client (prediction) and server
-- (authority) — mirrors DashImpulseSystem exactly. Owns the TACKLING tag end-to-end: adds it on fire
-- alongside a pair(TIMER, TACKLE_WINDOW) coast timer, and removes it EITHER when that timer elapses
-- naturally (whiff — TimerSystem's job, this system never ticks it) OR immediately on a TackleLand
-- event (a landed hit — see below). Nobody else touches TACKLING.
--
-- The RESOLVE (contact sweep, hit/whiff consequences) is a separate concern, handled by the
-- TackleSweep interaction node (server-only). It doesn't mutate TACKLING directly (ownership), so on
-- a landed hit it pushes TackleLand to request an early stop — without this, the tackler keeps
-- coasting through the now-stunned target for the rest of the window: ambient collision is exempted
-- while TACKLING (so the dive doesn't visually stall on a miss), so the overlap goes uncorrected and
-- the floor raycast (which only excludes the tackler's own model) can pick up the target's body as
-- ground and step the tackler onto it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local EventTypes = require(ReplicatedStorage.Code.Shared.EventTypes)
local TackleCalc = require(ReplicatedStorage.Code.Shared.TackleCalc)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local TACKLE_WINDOW_TIMER = jecs.pair(components.TIMER, components.TACKLE_WINDOW)

-- Tackling characters whose burst timer has elapsed (TimerSystem removed the pair) → end the coast.
local expiredQuery = world:query():with(tags.TACKLING):without(TACKLE_WINDOW_TIMER):cached()

local function tackleLaunchSystem()
	for entity in expiredQuery do
		world:remove(entity, tags.TACKLING)
	end

	-- Early stop: a landed hit ends the coast now instead of at natural timer expiry. Clear both the
	-- tag and the timer pair together — leaving the timer pair behind would make SERVER_TACKLE_WINDOW
	-- keep replicating a nonzero value and reconciliation would re-add TACKLING on the next replay.
	for _, entry in EventTypes.TackleLand:drain() do
		local entity = entry.entity
		if not world:contains(entity) then continue end
		world:remove(entity, tags.TACKLING)
		world:remove(entity, TACKLE_WINDOW_TIMER)
	end

	for _, entry in EventTypes.Tackle:drain() do
		local entity = entry.user
		if not world:contains(entity) then continue end
		local vel = world:get(entity, components.VELOCITY)
		local yaw = world:get(entity, components.YAW)
		if not vel or not yaw then continue end

		world:set(entity, components.VELOCITY, TackleCalc.launchVelocity(vel, yaw))
		world:set(entity, TACKLE_WINDOW_TIMER, TackleCalc.TACKLE_WINDOW_TICKS)
		world:add(entity, tags.TACKLING)
	end
end

return {
	name = "TackleLaunchSystem",
	phase = pipelines.Phases.Impulse,
	system = tackleLaunchSystem,
}
