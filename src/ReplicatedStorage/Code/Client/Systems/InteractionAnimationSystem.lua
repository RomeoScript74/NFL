-- InteractionAnimationSystem.lua — Client-only Visual layer. Plays action clips (tackle/throw/stun) off
-- the replicated gameplay STATE TAGS, never off the interaction nodes: a node runs on one machine (and
-- tackle's resolve is server-only), but the tag replicates, so reading the tag animates the owner AND
-- every remote from one code path. Reads ANIMATION_TRACKS (loaded by AnimationLoaderSystem) and drives
-- ONLY store.action — the Action-priority clip plays over locomotion automatically; clearing it lets the
-- walk show through again.
--
-- Reconciliation-safe by construction: this polls the SETTLED tag once per frame at PreRender (after the
-- replay loop has finished). TACKLING is client-predicted and churns on/off during a replay burst, but
-- the burst is over by the time this reads it, so the clip never re-triggers or stutters. (Same reason
-- locomotion polls velocity here instead of reacting inside the sim.)
--
-- Priority: a character can momentarily hold more than one state (a whiffed tackler gets STUNNED while
-- TACKLING is clearing). Highest-priority active state wins the single action slot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local phase = require(ReplicatedStorage.Packages["planck-runservice"]).Phases
local AnimationConfig = require(ReplicatedStorage.Code.Client.AnimationConfig)

local INT_FADE = AnimationConfig.InteractionFade

-- All characters with tracks loaded; the per-state tag membership is answered by :has() below.
local driveQuery = world:query(components.ANIMATION_TRACKS):with(tags.CHARACTER):cached()

-- A cached "does this character carry tag X" membership query — one per catalog state.
local function stateQuery(tag: number)
	return world:query():with(tags.CHARACTER, tag):cached()
end

-- A PREDICTED animated action can't key off one replicated tag: the owner's tag is predicted (instant)
-- but NOT replicated (replicating it strips the prediction), so remotes read a replicated ">0 = active"
-- window component instead. This factory builds that realm-split predicate — the owner reads its own
-- predicted tag, remotes read the window; predictedQuery gates the owner off its own laggy window so its
-- action animates instantly. One line per predicted-animated action, no bespoke function each. (Plain
-- server-only anims — the common case — need none of this: they're just a `tag` row in the config.)
local predictedQuery = world:query():with(tags.CHARACTER, tags.PREDICTED):cached()

local function predictedOrWindow(predictedTag, windowComponent)
	local ownerQuery = world:query():with(tags.CHARACTER, tags.PREDICTED, predictedTag):cached()
	return function(entity: number): boolean
		if ownerQuery:has(entity) then
			return true  -- owner mid-action (its own predicted tag, instant)
		end
		if predictedQuery:has(entity) then
			return false  -- owner not acting → ignore its laggy replicated window
		end
		local window = world:get(entity, windowComponent)  -- remote → replicated window (>0 = active)
		return window ~= nil and window > 0
	end
end

-- The priority catalog is DERIVED entirely from AnimationConfig.Actions (the single source of truth) —
-- order, clip names, trigger tag, and predicted-ness are ALL data there, so adding an interaction
-- animation is one config row, zero code here. A row with a `predictedWindow` becomes the realm-split
-- predicate; a plain row is straight tag membership. First active wins the single action slot.
local ACTION_CATALOG = {}
for _, def in AnimationConfig.Actions do
	local tag = tags[def.tag]
	if not tag then
		warn("[InteractionAnimation] Action '" .. def.name .. "' has unknown tag '" .. tostring(def.tag) .. "'")
	elseif def.predictedWindow then
		local windowComponent = components[def.predictedWindow]
		if windowComponent then
			table.insert(ACTION_CATALOG, { clip = def.name, resolve = predictedOrWindow(tag, windowComponent) })
		else
			warn("[InteractionAnimation] Action '" .. def.name .. "' has unknown predictedWindow '" .. tostring(def.predictedWindow) .. "'")
		end
	else
		table.insert(ACTION_CATALOG, { clip = def.name, query = stateQuery(tag) })
	end
end

-- Recovery clips: an action may name a `recovery` clip that plays as a one-shot when the action ENDS
-- (e.g. Hurdle → Land the instant HURDLING clears, i.e. on touchdown). Data-driven like the catalog:
-- { [actionName] = recoveryClipName }. This is how a discrete "landing/get-up" beat stays in the actions
-- layer — driven off the action's own state ending, not sniffed from velocity in locomotion.
local ACTION_RECOVERY = {}
for _, def in AnimationConfig.Actions do
	if def.recovery then
		ACTION_RECOVERY[def.name] = def.recovery
	end
end

-- The single active action for this entity, or nil — first matching catalog entry in priority order.
local function selectAction(entity: number): string?
	for _, entry in ACTION_CATALOG do
		local active
		if entry.resolve then
			active = entry.resolve(entity)
		else
			active = entry.query:has(entity)
		end
		if active then
			return entry.clip
		end
	end
	return nil
end

-- Drives the action slot. Action clips are ONE-SHOTS: once triggered they play their FULL length, and
-- Action priority keeps them over the walk until they naturally end. We must NOT stop a one-shot when its
-- state tag clears — the gameplay window (TACKLING's ~0.2s launch coast) is far shorter than the dive
-- clip, so stopping on tag-clear cuts the animation to a flicker. We stop the current clip only to start a
-- DIFFERENT action that HAS a clip, or when a held (looping) clip's state ends. store.action = last
-- selected state (edge detect); store.playing = the clip we're responsible for stopping.
local function driveAction(store, action: string?)
	if action == store.action then
		return
	end
	local prev = store.action
	store.action = action

	if action then
		local track = store.tracks[action]
		if track then
			-- New action has a clip → replace whatever's playing with it.
			local playing = store.playing and store.tracks[store.playing]
			if playing then
				playing:Stop(INT_FADE)
			end
			track:Play(INT_FADE)
			store.playing = action
		end
		-- else: this state has no clip (e.g. Stun with no id yet) → leave the current one-shot to finish.
	else
		-- State cleared. If the ending action has a RECOVERY clip (Hurdle → Land on touchdown), crossfade
		-- into it as a one-shot follow-up. Otherwise stop a held (looping) clip; let a plain one-shot finish.
		local recovery = prev and ACTION_RECOVERY[prev]
		if recovery and store.tracks[recovery] then
			local playing = store.playing and store.tracks[store.playing]
			if playing then
				playing:Stop(INT_FADE)
			end
			store.tracks[recovery]:Play(INT_FADE)
			store.playing = recovery
		else
			local track = store.playing and store.tracks[store.playing]
			if track and track.Looped then
				track:Stop(INT_FADE)
				store.playing = nil
			end
		end
	end
end

local function interactionAnimationSystem()
	for entity, store in driveQuery do
		driveAction(store, selectAction(entity))
	end
end

return {
	name = "InteractionAnimationSystem",
	phase = phase.PreRender,
	system = interactionAnimationSystem,
}
