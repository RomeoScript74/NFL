-- Parallel.lua — Parallel container node.
-- Runs all children simultaneously each tick.
-- Returns FAILURE if any child fails.
-- Returns RUNNING if any child is still running.
-- Returns SUCCESS when all children succeed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local FAILURE = NodeRegistry.FAILURE
local SUCCESS = NodeRegistry.SUCCESS
local RUNNING = NodeRegistry.RUNNING

NodeRegistry.register("Parallel", function(config)
	local children = {}
	if config.Children then
		for i, child in config.Children do
			children[i] = NodeRegistry.build(child)
		end
	end

	return {
		Type = "Parallel",
		children = children,

		execute = function(self, ctx)
			local anyRunning = false
			for _, child in self.children do
				local status = child:execute(ctx)
				if status == FAILURE then
					return FAILURE
				elseif status == RUNNING then
					anyRunning = true
				end
			end
			return if anyRunning then RUNNING else SUCCESS
		end,

		reset = function(self)
			for _, child in self.children do
				if child.reset then
				child:reset()
			end
			end
		end,
	}
end)

return nil
