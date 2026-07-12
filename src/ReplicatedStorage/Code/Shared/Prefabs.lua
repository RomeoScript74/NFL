-- Prefabs.lua -- Free functions that set up ECS components for entity types.
-- Follows FPS StandardEntities pattern: explicit composable functions, no bundle tables.
-- Only world:set() calls here — no Roblox instance manipulation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local DashCalc = require(ReplicatedStorage.Code.Shared.DashCalc)

local pair = jecs.pair

local Prefabs = {}

-- Server-side character: full base setup (stats, physics, input, netcode).
-- Called from CharacterSetup.lua after Roblox instance glue is done.
function Prefabs.Character(world, entity, rootPart, humanoid)
	-- Render
	world:set(entity, components.YAW, 0)
	world:set(entity, components.PITCH, 0)
	world:set(entity, components.INSTANCE, rootPart.Parent)
	world:set(entity, components.ROOTPART, rootPart)

	-- Physics
	world:set(entity, components.POSITION, rootPart.Position)
	world:set(entity, components.VELOCITY, Vector3.zero)
	world:set(entity, components.HIP_HEIGHT, humanoid.HipHeight)
	world:set(entity, components.WALK_SPEED, 16)
	world:set(entity, components.ACCELERATION, 2000)
	world:set(entity, components.DECELERATION, 2000)
	world:set(entity, components.GRAVITY_SCALE, 1.0)
	world:set(entity, components.COLLIDER_RADIUS, 1.5)
	world:add(entity, tags.CHARACTER)

	-- Input
	world:set(entity, components.INPUT_DIRECTION, Vector3.zero)
	world:set(entity, components.INPUT_FLAGS, 0)
	world:set(entity, components.INPUT_BUFFER, {})
	world:set(entity, components.INPUT_STATE, {
		Snap   = { pressed = false, held = false, released = false },
		Throw  = { pressed = false, held = false, released = false },
		Catch  = { pressed = false, held = false, released = false },
		Tackle = { pressed = false, held = false, released = false },
		Jump   = { pressed = false, held = false, released = false },
		Juke   = { pressed = false, held = false, released = false },
		Dive   = { pressed = false, held = false, released = false },
		Grab   = { pressed = false, held = false, released = false },
		Dash   = { pressed = false, held = false, released = false },
	})

	-- Interaction
	world:set(entity, components.INTERACTION_MANAGER, {
		active = {},
		cooldowns = {},
		combos = {},
	})

	-- HAS_INTERACTION pairs: register which actions this character can use
	world:set(entity, pair(components.HAS_INTERACTION, components.Throw),  components.Throw)
	world:set(entity, pair(components.HAS_INTERACTION, components.Tackle), components.Tackle)
	world:set(entity, pair(components.HAS_INTERACTION, components.Juke),   components.Juke)
	world:set(entity, pair(components.HAS_INTERACTION, components.Dive),   components.Dive)
	world:set(entity, pair(components.HAS_INTERACTION, components.Jump),   components.Jump)
	world:set(entity, pair(components.HAS_INTERACTION, components.Snap),   components.Snap)
	world:set(entity, pair(components.HAS_INTERACTION, components.Catch),  components.Catch)
	world:set(entity, pair(components.HAS_INTERACTION, components.Grab),   components.Grab)
	world:set(entity, pair(components.HAS_INTERACTION, components.Dash),   components.Dash)

	-- Netcode
	world:set(entity, components.STATE_HISTORY, {})
	world:set(entity, components.LAST_PROCESSED_TICK, 0)
	world:set(entity, components.CLOCK_SYNC, { Scale = 1.0 })
	world:set(entity, components.POSITION_HISTORY, {})
	world:set(entity, components.SERVER_COMBAT_STATE, {})
	world:set(entity, components.RENDER_FRAME, 0)
	world:set(entity, components.BUFFER_CONFIG, {
		TargetSize = 4,
		MaxSize = 12,
		MinSize = 2,
		StarvationFrames = 0,
		GrowthCooldown = 0,
		StabilityTimer = 0,
	})

	return entity
end

