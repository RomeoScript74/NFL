-- RemoteVisualRotationSystem.lua — Smoothly turns remote entities to face their MOVEMENT direction,
-- read from the smoothed VISUAL_VELOCITY (VisualVelocitySystem folds remotes' SERVER_VELOCITY into it).
-- Not the aim (YAW).
-- Runs on non-PREDICTED entities. Preserves position set by RemoteVisualInterpolator — both write
-- rootPart.CFrame but on orthogonal axes (this only rotation), so they're order-independent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local VisualFacing = require(ReplicatedStorage.Code.Client.VisualFacing)
local phase = require(ReplicatedStorage.Packages["planck-runservice"]).Phases

local ROTATION_SPEED = 12.0
local MAX_RENDER_DT = 0.100
local DT_SMOOTHING = 0.8

local lastFrameTime = os.clock()
local smoothedDt = 1 / 60

local rotationQuery = world:query(
	components.ROOTPART,
	components.VISUAL_VELOCITY
):without(tags.PREDICTED):cached()

local function remoteVisualRotationSystem()
	local now = os.clock()
	local rawDt = now - lastFrameTime
	lastFrameTime = now
	smoothedDt = smoothedDt * DT_SMOOTHING + rawDt * (1 - DT_SMOOTHING)
	local dt = math.min(smoothedDt, MAX_RENDER_DT)
	local alpha = math.min(ROTATION_SPEED * dt, 1.0)

	for _entity, rootPart, vel in rotationQuery do
		-- Preserve position (set by RemoteVisualInterpolator); only rotation changes here.
		local newRot = VisualFacing.rotateToward(rootPart.CFrame.Rotation, vel, alpha)
		rootPart.CFrame = CFrame.new(rootPart.Position) * newRot
	end
end

return {
	name = "RemoteVisualRotationSystem",
	phase = phase.PreRender,
	system = remoteVisualRotationSystem,
}
