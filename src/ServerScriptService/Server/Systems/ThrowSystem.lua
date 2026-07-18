-- ThrowSystem.lua — Server: performs the ECS mutations of a throw in response to events pushed by the
-- Throw chain (PushEvent nodes), and robustly owns the THROWING tag's lifetime:
--   Throw{windowTicks} -> add THROWING + a pair(TIMER, THROW_WINDOW) of that length (anim window opens)
--   LaunchBall{target} -> detach + launch the ball (the release frame; Wait timed the delay before this)
-- THROWING is removed when its TIMER elapses (generic TimerSystem counts it; expiredQuery clears the tag).
-- The timer — not the chain — owns the tag lifetime ON PURPOSE: the throw can be INTERRUPTED mid-motion
-- (InterruptSystem clears the chain when the QB is tackled), which stops the chain; a system timer still
-- expires and cleans up, so THROWING never leaks. Timing VALUES live in the chain def (windowTicks payload
-- + Wait.RunTime); this system just enforces them. Mirrors TackleLaunchSystem. Impulse phase.

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

local THROW_WINDOW_TIMER = pair(components.TIMER, components.THROW_WINDOW)

-- Throwers whose window timer has elapsed (TimerSystem removed the pair) → end the throw window.
local expiredQuery = world:query():with(tags.THROWING):without(THROW_WINDOW_TIMER):cached()

-- Detach the carried ball and launch it from the hand. HORIZONTAL direction is the carrier's BODY FACING
-- (FACING_YAW — where the model visibly points / where they're moving), NOT the camera; VERTICAL aim
-- (pitch) still comes from the look so you can loft or line-drive. Read NOW (at release) so it goes where
-- the body points when the ball leaves. Scaled by the stored charge.
local function launchBall(carrier: number, ball: number, charge: number)
	if not world:contains(ball) or not world:contains(carrier) then return end
	local carrierPos = world:get(carrier, components.POSITION)
	local facingYaw = world:get(carrier, components.FACING_YAW)
	local pitch = world:get(carrier, components.PITCH)
	if not carrierPos or not facingYaw or not pitch then return end

	-- Detach: remove both relationship directions and re-enable physics.
	local heldBy = world:target(ball, components.CARRIED_BY)
	if heldBy then
		world:remove(ball, pair(components.CARRIED_BY, heldBy))
	end
	world:remove(carrier, pair(components.CARRIES, ball))
	world:remove(ball, tags.PHYSICS_DISABLED)

	local speed = MIN_THROW_SPEED + (MAX_THROW_SPEED - MIN_THROW_SPEED) * charge
	local lookDir = CFrame.fromEulerAnglesYXZ(pitch, facingYaw, 0).LookVector
	world:set(ball, components.POSITION, Carry.handPosition(carrierPos, facingYaw))
	world:set(ball, components.VELOCITY, lookDir * speed)
end

local function throwSystem()
	-- End the throw window for any thrower whose timer TimerSystem has run out (also the interrupt path).
	for entity in expiredQuery do
		world:remove(entity, tags.THROWING)
	end

	-- Open: start the anim window with the node-specified length (THROWING replicates to all).
	for _, event in EventTypes.Throw:drain() do
		local carrier = event.user
		if carrier and world:contains(carrier) then
			world:add(carrier, tags.THROWING)
			world:set(carrier, THROW_WINDOW_TIMER, event.windowTicks or 33)
		end
	end

	-- Release frame: ball leaves the hand (event.target is the carried ball from SelectCarried).
	for _, event in EventTypes.LaunchBall:drain() do
		if event.user and event.target then
			launchBall(event.user, event.target, math.clamp(event.charge or 0, 0, 1))
		end
	end
end

return {
	name = "ThrowSystem",
	phase = pipelines.Phases.Impulse,
	system = throwSystem,
}
