local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local replecs = require(ReplicatedStorage.Packages.replecs)

local Tags = {
	PREDICTED       = jecs.tag(),
	IS_NPC          = jecs.tag(),
	IS_GROUNDED     = jecs.tag(),
	DASHING         = jecs.tag(),  -- active dash window: excluded from ground movement so the burst coasts; derived from CD_DASH remaining
	TACKLING        = jecs.tag(),  -- active tackle-launch window: excluded from ground movement so the forward burst coasts. Owned by TackleSystem (server); not replicated.
	STUNNED         = jecs.tag(),  -- frozen + vulnerable after a landed/whiffed tackle: excluded from movement and interactions. Owned by TackleSystem (server); replicated so remotes see it and the owner stops predicting movement.
	CHARACTER       = jecs.tag(),  -- collidable player character: the explicit filter for character-vs-character collision (never rely on COLLIDER_RADIUS presence)
	BRACED          = jecs.tag(),  -- brace stance active (BRACE input flag held): immovable in collision (pusher takes full separation). Derived from INPUT_FLAGS by BraceStateSystem; not replicated.
	THROWING        = jecs.tag(),  -- mid-throw motion window: set by ThrowSystem on release, held for the throw-anim duration (ball launches partway through). Owned by ThrowSystem (server); replicated to all so everyone plays the throw anim.
	WHIFFED         = jecs.tag(),  -- animation-only marker on a STUNNED tackler who missed: same freeze as STUNNED, but the anim plays the whiff stumble instead of the got-tackled fall. Added/removed alongside STUNNED by StunSystem (event.whiff); replicated so remotes pick the right clip.
	BALL            = jecs.tag(),
	BALL_GROUNDED   = jecs.tag(),
	WIND_AFFECTED   = jecs.tag(),
	PHYSICS_DISABLED = jecs.tag(),  -- general "skip physics": carried balls, frozen entities, etc.

	-- Client-only: set by ClientIdentity observer on characters owned by LocalPlayer.
	LOCAL_CHARACTER = jecs.tag(),
}

-- Mark every tag as replecs.shared with a name so replicated tags (e.g. IS_NPC)
-- resolve to the same local entity on server and client.
-- LOCAL_CHARACTER is client-only and must not be registered as shared.
for name, tag in pairs(Tags) do
	jecs.meta(tag, jecs.Name, name)
	jecs.meta(tag, replecs.shared)
end

return Tags
