-- ClockSyncSystem.lua -- Time-dilates server clock to keep client input buffer centered.
-- If buffer grows (client faster than server): slow server → client speeds up.
-- If buffer shrinks (client slower than server): speed server → client slows down.
-- Scale is replicated reliably to the client, applied to the physics accumulator.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local clockQuery = world:query(
	components.INPUT_BUFFER,
	components.CLOCK_SYNC,
	components.BUFFER_CONFIG
):cached()

local GAIN      = 0.006
local SCALE_MIN = 0.97
local SCALE_MAX = 1.03
local DEADZONE  = 2

local function clockSyncSystem()
	for entity, buffer, clock, config in clockQuery do
		local err = #buffer - config.TargetSize

		if math.abs(err) <= DEADZONE then
			err = 0
		end

		local scale = math.clamp(1.0 - (err * GAIN), SCALE_MIN, SCALE_MAX)

		clock.Scale = scale
		world:set(entity, components.CLOCK_SYNC, clock)
	end
end

return {
	name = "ClockSyncSystem",
	phase = pipelines.Phases.Timers,
	system = clockSyncSystem,
}
