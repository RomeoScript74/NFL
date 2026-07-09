-- Replecs_Server.lua -- Server-side replecs flush tick.
-- Collects reliable/unreliable updates from replicator and fires them
-- to each player via ZapServer. Registered on MainScheduler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local replicator = require(ServerScriptService.Server.Replicator)
local zap = require(ServerScriptService.Server.ZapServer)
local interval = require(ReplicatedStorage.Code.Shared.Utilities.Interval)
local scheduler = require(ReplicatedStorage.Code.Shared.Scheduler)

local reliableInterval = interval(1 / 20)
local unreliableInterval = interval(1 / 60)

local function replecsServer()
	if reliableInterval() then
		for player, buf, variants in replicator:collect_updates() do
			zap.OnReliableUpdates.Fire(player, buf, variants)
		end
	end
	if unreliableInterval() then
		for player, buf, variants in replicator:collect_unreliable() do
			zap.OnUnreliableUpdates.Fire(player, buf, variants)
		end
	end
end

scheduler.MainScheduler:addSystem(replecsServer)
return replecsServer
