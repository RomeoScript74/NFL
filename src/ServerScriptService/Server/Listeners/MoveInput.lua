-- MoveInput.lua -- Server-side MoveInput ZAP listener.
-- Receive input packets from clients and enqueue them in INPUT_BUFFER.
-- Spawned during server startup.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local zap = require(ServerScriptService.Server.ZapServer)
local world = require(ReplicatedStorage.Code.Shared.World)
local components = require(ReplicatedStorage.Code.Shared.Components)
local ref = require(ReplicatedStorage.Packages["jecs-utils"]).ref

zap.MoveInput.SetCallback(function(player: Player, packet)
	local character = player.Character
	if not character then return end

	local charEntity = ref.find(character)
	if not charEntity then return end

	local inputBuffer = world:get(charEntity, components.INPUT_BUFFER)
	if not inputBuffer then return end

	for _, frame in packet.History do
		table.insert(inputBuffer, {
			X = frame.X,
			Z = frame.Z,
			Tick = frame.Tick,
			Yaw = frame.Yaw,
			Pitch = frame.Pitch,
			Flags = frame.Flags,
			RenderFrame = frame.RenderFrame,
		})
	end
end)

return {}
