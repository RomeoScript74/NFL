-- CharacterSetup.lua -- Roblox instance glue + ECS character creation.
-- Handles SetNetworkOwner, Anchored, PlatformStand, SetStateEnabled.
-- Then delegates ECS component setup to Prefabs.Character().
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ref = require(ReplicatedStorage.Packages["jecs-utils"]).ref
local jecs = require(ReplicatedStorage.Packages.jecs)
local world = require(ReplicatedStorage.Code.Shared.World)
local components = require(ReplicatedStorage.Code.Shared.Components)
local Prefabs = require(ReplicatedStorage.Code.Shared.Prefabs)
local replicationPrefabs = require(ReplicatedStorage.Code.Shared.ReplicationPrefabs)

local pair = jecs.pair

return function(character: Model, player: Player)
	local playerEntity = ref.find(player)
	if not playerEntity then return end

	local rootPart = character:WaitForChild("HumanoidRootPart")
	local humanoid = character:WaitForChild("Humanoid")

	-- Instance-level setup (non-ECS glue)
	rootPart:SetNetworkOwner(nil)
	rootPart.Anchored = true
	humanoid.PlatformStand = true
	humanoid.EvaluateStateMachine = false

	humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)

	-- Characters never touch Roblox physics or raycasts — position, collision, and floor are all ECS.
	-- CanCollide=false stops overlapping bodies (e.g. mid-tackle, when ECS collision is exempted) from
	-- physically colliding and jittering the model + camera. CanQuery=false keeps them out of floor
	-- raycasts (no stepping onto another player) AND the camera's occlusion raycast (no zoom-in when
	-- bodies overlap) — same treatment the ball already gets (see BallSetup).
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanQuery = false
		end
	end

	-- Create character entity and link to player
	local charEntity = world:entity()
	world:add(charEntity, pair(components.OwnedBy, playerEntity))

	-- Store char ref so MoveInput can look it up in O(1)
	ref.set(character, charEntity)

	-- ECS component setup (pure, reusable)
	Prefabs.Character(world, charEntity, rootPart, humanoid)
	replicationPrefabs.applyCharacter(world, charEntity, player)

	-- Clean up entity and ref when character despawns
	character.Destroying:Connect(function()
		ref.delete(character)
		if charEntity and world:contains(charEntity) then
			world:delete(charEntity)
		end
	end)
end
