-- HistoryRecorderSystem.lua — Records predicted position + input state each physics tick.
-- Reconciliation replays these entries from the point of server disagreement.
-- Keeps 120 entries (2 seconds at 60 Hz).
--
-- Also snapshots the INTERACTION execution state (active chains + INPUT_STATE) into each entry, so
-- reconciliation can roll the interaction system back to the server tick before replay — the same
-- historical-local-state model Overwatch's State Script uses. Cheap: most ticks have no active chain,
-- and Phase 0 made chain state plain data (see ChainSnapshot).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)
local ChainSnapshot = require(ReplicatedStorage.Code.Shared.Interactions.ChainSnapshot)

local query = world:query(
	components.INPUT_HISTORY,
	components.INPUT_DIRECTION,
	components.INPUT_FLAGS,
	components.POSITION,
	components.VELOCITY,
	components.YAW,
	components.PITCH,
	components.INTERACTION_MANAGER,
	components.INPUT_STATE
):with(tags.PREDICTED):cached()

local function historyRecorderSystem()
	for entity, history, dir, flags, pos, vel, yaw, pitch, manager, inputState in query do
		local currentTick = (history.LastTick or 0) + 1
		history.LastTick = currentTick

		local entry = {
			Tick = currentTick,
			X = dir.X,
			Z = dir.Z,
			Yaw = yaw,
			Pitch = pitch,
			Flags = flags,
			PredictedPos = pos,
			PredictedVel = vel,
			-- Interaction execution state at end of this tick (active chains + input intent), for rollback.
			Interaction = ChainSnapshot.capture(manager.active, inputState),
		}

		table.insert(history, entry)
		while #history > 120 do
			table.remove(history, 1)
		end

		world:set(entity, components.INPUT_HISTORY, history)
	end
end

return {
	name = "HistoryRecorderSystem",
	phase = pipelines.Phases.React,
	system = historyRecorderSystem,
}
