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
local unbracedQuery = world:query(components.POSITION, components.VELOCITY, components.COLLIDER_RADIUS):with(tags.CHARACTER, tags.PREDICTED):without(tags.BRACED, tags.TACKLING, tags.HURDLING):cached()
-- Diving local player: pushes out ONLY against braced obstacles (brace is a deliberate wall — it
-- should still stop a dive). Non-braced obstacles are exempt: the dive's outcome is decided by
-- TackleSweep (server), not this ambient push, so this system must not fight it — a fast lunge
-- overlapping the runner's rendered position and stopping here (while the sweep independently
-- misses, favor-the-runner) is exactly what causes the "I hit him" reconciliation snap.
local tacklingQuery = world:query(components.POSITION, components.VELOCITY, components.COLLIDER_RADIUS):with(tags.CHARACTER, tags.PREDICTED, tags.TACKLING):cached()
-- Hurdling local player: same as a dive — phases through non-braced characters (it's airborne, vaulting
-- OVER them) so the vault carries it past instead of bumping to a stop; still stopped by a braced wall.
local hurdlingQuery = world:query(components.POSITION, components.VELOCITY, components.COLLIDER_RADIUS):with(tags.CHARACTER, tags.PREDICTED, tags.HURDLING):cached()
-- Braced local player: only pushes out while walking (INPUT_DIRECTION carries the move intent).
local bracedQuery = world:query(components.POSITION, components.VELOCITY, components.COLLIDER_RADIUS, components.INPUT_DIRECTION):with(tags.CHARACTER, tags.PREDICTED, tags.BRACED):cached()
-- Remote characters: CHARACTER-tagged, minus the local predicted player. Collide against the
-- rendered rootPart position — what the player sees.
local obstacleQuery = world:query(components.ROOTPART, components.COLLIDER_RADIUS):with(tags.CHARACTER):without(tags.PREDICTED):cached()
-- Braced obstacles: pushOut filters to "walls only" for a dive via :has() (O(1), always live off the
-- entity's current archetype) — no need to gather a parallel set.
local bracedObstacleQuery = world:query():with(tags.CHARACTER, tags.BRACED):without(tags.PREDICTED):cached()

-- A remote obstacle mid-dive/vault phases through everyone (its own realm exempts it), so we must NOT
-- collide the local player against it — the SERVER exempts the whole pair, so pushing out here would
-- just get reconciled backward. TACKLING/HURDLING aren't replicated (predicted, self-only), so read the
-- replicated ">0 = in progress" windows instead.
local function isDiving(obstacle: number): boolean
	local tackleWindow = world:get(obstacle, components.SERVER_TACKLE_WINDOW)
	if tackleWindow and tackleWindow > 0 then
		return true
	end
	local hurdleWindow = world:get(obstacle, components.SERVER_HURDLE_WINDOW)
	return hurdleWindow ~= nil and hurdleWindow > 0
end

-- Push-out of the local player against obstacles (all of them, or braced-only during a dive), then
-- cancel velocity into the wall. skipDivers = ignore obstacles mid-dive/vault (they phase through you,
-- and the server agrees — only a BRACED local player stops a diver, so it passes skipDivers=false).
local function pushOut(entity: number, pos: Vector3, vel: Vector3, radius: number, onlyBraced: boolean, skipDivers: boolean)
	local push = Vector3.zero
	for obstacle, rootPart, otherRadius in obstacleQuery do
		if onlyBraced and not bracedObstacleQuery:has(obstacle) then continue end
		if skipDivers and isDiving(obstacle) then continue end
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
	-- Normal (unbraced) player: push out of everyone EXCEPT a diver/vaulter — that attacker phases
	-- through you and the server exempts the pair, so colliding here is the "little movement then
	-- reconcile" snap when you get tackled. skipDivers=true fixes it.
	for entity, pos, vel, radius in unbracedQuery do
		pushOut(entity, pos, vel, radius, false, true)
	end

	for entity, pos, vel, radius in tacklingQuery do
		pushOut(entity, pos, vel, radius, true, false)
	end

	-- Hurdling player phases the same way as a dive (braced-only push-out) — airborne over the tackler.
	for entity, pos, vel, radius in hurdlingQuery do
		pushOut(entity, pos, vel, radius, true, false)
	end

	-- Braced: immovable while planted (skip → matches the server keeping it still), solid while
	-- walking (push out → can't phase through). A braced target is the one thing that STOPS a diver, so
	-- it does NOT skip them (skipDivers=false). The plow of the other player is server-authoritative.
	for entity, pos, vel, radius, dir in bracedQuery do
		if dir.Magnitude > 0 then
			pushOut(entity, pos, vel, radius, false, false)
		end
	end
end

return {
	name = "ClientCharacterCollisionSystem",
	phase = pipelines.Phases.PostCollision,
	system = clientCharacterCollisionSystem,
}
