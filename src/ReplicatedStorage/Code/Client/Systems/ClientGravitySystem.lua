-- ClientGravitySystem.lua — Client-side gravity prediction.
-- Mirrors server GravitySystem but filters to PREDICTED entities only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local PhysicsCalc = require(ReplicatedStorage.Code.Shared.PhysicsCalc)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local gravityQuery = world:query(
	components.VELOCITY,
	components.GRAVITY_SCALE
):with(tags.PREDICTED):cached()

local FIXED_DT = 1 / 60

local function clientGravitySystem()
	for entity, vel, scale in gravityQuery do
		local newVel = PhysicsCalc.calculateGravity(vel, scale, FIXED_DT)
		world:set(entity, components.VELOCITY, newVel)
	end
end

return {
	name = "ClientGravitySystem",
	phase = pipelines.Phases.Gravity,
	system = clientGravitySystem,
}
