local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")
local Resources = require(ReplicatedStorage.Code.Shared.Init.Resources)

local world = Resources.world
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local jecs = require(ReplicatedStorage.Packages.jecs)
local replecs = require(ReplicatedStorage.Packages.replecs)
local ref = require(ReplicatedStorage.Packages["jecs-utils"]).ref

local Prefabs = require(ReplicatedStorage.Code.Shared.Prefabs)
Prefabs.Interactions(world)

local _nodes = require(ReplicatedStorage.Code.Shared.Init.InitInteractions)
local _ref = require(ReplicatedStorage.Code.Shared.Init.Ref)
local _network = require(ServerScriptService.Server.Init.Networking)
local _playerAdded = require(ServerScriptService.Server.Init.PlayerAdded)()

-- Spawn ball from template asset; fallback to programmatic football
local ballTemplate = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Part")
local ballPart: Part
if ballTemplate and ballTemplate:IsA("BasePart") then
	ballPart = ballTemplate:Clone()
	ballPart.Name = "Football"
	ballPart.Anchored = true
	ballPart.Position = Vector3.new(0, 5, 0)
else
	ballPart = Instance.new("Part")
	ballPart.Name = "Football"
	ballPart.Size = Vector3.new(1, 0.5, 0.5)
	ballPart.Shape = Enum.PartType.Ball
	ballPart.BrickColor = BrickColor.new("Brown")
	ballPart.Anchored = true
	ballPart.Position = Vector3.new(0, 5, 0)
end
ballPart.Parent = Workspace

local replicationPrefabs = require(ReplicatedStorage.Code.Shared.ReplicationPrefabs)

local ballEntity = world:entity()
ref.set(ballPart, ballEntity)
world:set(ballEntity, components.INSTANCE, ballPart)
world:set(ballEntity, components.ROOTPART, ballPart)
world:set(ballEntity, components.POSITION, ballPart.Position)
world:set(ballEntity, components.VELOCITY, Vector3.zero)
world:set(ballEntity, components.GRAVITY_SCALE, 1)
world:set(ballEntity, components.LAST_PROCESSED_TICK, 0)
world:add(ballEntity, tags.BALL)
world:add(ballEntity, jecs.pair(replecs.reliable, tags.BALL))
replicationPrefabs.applyBall(world, ballEntity)

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
