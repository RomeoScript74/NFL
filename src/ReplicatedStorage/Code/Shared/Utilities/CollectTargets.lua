-- CollectTargets — Iterates all pair targets for a given relationship on an entity.
-- Returns a plain array. Safe to use before mutating pair components during iteration.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local world = require(ReplicatedStorage.Code.Shared.World)

local function collectTargets(entity, relation)
	local targets = {}
	local nth = 0
	local target = world:target(entity, relation, nth)
	while target do
		table.insert(targets, target)
		nth += 1
		target = world:target(entity, relation, nth)
	end
	return targets
end

return collectTargets
