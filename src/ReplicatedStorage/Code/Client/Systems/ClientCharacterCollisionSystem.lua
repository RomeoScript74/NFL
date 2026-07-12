-- ClientCharacterCollisionSystem.lua — Client-side collision prediction. Pushes ONLY the local
-- predicted player fully out of the other players (the client can only move its own player, so it
-- takes the full separation — that's what keeps it from sinking into them). Runs in PostCollision
-- → replays during reconciliation, so the local player never phases through.
--
-- Remote characters are interpolated: their rendered position lives on the ROOTPART (POSITION is
-- never replicated), so obstacle positions come from rootPart.Position — what the player sees.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local PhysicsCalc = require(ReplicatedStorage.Code.Shared.PhysicsCalc)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

-- CHARACTER is the explicit collision filter; COLLIDER_RADIUS is read for the cylinder size.
local predictedQuery = world:query(components.POSITION, components.COLLIDER_RADIUS):with(tags.CHARACTER, tags.PREDICTED):cached()
-- Remote characters: CHARACTER-tagged, minus the local predicted player.
local obstacleQuery = world:query(components.ROOTPART, components.COLLIDER_RADIUS):with(tags.CHARACTER):without(tags.PREDICTED):cached()

local function clientCharacterCollisionSystem()
	for entity, pos, radius in predictedQuery do
		local push = Vector3.zero
		for _, rootPart, otherRadius in obstacleQuery do
			push = push + PhysicsCalc.separation(pos, radius, rootPart.Position, otherRadius)
		end
		if push ~= Vector3.zero then
			world:set(entity, components.POSITION, pos + push)
		end
	end
end

return {
	name = "ClientCharacterCollisionSystem",
	phase = pipelines.Phases.PostCollision,
	system = clientCharacterCollisionSystem,
}
