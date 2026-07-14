-- BraceStateSystem.lua — Owns the BRACED tag. Derives it from the BRACE input flag: a held stance
-- that makes a character immovable in character-vs-character collision (the pusher takes the full
-- separation). Shared: runs on server (all characters) and client (only the predicted local
-- character, since remotes carry no INPUT_FLAGS). Runs in PostCombat — after INPUT_FLAGS is
-- resolved (server InputBufferSystem @ Input) and before collision reads BRACED (@ PostCollision).
-- Inside the Simulation pipeline, so reconciliation replay reconstructs the tag from replayed flags.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local InputType = require(ReplicatedStorage.Code.Shared.InputType)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

-- INPUT_FLAGS presence scopes this to input-driven characters; on the client that is only the
-- predicted local player (remotes have no INPUT_FLAGS), which is exactly what we want.
local braceQuery = world:query(components.INPUT_FLAGS):with(tags.CHARACTER):cached()

local function braceStateSystem()
	for entity, flags in braceQuery do
		if InputType.has(flags, InputType.BRACE) then
			world:add(entity, tags.BRACED)
		else
			world:remove(entity, tags.BRACED)
		end
	end
end

return {
	name = "BraceStateSystem",
	phase = pipelines.Phases.PostCombat,
	system = braceStateSystem,
}