-- Client-side prediction augmentation. Runs on an entity already created by the
-- server and replicated to the owner (detected by InitLocalCharacterSystem).
-- Adds the PREDICTED tag plus the client-owned per-tick state that is NOT
-- replicated to the owner: POSITION/VELOCITY/YAW/PITCH are ignoreOwner, and
-- INPUT_DIRECTION/INPUT_FLAGS are never replicated. Movement params
-- (WALK_SPEED, HIP_HEIGHT, etc.) arrive via reliable replication.
function Prefabs.PredictedCharacter(world, entity, rootPart)
	world:add(entity, tags.PREDICTED)

	-- Physics (client-owned copies of ignoreOwner components)
	world:set(entity, components.POSITION, rootPart.Position)
	world:set(entity, components.VELOCITY, Vector3.zero)
	world:set(entity, components.YAW, 0)
	world:set(entity, components.PITCH, 0)

	-- Input (client writes these; server never sees them)
	world:set(entity, components.INPUT_DIRECTION, Vector3.zero)
	world:set(entity, components.INPUT_FLAGS, 0)

	-- Reconciliation (client-only — never replicated)
	world:set(entity, components.INPUT_HISTORY, { LastTick = 0 })
	world:set(entity, components.LAST_RECONCILED_TICK, 0)
	world:set(entity, components.VISUAL_OFFSET, Vector3.zero)
	world:set(entity, components.PREV_POSITION, rootPart.Position)

	-- Client-side interaction prediction, scoped to self-movement abilities. The server owns
	-- INTERACTION_MANAGER/INPUT_STATE/HAS_INTERACTION for every action; the client re-registers
	-- ONLY the predicted ones here so InteractionDispatchSystem ticks their chains locally.
	-- Cross-entity actions (Throw/Grab/Tackle) are intentionally absent → they stay server-only.
	world:set(entity, components.INTERACTION_MANAGER, { active = {}, cooldowns = {}, combos = {} })
	world:set(entity, components.INPUT_STATE, {
		Dash = { pressed = false, held = false, released = false },
	})
	world:set(entity, pair(components.HAS_INTERACTION, components.Dash), components.Dash)

	return entity
end

-- ═══════════════ NFL Interaction Definitions ═══════════════
-- Sets CHAIN_DEF, COOLDOWN_CONFIG, and INTERACTION_RULES on each def entity.
-- Called once at startup. Each chain is a Serial of: CooldownCondition → TriggerCooldown → PushEvent.
-- The PushEvent node pushes to EventTypes, drained by impulse systems.

