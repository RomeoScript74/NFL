-- WindSystem.lua — Applies the global WIND acceleration to wind-affected entities.
-- WIND is a singleton (Vector3, studs/s^2, runtime-tunable); WIND_AFFECTED tags the
-- entities the wind pushes (currently the ball). Runs in the Gravity phase — wind is
-- just another environmental acceleration on VELOCITY, integrated the same tick.
--
-- Deliberately does NOT filter on grounded state: wind pushes airborne balls (curving
-- the arc) and grounded ones alike. On the ground BallFrictionSystem resists it, so a
-- gentle wind barely moves a resting ball while a strong one drags it — "ground push"
-- is a matter of tuning WIND, not a capability that was excluded here.
-- Server-only: the ball is server-authoritative.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local FIXED_DT = 1 / 60

local windQuery = world:query(
	components.VELOCITY
):with(tags.WIND_AFFECTED):cached()

local function windSystem()
	local wind = world:get(components.WIND, components.WIND)
	if not wind or wind == Vector3.zero then return end

	local delta = wind * FIXED_DT
	for entity, vel in windQuery do
		world:set(entity, components.VELOCITY, vel + delta)
	end
end

return {
	name = "WindSystem",
	phase = pipelines.Phases.Gravity,
	system = windSystem,
}
