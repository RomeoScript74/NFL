-- ClientVisualOffsetSystem.lua — Applies ECS POSITION + YAW to the Roblox model.
-- Applies VISUAL_OFFSET so reconciliation corrections don't visibly teleport.
-- Runs on MainScheduler PostSimulation (after physics, before render).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local phase = require(ReplicatedStorage.Packages["planck-runservice"]).Phases

local VISUAL_OFFSET_DECAY = 0.88

local visualQuery = world:query(
	components.POSITION,
	components.VISUAL_OFFSET,
	components.ROOTPART,
	components.YAW
):with(tags.PREDICTED):cached()

local function clientVisualOffsetSystem()
	for entity, pos, visualOffset, rootPart, yaw in visualQuery do
		-- Smooth offset toward zero so the character doesn't visibly snap
		if visualOffset.Magnitude > 0.01 then
			visualOffset = visualOffset * VISUAL_OFFSET_DECAY
			world:set(entity, components.VISUAL_OFFSET, visualOffset)
		elseif visualOffset.Magnitude > 0 then
			world:set(entity, components.VISUAL_OFFSET, Vector3.zero)
		end

		local targetRot = CFrame.Angles(0, yaw, 0)
		rootPart.CFrame = CFrame.new(pos + visualOffset) * targetRot
	end
end

return {
	name = "ClientVisualOffsetSystem",
	phase = phase.PostSimulation,
	system = clientVisualOffsetSystem,
}
