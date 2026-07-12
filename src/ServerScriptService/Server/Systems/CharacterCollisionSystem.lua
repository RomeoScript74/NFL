-- CharacterCollisionSystem.lua — Server-authoritative character-vs-character collision. Models
-- each character as a vertical cylinder (COLLIDER_RADIUS) and symmetrically pushes overlapping
-- pairs apart (half each). Runs in PostCollision (after floor collision has settled Y this tick),
-- N² over all characters.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local PhysicsCalc = require(ReplicatedStorage.Code.Shared.PhysicsCalc)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

-- CHARACTER tag is the explicit collision filter; COLLIDER_RADIUS is read for the cylinder size.
local collisionQuery = world:query(components.POSITION, components.COLLIDER_RADIUS):with(tags.CHARACTER):cached()

-- Reused across ticks so a steady state allocates nothing.
local entities = {}
local positions = {}
local radii = {}
local pushes = {}

local function characterCollisionSystem()
	local count = 0
	for entity, pos, radius in collisionQuery do
		count += 1
		entities[count] = entity
		positions[count] = pos
		radii[count] = radius
		pushes[count] = Vector3.zero
	end

	-- N² pairs: each character in an overlapping pair moves half the penetration.
	for i = 1, count - 1 do
		for j = i + 1, count do
			local sep = PhysicsCalc.separation(positions[i], radii[i], positions[j], radii[j])
			if sep ~= Vector3.zero then
				pushes[i] = pushes[i] + sep * 0.5
				pushes[j] = pushes[j] - sep * 0.5
			end
		end
	end

	for i = 1, count do
		if pushes[i] ~= Vector3.zero then
			world:set(entities[i], components.POSITION, positions[i] + pushes[i])
		end
	end
end

return {
	name = "CharacterCollisionSystem",
	phase = pipelines.Phases.PostCollision,
	system = characterCollisionSystem,
}
