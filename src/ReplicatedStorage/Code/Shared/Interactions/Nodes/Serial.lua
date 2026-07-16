-- Serial.lua — Sequential container node.
-- Runs children one at a time: child1 -> child2 -> child3.
-- Returns FAILURE on first child failure (short-circuit).
-- Returns RUNNING if current child is still running.
-- Returns SUCCESS when all children succeed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local FAILURE = NodeRegistry.FAILURE
local SUCCESS = NodeRegistry.SUCCESS
local RUNNING = NodeRegistry.RUNNING

NodeRegistry.register("Serial", function(config)
	local children = {}
	if config.Children then
		for i, child in config.Children do
			children[i] = NodeRegistry.build(child)
		end
	end

	return {
		Type = "Serial",
		children = children,
		childIndex = 1,

		execute = function(self, ctx)
			while self.childIndex <= #self.children do
				local child = self.children[self.childIndex]
				-- A realm-gated child (side="server"/"client") that doesn't belong here counts as an
				-- automatic pass-through — same as tickChain's top-level skip behavior.
				local status = NodeRegistry.isSkipped(child) 
				and SUCCESS or child:execute(ctx)

				if status == FAILURE then
					return FAILURE
				elseif status == RUNNING then
					return RUNNING
				end

				self.childIndex = self.childIndex + 1
			end

			return SUCCESS
		end,

		reset = function(self)
			self.childIndex = 1
			for _, child in self.children do
				if child.reset then
				child:reset()
			end
			end
		end,
	}
end)

return nil