function Prefabs.Interactions(world)
	-- Throw (hold to charge, release to throw the carried ball along your look direction).
	-- SelectCarried both validates "am I carrying a ball" and provides the ball as the
	-- target; if you aren't carrying, it fails the chain (no throw, no cooldown consumed).
	world:set(components.Throw, components.CHAIN_DEF, {
		Type = "Serial",
		Children = {
			{ Type = "CooldownCondition", CooldownId = "CD_PASS" },
			{ Type = "HoldToCharge", MaxTime = 1.5 },
			{ Type = "SelectCarried" },
			{ Type = "TriggerCooldown", CooldownId = "CD_PASS" },
			{ Type = "PushEvent", Queue = "Throw" },
		},
	})
	world:set(components.Throw, components.COOLDOWN_CONFIG, { Duration = 0.5 })
	world:set(components.Throw, components.INTERACTION_RULES, {
		BlockedBy = { components.Tackle },
		InterruptedBy = { components.Tackle },
	})

	-- Tackle
	world:set(components.Tackle, components.CHAIN_DEF, {
		Type = "Serial",
		Children = {
			{ Type = "CooldownCondition", CooldownId = "CD_TACKLE" },
			{ Type = "TriggerCooldown", CooldownId = "CD_TACKLE" },
			{ Type = "PushEvent", Queue = "Tackle" },
		},
	})
	world:set(components.Tackle, components.COOLDOWN_CONFIG, { Duration = 2.0 })
	world:set(components.Tackle, components.INTERACTION_RULES, {
		InterruptedBy = { components.Juke, components.Dive },
	})

	-- Juke
	world:set(components.Juke, components.CHAIN_DEF, {
		Type = "Serial",
		Children = {
			{ Type = "CooldownCondition", CooldownId = "CD_JUKE" },
			{ Type = "TriggerCooldown", CooldownId = "CD_JUKE" },
			{ Type = "PushEvent", Queue = "Juke" },
		},
	})
	world:set(components.Juke, components.COOLDOWN_CONFIG, { Duration = 1.5 })
	world:set(components.Juke, components.INTERACTION_RULES, {
		InterruptedBy = { components.Tackle },
	})

	-- Dive
	world:set(components.Dive, components.CHAIN_DEF, {
		Type = "Serial",
		Children = {
			{ Type = "CooldownCondition", CooldownId = "CD_DIVE" },
			{ Type = "TriggerCooldown", CooldownId = "CD_DIVE" },
			{ Type = "PushEvent", Queue = "Dive" },
		},
	})
	world:set(components.Dive, components.COOLDOWN_CONFIG, { Duration = 2.0 })
	world:set(components.Dive, components.INTERACTION_RULES, {
		InterruptedBy = { components.Tackle },
	})

	-- Jump
	world:set(components.Jump, components.CHAIN_DEF, {
		Type = "Serial",
		Children = {
			{ Type = "Condition", Tag = tags.IS_GROUNDED },
			{ Type = "CooldownCondition", CooldownId = "CD_JUMP" },
			{ Type = "TriggerCooldown", CooldownId = "CD_JUMP" },
			{ Type = "PushEvent", Queue = "GroundJump" },
		},
	})
	world:set(components.Jump, components.COOLDOWN_CONFIG, { Duration = 0.5 })
	world:set(components.Jump, components.INTERACTION_RULES, {})

	-- Snap (center snaps ball to QB)
	world:set(components.Snap, components.CHAIN_DEF, {
		Type = "Serial",
		Children = {
			{ Type = "PushEvent", Queue = "Snap" },
		},
	})
	world:set(components.Snap, components.COOLDOWN_CONFIG, { Duration = 1.0 })
	world:set(components.Snap, components.INTERACTION_RULES, {})

	-- Catch (receiver catches ball)
	world:set(components.Catch, components.CHAIN_DEF, {
		Type = "Serial",
		Children = {
			{ Type = "PushEvent", Queue = "Catch" },
		},
	})
	world:set(components.Catch, components.COOLDOWN_CONFIG, { Duration = 1.0 })
	world:set(components.Catch, components.INTERACTION_RULES, {})

	-- Grab (press near a loose ball to pick it up and carry it).
	-- SelectNearby finds the closest loose ball in range (it skips PHYSICS_DISABLED, so
	-- carried balls aren't grabbable); GrabSystem then attaches it to the carrier.
	world:set(components.Grab, components.CHAIN_DEF, {
		Type = "Serial",
		Children = {
			{ Type = "CooldownCondition", CooldownId = "CD_GRAB" },
			{ Type = "SelectNearby", Tag = "BALL", Range = 10, Without = "PHYSICS_DISABLED" },
			{ Type = "TriggerCooldown", CooldownId = "CD_GRAB" },
			{ Type = "PushEvent", Queue = "Grab" },
		},
	})
	world:set(components.Grab, components.COOLDOWN_CONFIG, { Duration = 0.5 })
	world:set(components.Grab, components.INTERACTION_RULES, {})

	-- Dash (predicted self-movement burst). Instant chain: Condition blocks re-fire while the
	-- burst window is active (DASHING); CooldownCondition gates on the server-authoritative
	-- pair(COOLDOWN, CD_DASH); PushEvent hands off to the shared DashImpulseSystem, which owns the
	-- burst velocity + DASH_WINDOW timer in ECS. Runs on client (prediction) and server (authority).
	world:set(components.Dash, components.CHAIN_DEF, {
		Type = "Serial",
		Children = {
			{ Type = "Condition", Tag = "DASHING", Invert = true },
			{ Type = "CooldownCondition", CooldownId = "CD_DASH" },
			{ Type = "TriggerCooldown", CooldownId = "CD_DASH" },
			{ Type = "PushEvent", Queue = "Dash" },
		},
	})
	world:set(components.Dash, components.COOLDOWN_CONFIG, { Duration = DashCalc.DASH_COOLDOWN_DURATION })
	world:set(components.Dash, components.INTERACTION_RULES, {})
end

return Prefabs
