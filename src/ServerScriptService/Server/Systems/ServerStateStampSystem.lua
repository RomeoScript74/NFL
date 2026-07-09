-- ServerStateStampSystem.lua — Stamps SERVER_TICK, SERVER_POSITION, SERVER_VELOCITY,
-- and REMOTE_TICK for replication each tick. The client uses these to detect desync.
-- Stripped of FPS-specific combat/dash cooldown stamping.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local stampQuery = world:query(
	components.POSITION,
	components.VELOCITY,
	components.LAST_PROCESSED_TICK
):cached()

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
end

return {
	name = "ServerStateStampSystem",
	phase = pipelines.Phases.React,
	system = serverStateStampSystem,
}
