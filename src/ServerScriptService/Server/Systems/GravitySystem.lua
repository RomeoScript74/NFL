-- GravitySystem.lua — Applies gravity to all entities with VELOCITY and GRAVITY_SCALE.
-- Unfiltered query: gravity affects grounded and airborne entities alike.
-- FloorCollisionSystem clamps grounded Y velocity to -0.1 post-gravity.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local world = require(ReplicatedStorage.Code.Shared.World)
local PhysicsCalc = require(ReplicatedStorage.Code.Shared.PhysicsCalc)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local gravityQuery = world:query(
	components.VELOCITY,
	components.GRAVITY_SCALE
):cached()

local FIXED_DT = 1 / 60

local function gravitySystem()
	for entity, vel, scale in gravityQuery do
		local newVel = PhysicsCalc.calculateGravity(vel, scale, FIXED_DT)
		world:set(entity, components.VELOCITY, newVel)
	end
end

return {
	name = "GravitySystem",
	phase = pipelines.Phases.Gravity,
	system = gravitySystem,
}
