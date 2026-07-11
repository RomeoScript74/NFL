-- ScoringSystem.lua — Server: detects when a ball carrier enters an endzone and ends the
-- carry. Runs in PostCollision, after CarrySystem, so it reads the ball's POSITION already
-- updated to the carrier's hand for this tick.
--
-- v1 scope: crossing into the endzone volume while CARRIED_BALL is set is enough to count —
-- no fumble/tackle-timing edge cases yet (there's no tackle system to race against). This
-- only detects the score and releases the ball (same detach as ThrowSystem, minus the
-- launch). Score-keeping, UI, and kickoff/reset need a TEAM/GameState system that doesn't
-- exist yet — out of scope here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local pair = jecs.pair

-- Endzone bounds, derived from the field model's Position/Size (Roblox parts are
-- center-origin: bound = position ± size/2). Update these if the field geometry changes.
local ENDZONES = {
	{ Name = "TD1", MinX = 67, MaxX = 134.5, MinZ = 208, MaxZ = 222.5 },
	{ Name = "TD2", MinX = 67, MaxX = 134.5, MinZ = 92, MaxZ = 106.5 },
}

local function isInZone(pos: Vector3, zone): boolean
	return pos.X >= zone.MinX and pos.X <= zone.MaxX
		and pos.Z >= zone.MinZ and pos.Z <= zone.MaxZ
end

local carrierQuery = world:query(components.CARRIED_BALL):cached()

local function scoringSystem()
	for carrier, ball in carrierQuery do
		if not world:contains(ball) then continue end

		local ballPos = world:get(ball, components.POSITION)
		if not ballPos then continue end

		for _, zone in ENDZONES do
			if not isInZone(ballPos, zone) then continue end

			local heldBy = world:target(ball, components.CARRIED_BY)
			if heldBy then
				world:remove(ball, pair(components.CARRIED_BY, heldBy))
			end
			world:remove(carrier, components.CARRIED_BALL)
			world:remove(ball, tags.PHYSICS_DISABLED)
			break
		end
	end
end

return {
	name = "ScoringSystem",
	phase = pipelines.Phases.PostCollision,
	system = scoringSystem,
}
