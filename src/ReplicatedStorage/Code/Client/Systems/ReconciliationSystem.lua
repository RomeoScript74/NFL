-- ReconciliationSystem.lua — Detects desync when server state arrives, snaps to
-- server-authoritative position, replays predicted inputs to catch back up.
-- Overwatch-style: snap + replay, then smooth visual offset to zero.
-- Predicted dash cooldown + burst (pair(COOLDOWN, CD_DASH) / DASH_WINDOW) are restored to the
-- server-authoritative values before the replay loop, then re-simulated (input-replay rollback).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local scheduler = require(ReplicatedStorage.Code.Shared.Scheduler)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)
local phase = require(ReplicatedStorage.Packages["planck-runservice"]).Phases

-- Predicted dash cooldown pair — restored from SERVER_DASH_CD before the replay loop.
local DASH_CD_PAIR = jecs.pair(components.COOLDOWN, components.CD_DASH)
-- Predicted dash burst timer — restored from SERVER_DASH_WINDOW before the replay loop.
local DASH_WINDOW_TIMER = jecs.pair(components.TIMER, components.DASH_WINDOW)

local HORIZONTAL_THRESHOLD = 1.5
local VERTICAL_GROUNDED   = 1.1
local VERTICAL_AIR        = 0.5

local reconciliationQuery = world:query(
	components.SERVER_TICK,
	components.SERVER_POSITION,
	components.SERVER_VELOCITY,
	components.SERVER_DASH_CD,
	components.SERVER_DASH_WINDOW,
	components.INPUT_HISTORY,
	components.LAST_RECONCILED_TICK,
	components.POSITION,
	components.INPUT_DIRECTION,
	components.INPUT_FLAGS,
	components.VISUAL_OFFSET
):with(tags.PREDICTED):cached()

local function reconciliationSystem()
	for entity, serverTick, serverPos, serverVel, serverDashCd, serverDashWindow, history, lastReconciled, pos, inputDir, inputFlags, visualOffset in reconciliationQuery do
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

		-- Restore the predicted dash burst to the server-authoritative value at serverTick
		-- before replay (AAA/Overwatch style: the whole predicted snapshot — position, velocity,
		-- AND ability state — rolls back, then re-simulates). A server-confirmed dash restores its
		-- remaining window here so replayed ticks keep coasting; an unconfirmed dash restores 0
		-- and the replayed DASH input re-fires it. Either way replay reconstructs exactly.
		if serverDashWindow > 0 then
			world:set(entity, DASH_WINDOW_TIMER, serverDashWindow)
			world:add(entity, tags.DASHING)
		else
			world:remove(entity, tags.DASHING)
			world:remove(entity, DASH_WINDOW_TIMER)
		end

		-- Restore the PREDICTED cooldown to the server value at serverTick, then the replay
		-- re-ticks it (CooldownSystem) from the correct anchor. Without this, each replay
		-- over-decrements the predicted cooldown and the client re-fires dash early. 0 = off
		-- cooldown, so remove the pair.
		if serverDashCd > 0 then
			world:set(entity, DASH_CD_PAIR, serverDashCd)
		else
			world:remove(entity, DASH_CD_PAIR)
		end

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
