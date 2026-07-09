--[[
	Tick.lua — Drives the MainScheduler every render frame.
	Registers a persistent callback on require.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local scheduler = require(ReplicatedStorage.Code.Shared.Scheduler)
local GamePipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

RunService:BindToRenderStep("RunVisuals", Enum.RenderPriority.Camera.Value + 1, function()
	scheduler.MainScheduler:run(GamePipelines.Pipelines.Visuals)
end)

return {}
