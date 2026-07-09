-- PlayerSetup.lua -- Creates the player entity on PlayerAdded.
-- Maps Player instance → ECS entity via jecs-utils ref.
-- Entity MUST be networked so the client can find its local player.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ref = require(ReplicatedStorage.Packages["jecs-utils"]).ref
local jecs = require(ReplicatedStorage.Packages.jecs)
local replecs = require(ReplicatedStorage.Packages.replecs)
local world = require(ReplicatedStorage.Code.Shared.World)
local components = require(ReplicatedStorage.Code.Shared.Components)

return function(player: Player)
	local playerEntity = ref.get(player, function(entity)
		world:set(entity, components.PLAYER, player)
		world:add(entity, replecs.networked)
		world:add(entity, jecs.pair(replecs.reliable, components.PLAYER))
	end)
	
	-- Clean up entity when player leaves
	player.AncestryChanged:Connect(function(_, parent)
		if not parent then
			if world:contains(playerEntity) then
				world:delete(playerEntity)
			end
			ref.delete(player)
		end
	end)
end
