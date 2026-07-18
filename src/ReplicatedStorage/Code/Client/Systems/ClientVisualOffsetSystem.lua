-- ClientVisualOffsetSystem.lua — Applies ECS POSITION to the local predicted model, plus VISUAL_OFFSET
-- so reconciliation corrections don't visibly teleport. Rotation faces the MOVEMENT direction, read from
-- the smoothed VISUAL_VELOCITY (so recon velocity snaps don't twitch the facing) — not the camera aim
-- (YAW); YAW stays the gameplay aim for dash/tackle/throw.
-- Runs on MainScheduler PostSimulation (after physics, before render), so it reads settled state once
-- per frame — reconciliation's replay can't spin it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local VisualFacing = require(ReplicatedStorage.Code.Client.VisualFacing)
local phase = require(ReplicatedStorage.Packages["planck-runservice"]).Phases

local VISUAL_OFFSET_DECAY = 0.88
local ROTATION_SPEED = 12.0
local MAX_RENDER_DT = 0.100
local DT_SMOOTHING = 0.8

local lastFrameTime = os.clock()
local smoothedDt = 1 / 60

local visualQuery = world:query(
	components.POSITION,
	components.VISUAL_OFFSET,
	components.ROOTPART,
	components.VISUAL_VELOCITY
):with(tags.PREDICTED):cached()

local function clientVisualOffsetSystem()
	local now = os.clock()
	local rawDt = now - lastFrameTime
	lastFrameTime = now
	smoothedDt = smoothedDt * DT_SMOOTHING + rawDt * (1 - DT_SMOOTHING)
	local dt = math.min(smoothedDt, MAX_RENDER_DT)
	local alpha = math.min(ROTATION_SPEED * dt, 1.0)

	for entity, pos, visualOffset, rootPart, vel in visualQuery do
		-- Smooth offset toward zero so the character doesn't visibly snap
		if visualOffset.Magnitude > 0.01 then
			visualOffset = visualOffset * VISUAL_OFFSET_DECAY
			world:set(entity, components.VISUAL_OFFSET, visualOffset)
		elseif visualOffset.Magnitude > 0 then
			world:set(entity, components.VISUAL_OFFSET, Vector3.zero)
		end

		local newRot = VisualFacing.rotateToward(rootPart.CFrame.Rotation, vel, alpha)
		rootPart.CFrame = CFrame.new(pos + visualOffset) * newRot
	end
end

return {
	name = "ClientVisualOffsetSystem",
	phase = phase.PostSimulation,
	system = clientVisualOffsetSystem,
}
