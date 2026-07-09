-- BallGroundSystem.lua — Server floor collision + ground-contact state for the ball.
-- Raycasts down from the ball's ECS position; when the ball reaches the floor it rests
-- on it (Y clamped, downward velocity killed) and publishes the BALL_GROUNDED tag.
-- While airborne it clears the tag and does nothing, so Gravity + Kinematic produce a
-- clean arc. Owns BALL_GROUNDED end-to-end (BallFrictionSystem only reads it).
--
-- Mirrors CharFloorCollisionSystem's split: collision/contact-state here (Collision
-- phase), velocity work (friction) in BallFrictionSystem (Movement phase).
-- Server-only: the ball is server-authoritative. Runs after Integration has moved it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local FIXED_DT = 1 / 60
local CONTACT_SLOP = 0.05      -- studs of tolerance for "on the floor"

local ballQuery = world:query(
	components.POSITION,
	components.VELOCITY,
	components.ROOTPART
):with(tags.BALL):cached()

local function ballGroundSystem()
	for entity, pos, vel, rootPart in ballQuery do
		local radius = rootPart.Size.Y / 2

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { rootPart }

		local origin = pos + Vector3.new(0, radius, 0)
		local reach = radius * 2 + math.max(0, -vel.Y) * FIXED_DT + 0.5
		local result = workspace:Raycast(origin, Vector3.new(0, -reach, 0), rayParams)

		local grounded = false
		if result then
			local restY = result.Position.Y + radius
			-- Grounded only when at/under the floor and not moving upward.
			if pos.Y <= restY + CONTACT_SLOP and vel.Y <= 0 then
				grounded = true
				world:set(entity, components.POSITION, Vector3.new(pos.X, restY, pos.Z))
				world:set(entity, components.VELOCITY, Vector3.new(vel.X, 0, vel.Z))
			end
		end

		if grounded then
			world:add(entity, tags.BALL_GROUNDED)
		else
			world:remove(entity, tags.BALL_GROUNDED)
		end
	end
end

return {
	name = "BallGroundSystem",
	phase = pipelines.Phases.Collision,
	system = ballGroundSystem,
}
