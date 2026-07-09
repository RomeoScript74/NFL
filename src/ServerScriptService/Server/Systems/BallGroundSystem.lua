-- BallGroundSystem.lua — Server ground collision + bounce for the ball (detection + response).
-- Detection and response to a floor contact are one atomic step, so they live together here;
-- only the continuous rolling friction (a persistent-grounded-state concern) is separate,
-- in BallFrictionSystem.
--
-- Uses a SWEPT ray — from where the ball spanned before this tick's integration down past its
-- current bottom — so a fast ball can't tunnel through a thin floor in a single 60 Hz step.
-- On contact it clamps the ball to the surface, then either:
--   * bounces (impact > SETTLE_SPEED): reflect vertical velocity scaled by the ball's own
--     BOUNCINESS, so each bounce is lower and a tennis ball out-bounces a bowling ball; or
--   * settles (impact <= SETTLE_SPEED): kill vertical velocity and tag BALL_GROUNDED, handing
--     off to BallFrictionSystem to roll it to a stop.
-- Owns BALL_GROUNDED end-to-end. Server-only. Collision phase (after Integration).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local FIXED_DT = 1 / 60
local CONTACT_SLOP = 0.05      -- studs of tolerance for "on the floor"
local SETTLE_SPEED = 6         -- vertical impact speed below which the ball settles instead of bouncing

local ballQuery = world:query(
	components.POSITION,
	components.VELOCITY,
	components.ROOTPART,
	components.BOUNCINESS
):with(tags.BALL):cached()

local function ballGroundSystem()
	for entity, pos, vel, rootPart, bounciness in ballQuery do
		local radius = rootPart.Size.Y / 2

		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = { rootPart }

		-- Swept vertical ray: span from the ball's highest reach this tick (its previous
		-- center when falling) down past its current bottom, so deep single-tick
		-- penetration is still detected instead of tunnelling straight through.
		local prevY = pos.Y - vel.Y * FIXED_DT
		local topY = math.max(prevY, pos.Y) + radius
		local origin = Vector3.new(pos.X, topY, pos.Z)
		local length = (topY - (pos.Y - radius)) + CONTACT_SLOP
		local result = workspace:Raycast(origin, Vector3.new(0, -length, 0), rayParams)

		local grounded = false
		if result then
			local restY = result.Position.Y + radius
			-- Contact only when at/under the floor and moving into it.
			if pos.Y <= restY + CONTACT_SLOP and vel.Y <= 0 then
				local impactSpeed = -vel.Y
				world:set(entity, components.POSITION, Vector3.new(pos.X, restY, pos.Z))

				if impactSpeed > SETTLE_SPEED then
					-- Bounce: reflect vertical velocity, scaled by restitution. Stays airborne.
					world:set(entity, components.VELOCITY, Vector3.new(vel.X, impactSpeed * bounciness, vel.Z))
				else
					-- Settle: too slow to bounce — rest and hand off to friction.
					grounded = true
					world:set(entity, components.VELOCITY, Vector3.new(vel.X, 0, vel.Z))
				end
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
