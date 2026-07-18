-- LocomotionAnimationSystem.lua — Client-only Visual layer. Drives idle/walk/run/jump/fall body
-- animation off ECS velocity — reads state, never writes it. Reads the ANIMATION_TRACKS component that
-- AnimationLoaderSystem owns/loads; drives ONLY the store.loco slot (InteractionAnimationSystem drives
-- store.action, at Action priority, so it plays over whatever loco is doing here).
--
-- Driven off VISUAL_VELOCITY (VisualVelocitySystem's low-passed velocity), NOT raw velocity — that's
-- what keeps the stride from stuttering when reconciliation snaps velocity on a slow client. It also
-- means one drive query for everyone: the smoother already folded the local (VELOCITY) / remote
-- (SERVER_VELOCITY) split into VISUAL_VELOCITY, so this system no longer branches by realm. State is
-- chosen from that velocity ALONE (no IS_GROUNDED dependency — remotes aren't simulated and never have
-- that tag): vertical speed picks jump/fall, horizontal speed picks idle/walk/run and scales the
-- clip's playback speed so the feet don't skate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local phase = require(ReplicatedStorage.Packages["planck-runservice"]).Phases
local AnimationConfig = require(ReplicatedStorage.Code.Client.AnimationConfig)

local FADE = AnimationConfig.FadeTime
local IDLE_THRESHOLD = AnimationConfig.IdleThreshold
local RUN_THRESHOLD = AnimationConfig.RunThreshold
local WALK_REF = AnimationConfig.WalkRefSpeed
local RUN_REF = AnimationConfig.RunRefSpeed
local JUMP_VEL = AnimationConfig.JumpVelThreshold
local FALL_VEL = AnimationConfig.FallVelThreshold

-- All characters (local + remote) drive off the smoothed VISUAL_VELOCITY — one query, no realm split.
local driveQuery = world:query(components.VISUAL_VELOCITY, components.ANIMATION_TRACKS):with(tags.CHARACTER):cached()

-- Pick the locomotion state + playback speed from a velocity vector. Jump/fall win over ground
-- states; walk/run scale their speed to actual horizontal velocity so strides match ground travel.
local function selectState(vel: Vector3, tracks: { [string]: AnimationTrack }): (string, number)
	if vel.Y > JUMP_VEL and tracks.Jump then
		return "Jump", 1
	elseif vel.Y < -FALL_VEL and tracks.Fall then
		return "Fall", 1
	end

	local h = Vector3.new(vel.X, 0, vel.Z).Magnitude
	if h < IDLE_THRESHOLD then
		return "Idle", 1
	elseif tracks.Run and h >= RUN_THRESHOLD then
		return "Run", h / RUN_REF
	end
	return "Walk", h / WALK_REF
end

-- Crossfade to the selected state (only on change) and keep the active clip's playback speed synced.
local function driveLocomotion(store, vel: Vector3)
	local state, speed = selectState(vel, store.tracks)

	if state ~= store.loco then
		local old = store.loco and store.tracks[store.loco]
		if old then
			old:Stop(FADE)
		end
		local new = store.tracks[state]
		if new then
			new:Play(FADE)
		end
		store.loco = state
	end

	local active = store.tracks[store.loco]
	if active then
		active:AdjustSpeed(speed)
	end
end

local function locomotionAnimationSystem()
	for _entity, vel, store in driveQuery do
		driveLocomotion(store, vel)
	end
end

return {
	name = "LocomotionAnimationSystem",
	phase = phase.PreRender,
	system = locomotionAnimationSystem,
}
