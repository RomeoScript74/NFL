-- Repeat.lua — Loop container. Repeats child N times.
-- Config: { Times = N, Delay = seconds, Guard = nodeConfig, Children = {...} }
-- Delay between iterations (0 = immediate).
-- Guard is optional — checks before each iteration, exits on FAILURE.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local SUCCESS = NodeRegistry.SUCCESS
local RUNNING = NodeRegistry.RUNNING
local DT = 1 / 60

NodeRegistry.register("Repeat", function(config)
	local child = NodeRegistry.build({ Type = "Serial", Children = config.Children })
	local guard = config.Guard and NodeRegistry.build(config.Guard) or nil

	return {
		Type = "Repeat",
		times = config.Times or 1,
		delay = config.Delay or 0,
		guard = guard,
		child = child,
		iteration = 0,
		delayRemaining = 0,

		execute = function(self, ctx)
			if self.delayRemaining > 0 then
				self.delayRemaining = self.delayRemaining - DT
				if self.delayRemaining > 0 then
					return RUNNING
				end
			end

			if self.guard then
				local guardStatus = self.guard:execute(ctx)
				if guardStatus ~= SUCCESS then
					return SUCCESS
				end
			end

			local status = self.child:execute(ctx)

			if status == RUNNING then
				return RUNNING
			end

			self.iteration = self.iteration + 1

			if self.iteration >= self.times then
				return SUCCESS
			end

			self.child:reset()
			if self.delay > 0 then
				self.delayRemaining = self.delay
				return RUNNING
			end

			return RUNNING
		end,

		reset = function(self)
			self.iteration = 0
			self.delayRemaining = 0
			if self.child.reset then
			self.child:reset()
		end
		end,
	}
end)

return nil
