-- BallSetup.lua — Spawns the single game ball. Module: call BallSetup.spawn().
-- Clones ReplicatedStorage.Assets.Part into Workspace and anchors it: the ball is
-- driven entirely by ECS (Gravity/Kinematic/BallGroundSystem), never Roblox physics.
-- CanQuery is disabled so it never registers as floor in other entities' raycasts.
-- The entity is replicated via applyBall; clients bind + interpolate it.
-- Registers a ref (part <-> entity) so any system can resolve one from the other.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local world = require(ReplicatedStorage.Code.Shared.World)
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local replicationPrefabs = require(ReplicatedStorage.Code.Shared.ReplicationPrefabs)
local ref = require(ReplicatedStorage.Packages["jecs-utils"]).ref

local SPAWN_POSITION = Vector3.new(0, 10, 0)

local BallSetup = {}

function BallSetup.spawn()
	local assets = ReplicatedStorage:WaitForChild("Assets")
	local template = assets:WaitForChild("Part")

	local ballPart = template:Clone()
	ballPart.Name = "Ball"
	ballPart.Anchored = true
	ballPart.CanCollide = false
	ballPart.CanQuery = false
	ballPart.CFrame = CFrame.new(SPAWN_POSITION)
	ballPart.Parent = Workspace

	local ballEntity = world:entity()
	world:add(ballEntity, tags.BALL)
	world:add(ballEntity, tags.WIND_AFFECTED)
	world:set(ballEntity, components.POSITION, SPAWN_POSITION)
	world:set(ballEntity, components.VELOCITY, Vector3.zero)
	world:set(ballEntity, components.GRAVITY_SCALE, 1.0)
	world:set(ballEntity, components.BOUNCINESS, 0.5)  -- 0 = dead, 1 = perfectly elastic
	world:set(ballEntity, components.ROOTPART, ballPart)
	world:set(ballEntity, components.INSTANCE, ballPart)
	-- Lets ServerStateStampSystem stamp SERVER_* for replication (value unused —
	-- the ball is never reconciled, only interpolated).
	world:set(ballEntity, components.LAST_PROCESSED_TICK, 0)

	replicationPrefabs.applyBall(world, ballEntity)

	-- Instance <-> entity mapping for O(1) lookup from either side
	-- (ref.find(ballPart) -> entity; world:get(entity, ROOTPART) -> ballPart).
	ref.set(ballPart, ballEntity)

	return ballEntity
end

return BallSetup
