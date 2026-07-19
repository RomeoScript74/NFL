-- AnimationLoaderInit.lua — Client: loads each character's animation tracks reactively (monitor),
-- mirroring BallInit / RemoteInterpolationInit rather than polling every frame. Owns ANIMATION_TRACKS:
-- the moment a character has a resolved ROOTPART (InitCharacterSystem sets it post-apply_full), this
-- resolves its Animator and loads every configured clip once. Registered before apply_full so the
-- monitor catches ROOTPART being added later (observe_archetypes keeps the match set live, so the late
-- transition fires .added — see BallInit). ANIMATION_TRACKS present is the "already loaded" gate.
--
-- Query shape note: the trigger (ROOTPART) and the presence-filter (CHARACTER) are BASE terms, NOT
-- :with — jecsUtils.monitor hooks `filter_with or query.ids`, so a :with term would REPLACE the base
-- terms as the change-tracked set and ROOTPART's late addition would be missed. CHARACTER excludes the
-- ball (which also carries ROOTPART, but no Humanoid).
--
-- Locomotion clips load at Movement priority, action clips (tackle/throw/stun) at Action priority — so
-- an action plays OVER the walk automatically and the walk shows through again when it ends. store shape:
-- { tracks = { name -> AnimationTrack }, loco, action, playing } — loco/action/playing are each managed
-- by the driver systems (LocomotionAnimationSystem / InteractionAnimationSystem) that READ these tracks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local jecsUtils = require(ReplicatedStorage.Packages["jecs-utils"])
local AnimationConfig = require(ReplicatedStorage.Code.Client.AnimationConfig)

local MOVEMENT = Enum.AnimationPriority.Movement
local ACTION = Enum.AnimationPriority.Action

-- Load one Animation asset into a track; "" id → nil (state skipped). loop + priority are forced in
-- code (not left to the asset) so ground/held cycles repeat and one-shots don't, and so action clips
-- outrank locomotion regardless of how they were authored.
local function loadTrack(animator: Animator, id: string, priority: Enum.AnimationPriority, loop: boolean): AnimationTrack?
	if id == "" then return nil end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	-- Guard the external load: an asset the experience can't access (unowned / unpublished / still
	-- processing) makes LoadAnimation THROW. A bad clip must degrade to "skipped", never crash.
	local ok, track = pcall(animator.LoadAnimation, animator, anim)
	if not ok or not track then
		warn("[AnimationLoader] LoadAnimation failed for", id, "-", track)
		return nil
	end
	track.Priority = priority
	track.Looped = loop
	return track
end

local function loadTracks(entity: number)
	if not world:contains(entity) then return end
	local rootPart = world:get(entity, components.ROOTPART)
	local model = rootPart and rootPart.Parent
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end

	-- Derive every track from AnimationConfig — the single source of truth. Locomotion at Movement
	-- priority (loop per config), actions at Action priority (always one-shots).
	local tracks = {}
	for name, def in AnimationConfig.Locomotion do
		tracks[name] = loadTrack(animator, def.id, MOVEMENT, def.loop)
	end
	for _, def in AnimationConfig.Actions do
		tracks[def.name] = loadTrack(animator, def.id, ACTION, false)
	end
	-- Land: the hurdle's recovery clip (Action priority). InteractionAnimationSystem plays it when the
	-- Hurdle action ends (= touchdown, since HURDLING now ends on landing); referenced by `recovery`.
	tracks.Land = loadTrack(animator, AnimationConfig.Land.id, ACTION, false)
	world:set(entity, components.ANIMATION_TRACKS, { tracks = tracks, loco = nil, action = nil, playing = nil })
end

return function()
	local loadQuery = world:query(components.ROOTPART, tags.CHARACTER):without(components.ANIMATION_TRACKS)

	jecsUtils.monitor(loadQuery).added(function(entity)
		-- task.spawn: the monitor fires on Replecs's replication thread, and LoadAnimation can yield
		-- while the asset streams — never yield that thread (mirrors BallInit). world:set lands a frame
		-- later; the driver systems just wait for ANIMATION_TRACKS to appear.
		task.spawn(loadTracks, entity)
	end)
end
