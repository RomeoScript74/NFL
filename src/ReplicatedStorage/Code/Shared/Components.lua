local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local replecs = require(ReplicatedStorage.Packages.replecs)
local world = require(ReplicatedStorage.Code.Shared.World)

local Components = {
	-- Input
	INPUT_FLAGS = world:component(),
	INPUT_DIRECTION = world:component(),
	INPUT_BUFFER = world:component(),
	INPUT_STATE = world:component(),

	-- Render / Instance refs
	INSTANCE = world:component(),
	ROOTPART = world:component(),
	YAW = world:component(),
	PITCH = world:component(),

	-- Physics
	POSITION = world:component(),
	VELOCITY = world:component(),
	HIP_HEIGHT = world:component(),
	WALK_SPEED = world:component(),
	ACCELERATION = world:component(),
	DECELERATION = world:component(),
	GRAVITY_SCALE = world:component(),
	FLOOR_NORMAL = world:component(),

	-- Player identity
	PLAYER = world:component(),

	-- Interaction
	INTERACTION_MANAGER = world:component(),

	-- Interaction Chain System (Hytale-style BT execution)
	CHAIN_DEF         = world:component(),  -- table: root node on definition entities
	INTERACTIONS      = world:component(),  -- table: type -> def cache on character
	HAS_INTERACTION   = world:component(),  -- pair(HAS_INTERACTION, iType) = defEntity
	COOLDOWN_CONFIG   = world:component(),  -- { Duration, Charges, ChargeDuration }
	INTERACTION_RULES = world:component(),  -- { BlockedBy, Blocks, Interrupts, InterruptedBy, ...Bypass strings }
	ASSET_TAGS        = world:component(),  -- { "tag1", "tag2", ... } -- bypass tags
	COMBO_CONFIG      = world:component(),  -- { Steps, WindowTime }
	INTERACTION_VARS  = world:component(),  -- { VarName = chainTemplate } for Replace node
	SELECTOR          = world:component(),  -- "Raycast" / "AOE" / "Melee"

	-- Timers & Cooldowns (pair-based, ticked by TimerSystem / CooldownSystem)
	TIMER = world:component(),
	COOLDOWN = world:component(),

	-- Networking (server → client reliable)
	SERVER_TICK = world:component(),
	SERVER_POSITION = world:component(),
	SERVER_VELOCITY = world:component(),
	CLOCK_SYNC = world:component(),

	-- Networking (server → client unreliable)
	REMOTE_TICK = world:component(),

	-- Reconciliation
	INPUT_HISTORY = world:component(),
	STATE_HISTORY = world:component(),
	LAST_PROCESSED_TICK = world:component(),
	LAST_RECONCILED_TICK = world:component(),
	POSITION_HISTORY = world:component(),
	VISUAL_OFFSET = world:component(),
	PREV_POSITION = world:component(),
	RENDER_FRAME = world:component(),
	BUFFER_CONFIG = world:component(),
	IS_REPLAYING = world:component(),

	-- Interpolation (remote entities)
	SNAPSHOT_BUFFER = world:component(),
	INTERPOLATION_CLOCK = world:component(),
	INTERP_DRIFT = world:component(),
	INTERP_LAST_CLOCK = world:component(),

	-- Combat state snapshot (server-authoritative, replicated for reconciliation)
	SERVER_COMBAT_STATE = world:component(),

	-- Cooldown pair targets (pair(COOLDOWN, CD_*))
	CD_PASS   = world:component(),
	CD_TACKLE = world:component(),
	CD_JUKE   = world:component(),
	CD_DIVE   = world:component(),
	CD_JUMP   = world:component(),

	-- NFL Definition Entities (pair targets for HAS_INTERACTION)
	Throw  = world:entity(),
	Tackle = world:entity(),
	Juke   = world:entity(),
	Dive   = world:entity(),
	Jump   = world:entity(),
	Snap   = world:entity(),
	Sprint = world:entity(),
	Catch  = world:entity(),

	-- Relationships (pairs)
	OwnedBy = world:component(),
}

-- Mark every component as replecs.shared with a name so Replecs resolves
-- component and pair-target IDs to the same local entity on server and client.
for name, component in pairs(Components) do
	world:add(component, replecs.shared)
	world:set(component, jecs.Name, name)
end

return Components
