local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local replecs = require(ReplicatedStorage.Packages.replecs)

local Tags = {
	PREDICTED       = jecs.tag(),
	IS_NPC          = jecs.tag(),
	IS_GROUNDED     = jecs.tag(),
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
