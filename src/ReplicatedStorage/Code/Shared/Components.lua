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
	YAW = world:component(),  -- camera/aim yaw (from InputBridge) — where you're LOOKING; used by throw/carry
	FACING_YAW = world:component(),  -- body-facing yaw: derived from movement (held when stopped) by FacingSystem — where you're GOING. Dash/tackle launch along this (their standstill fallback), NOT the camera. Deterministic (from velocity, both realms), so no replication needed
	PITCH = world:component(),
	ANIMATION_TRACKS = world:component(),  -- client-only: { tracks = {name -> AnimationTrack}, current = stateName }; loaded from the model's Animator, never replicated (Instances → pitfall #2), resolved locally like ROOTPART

	-- Physics
	POSITION = world:component(),
	VELOCITY = world:component(),
	HIP_HEIGHT = world:component(),
	WALK_SPEED = world:component(),
	ACCELERATION = world:component(),
	DECELERATION = world:component(),
	GRAVITY_SCALE = world:component(),
	FLOOR_NORMAL = world:component(),
	COLLIDER_RADIUS = world:component(),  -- character cylinder radius (studs) for character-vs-character collision
	WIND = world:component(),  -- singleton: global wind acceleration (Vector3, studs/s^2)
	BOUNCINESS = world:component(),  -- per-entity restitution 0..1 (fraction of vertical speed kept per bounce)
	DASH_WINDOW = world:component(),  -- target for pair(TIMER, DASH_WINDOW): the dash burst timer (ticks remaining), ticked by TimerSystem; DASHING lives while it exists
	TACKLE_WINDOW = world:component(),  -- target for pair(TIMER, TACKLE_WINDOW): the tackler's forward-launch coast timer; TACKLING lives while it exists
	THROW_WINDOW = world:component(),  -- target for pair(TIMER, THROW_WINDOW): the throw-motion anim window; THROWING lives while it exists (length = Throw chain's PushEvent Payload.windowTicks, robust to interrupt)
	STUN_WINDOW = world:component(),  -- target for pair(TIMER, STUN_WINDOW): stun duration (ticks remaining); STUNNED lives while it exists

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
	SERVER_DASH_CD = world:component(),  -- authoritative CD_DASH remaining at SERVER_TICK; reconciliation restores the PREDICTED pair(COOLDOWN, CD_DASH) to this before replay
	SERVER_DASH_WINDOW = world:component(),  -- authoritative DASH_WINDOW remaining at SERVER_TICK; reconciliation restores DASH_WINDOW to this before replay
	SERVER_TACKLE_CD = world:component(),  -- authoritative CD_TACKLE remaining at SERVER_TICK; reconciliation restores the PREDICTED pair(COOLDOWN, CD_TACKLE) before replay
	SERVER_TACKLE_WINDOW = world:component(),  -- authoritative TACKLE_WINDOW remaining at SERVER_TICK; reconciliation restores the predicted launch coast (TACKLING + TACKLE_WINDOW) before replay
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
	VISUAL_VELOCITY = world:component(),  -- client-only: velocity low-passed for the visual layer (anim speed + body facing), so reconciliation's raw velocity snaps don't stutter them. The velocity analog of VISUAL_OFFSET; owned by VisualVelocitySystem, never replicated
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
	CD_GRAB   = world:component(),
	CD_DASH   = world:component(),

	-- NFL Definition Entities (pair targets for HAS_INTERACTION)
	Throw  = world:entity(),
	Tackle = world:entity(),
	Juke   = world:entity(),
	Dive   = world:entity(),
	Jump   = world:entity(),
	Snap   = world:entity(),
	Catch  = world:entity(),
	Grab   = world:entity(),
	Dash   = world:entity(),

	-- Carry state
	CARRIES = world:component(),  -- relation on carrier → the ball it holds: pair(CARRIES, ball). Replicated (replecs.relation, auto-remapped like CARRIED_BY/OwnedBy) so the predicted client sees who's carrying and gates on it (e.g. can't tackle while carrying). Reverse of the ball's CARRIED_BY.

	-- Relationships (pairs)
	OwnedBy = world:component(),
	CARRIED_BY = world:component(),  -- pair(CARRIED_BY, carrier) on the ball → who holds it
}

-- Mark every component as replecs.shared with a name so Replecs resolves
-- component and pair-target IDs to the same local entity on server and client.
for name, component in pairs(Components) do
	world:add(component, replecs.shared)
	world:set(component, jecs.Name, name)
end

return Components
