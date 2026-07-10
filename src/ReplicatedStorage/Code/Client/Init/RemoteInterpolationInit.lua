-- RemoteInterpolationInit.lua — Bootstraps interpolation state for remote entities.
-- Registered before apply_full so the monitor catches entities as they arrive.
-- Sets SNAPSHOT_BUFFER with the first snapshot so RemoteVisualInterpolator starts clean.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local jecsUtils = require(ReplicatedStorage.Packages["jecs-utils"])

local FIXED_DT = 1 / 60
local BUFFER_DELAY = 0.150

return function()
	local remoteQuery = world:query(
		components.REMOTE_TICK,
		components.SERVER_POSITION,
		components.SERVER_VELOCITY
	):without(tags.PREDICTED, tags.BALL)

	jecsUtils.monitor(remoteQuery).added(function(entity)
		local pos = world:get(entity, components.SERVER_POSITION)
		local vel = world:get(entity, components.SERVER_VELOCITY)
		local tick = world:get(entity, components.REMOTE_TICK)

		if pos and vel and tick then
			local serverTime = tick * FIXED_DT
			world:set(entity, components.SNAPSHOT_BUFFER, {
				{ Time = serverTime, Pos = pos, Vel = vel },
			})
			world:set(entity, components.INTERPOLATION_CLOCK, serverTime - BUFFER_DELAY)
			world:set(entity, components.INTERP_DRIFT, 0)
			world:set(entity, components.INTERP_LAST_CLOCK, serverTime - BUFFER_DELAY)
		end
		-- ROOTPART resolved by InitCharacterSystem (PreSimulation polling).
	end)
end
