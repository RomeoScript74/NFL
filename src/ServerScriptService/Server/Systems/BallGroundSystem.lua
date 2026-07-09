-- BallGroundSystem.lua — Ground clamp + rolling friction for the ball.
-- Server-only: the ball is Anchored, driven by ECS POSITION.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local BALL_RADIUS = 1
local GROUND_FRICTION = 0.9
local STOP_SPEED = 1.5

local query = world:query(
	components.POSITION,
	components.VELOCITY
):with(tags.BALL):cached()

local _dbg = 0
local function ballGroundSystem()
	_dbg += 1
	for entity, pos, vel in query do
		if _dbg % 120 == 1 then
			print("[Phase2a BallGround] pos:", pos, "vel:", vel)
		end
		if pos.Y <= BALL_RADIUS then
			world:set(entity, components.POSITION, Vector3.new(pos.X, BALL_RADIUS, pos.Z))
			local verticalY = if vel.Y < 0 then 0 else vel.Y
			local horizontal = Vector3.new(vel.X, 0, vel.Z) * GROUND_FRICTION
			if horizontal.Magnitude < STOP_SPEED then
				horizontal = Vector3.zero
			end
			world:set(entity, components.VELOCITY, Vector3.new(horizontal.X, verticalY, horizontal.Z))
		end
	end
end

return {
	name = "BallGroundSystem",
	phase = pipelines.Phases.Collision,
	system = ballGroundSystem,
}
