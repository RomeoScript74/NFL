-- init.lua — Player/character setup entry point. For each player (and each of their characters), runs
-- every handler module under this script's PlayerAdded/ and CharacterAdded/ folders.
--
-- The catch-up is the load-bearing part. `PlayerAdded`/`CharacterAdded` only fire for arrivals AFTER we
-- connect, so anyone already present when this runs — e.g. a player who joined during server boot, common
-- in Team Test — would be skipped. So we ALSO run setup for whoever is already here. Without it, the first
-- player gets no PlayerSetup/CharacterSetup: no PLAYER entity, nothing networked, empty full-sync — the
-- "first player broken, second fine" race (timing-sensitive, no error). This same connect-plus-catch-up
-- shape is used for players (via GetPlayers) and for each player's character (via player.Character).

local Players = game:GetService("Players")

-- Run every handler module in `folder`, passing it `...`. Each module returns a function(...); each is
-- spawned so one slow or erroring handler can't block the others.
local function runHandlers(folder: Instance, ...)
	for _, moduleScript in folder:GetChildren() do
		if moduleScript:IsA("ModuleScript") then
			task.spawn(require(moduleScript) :: (...any) -> (), ...)
		end
	end
end

return function()
	-- A player can be reached by both the signal and the catch-up (a join in the sliver between). Dedupe
	-- so their setup runs exactly once.
	local didSetup = {}

	local function setupCharacter(character: Model, player: Player)
		runHandlers(script.CharacterAdded, character, player)
	end

	local function setupPlayer(player: Player)
		if didSetup[player] then
			return
		end
		didSetup[player] = true

		runHandlers(script.PlayerAdded, player)

		-- Same connect + catch-up for this player's character: future spawns via the event, plus the one
		-- already present (the event won't refire for it).
		player.CharacterAdded:Connect(function(character)
			setupCharacter(character, player)
		end)
		if player.Character then
			setupCharacter(player.Character, player)
		end
	end

	-- Future joins via the event; everyone already here via GetPlayers().
	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(setupPlayer, player)
	end
end
