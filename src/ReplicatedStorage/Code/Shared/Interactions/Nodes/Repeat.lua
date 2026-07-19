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

		-- STATELESS: iteration + delayRemaining live in ctx:nodeState(self). Between iterations we clear the
		-- child's whole subtree scratch via ctx:resetNode (replaces the old recursive child:reset()).
		execute = function(self, ctx)
			local s = ctx:nodeState(self)
			s.iteration = s.iteration or 0
			s.delayRemaining = s.delayRemaining or 0

			if s.delayRemaining > 0 then
				s.delayRemaining = s.delayRemaining - DT
				if s.delayRemaining > 0 then
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

			s.iteration = s.iteration + 1

			if s.iteration >= self.times then
				return SUCCESS
			end

			ctx:resetNode(self.child)
			if self.delay > 0 then
				s.delayRemaining = self.delay
				return RUNNING
			end

			return RUNNING
		end,
	}
end)

return nil
