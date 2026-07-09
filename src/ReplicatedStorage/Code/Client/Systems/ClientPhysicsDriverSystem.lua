-- ClientPhysicsDriverSystem.lua — Drives the PhysicsScheduler at a fixed 60 Hz timestep.
-- Calls Input.update(dt) each render frame to populate phase state (value2d, booleans).
-- Wraps each physics tick in Input.runPhase so systems can read Input.pressed/clamped2d.
-- Applies CLOCK_SYNC.Scale to the accumulator so the client time-dilates to match server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local scheduler = require(ReplicatedStorage.Code.Shared.Scheduler)
local GamePipelines = require(ReplicatedStorage.Code.Shared.PipeLines)
local Input = require(ReplicatedStorage.Code.Client.Input)
local phase = require(ReplicatedStorage.Packages["planck-runservice"]).Phases
local world = require(ReplicatedStorage.Code.Shared.World)
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local jecsUtils = require(ReplicatedStorage.Packages["jecs-utils"])

local clockQuery = world:query(components.CLOCK_SYNC):with(tags.LOCAL_CHARACTER):cached()

local FIXED_DT = 1 / 60
local accumulator = 0

local function clientPhysicsDriverSystem()
	local dt = scheduler.MainScheduler:getDeltaTime()

	-- Populate phase state from raw input events (must happen before runPhase)
	Input.update(dt)

	-- Apply server clock scale so client physics matches server cadence
	local _, clock = jecsUtils.query_first(clockQuery)
	local timeScale = if clock then clock.Scale or 1.0 else 1.0

	accumulator = accumulator + dt * timeScale

	while accumulator >= FIXED_DT do
		accumulator = accumulator - FIXED_DT

		Input.runPhase("physics", function()
			scheduler.PhysicsScheduler:run(GamePipelines.Pipelines.InputBridge)
			scheduler.PhysicsScheduler:run(GamePipelines.Pipelines.Simulation)
			scheduler.PhysicsScheduler:run(GamePipelines.Pipelines.Effects)
		end)
	end
end

return {
	name = "ClientPhysicsDriverSystem",
	phase = phase.PreSimulation,
	system = clientPhysicsDriverSystem,
}
