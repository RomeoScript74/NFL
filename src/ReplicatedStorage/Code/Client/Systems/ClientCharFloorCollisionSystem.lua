-- ClientCharFloorCollisionSystem.lua — Client-side floor collision prediction.
-- Mirrors server CharFloorCollisionSystem but filters to PREDICTED entities only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local PhysicsCalc = require(ReplicatedStorage.Code.Shared.PhysicsCalc)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local collisionQuery = world:query(
	components.POSITION,
	components.VELOCITY,
	components.ROOTPART,
	components.HIP_HEIGHT
):with(tags.PREDICTED):cached()

local FIXED_DT = 1 / 60

local function clientCharFloorCollisionSystem()
	for entity, pos, vel, root, hip in collisionQuery do
		local newPos, newVel, isGrounded, floorNormal =
			PhysicsCalc.resolveFloorCollision(pos, vel, hip, root, FIXED_DT)

		world:set(entity, components.POSITION, newPos)
		world:set(entity, components.VELOCITY, newVel)

		if isGrounded and floorNormal then
			world:set(entity, components.FLOOR_NORMAL, floorNormal)
			world:add(entity, tags.IS_GROUNDED)
		else
			world:remove(entity, components.FLOOR_NORMAL)
			world:remove(entity, tags.IS_GROUNDED)
		end
	end
end

return {
	name = "ClientCharFloorCollisionSystem",
	phase = pipelines.Phases.Collision,
	system = clientCharFloorCollisionSystem,
}
