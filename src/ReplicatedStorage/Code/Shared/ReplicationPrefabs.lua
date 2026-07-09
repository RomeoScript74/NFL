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
	world:add(entity, pair(replecs.reliable, components.SERVER_COMBAT_STATE))
	world:add(entity, pair(replecs.reliable, tags.IS_NPC))

	-- Snapshot model: POSITION/VELOCITY are NEVER replicated — they are always
	-- local (predicted on owner, computed from SERVER_* on remotes). Only the
	-- authoritative SERVER_* channel is on the wire. YAW/PITCH still replicate
	-- to remotes for rotation rendering.
	local ownerFilter = { [owner] = false }
	world:set(entity, pair(replecs.unreliable, components.YAW),   ownerFilter)
	world:set(entity, pair(replecs.unreliable, components.PITCH), ownerFilter)

	-- Relationships
	world:add(entity, pair(replecs.relation, components.OwnedBy))
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
end

return ReplicationPrefabs
