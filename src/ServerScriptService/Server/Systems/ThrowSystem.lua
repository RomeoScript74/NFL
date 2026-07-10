-- ThrowSystem.lua — Server: launches the carried ball on release.
-- Drains the Throw queue (Throw interaction: HoldToCharge -> SelectCarried -> PushEvent).
-- Detaches the ball, re-enables its physics, and sets its velocity along the carrier's
-- look direction (yaw + pitch — look up to throw higher) scaled by charge (hold longer to
-- throw farther). Launch origin is the hand (yaw-only, matching the carry visual); launch
-- direction includes pitch. Server-authoritative. Impulse phase.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)
local EventTypes = require(ReplicatedStorage.Code.Shared.EventTypes)
local Carry = require(ReplicatedStorage.Code.Shared.Carry)

local pair = jecs.pair

local MIN_THROW_SPEED = 40      -- studs/s at zero charge
local MAX_THROW_SPEED = 140     -- studs/s at full charge

local function throwSystem()
	for _, event in EventTypes.Throw:drain() do
		local ball = event.target
		local carrier = event.user
		if not ball or not world:contains(ball) then continue end
		if not carrier or not world:contains(carrier) then continue end

		local carrierPos = world:get(carrier, components.POSITION)
		local yaw = world:get(carrier, components.YAW)
		local pitch = world:get(carrier, components.PITCH)
		if not carrierPos or not yaw or not pitch then continue end

		-- Detach: remove the relationship, the carrier's held-ball link, and re-enable physics.
		local heldBy = world:target(ball, components.CARRIED_BY)
		if heldBy then
			world:remove(ball, pair(components.CARRIED_BY, heldBy))
		end
		world:remove(carrier, components.CARRIED_BALL)
		world:remove(ball, tags.PHYSICS_DISABLED)

		-- Launch from the hand, along the full look direction, scaled by charge.
		local charge = math.clamp(event.charge or 0, 0, 1)
		local speed = MIN_THROW_SPEED + (MAX_THROW_SPEED - MIN_THROW_SPEED) * charge
		local lookDir = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0).LookVector

		world:set(ball, components.POSITION, Carry.handPosition(carrierPos, yaw))
		world:set(ball, components.VELOCITY, lookDir * speed)
	end
end

return {
	name = "ThrowSystem",
	phase = pipelines.Phases.Impulse,
	system = throwSystem,
}
