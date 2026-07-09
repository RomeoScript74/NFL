local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Resources = require(ReplicatedStorage.Code.Shared.Init.Resources)

local world = Resources.world

local Prefabs = require(ReplicatedStorage.Code.Shared.Prefabs)
Prefabs.Interactions(world)

local _nodes = require(ReplicatedStorage.Code.Shared.Init.InitInteractions)
local _ref = require(ReplicatedStorage.Code.Shared.Init.Ref)
local _network = require(ServerScriptService.Server.Init.Networking)
local _playerAdded = require(ServerScriptService.Server.Init.PlayerAdded)()

-- Spawn the game ball (server-authoritative, replicated to all clients).
local _ball = require(ServerScriptService.Server.Init.BallSetup).spawn()

-- Initialize global wind singleton.
local _wind = require(ServerScriptService.Server.Init.WindInit).init()

local startUp = require(ReplicatedStorage.Code.Shared.Init.StartUp)

local systems = {}

local function addSystems(folder)
	for _, child in folder:GetChildren() do
		if not child:IsA("ModuleScript") then
			continue
		end

		local ok, mod = pcall(require, child)
		if ok and mod then
			table.insert(systems, mod)
		else
			warn("ServerStartup: failed to require system:", child:GetFullName(), mod)
		end
	end
end

addSystems(ReplicatedStorage.Code.Shared.Systems)
addSystems(ServerScriptService.Server.Systems)

startUp(systems)
