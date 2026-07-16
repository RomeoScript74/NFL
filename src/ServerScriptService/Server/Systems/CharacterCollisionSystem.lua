-- CharacterCollisionSystem.lua — Server-authoritative character-vs-character collision. Models
-- each character as a vertical cylinder (COLLIDER_RADIUS) and separates overlapping pairs, split by
-- inverse-mass. Runs in PostCollision (after floor collision has settled Y this tick), N² over all
-- characters. A braced character (BraceStateSystem owns BRACED) is immovable (weight 0) — its
-- partner takes the whole push; two braced split evenly to stay solid.
--
-- After pushing a character out, we also kill its velocity component INTO the obstacle. Otherwise a
-- blocked character's position sits still while its (replicated) velocity still points into the
-- wall, and observers' Hermite interpolation bulges it forward and back — a visible vibration.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local PhysicsCalc = require(ReplicatedStorage.Code.Shared.PhysicsCalc)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

-- CHARACTER tag is the explicit collision filter; COLLIDER_RADIUS is read for the cylinder size.
local collisionQuery = world:query(components.POSITION, components.VELOCITY, components.COLLIDER_RADIUS):with(tags.CHARACTER):cached()
-- Braced characters are immovable (weight 0). Cached queries answer membership directly via :has()
-- (O(1), always live off the entity's current archetype) — no need to gather a parallel set.
local bracedQuery = world:query():with(tags.CHARACTER, tags.BRACED):cached()
-- Diving tacklers: their dive is resolved by TackleSweep (the decisive layer), not this ambient
-- push-apart — :has() lets the N² loop exempt tackler-vs-non-braced pairs directly.
local tacklingQuery = world:query():with(tags.CHARACTER, tags.TACKLING):cached()

-- Reused across ticks so a steady state allocates nothing.
local entities = {}
local positions = {}
local velocities = {}
local radii = {}
local weights = {}  -- inverse-mass: 1 = movable, 0 = braced (immovable)
local pushes = {}

local function characterCollisionSystem()
	local count = 0
	for entity, pos, vel, radius in collisionQuery do
		count += 1
		entities[count] = entity
		positions[count] = pos
		velocities[count] = vel
		radii[count] = radius
		weights[count] = bracedQuery:has(entity) and 0 or 1
		pushes[count] = Vector3.zero
	end

	-- N² pairs split the separation by inverse-mass — two movable go half each; a braced one stays
	-- put and its partner takes the whole push; two braced (total 0) split evenly to stay solid.
	for i = 1, count - 1 do
		for j = i + 1, count do
			-- A diving tackler phases through everyone except a braced target (brace is a deliberate
			-- wall — it should still stop a dive on contact). Otherwise this ambient push would fight
			-- TackleSweep's resolve: a fast lunge overlaps the runner's rendered position and stops
			-- here, while the sweep independently misses (favor-the-runner) — two different answers,
			-- the server wins, and the tackler reconciles backward.
			local iDiving = tacklingQuery:has(entities[i]) and not bracedQuery:has(entities[j])
			local jDiving = tacklingQuery:has(entities[j]) and not bracedQuery:has(entities[i])
			if iDiving or jDiving then continue end

			local sep = PhysicsCalc.separation(positions[i], radii[i], positions[j], radii[j])
			if sep ~= Vector3.zero then
				local wi, wj = weights[i], weights[j]
				local total = wi + wj
				local fi, fj
				if total > 0 then
					fi, fj = wi / total, wj / total
				else
					fi, fj = 0.5, 0.5
				end
				pushes[i] = pushes[i] + sep * fi
				pushes[j] = pushes[j] - sep * fj
			end
		end
	end

	for i = 1, count do
		local push = pushes[i]
		if push ~= Vector3.zero then
			world:set(entities[i], components.POSITION, positions[i] + push)

			-- Remove the velocity component pushing this character back into what it was ejected
			-- from, so its replicated velocity doesn't point into the wall (no interp vibration).
			local n = push.Unit
			local vel = velocities[i]
			local intoWall = vel:Dot(n)
			if intoWall < 0 then
				world:set(entities[i], components.VELOCITY, vel - n * intoWall)
			end
		end
	end
end

return {
	name = "CharacterCollisionSystem",
	phase = pipelines.Phases.PostCollision,
	system = characterCollisionSystem,
}
