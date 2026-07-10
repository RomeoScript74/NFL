-- BallInterpolationInit.lua — Bootstraps interpolation state for the ball.
-- Split from RemoteInterpolationInit so the ball is tuned independently of characters: it
-- moves far faster, and (unlike a character) re-enters interpolation each time it's thrown.
-- Registered before apply_full so the monitor catches the ball as it arrives / re-arrives
-- (grabbing removes PHYSICS_DISABLED-gated membership; throwing restores it → re-fires).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local jecsUtils = require(ReplicatedStorage.Packages["jecs-utils"])

local FIXED_DT = 1 / 60
local BUFFER_DELAY = 0.150

return function()
	local ballQuery = world:query(
		components.REMOTE_TICK,
		components.SERVER_POSITION,
		components.SERVER_VELOCITY
	):with(tags.BALL):without(tags.PREDICTED, tags.PHYSICS_DISABLED)

	jecsUtils.monitor(ballQuery).added(function(entity)
		local pos = world:get(entity, components.SERVER_POSITION)
		local vel = world:get(entity, components.SERVER_VELOCITY)
		local tick = world:get(entity, components.REMOTE_TICK)

		if pos and vel and tick then
			local serverTime = tick * FIXED_DT

			-- Re-entry (ball was interpolated → grabbed [left] → thrown [re-enters]) still
			-- has its buffer from before the grab. Seed the clock AT the snapshot time, not
			-- BUFFER_DELAY behind it: with one snapshot and the clock in the past the ball
			-- would hang at the launch point for ~150ms then rush to catch up ("shoots,
			-- stops, speeds up"). Seeding at serverTime extrapolates forward from launch
			-- immediately; drift correction eases it back to the normal delay. The very first
			-- spawn (no buffer yet) keeps the -BUFFER_DELAY seed.
			local clock = serverTime - BUFFER_DELAY
			if world:get(entity, components.SNAPSHOT_BUFFER) ~= nil then
				clock = serverTime
			end

			world:set(entity, components.SNAPSHOT_BUFFER, {
				{ Time = serverTime, Pos = pos, Vel = vel },
			})
			world:set(entity, components.INTERPOLATION_CLOCK, clock)
			world:set(entity, components.INTERP_DRIFT, 0)
			world:set(entity, components.INTERP_LAST_CLOCK, clock)
		end
	end)
end
