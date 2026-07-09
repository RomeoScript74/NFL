-- CooldownSystem — Ticks all pair(COOLDOWN, *) components down by FIXED_DT each
-- physics tick. Removes the pair when remaining ≤ EPSILON.
-- Uses deferred removal to safely mutate during query iteration.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)
local collectTargets = require(ReplicatedStorage.Code.Shared.Utilities.CollectTargets)

local pair = jecs.pair
local Wildcard = jecs.Wildcard
local COOLDOWN = components.COOLDOWN
local FIXED_DT = 1 / 60

local function cooldownSystem()
	for entity in world:query(pair(COOLDOWN, Wildcard)) do
		for _, target in collectTargets(entity, COOLDOWN) do
			local pairId = pair(COOLDOWN, target)
			local remaining = world:get(entity, pairId) - FIXED_DT
			if remaining <= 0 then
				world:remove(entity, pairId)
			else
				world:set(entity, pairId, remaining)
			end
		end
	end
end

return {
	name = "CooldownSystem",
	phase = pipelines.Phases.Timers,
	system = cooldownSystem,
}
