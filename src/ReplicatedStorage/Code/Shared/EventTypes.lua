-- EventQueues.lua -- Typed event channels bridging interaction layer to ECS.
-- Interactions push plain data entries; impulse/action systems drain and apply.
-- This avoids archetype moves for one-shot events.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventQueue = require(ReplicatedStorage.Code.Shared.Utilities.EventQueue)

local EventQueues = {
	-- Snap (QB receives ball): SnapInteraction -> SnapSystem
	Snap = EventQueue.new(128),

	-- Throw: ThrowInteraction (PushEvent) -> ThrowSystem (opens the THROWING window)
	Throw = EventQueue.new(128),

	-- LaunchBall: Throw chain's PushEvent (after the Wait) -> ThrowSystem (detaches + launches the ball)
	LaunchBall = EventQueue.new(128),

	-- Catch: CatchInteraction -> CatchSystem
	Catch = EventQueue.new(128),

	-- Tackle: TackleInteraction -> TackleLaunchSystem
	Tackle = EventQueue.new(128),

	-- Stun: any stun source (TackleSystem today; blocks/trips/abilities later) -> StunSystem
	Stun = EventQueue.new(128),

	-- Fumble: any ball-loose cause (TackleSystem today; strips/big hits later) -> FumbleSystem
	Fumble = EventQueue.new(128),

	-- Interrupt: any cause that should cancel a target's in-progress interaction (TackleSweep on a
	-- landed hit today) -> InterruptSystem. Deliberately separate from Stun — being stunned and
	-- having your action cancelled are independent consequences (mirrors Hytale's InterruptInteraction
	-- being its own node, not an automatic side effect of a stun/status system).
	Interrupt = EventQueue.new(128),

	-- Juke: JukeInteraction -> JukeSystem
	Juke = EventQueue.new(128),

	-- Dive: DiveInteraction -> DiveSystem
	Dive = EventQueue.new(128),

	-- Grab: Grab interaction (SelectNearby -> PushEvent) -> GrabSystem
	Grab = EventQueue.new(128),

	-- Dash: Dash interaction (Condition -> CooldownCondition -> PushEvent) -> DashImpulseSystem (shared, predicted)
	Dash = EventQueue.new(128),

	-- Hurdle: Hurdle interaction (predicted vertical launch) -> HurdleLaunchSystem (shared, predicted)
	Hurdle = EventQueue.new(128),

	-- StartCooldown: TriggerCooldown node -> CooldownStartSystem (applies pair(COOLDOWN, *) server-side)
	StartCooldown = EventQueue.new(128),
}

return EventQueues
