-- GrabSystem.lua — Server: attaches a grabbed loose ball to its carrier.
-- Drains the Grab queue (Grab interaction: SelectNearby -> PushEvent). For each grab,
-- if the ball is still loose and the carrier's hands are empty, it links ball <-> carrier
-- and disables the ball's physics:
--   * pair(CARRIED_BY, carrier) on the ball  — replicated, drives client attachment.
--   * pair(CARRIES, ball) on the carrier      — replicated; SelectCarried/throw look up the ball, and
--                                               the predicted tackle gate reads its presence.
--   * PHYSICS_DISABLED on the ball            — physics systems skip it; CarrySystem moves it.
-- Server-authoritative. Impulse phase (drains events pushed in Combat).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)
local EventTypes = require(ReplicatedStorage.Code.Shared.EventTypes)

local pair = jecs.pair

local function grabSystem()
	for _, event in EventTypes.Grab:drain() do
		local ball = event.target
		local carrier = event.user
		if not ball or not world:contains(ball) then continue end
		if not carrier or not world:contains(carrier) then continue end

		-- The queue is a boundary — re-validate: ball still loose, hands still empty.
		if world:target(ball, components.CARRIED_BY) then continue end
		if world:target(carrier, components.CARRIES) then continue end

		world:add(ball, pair(components.CARRIED_BY, carrier))
		world:add(ball, tags.PHYSICS_DISABLED)
		world:add(carrier, pair(components.CARRIES, ball))
	end
end

return {
	name = "GrabSystem",
	phase = pipelines.Phases.Impulse,
	system = grabSystem,
}
