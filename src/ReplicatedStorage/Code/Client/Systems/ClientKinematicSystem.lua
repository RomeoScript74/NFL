-- ClientKinematicSystem.lua — Client-side position integration prediction.
-- Mirrors server KinematicSystem but filters to PREDICTED entities only.
-- Integrates velocity into position (pos += vel * dt) in the Integration phase,
-- after Movement/Gravity have computed velocity and before Collision resolves it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local query = world:query(
	components.POSITION,
	components.VELOCITY
):with(tags.PREDICTED):cached()

local FIXED_DT = 1 / 60

local function clientKinematicSystem()
	for entity, pos, vel in query do
		if vel.Magnitude > 0 then
			world:set(entity, components.POSITION, pos + (vel * FIXED_DT))
		end
	end
end

return {
	name = "ClientKinematicSystem",
	phase = pipelines.Phases.Integration,
	system = clientKinematicSystem,
}
