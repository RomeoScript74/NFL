-- FumbleSystem.lua — Server: owns the ball-loose transition. Drains the Fumble queue (any cause —
-- TackleSystem today, strips/big hits later — requests that a carrier lose the ball): it detaches the
-- carried ball from its carrier (the reverse of GrabSystem's attach) and pops it loose. Centralizing
-- the detach here keeps carry-state mutation out of every system that merely CAUSES a fumble.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)
local EventTypes = require(ReplicatedStorage.Code.Shared.EventTypes)

local pair = jecs.pair

local function fumbleSystem()
	for _, event in EventTypes.Fumble:drain() do
		local carrier = event.carrier
		if not carrier or not world:contains(carrier) then continue end

		local ball = world:target(carrier, components.CARRIES)
		if not ball or not world:contains(ball) then continue end

		-- Detach both ways + re-enable physics (reverse of GrabSystem's attach).
		world:remove(ball, pair(components.CARRIED_BY, carrier))
		world:remove(carrier, pair(components.CARRIES, ball))
		world:remove(ball, tags.PHYSICS_DISABLED)

		-- Pop the ball loose just above the carrier.
		local carrierPos = world:get(carrier, components.POSITION)
		if carrierPos then
			world:set(ball, components.POSITION, carrierPos + Vector3.new(0, 2, 0))
			world:set(ball, components.VELOCITY, Vector3.new(0, 8, 0))
		end
	end
end

return {
	name = "FumbleSystem",
	phase = pipelines.Phases.Impulse,
	system = fumbleSystem,
}
