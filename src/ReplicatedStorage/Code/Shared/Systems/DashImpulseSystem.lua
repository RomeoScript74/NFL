-- DashImpulseSystem.lua — Drains Dash events (pushed by the Dash interaction chain) and applies
-- the burst. Shared: runs on client (prediction) and server (authority). It OWNS the DASHING tag:
-- adds it on fire alongside a pair(TIMER, DASH_WINDOW) burst timer, and removes it when that timer
-- has elapsed. The countdown itself is the generic TimerSystem's job — this system never ticks.
-- Reconciliation restores the timer + tag before replay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local EventTypes = require(ReplicatedStorage.Code.Shared.EventTypes)
local DashCalc = require(ReplicatedStorage.Code.Shared.DashCalc)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local DASH_WINDOW_TIMER = jecs.pair(components.TIMER, components.DASH_WINDOW)

-- Dashing characters whose burst timer has elapsed (TimerSystem removed the pair) → end the coast.
local expiredQuery = world:query():with(tags.DASHING):without(DASH_WINDOW_TIMER):cached()

local function dashImpulseSystem()
	-- End the coast for any dash whose window timer TimerSystem has already run out.
	for entity in expiredQuery do
		world:remove(entity, tags.DASHING)
	end

	-- Fire: apply the burst and start the window timer (TimerSystem counts it down from here).
	for _, entry in EventTypes.Dash:drain() do
		local entity = entry.user
		if not world:contains(entity) then continue end
		local vel = world:get(entity, components.VELOCITY)
		local dir = world:get(entity, components.INPUT_DIRECTION)
		if not vel or not dir then continue end
		local facingYaw = world:get(entity, components.FACING_YAW) or 0

		world:set(entity, components.VELOCITY, DashCalc.dashVelocity(vel, dir, facingYaw))
		world:set(entity, DASH_WINDOW_TIMER, DashCalc.DASH_WINDOW_TICKS)
		world:add(entity, tags.DASHING)
	end
end

return {
	name = "DashImpulseSystem",
	phase = pipelines.Phases.Impulse,
	system = dashImpulseSystem,
}
