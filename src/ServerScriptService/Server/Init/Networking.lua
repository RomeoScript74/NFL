-- Networking.lua -- Server networking setup.
-- Wires ZapServer, ReplecsServer, and Replicator in the correct order.
-- Just require once during startup. Mirrors Client/Init/Networking.lua.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local world = require(ReplicatedStorage.Code.Shared.World)

-- Wire up the networking stack
local zapServer = require(ServerScriptService.Server.ZapServer)
local replicator = require(ServerScriptService.Server.Replicator)
local _replecsServer = require(ServerScriptService.Server.ReplecsServer)

-- Register ZAP listeners (side-effect at require time)
local _moveInput = require(ServerScriptService.Server.Listeners.MoveInput)

replicator:init(world)

zapServer.WaitForServer.SetCallback(function(player)
	if replicator:is_player_ready(player) then
		return nil, nil, nil
	end
	replicator:mark_player_ready(player)
	return replicator:get_full(player)
end)

return {}
