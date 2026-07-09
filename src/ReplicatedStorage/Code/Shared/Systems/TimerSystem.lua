-- TimerSystem — Ticks all pair(TIMER, *) components down by 1 each physics tick.
-- Removes the pair when remaining hits 0.
-- Uses deferred removal to safely mutate during query iteration.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)
local collectTargets = require(ReplicatedStorage.Code.Shared.Utilities.CollectTargets)

local pair = jecs.pair
local Wildcard = jecs.Wildcard
local TIMER = components.TIMER

local function timerSystem()
	for entity in world:query(pair(TIMER, Wildcard)) do
		for _, target in collectTargets(entity, TIMER) do
			local pairId = pair(TIMER, target)
			local remaining = world:get(entity, pairId) - 1
			if remaining <= 0 then
				world:remove(entity, pairId)
			else
				world:set(entity, pairId, remaining)
			end
		end
	end
end

return {
	name = "TimerSystem",
	phase = pipelines.Phases.Timers,
	system = timerSystem,
}
