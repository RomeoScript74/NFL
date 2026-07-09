-- ServerPhysicsDriverSystem.lua — Drives the PhysicsScheduler at a fixed 60 Hz timestep.
-- Accumulates real time, runs Simulation + Effects pipelines each tick.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local scheduler = require(ReplicatedStorage.Code.Shared.Scheduler)
local GamePipelines = require(ReplicatedStorage.Code.Shared.PipeLines)
local phase = require(ReplicatedStorage.Packages["planck-runservice"]).Phases

local FIXED_DT = 1 / 60
local accumulator = 0
local lastFrameTime = os.clock()

local function serverPhysicsDriverSystem()
	local now = os.clock()
	local dt = now - lastFrameTime
	lastFrameTime = now

	if dt > 0.25 then
		dt = 0.25
	end

	accumulator = accumulator + dt

	while accumulator >= FIXED_DT do
		accumulator = accumulator - FIXED_DT

		scheduler.PhysicsScheduler:run(GamePipelines.Pipelines.Simulation)
		scheduler.PhysicsScheduler:run(GamePipelines.Pipelines.Effects)
	end
end

return {
	name = "ServerPhysicsDriverSystem",
	phase = phase.PreSimulation,
	system = serverPhysicsDriverSystem,
}
