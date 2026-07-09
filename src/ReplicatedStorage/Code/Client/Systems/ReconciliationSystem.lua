-- ReconciliationSystem.lua — Detects desync when server state arrives, snaps to
-- server-authoritative position, replays predicted inputs to catch back up.
-- Overwatch-style: snap + replay, then smooth visual offset to zero.
-- Stripped of FPS-specific combat/dash cooldown reconciliation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local scheduler = require(ReplicatedStorage.Code.Shared.Scheduler)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)
local phase = require(ReplicatedStorage.Packages["planck-runservice"]).Phases

local HORIZONTAL_THRESHOLD = 1.5
local VERTICAL_GROUNDED   = 1.1
local VERTICAL_AIR        = 0.5

local reconciliationQuery = world:query(
	components.SERVER_TICK,
	components.SERVER_POSITION,
	components.SERVER_VELOCITY,
	components.INPUT_HISTORY,
	components.LAST_RECONCILED_TICK,
	components.POSITION,
	components.INPUT_DIRECTION,
	components.INPUT_FLAGS,
	components.VISUAL_OFFSET
):with(tags.PREDICTED):cached()

local function reconciliationSystem()
	for entity, serverTick, serverPos, serverVel, history, lastReconciled, pos, inputDir, inputFlags, visualOffset in reconciliationQuery do
		if serverTick == lastReconciled then continue end
		world:set(entity, components.LAST_RECONCILED_TICK, serverTick)

		if #history == 0 then continue end

		-- Find the history entry matching this server tick
		local historyIndex = nil
		for i = #history, 1, -1 do
			if history[i].Tick == serverTick then
				historyIndex = i
				break
			end
		end
		if not historyIndex then continue end

		local predictedPos = history[historyIndex].PredictedPos
		if not predictedPos then continue end

		local diff = predictedPos - serverPos
		local horizontalError = Vector3.new(diff.X, 0, diff.Z).Magnitude
		local verticalError = math.abs(diff.Y)

		local isGrounded = world:has(entity, tags.IS_GROUNDED)
		local verticalThreshold = isGrounded and VERTICAL_GROUNDED or VERTICAL_AIR

		local isDesync = horizontalError > HORIZONTAL_THRESHOLD
			or verticalError > verticalThreshold

		if not isDesync then
			for _ = 1, historyIndex do
				table.remove(history, 1)
			end
			continue
		end

		-- Desync detected: snap to server state, replay remaining history
		local oldClientPos = pos

		world:set(entity, components.POSITION, serverPos)
		world:set(entity, components.VELOCITY, serverVel)

		-- Suppress observers/VFX during replay
		world:set(components.IS_REPLAYING, components.IS_REPLAYING, true)

		-- Replay all history entries after the server tick
		for i = historyIndex + 1, #history do
			local move = history[i]
			local dir = Vector3.new(move.X, 0, move.Z)

			world:set(entity, components.INPUT_DIRECTION, dir)
			world:set(entity, components.INPUT_FLAGS, move.Flags or 0)

			scheduler.PhysicsScheduler:run(pipelines.Pipelines.Simulation)

			-- Must re-read: mutated by PhysicsScheduler:run
			move.PredictedPos = world:get(entity, components.POSITION)
			move.PredictedVel = world:get(entity, components.VELOCITY)
		end

		-- Restore current input
		world:set(entity, components.INPUT_DIRECTION, inputDir)
		world:set(entity, components.INPUT_FLAGS, inputFlags)

		world:set(components.IS_REPLAYING, components.IS_REPLAYING, false)

		-- Must re-read: mutated by replay loop
		local newPos = world:get(entity, components.POSITION)
		world:set(entity, components.VISUAL_OFFSET, visualOffset + oldClientPos - newPos)

		-- Trim processed history
		for _ = 1, historyIndex do
			table.remove(history, 1)
		end
	end
end

return {
	name = "ReconciliationSystem",
	phase = phase.PreSimulation,
	system = reconciliationSystem,
}
