-- ClientCharGroundVelocitySystem.lua — Client-side ground movement prediction.
-- Mirrors server CharGroundVelocitySystem but filters to PREDICTED entities only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local PhysicsCalc = require(ReplicatedStorage.Code.Shared.PhysicsCalc)
local InputType = require(ReplicatedStorage.Code.Shared.InputType)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local groundMoveQuery = world:query(
	components.VELOCITY,
	components.INPUT_DIRECTION,
	components.INPUT_FLAGS,
	components.WALK_SPEED,
	components.ACCELERATION,
	components.DECELERATION,
	components.GRAVITY_SCALE
):with(tags.IS_GROUNDED, tags.PREDICTED):without(tags.DASHING, tags.TACKLING, tags.STUNNED):cached()

local FIXED_DT = 1 / 60
local SPRINT_SPEED_MULTIPLIER = 1.5
local BRACE_SPEED_MULTIPLIER = 0.4

local function clientCharGroundVelocitySystem()
	for entity, vel, dir, flags, speed, accel, decel, _gravScale in groundMoveQuery do
		-- Brace stance overrides sprint: you plant and move slowly.
		local effectiveSpeed = speed
		if InputType.has(flags, InputType.BRACE) then
			effectiveSpeed = speed * BRACE_SPEED_MULTIPLIER
		elseif InputType.has(flags, InputType.SPRINT) then
			effectiveSpeed = speed * SPRINT_SPEED_MULTIPLIER
		end

		local newVel = PhysicsCalc.calculateMovement(vel, dir, effectiveSpeed, accel, decel, FIXED_DT)
		world:set(entity, components.VELOCITY, newVel)
	end
end

return {
	name = "ClientCharGroundVelocitySystem",
	phase = pipelines.Phases.Movement,
	system = clientCharGroundVelocitySystem,
}
