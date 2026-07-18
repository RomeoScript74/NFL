-- VisualVelocitySystem.lua — Client-only. Owns VISUAL_VELOCITY: a low-passed copy of each character's
-- velocity for the VISUAL layer to consume (locomotion anim speed + body facing). Reconciliation snaps
-- raw VELOCITY to the server value (and, on a slow client, does so often), which the anim/facing would
-- otherwise read directly and stutter — this is the velocity analog of VISUAL_OFFSET's position smoothing.
--
-- It also unifies the realm split at the source: the local predicted player carries live VELOCITY,
-- remotes carry only SERVER_VELOCITY. Both feed one VISUAL_VELOCITY here, so the consumers (anim +
-- both facing paths) read a single component and no longer need their own local/remote branches.
--
-- Seed queries set VISUAL_VELOCITY to the raw value on first sight (no startup pop); update queries ease
-- it toward the raw value each frame. Seed + update live together — one owner of VISUAL_VELOCITY, and the
-- realm-split source pick (VELOCITY vs SERVER_VELOCITY) isn't duplicated across files. Runs at PreRender;
-- consumers tolerate a one-frame lag (it's a smoothing signal) and filter :with(VISUAL_VELOCITY).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local phase = require(ReplicatedStorage.Packages["planck-runservice"]).Phases

local SMOOTH_TIME = 0.1  -- seconds; larger = smoother/laggier, smaller = snappier/less damping
local MAX_RENDER_DT = 0.100
local DT_SMOOTHING = 0.8

local lastFrameTime = os.clock()
local smoothedDt = 1 / 60

-- Local predicted player: raw source is live VELOCITY.
local localSeedQuery = world:query(components.VELOCITY):with(tags.CHARACTER, tags.PREDICTED):without(components.VISUAL_VELOCITY):cached()
local localUpdateQuery = world:query(components.VELOCITY, components.VISUAL_VELOCITY):with(tags.CHARACTER, tags.PREDICTED):cached()
-- Remote characters: raw source is the replicated SERVER_VELOCITY (no live VELOCITY on interpolated entities).
local remoteSeedQuery = world:query(components.SERVER_VELOCITY):with(tags.CHARACTER):without(tags.PREDICTED, components.VISUAL_VELOCITY):cached()
local remoteUpdateQuery = world:query(components.SERVER_VELOCITY, components.VISUAL_VELOCITY):with(tags.CHARACTER):without(tags.PREDICTED):cached()

local function visualVelocitySystem()
	local now = os.clock()
	local rawDt = now - lastFrameTime
	lastFrameTime = now
	smoothedDt = smoothedDt * DT_SMOOTHING + rawDt * (1 - DT_SMOOTHING)
	local dt = math.min(smoothedDt, MAX_RENDER_DT)
	local alpha = math.min(dt / SMOOTH_TIME, 1.0)

	-- Seed on first sight (no startup pop): set VISUAL_VELOCITY to the current raw velocity.
	for entity, vel in localSeedQuery do
		world:set(entity, components.VISUAL_VELOCITY, vel)
	end
	for entity, vel in remoteSeedQuery do
		world:set(entity, components.VISUAL_VELOCITY, vel)
	end

	for entity, vel, visualVel in localUpdateQuery do
		world:set(entity, components.VISUAL_VELOCITY, visualVel:Lerp(vel, alpha))
	end
	for entity, vel, visualVel in remoteUpdateQuery do
		world:set(entity, components.VISUAL_VELOCITY, visualVel:Lerp(vel, alpha))
	end
end

return {
	name = "VisualVelocitySystem",
	phase = phase.PreRender,
	system = visualVelocitySystem,
}
