-- Replicator.lua -- Shared replicator instance.
-- replecs.create(world) produces both .client and .server halves.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local replecs = require(ReplicatedStorage.Packages.replecs)
local world = require(ReplicatedStorage.Code.Shared.World)

return replecs.create(world)
