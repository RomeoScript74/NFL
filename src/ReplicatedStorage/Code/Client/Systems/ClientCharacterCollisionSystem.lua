-- ClientCharacterCollisionSystem.lua — Client-side collision prediction. Pushes ONLY the local
-- predicted player fully out of the other players (the client can only move its own player, so it
-- takes the full separation — that's what keeps it from sinking into them). Runs in PostCollision
-- → replays during reconciliation, so the local player never phases through.
--
-- Brace: a braced player is immovable only while PLANTED (no move input) — the defensive anchor.
-- While WALKING it collides normally, so it stays solid and can't phase through anyone.
--
-- After pushing out, the velocity component driving the player into the wall is removed (mirrors the
-- server) so predicted velocity matches SERVER_VELOCITY and reconciliation stays clean.
--
-- Remote characters are interpolated: their rendered position lives on the ROOTPART, so obstacle
-- positions come from rootPart.Position — what the player sees, so contact looks correct. The cost:
-- continuous collision against a moving remote can't be perfectly reconcile-free (client uses the
-- rendered/past position, the server the true one). Ambient bump-collision is left soft and
-- forgiving; the contact that decides plays (blocks/tackles) is a discrete lag-compensated
-- interaction, not this layer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local PhysicsCalc = require(ReplicatedStorage.Code.Shared.PhysicsCalc)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

-- CHARACTER is the explicit collision filter; COLLIDER_RADIUS is read for the cylinder size.
-- Unbraced, non-diving local player: always pushes itself fully out (the sink-proof baseline).
local unbracedQuery = world:query(components.POSITION, components.VELOCITY, components.COLLIDER_RADIUS):with(tags.CHARACTER, tags.PREDICTED):without(tags.BRACED, tags.TACKLING):cached()
-- Diving local player: pushes out ONLY against braced obstacles (brace is a deliberate wall — it
-- should still stop a dive). Non-braced obstacles are exempt: the dive's outcome is decided by
-- TackleSweep (server), not this ambient push, so this system must not fight it — a fast lunge
-- overlapping the runner's rendered position and stopping here (while the sweep independently
-- misses, favor-the-runner) is exactly what causes the "I hit him" reconciliation snap.
local tacklingQuery = world:query(components.POSITION, components.VELOCITY, components.COLLIDER_RADIUS):with(tags.CHARACTER, tags.PREDICTED, tags.TACKLING):cached()
-- Braced local player: only pushes out while walking (INPUT_DIRECTION carries the move intent).
local bracedQuery = world:query(components.POSITION, components.VELOCITY, components.COLLIDER_RADIUS, components.INPUT_DIRECTION):with(tags.CHARACTER, tags.PREDICTED, tags.BRACED):cached()
-- Remote characters: CHARACTER-tagged, minus the local predicted player. Collide against the
-- rendered rootPart position — what the player sees.
local obstacleQuery = world:query(components.ROOTPART, components.COLLIDER_RADIUS):with(tags.CHARACTER):without(tags.PREDICTED):cached()
-- Braced obstacles: pushOut filters to "walls only" for a dive via :has() (O(1), always live off the
-- entity's current archetype) — no need to gather a parallel set.
local bracedObstacleQuery = world:query():with(tags.CHARACTER, tags.BRACED):without(tags.PREDICTED):cached()

-- Push-out of the local player against obstacles (all of them, or braced-only during a dive), then
-- cancel velocity into the wall.
local function pushOut(entity: number, pos: Vector3, vel: Vector3, radius: number, onlyBraced: boolean)
	local push = Vector3.zero
	for obstacle, rootPart, otherRadius in obstacleQuery do
		if onlyBraced and not bracedObstacleQuery:has(obstacle) then continue end
		push = push + PhysicsCalc.separation(pos, radius, rootPart.Position, otherRadius)
	end
	if push ~= Vector3.zero then
		world:set(entity, components.POSITION, pos + push)

		local n = push.Unit
		local intoWall = vel:Dot(n)
		if intoWall < 0 then
			world:set(entity, components.VELOCITY, vel - n * intoWall)
		end
	end
end

local function clientCharacterCollisionSystem()
	for entity, pos, vel, radius in unbracedQuery do
		pushOut(entity, pos, vel, radius, false)
	end

	for entity, pos, vel, radius in tacklingQuery do
		pushOut(entity, pos, vel, radius, true)
	end

	-- Braced: immovable while planted (skip → matches the server keeping it still), solid while
	-- walking (push out → can't phase through). The plow of the other player is server-authoritative.
	for entity, pos, vel, radius, dir in bracedQuery do
		if dir.Magnitude > 0 then
			pushOut(entity, pos, vel, radius, false)
		end
	end
end

return {
	name = "ClientCharacterCollisionSystem",
	phase = pipelines.Phases.PostCollision,
	system = clientCharacterCollisionSystem,
}
