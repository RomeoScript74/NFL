-- BallFrictionSystem.lua — Rolling friction for a grounded ball.
-- Bleeds off horizontal velocity while the ball rests/rolls on the floor, snapping to
-- a full stop below REST_EPSILON. Queries BALL_GROUNDED (published by BallGroundSystem)
-- so it never touches airborne balls — their arc stays untouched.
--
-- Runs in PostGravity — deliberately AFTER WindSystem (Gravity phase), not Movement.
-- Wind is a per-tick acceleration on VELOCITY; if friction ran before wind (like
-- CharGroundVelocitySystem does for characters, who have no wind), it would always be
-- decelerating LAST tick's push, never this tick's — so Integration would always move
-- the ball by one tick's unopposed wind before friction ever got a chance to react,
-- producing a constant, magnitude-independent creep no amount of friction could cancel.
-- Running after Gravity fixes that: friction sees this tick's wind before Integration
-- reads velocity. It still runs BEFORE Impulse, so a kick's launch velocity (set that
-- same tick, while BALL_GROUNDED is still stale from last tick) is never dampened.
-- Only touches X/Z; Y is owned by Gravity + BallGroundSystem. Server-only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local FIXED_DT = 1 / 60
local GROUND_FRICTION = 90     -- studs/s^2 horizontal decel while rolling
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
	phase = pipelines.Phases.PostGravity,
	system = ballFrictionSystem,
}
