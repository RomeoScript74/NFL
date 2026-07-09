-- KickImpulseSystem.lua — Server-authoritative ball kick (pure application).
-- Drains the Kick event queue and launches the target ball the interaction already
-- selected: along the kicker's yaw at a 45° angle, speed scaled by charge. It does
-- NOT decide *whether* a kick is valid or *which* ball — that's the interaction's
-- job (the SelectNearby node picks the target and fails the chain if none is in
-- range). This system only applies the effect, keeping evaluation out of ECS.
--
-- No Roblox physics — only sets the ball's ECS VELOCITY; Gravity + Kinematic +
-- BallGroundSystem produce the arc and landing. Runs in the Impulse phase: after
-- Gravity (so the launch overwrites this tick's gravity) and before Integration.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)
local EventTypes = require(ReplicatedStorage.Code.Shared.EventTypes)

local MIN_KICK_SPEED = 40         -- studs/s at zero charge (~8 stud range)
local MAX_KICK_SPEED = 130        -- studs/s at full charge (~86 stud range)
local DEFAULT_LAUNCH_ANGLE = 45   -- degrees, if the Kick def has no LAUNCH_ANGLE

local function kickImpulseSystem()
	for _, event in EventTypes.Kick:drain() do
		-- Target chosen by the interaction's SelectNearby node. The queue is an
		-- entity boundary, so validate the reference survived to this tick.
		local ballEntity = event.target
		if not ballEntity or not world:contains(ballEntity) then continue end

		local yaw = world:get(event.user, components.YAW)
		if not yaw then continue end

		local charge = math.clamp(event.charge or 0, 0, 1)
		local speed = MIN_KICK_SPEED + (MAX_KICK_SPEED - MIN_KICK_SPEED) * charge

		-- Launch elevation is data-driven (LAUNCH_ANGLE on the Kick def), read live so
		-- it can be retuned at runtime. Degrees in the component, radians for the math.
		local angleDeg = world:get(components.Kick, components.LAUNCH_ANGLE) or DEFAULT_LAUNCH_ANGLE
		local angle = math.rad(angleDeg)

		-- Flat forward from yaw (matches camera LookVector projected onto XZ), tilted
		-- up by `angle`. Both basis vectors are unit + orthogonal, so |launchVel| = speed.
		local flatForward = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
		local launchVel = (flatForward * math.cos(angle) + Vector3.new(0, 1, 0) * math.sin(angle)) * speed

		world:set(ballEntity, components.VELOCITY, launchVel)
	end
end

return {
	name = "KickImpulseSystem",
	phase = pipelines.Phases.Impulse,
	system = kickImpulseSystem,
}
