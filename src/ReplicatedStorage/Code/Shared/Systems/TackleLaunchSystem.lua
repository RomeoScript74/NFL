-- TackleLaunchSystem.lua — Drains Tackle events (pushed by the Tackle interaction chain's PushEvent
-- step) and applies the forward launch burst. Shared: runs on client (prediction) and server
-- (authority) — mirrors DashImpulseSystem exactly. Owns the TACKLING tag end-to-end: adds it on fire
-- alongside a pair(TIMER, TACKLE_WINDOW) coast timer, and removes it when that timer elapses (TimerSystem's
-- job — this system never ticks it). Nobody else touches TACKLING.
--
-- The coast runs its FULL window whether the tackle hits or whiffs — a tackle plows THROUGH, it doesn't
-- halt on contact. The RESOLVE (contact sweep, hit/whiff consequences) is a separate concern in the
-- TackleSweep node (server-only): it pushes Stun/Fumble/Interrupt but does NOT stop the coast, so the
-- tackler drives past the tackled runner. (Driving through a body is clean because character parts are
-- CanQuery=false — the floor raycast can't catch the target and step the tackler up onto it; that
-- CharacterSetup change is what retired the old TackleLand early-stop.)

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

	for _, entry in EventTypes.Tackle:drain() do
		local entity = entry.user
		if not world:contains(entity) then continue end
		local vel = world:get(entity, components.VELOCITY)
		local dir = world:get(entity, components.INPUT_DIRECTION)
		local facingYaw = world:get(entity, components.FACING_YAW)
		if not vel or not dir or not facingYaw then continue end

		world:set(entity, components.VELOCITY, TackleCalc.launchVelocity(vel, dir, facingYaw))
		world:set(entity, TACKLE_WINDOW_TIMER, TackleCalc.TACKLE_WINDOW_TICKS)
		world:add(entity, tags.TACKLING)
	end
end

return {
	name = "TackleLaunchSystem",
	phase = pipelines.Phases.Impulse,
	system = tackleLaunchSystem,
}
