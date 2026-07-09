-- BufferManagementSystem.lua -- Adaptive input buffer sizing + overflow trim.
-- Trims buffer past MaxSize. Grows TargetSize on starvation, shrinks after stability.
-- Runs in Timers phase before ClockSync reads the buffer.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local bufferQuery = world:query(
	components.INPUT_BUFFER,
	components.BUFFER_CONFIG
):cached()

local function bufferManagementSystem()
	for _entity, buffer, config in bufferQuery do
		local bufferSize = #buffer

		-- Anti-flood: trim oldest inputs when buffer overflows
		if bufferSize > config.MaxSize then
			local overflow = bufferSize - config.MaxSize
			for _ = 1, overflow do
				table.remove(buffer, 1)
			end
			bufferSize = config.MaxSize
		end

		local isStarving = bufferSize == 0

		if isStarving then
			-- Starving: grow target (with cooldown so one spike doesn't inflate permanently)
			if config.GrowthCooldown <= 0 then
				config.TargetSize = math.min(config.TargetSize + 1, config.MaxSize)
				config.GrowthCooldown = 30
			end
			config.StabilityTimer = 0
		else
			if config.GrowthCooldown > 0 then
				config.GrowthCooldown = config.GrowthCooldown - 1
			end

			config.StabilityTimer = config.StabilityTimer + 1
			-- Shrink target after sustained stability (180 ticks = 3 seconds at 60Hz)
			if config.StabilityTimer > 180 then
				config.TargetSize = math.max(config.TargetSize - 1, config.MinSize)
				config.StabilityTimer = 0
			end
		end
	end
end

return {
	name = "BufferManagementSystem",
	phase = pipelines.Phases.Timers,
	system = bufferManagementSystem,
}
