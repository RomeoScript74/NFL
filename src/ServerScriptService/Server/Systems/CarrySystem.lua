-- CarrySystem.lua — Server: keeps each carried ball at its carrier's hand.
-- Runs in PostCollision, after the carrier's position is finalized for the tick, so the
-- ball's authoritative POSITION tracks the hand. This keeps SERVER_POSITION continuous
-- through carry so the throw transition (carried -> free -> interpolated) doesn't jump,
-- and gives the throw a correct launch origin. The client renders the ball via
-- BallAttachmentSystem; this is purely the authoritative bookkeeping. Server-only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)
local Carry = require(ReplicatedStorage.Code.Shared.Carry)

local pair = jecs.pair
local Wildcard = jecs.Wildcard

local function carrySystem()
	-- Uncached wildcard-pair query (matches CooldownSystem/TimerSystem); usually 0-1 balls.
	for ball in world:query(components.POSITION, pair(components.CARRIED_BY, Wildcard)) do
		local carrier = world:target(ball, components.CARRIED_BY)
		if not carrier then continue end

		local carrierPos = world:get(carrier, components.POSITION)
		local yaw = world:get(carrier, components.YAW)
		if not carrierPos or not yaw then continue end

		world:set(ball, components.POSITION, Carry.handPosition(carrierPos, yaw))
		world:set(ball, components.VELOCITY, Vector3.zero)
	end
end

return {
	name = "CarrySystem",
	phase = pipelines.Phases.PostCollision,
	system = carrySystem,
}
