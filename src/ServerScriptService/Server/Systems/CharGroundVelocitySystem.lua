-- CharGroundVelocitySystem.lua — Accelerates/decelerates ground movement.
-- Reads INPUT_DIRECTION and movement params; writes to VELOCITY (X/Z only).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local PhysicsCalc = require(ReplicatedStorage.Code.Shared.PhysicsCalc)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local groundMoveQuery = world:query(
	components.VELOCITY,
	components.INPUT_DIRECTION,
	components.WALK_SPEED,
	components.ACCELERATION,
	components.DECELERATION,
	components.GRAVITY_SCALE
):with(tags.IS_GROUNDED):cached()

local FIXED_DT = 1 / 60

local function charGroundVelocitySystem()
	for entity, vel, dir, speed, accel, decel, _gravScale in groundMoveQuery do
		local newVel = PhysicsCalc.calculateMovement(vel, dir, speed, accel, decel, FIXED_DT)
		world:set(entity, components.VELOCITY, newVel)
	end
end

return {
	name = "CharGroundVelocitySystem",
	phase = pipelines.Phases.Movement,
	system = charGroundVelocitySystem,
}
