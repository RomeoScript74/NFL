local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Resources = require(ReplicatedStorage.Code.Shared.Init.Resources)

local world = Resources.world

-- Set up NFL interaction definitions on shared def entities
local Prefabs = require(ReplicatedStorage.Code.Shared.Prefabs)
Prefabs.Interactions(world)

-- Wait for local character to fully stream before ECS arrives.
-- We're inside StarterCharacterScripts, so player.Character is guaranteed
-- to exist (and be the local character). WaitForChild("HRP") blocks until
-- the HumanoidRootPart streams — after this point, FindFirstChild is instant.
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local _hrp = character:WaitForChild("HumanoidRootPart")

local _nodes = require(ReplicatedStorage.Code.Shared.Init.InitInteractions)
local _ref = require(ReplicatedStorage.Code.Shared.Init.Ref)
local _remoteInterp = require(ReplicatedStorage.Code.Client.Init.RemoteInterpolationInit)()
local _ballInterp = require(ReplicatedStorage.Code.Client.Init.BallInterpolationInit)()
local _ballInit = require(ReplicatedStorage.Code.Client.Init.BallInit)()
local _animLoader = require(ReplicatedStorage.Code.Client.Init.AnimationLoaderInit)()
local _network = require(ReplicatedStorage.Code.Client.Init.Networking)

-- apply_full has completed, all ECS entities exist. Resolve ROOTPART + promote local.
local _initAllCharacters = require(ReplicatedStorage.Code.Client.Init.CharacterInitializer)()
local _initClientPipelines = require(ReplicatedStorage.Code.Client.Init.InitPipelines)
local _tick = require(ReplicatedStorage.Code.Client.Init.Tick)
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
			warn("ClientStartup: failed to require system:", child:GetFullName(), mod)
		end
	end
end

addSystems(ReplicatedStorage.Code.Shared.Systems)
addSystems(ReplicatedStorage.Code.Client.Systems)

startUp(systems)
