-- SelectNearby.lua — Target-acquisition leaf node.
-- Finds the nearest entity carrying `Tag` within `Range` (horizontal) studs of the
-- acting entity, stores it on the context as the target, and returns SUCCESS. If no
-- candidate is in range it returns FAILURE, which aborts the surrounding Serial —
-- i.e. "no valid target → the interaction doesn't happen". This keeps target
-- selection in the interaction layer; the impulse system just applies to the target.
--
-- Config: { Tag = "BALL", Range = 10 }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local FAILURE = NodeRegistry.FAILURE
local SUCCESS = NodeRegistry.SUCCESS

-- One cached query per (candidate tag, optional exclusion tag), shared across all chains.
-- The node stays generic: WHAT to exclude is data, declared in the chain def's config
-- (e.g. Without = "PHYSICS_DISABLED" so grab skips carried balls), not hardcoded here.
local queryCache = {}
local function candidateQuery(tag, withoutTag)
	local key = tostring(tag) .. "|" .. tostring(withoutTag)
	local q = queryCache[key]
	if not q then
		local builder = world:query(components.POSITION):with(tag)
		if withoutTag then
			builder = builder:without(withoutTag)
		end
		q = builder:cached()
		queryCache[key] = q
	end
	return q
end

NodeRegistry.register("SelectNearby", function(config)
	local tag = tags[config.Tag]
	local withoutTag = if config.Without then tags[config.Without] else nil
	local range = config.Range or 10
	local rangeSq = range * range

	return {
		Type = "SelectNearby",
		execute = function(_self, ctx)
			local userPos = world:get(ctx.user, components.POSITION)
			if not userPos then return FAILURE end

			local nearest, nearestSq = nil, rangeSq
			for entity, pos in candidateQuery(tag, withoutTag) do
				if entity == ctx.user then continue end
				local dx, dz = pos.X - userPos.X, pos.Z - userPos.Z
				local dSq = dx * dx + dz * dz
				if dSq <= nearestSq then
					nearest = entity
					nearestSq = dSq
				end
			end

			if not nearest then return FAILURE end

			ctx:setMeta("TargetEntity", nearest)
			return SUCCESS
		end,
	}
end)

return nil
