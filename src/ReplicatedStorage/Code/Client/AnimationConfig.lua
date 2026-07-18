-- AnimationConfig.lua — Client-only visual config for character animation. The SINGLE source of truth:
-- AnimationLoaderInit (what tracks to load) and InteractionAnimationSystem (the tag→clip priority catalog)
-- both DERIVE from this table — adding an animation is one edit here, not three.
--
-- Lives OUTSIDE Client/Systems (that folder auto-registers every ModuleScript as a Planck system — a
-- config module there would be junk). Pure data: no world/ECS access; it stores tag NAMES as strings, and
-- the systems resolve them. Animation is a client-only Visual concern (the server never plays tracks), so
-- this is NOT a shared *Calc module — nothing here has to stay bit-identical across realms.
--
-- Paste your uploaded asset ids ("rbxassetid://..."). Leave an id "" and that clip is skipped (never
-- loaded/played) — a partial set degrades cleanly. Ids take effect on (re)load, i.e. next character spawn.

local AnimationConfig = {
	-- Locomotion: continuous, velocity-driven. name -> { id, loop }. Loaded at Movement priority. The
	-- names are FIXED — LocomotionAnimationSystem.selectState picks between them from velocity; you tune
	-- ids/loop here, not the set. ("" id = that state falls through, e.g. no Run clip → speed-scaled Walk.)
	Locomotion = {
		Idle = { id = "",                             loop = true },
		Walk = { id = "rbxassetid://136888987725031", loop = true },
		Run  = { id = "rbxassetid://76307876961727",  loop = true },
		Jump = { id = "",                             loop = false },
		Fall = { id = "",                             loop = true },
	},

	-- Actions: discrete, state-driven one-shots. Loaded at Action priority so they play OVER locomotion
	-- (the walk shows through again when the clip ends). ORDERED by priority — first match wins the single
	-- action slot. Each row is the WHOLE declaration, fully data (no code per animation):
	--   name            = track key + clip name
	--   id              = asset ("" skips the clip; the state still exists, just no visual)
	--   tag             = the gameplay state tag (by name) that triggers it
	--   predictedWindow = OPTIONAL. Presence marks this a PREDICTED action: the owner reads `tag` (its own
	--                     predicted, un-replicated tag → instant), remotes read this replicated
	--                     ">0 = active" window component (the predicted tag can't be replicated). Plain
	--                     server-authoritative anims omit it and just match `tag` on everyone.
	-- Whiff is first so a whiffed tackler (WHIFFED + STUNNED) plays the stumble, not the victim's fall.
	Actions = {
		{ name = "Whiff",  id = "",                             tag = "WHIFFED" },
		{ name = "Stun",   id = "rbxassetid://132753410690816", tag = "STUNNED" },  -- got-tackled fall
		{ name = "Throw",  id = "rbxassetid://76796874443961",  tag = "THROWING" },
		{ name = "Tackle", id = "rbxassetid://136908519069282", tag = "TACKLING", predictedWindow = "SERVER_TACKLE_WINDOW" },
	},

	-- Blend / selection tuning (gameplay feel — safe to change).
	InteractionFade  = 0.1,   -- crossfade seconds when an action clip starts/ends
	FadeTime         = 0.15,  -- crossfade seconds when switching locomotion state
	IdleThreshold    = 0.5,   -- horizontal studs/s below this = Idle
	RunThreshold     = 20,    -- horizontal studs/s at/above this = Run (only if a Run id is set)
	WalkRefSpeed     = 12,    -- studs/s the Walk clip was authored at; playback speed = actual / this (no foot skate)
	RunRefSpeed      = 24,    -- studs/s the Run clip was authored at
	JumpVelThreshold = 3,     -- vertical studs/s above this = Jump (airborne, rising)
	FallVelThreshold = 3,     -- vertical studs/s below -this = Fall (airborne, dropping)
}

return AnimationConfig
