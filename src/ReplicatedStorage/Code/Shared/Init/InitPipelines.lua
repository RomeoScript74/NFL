--[[
	Pipelines.lua — Physics pipeline registration (shared).
	Defines which pipelines run on the PhysicsScheduler, in what order.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local scheduler = require(ReplicatedStorage.Code.Shared.Scheduler)
local GamePipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

scheduler.PhysicsScheduler:insert(GamePipelines.Pipelines.InputBridge)
scheduler.PhysicsScheduler:insert(GamePipelines.Pipelines.Simulation)
scheduler.PhysicsScheduler:insert(GamePipelines.Pipelines.Effects)

return {}
