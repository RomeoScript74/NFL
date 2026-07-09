-- BallFrictionSystem.lua — Rolling friction for a grounded ball.
-- Bleeds off horizontal velocity while the ball rests/rolls on the floor, snapping to
-- a full stop below REST_EPSILON. Queries BALL_GROUNDED (published by BallGroundSystem)
-- so it never touches airborne balls — their arc stays untouched.
--
-- Mirrors CharGroundVelocitySystem: a velocity operation in the Movement phase that
-- reads the grounded tag the Collision-phase system produced (one frame stale, same as
-- characters). Only touches X/Z; Y is owned by Gravity + BallGroundSystem.
-- Server-only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local FIXED_DT = 1 / 60
local GROUND_FRICTION = 40     -- studs/s^2 horizontal decel while rolling
local REST_EPSILON = 0.05      -- below this horizontal speed, stop dead

local frictionQuery = world:query(
	components.VELOCITY
):with(tags.BALL_GROUNDED):cached()

local function ballFrictionSystem()
	for entity, vel in frictionQuery do
		local horizontal = Vector3.new(vel.X, 0, vel.Z)
		local speed = horizontal.Magnitude

		if speed <= REST_EPSILON then
			if speed > 0 then
				world:set(entity, components.VELOCITY, Vector3.new(0, vel.Y, 0))
			end
			continue
		end

		local newSpeed = math.max(0, speed - GROUND_FRICTION * FIXED_DT)
		local newHorizontal = horizontal.Unit * newSpeed
		world:set(entity, components.VELOCITY, Vector3.new(newHorizontal.X, vel.Y, newHorizontal.Z))
	end
end

return {
	name = "BallFrictionSystem",
	phase = pipelines.Phases.Movement,
	system = ballFrictionSystem,
}
