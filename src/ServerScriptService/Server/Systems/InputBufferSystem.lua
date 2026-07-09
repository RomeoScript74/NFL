-- InputBufferSystem.lua — Consumes 1 input per tick from INPUT_BUFFER.
-- Writes INPUT_DIRECTION, INPUT_FLAGS, YAW, PITCH so physics systems can read them.
-- Starvation: repeats last input for a short jitter window, then zeros out.
-- No long extrapolation — server is authoritative, not predictive.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local inputBufferQuery = world:query(
	components.INPUT_BUFFER,
	components.BUFFER_CONFIG,
	components.INPUT_FLAGS
):cached()

-- Short jitter window only — not prediction.
-- 3 frames covers normal UDP reordering without extrapolating movement.
local JITTER_WINDOW = 3

local function inputBufferSystem()
	for entity, buffer, config, _currentFlags in inputBufferQuery do
		if #buffer > 0 then
			config.StarvationFrames = 0

			local nextInput = table.remove(buffer, 1)
			world:set(entity, components.LAST_PROCESSED_TICK, nextInput.Tick)

			local x = nextInput.X or 0
			local z = nextInput.Z or 0
			local dir = Vector3.new(x, 0, z)
			
			if dir.Magnitude > 0 then
				dir = dir.Unit
			end

			world:set(entity, components.INPUT_DIRECTION, dir)
			world:set(entity, components.INPUT_FLAGS, nextInput.Flags or 0)

			if nextInput.Yaw then
				world:set(entity, components.YAW, nextInput.Yaw)
			end
			if nextInput.Pitch then
				world:set(entity, components.PITCH, nextInput.Pitch)
			end
			if nextInput.RenderFrame then
				world:set(entity, components.RENDER_FRAME, nextInput.RenderFrame)
			end
		else
			config.StarvationFrames = (config.StarvationFrames or 0) + 1

			if config.StarvationFrames > JITTER_WINDOW then
				-- Past jitter tolerance — stop the character authoritatively
				world:set(entity, components.INPUT_DIRECTION, Vector3.zero)
				world:set(entity, components.INPUT_FLAGS, 0)
			end
			-- Within jitter window: leave last input values in place
		end
	end
end

return {
	name = "InputBufferSystem",
	phase = pipelines.Phases.Input,
	system = inputBufferSystem,
}
