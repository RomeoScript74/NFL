-- ReplicationPrefabs.lua — Replecs replication setup per entity type.
-- Explicit functions per type: no loops, no type-filter tables.
-- Channel semantics:
--   reliable   → delivered in order, 20Hz, sent to all including owner
--   unreliable → best-effort, 30Hz, ignoreOwner = sent to everyone EXCEPT owner

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local replecs = require(ReplicatedStorage.Packages.replecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local jecs = require(ReplicatedStorage.Packages.jecs)

local pair = jecs.pair

local ReplicationPrefabs = {}

-- Character entity: player-controlled character with physics + netcode.
function ReplicationPrefabs.applyCharacter(world, entity, owner: Player)
	world:add(entity, replecs.networked)

	-- Reliable: sent to owner and all observers (gameplay params, authority state)
	world:add(entity, pair(replecs.reliable, components.SERVER_TICK))
	world:add(entity, pair(replecs.reliable, components.SERVER_POSITION))
	world:add(entity, pair(replecs.reliable, components.SERVER_VELOCITY))
	-- Reconciliation anchors: SERVER_DASH_CD restores the PREDICTED cooldown, SERVER_DASH_WINDOW
	-- restores the PREDICTED burst — both re-applied before the replay loop. The cooldown pair
	-- itself is NOT replicated: it's client-predicted, and replicating it would overwrite the
	-- prediction with the server value (which can't carry a sub-tick cooldown clear).
	world:add(entity, pair(replecs.reliable, components.SERVER_DASH_CD))
	world:add(entity, pair(replecs.reliable, components.SERVER_DASH_WINDOW))
	-- Tackle anchors: same pattern as dash — SERVER_TACKLE_CD restores the predicted cooldown,
	-- SERVER_TACKLE_WINDOW restores the predicted launch coast (TACKLING + TACKLE_WINDOW) on replay.
	world:add(entity, pair(replecs.reliable, components.SERVER_TACKLE_CD))
	world:add(entity, pair(replecs.reliable, components.SERVER_TACKLE_WINDOW))
	-- Hurdle anchors: same pattern — SERVER_HURDLE_CD restores the predicted cooldown, SERVER_HURDLE_WINDOW
	-- restores the predicted vault window (HURDLING + HURDLE_WINDOW) on replay AND is the remote anim source
	-- (>0 = mid-hurdle), since the predicted HURDLING tag itself can't be replicated.
	world:add(entity, pair(replecs.reliable, components.SERVER_HURDLE_CD))
	world:add(entity, pair(replecs.reliable, components.SERVER_HURDLE_WINDOW))
	world:add(entity, pair(replecs.reliable, components.REMOTE_TICK))
	-- ROOTPART is a raw Roblox Instance — replicating it causes "received
	-- instance is nil!" on slow/rejoining clients when the instance hasn't
	-- streamed into Workspace yet. Resolved locally by ClientInstanceLinkSystem.
	world:add(entity, pair(replecs.reliable, components.CLOCK_SYNC))
	world:add(entity, pair(replecs.reliable, components.HIP_HEIGHT))
	world:add(entity, pair(replecs.reliable, components.WALK_SPEED))
	world:add(entity, pair(replecs.reliable, components.ACCELERATION))
	world:add(entity, pair(replecs.reliable, components.DECELERATION))
	world:add(entity, pair(replecs.reliable, components.GRAVITY_SCALE))
	-- COLLIDER_RADIUS: per-character, needed on the client so predicted collision (and remote
	-- obstacle checks) know each character's cylinder size.
	world:add(entity, pair(replecs.reliable, components.COLLIDER_RADIUS))
	world:add(entity, pair(replecs.reliable, components.SERVER_COMBAT_STATE))
	world:add(entity, pair(replecs.reliable, tags.IS_NPC))
	-- CHARACTER: replicated so remote characters carry the collision filter on the client
	-- (obstacle query filters on it instead of relying on COLLIDER_RADIUS presence).
	world:add(entity, pair(replecs.reliable, tags.CHARACTER))
	-- STUNNED: server-authoritative tackle outcome. Replicated so remotes render the stun and the
	-- owner's prediction stops driving movement while frozen (otherwise a 1s stun reconciles for 1s).
	world:add(entity, pair(replecs.reliable, tags.STUNNED))
	-- THROWING: server-only action (the owner doesn't predict throw), so unlike TACKLING it replicates
	-- to EVERYONE including the owner — that's how the thrower sees their own throw anim. No owner filter.
	world:add(entity, pair(replecs.reliable, tags.THROWING))
	-- WHIFFED: animation marker on a whiffed tackler (rides with STUNNED). Replicated so remotes play
	-- the stumble clip instead of the got-tackled fall.
	world:add(entity, pair(replecs.reliable, tags.WHIFFED))

	-- Snapshot model: POSITION/VELOCITY are NEVER replicated — they are always
	-- local (predicted on owner, computed from SERVER_* on remotes). Only the
	-- authoritative SERVER_* channel is on the wire. YAW/PITCH still replicate
	-- to remotes for rotation rendering.
	local ownerFilter = { [owner] = false }
	world:set(entity, pair(replecs.unreliable, components.YAW),   ownerFilter)
	world:set(entity, pair(replecs.unreliable, components.PITCH), ownerFilter)
	-- TACKLING is deliberately NOT replicated: the tackler predicts it, and replicating it (even
	-- owner-filtered) makes replecs manage/strip the predicted tag on the owner. Remotes get the dive
	-- from the already-replicated SERVER_TACKLE_WINDOW (>0 = mid-tackle) instead — see
	-- InteractionAnimationSystem.

	-- Relationships
	world:add(entity, pair(replecs.relation, components.OwnedBy))
	-- CARRIES (carrier → held ball): server-authoritative, replicated so the predicted client sees who's
	-- carrying and gates on it (can't tackle while carrying). Not predicted → replecs won't fight it.
	world:add(entity, pair(replecs.relation, components.CARRIES))
end

-- Item entity: ball, interactable object — no owner, position replicated to all.
function ReplicationPrefabs.applyItem(world, entity)
	world:add(entity, replecs.networked)

	world:set(entity, pair(replecs.unreliable, components.POSITION), {})
	world:set(entity, pair(replecs.unreliable, components.VELOCITY), {})

	world:add(entity, pair(replecs.relation, components.OwnedBy))
end

-- Ball entity: server-authoritative, no owner. Replicated to everyone via the
-- SERVER_* channel so clients render it through RemoteVisualInterpolator with no
-- prediction — identical netcode path to remote characters, minus the owner filter.
function ReplicationPrefabs.applyBall(world, entity)
	world:add(entity, replecs.networked)

	world:add(entity, pair(replecs.reliable, components.SERVER_TICK))
	world:add(entity, pair(replecs.reliable, components.SERVER_POSITION))
	world:add(entity, pair(replecs.reliable, components.SERVER_VELOCITY))
	world:add(entity, pair(replecs.reliable, components.REMOTE_TICK))
	world:add(entity, pair(replecs.reliable, tags.BALL))

	-- Carry state: PHYSICS_DISABLED tells the client to attach (not interpolate) the ball,
	-- and CARRIED_BY (a relation) tells it whose hand to attach it to.
	world:add(entity, pair(replecs.reliable, tags.PHYSICS_DISABLED))
	world:add(entity, pair(replecs.relation, components.CARRIED_BY))
end

return ReplicationPrefabs
