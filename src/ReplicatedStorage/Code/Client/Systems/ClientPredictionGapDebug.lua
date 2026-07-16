-- ClientPredictionGapDebug.lua — TEMP diagnostic. Prints how far the local prediction leads the last
-- confirmed server state: gap = POSITION (what you see) − SERVER_POSITION (last server-authoritative).
-- That gap is exactly the distance the tackle's velocity-lead has to cover for "past on my screen =
-- safe" to hold. If this reads ~1-2 studs but tackles still feel "way past," the culprit is tackle
-- RANGE, not latency. Throttled ~2/s, skipped during reconciliation replay. Delete when tuning's done.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local query = world:query(components.POSITION, components.SERVER_POSITION, components.VELOCITY)
	:with(tags.PREDICTED):cached()

local frame = 0

local function clientPredictionGapDebug()
	-- Don't count replay ticks — they re-run this phase many times per frame.
	if world:get(components.IS_REPLAYING, components.IS_REPLAYING) then return end
	frame += 1
	if frame % 30 ~= 0 then return end

	for _, pos, serverPos, vel in query do
		local gap = pos - serverPos
		local flatGap = Vector3.new(gap.X, 0, gap.Z).Magnitude
		local speed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		print(string.format("[PRED-GAP] aheadOfServer=%.2f studs  speed=%.1f", flatGap, speed))
	end
end

return {
	name = "ClientPredictionGapDebug",
	phase = pipelines.Phases.PostCollision,
	system = clientPredictionGapDebug,
}
