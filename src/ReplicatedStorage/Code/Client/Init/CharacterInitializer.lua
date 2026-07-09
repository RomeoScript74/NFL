-- CharacterInitializer.lua — Resolves ROOTPART + promotes local character.
-- Called after apply_full (initial batch) and via replicator:added hook (ongoing).
-- Safe to call at any time — skips entities that already have PREDICTED or ROOTPART.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local world = require(ReplicatedStorage.Code.Shared.World)
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local ref = require(ReplicatedStorage.Packages["jecs-utils"]).ref
local Prefabs = require(ReplicatedStorage.Code.Shared.Prefabs)
local replicator = require(ReplicatedStorage.Code.Client.Replicator)

local function initAllCharacters()
	for charEntity in world:query(components.SERVER_POSITION) do
		if world:has(charEntity, tags.PREDICTED) then continue end
		if world:has(charEntity, components.ROOTPART) then continue end

		local playerEntity = world:target(charEntity, components.OwnedBy)
		if not playerEntity then continue end
		local player = world:get(playerEntity, components.PLAYER)
		if not player then continue end
		if not player.Character then continue end
		local hrp = player.Character:FindFirstChild("HumanoidRootPart")
		if not hrp then continue end

		world:set(charEntity, components.ROOTPART, hrp)

		if player == Players.LocalPlayer then
			ref.set(player.Character, charEntity)
			world:add(charEntity, tags.LOCAL_CHARACTER)
			Prefabs.PredictedCharacter(world, charEntity, hrp)
		end
	end
end

-- Ongoing batches: registered once at module load.
replicator:added(function(_entity)
	replicator:after_replication(initAllCharacters)
end)

return initAllCharacters
