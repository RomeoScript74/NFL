-- Ref.lua -- jecs-utils ref setup.
-- Requires this once during startup to wire the ref module to the world.
-- After this, ref.get(entity) and ref.set(entity, value) work anywhere.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local world = require(ReplicatedStorage.Code.Shared.World)
local ref = require(ReplicatedStorage.Packages["jecs-utils"]).ref

ref.world(world)

return {}
