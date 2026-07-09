-- Replecs_Client.lua -- Client-side replecs update tick.
-- Polls ZapClient for incoming reliable/unreliable buffers and applies them
-- to the replicator client. Registered on MainScheduler.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local replicator = require(ReplicatedStorage.Code.Client.Replicator)
local scheduler = require(ReplicatedStorage.Code.Shared.Scheduler)
local zap = require(ReplicatedStorage.Code.Client.ZapClient)

local function replecsClient()
	for _, buf, variants in zap.OnReliableUpdates.Iter() do
		replicator:apply_updates(buf, variants)
	end
	for _, buf, variants in zap.OnUnreliableUpdates.Iter() do
		replicator:apply_unreliable(buf, variants)
	end
end

scheduler.MainScheduler:addSystem(replecsClient)
return replecsClient
