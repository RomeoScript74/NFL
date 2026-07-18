-- Serial.lua — Sequential container node.
-- Runs children one at a time: child1 -> child2 -> child3.
-- Returns FAILURE on first child failure (short-circuit).
-- Returns RUNNING if current child is still running.
-- Returns SUCCESS when all children succeed.
--
-- RunTime (framework-timed waiting): a child that SUCCEEDS but declares a RunTime (seconds) is HELD here
-- for that duration before Serial advances — the child is NOT re-executed during the hold. This is how a
-- `Wait { RunTime = 0.3 }` node waits: the FRAMEWORK times it (this container), the node never counts
-- ticks itself. Same field tickChain honors for top-level nodes, now honored inside the container too.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local FAILURE = NodeRegistry.FAILURE
local SUCCESS = NodeRegistry.SUCCESS
local RUNNING = NodeRegistry.RUNNING
local DT = 1 / 60  -- fixed physics step; matches InteractionSystem's DT

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
		_holdRemaining = nil,

		execute = function(self, ctx)
			while self.childIndex <= #self.children do
				-- Framework-timed hold: the current child SUCCEEDED with a RunTime → wait it out here
				-- (without re-executing the child), then advance. This is how a Wait node waits.
				if self._holdRemaining then
					self._holdRemaining -= DT
					if self._holdRemaining > 0 then
						return RUNNING
					end
					self._holdRemaining = nil
					self.childIndex = self.childIndex + 1
					continue
				end

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

				-- SUCCESS: if the child declares a RunTime, start holding it (advance after the duration);
				-- otherwise move on immediately.
				if child.RunTime and child.RunTime > 0 then
					self._holdRemaining = child.RunTime
				else
					self.childIndex = self.childIndex + 1
				end
			end

			return SUCCESS
		end,

		reset = function(self)
			self.childIndex = 1
			self._holdRemaining = nil
			for _, child in self.children do
				if child.reset then
					child:reset()
				end
			end
		end,
	}
end)

return nil
