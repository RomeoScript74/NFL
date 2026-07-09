-- SnapshotPrevPositionSystem.lua — Snapshots POSITION before physics so reconciliation
-- can compute the visual offset after a correction.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local query = world:query(components.POSITION):with(tags.PREDICTED):cached()

local function snapshotPrevPositionSystem()
	for entity, pos in query do
		world:set(entity, components.PREV_POSITION, pos)
	end
end

return {
	name = "SnapshotPrevPositionSystem",
	phase = pipelines.Phases.PreInput,
	system = snapshotPrevPositionSystem,
}
