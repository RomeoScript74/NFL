-- KickImpulseSystem — drains the Kick event queue and launches the ball.
-- Shared: server-authoritative (ball has POSITION on server, no-ops on client).
-- Uses KickPhysics for the launch formula.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)
local EventTypes = require(ReplicatedStorage.Code.Shared.EventTypes)

local MIN_KICK_SPEED = 45
local MAX_KICK_SPEED = 140
local LAUNCH_PITCH = math.rad(35)
local KICK_RANGE = 12

local ballQuery = world:query(
	components.POSITION,
	components.VELOCITY
):with(tags.BALL):cached()

local function kickImpulseSystem()
	for _, event in EventTypes.Kick:drain() do
		print("[Phase2a] Kick event! charge:", (event.meta and event.meta.Charge))
		local kicker = event.entity
		local kickerPos = world:get(kicker, components.POSITION)
		local yaw = world:get(kicker, components.YAW)
		if not kickerPos or not yaw then continue end

		local charge = (event.meta and event.meta.Charge) or 0
		local speed = MIN_KICK_SPEED + (MAX_KICK_SPEED - MIN_KICK_SPEED) * charge

		local flat = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
		local dir = flat * math.cos(LAUNCH_PITCH)
			+ Vector3.new(0, math.sin(LAUNCH_PITCH), 0)
		local velocity = dir * speed

		for ballEntity, ballPos in ballQuery do
			if (ballPos - kickerPos).Magnitude <= KICK_RANGE then
				world:set(ballEntity, components.VELOCITY, velocity)
			end
		end
	end
end

return {
	name = "KickImpulseSystem",
	phase = pipelines.Phases.Impulse,
	system = kickImpulseSystem,
}
