-- init.lua -- PlayerAdded entry point.
-- Connects to PlayerAdded and CharacterAdded, spawns the handler modules.

return function()
	local Players = game:GetService("Players")

	Players.PlayerAdded:Connect(function(player)
		for _, moduleScript in script.PlayerAdded:GetChildren() do
			if moduleScript:IsA("ModuleScript") then
				local module = require(moduleScript)
				task.spawn(module, player)
			end
		end

		player.CharacterAdded:Connect(function(character)
			for _, moduleScript in script.CharacterAdded:GetChildren() do
				if moduleScript:IsA("ModuleScript") then
					local module = require(moduleScript)
					task.spawn(module, character, player)
				end
			end
		end)
	end)
end
