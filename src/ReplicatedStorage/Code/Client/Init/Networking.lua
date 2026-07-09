--[[
	Networking.lua — Client networking setup.
	Wires Zap, Replecs, and Replicator. Character init is in CharacterInitializer.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local world = require(ReplicatedStorage.Code.Shared.World)

local zapClient = require(ReplicatedStorage.Code.Client.ZapClient)
local _replecsClient = require(ReplicatedStorage.Code.Client.ReplecsClient)
local replicator = require(ReplicatedStorage.Code.Client.Replicator)

replicator:init(world)

-- Fetch full world state from server.
local buf, variants = zapClient.WaitForServer.Call()
replicator:apply_full(buf, variants)

return {}
