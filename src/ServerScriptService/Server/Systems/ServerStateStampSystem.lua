-- ServerStateStampSystem.lua — Stamps SERVER_TICK, SERVER_POSITION, SERVER_VELOCITY,
-- REMOTE_TICK, SERVER_DASH_CD, and SERVER_DASH_WINDOW for replication each tick. The client uses
-- SERVER_* to detect desync and to restore the predicted dash cooldown + burst before replay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local DASH_CD = jecs.pair(components.COOLDOWN, components.CD_DASH)
local DASH_WINDOW_TIMER = jecs.pair(components.TIMER, components.DASH_WINDOW)
local TACKLE_CD = jecs.pair(components.COOLDOWN, components.CD_TACKLE)
local TACKLE_WINDOW_TIMER = jecs.pair(components.TIMER, components.TACKLE_WINDOW)

local stampQuery = world:query(
	components.POSITION,
	components.VELOCITY,
	components.LAST_PROCESSED_TICK
):cached()

-- Dash burst mirror: INPUT_FLAGS selects characters (the ball lacks it). Stamped every tick —
-- including 0 when DASH_WINDOW is absent — so the wire never goes stale after the burst ends
-- (a stale value would restore a phantom burst on replay).
local dashStampQuery = world:query(components.INPUT_FLAGS):cached()

-- Server-side tick counter for REMOTE_TICK (monotonic, per-entity).
-- Each physics tick, the counter advances so remote interpolators can measure age.
local tickCounter = 0

local function serverStateStampSystem()
	tickCounter = tickCounter + 1

	for entity, pos, vel, lastTick in stampQuery do
		world:set(entity, components.SERVER_POSITION, pos)
		world:set(entity, components.SERVER_VELOCITY, vel)
		world:set(entity, components.SERVER_TICK, lastTick)
		world:set(entity, components.REMOTE_TICK, tickCounter)
	end

	for entity in dashStampQuery do
		world:set(entity, components.SERVER_DASH_CD, world:get(entity, DASH_CD) or 0)
		world:set(entity, components.SERVER_DASH_WINDOW, world:get(entity, DASH_WINDOW_TIMER) or 0)
		world:set(entity, components.SERVER_TACKLE_CD, world:get(entity, TACKLE_CD) or 0)
		world:set(entity, components.SERVER_TACKLE_WINDOW, world:get(entity, TACKLE_WINDOW_TIMER) or 0)
	end
end

return {
	name = "ServerStateStampSystem",
	phase = pipelines.Phases.React,
	system = serverStateStampSystem,
}
