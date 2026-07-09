-- Replicator.lua -- Client-side replicator wrapper.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local replicator = require(ReplicatedStorage.Code.Shared.Replicator)

return replicator.client
