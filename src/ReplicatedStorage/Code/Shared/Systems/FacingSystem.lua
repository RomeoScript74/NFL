-- FacingSystem.lua — Maintains FACING_YAW: the character's BODY facing (where you're GOING), as opposed
-- to YAW (the camera/aim, where you're LOOKING). Updated from the horizontal velocity heading while
-- moving, HELD unchanged while stopped — so a standing character keeps facing the way he last ran.
--
-- Shared: runs on client prediction AND server authority, inside the replayed physics pipeline, so both
-- realms derive the same value from the (reconciled) velocity — no replication needed. Dash/tackle read
-- it as their launch fallback (PhysicsCalc.launchHeading) so a standstill ability fires along the body
-- facing instead of the camera. Same yaw convention as VisualFacing / forwardFromYaw: atan2(-vx, -vz).
--
-- Runs in PostGravity: horizontal velocity is final by then (Move set it, Gravity only touches Y), and
-- it's before Impulse where dash/tackle actually read FACING_YAW.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local FACING_MIN_SPEED = 1.0  -- horizontal studs/s below which we hold facing (matches PhysicsCalc.HEADING_MIN_SPEED)

-- Characters with a live VELOCITY (predicted local player on the client; every character on the server).
-- Remotes carry SERVER_VELOCITY not VELOCITY, so they're naturally excluded — they never fire abilities
-- on the client anyway.
local query = world:query(components.VELOCITY):with(tags.CHARACTER):cached()

local function facingSystem()
	for entity, vel in query do
		-- Below the threshold there's no meaningful heading → hold the last facing (don't touch it).
		if vel.X * vel.X + vel.Z * vel.Z >= FACING_MIN_SPEED * FACING_MIN_SPEED then
			world:set(entity, components.FACING_YAW, math.atan2(-vel.X, -vel.Z))
		end
	end
end

return {
	name = "FacingSystem",
	phase = pipelines.Phases.PostGravity,
	system = facingSystem,
}
