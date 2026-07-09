--[[
	Pipelines.lua — Visual pipeline registration (client only).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local scheduler = require(ReplicatedStorage.Code.Shared.Scheduler)
local GamePipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

scheduler.MainScheduler:insert(GamePipelines.Pipelines.Visuals)

return {}
