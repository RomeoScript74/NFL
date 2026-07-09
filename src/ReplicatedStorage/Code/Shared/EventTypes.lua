-- EventQueues.lua -- Typed event channels bridging interaction layer to ECS.
-- Interactions push plain data entries; impulse/action systems drain and apply.
-- This avoids archetype moves for one-shot events.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventQueue = require(ReplicatedStorage.Code.Shared.Utilities.EventQueue)

local EventQueues = {
	-- Snap (QB receives ball): SnapInteraction -> SnapSystem
	Snap = EventQueue.new(128),

	-- Throw: ThrowInteraction -> ThrowSystem
	Throw = EventQueue.new(128),

	-- Catch: CatchInteraction -> CatchSystem
	Catch = EventQueue.new(128),

	-- Tackle: TackleInteraction -> TackleSystem
	Tackle = EventQueue.new(128),

	-- Sprint burst: SprintInteraction -> SprintSystem
	Sprint = EventQueue.new(128),

	-- Juke: JukeInteraction -> JukeSystem
	Juke = EventQueue.new(128),

	-- Dive: DiveInteraction -> DiveSystem
	Dive = EventQueue.new(128),

	-- Ground jump: Jump interaction node -> GroundJumpImpulseSystem
	GroundJump = EventQueue.new(128),

	-- Kick: Kick interaction (HoldToCharge -> PushEvent) -> KickImpulseSystem
	Kick = EventQueue.new(128),
}

return EventQueues
