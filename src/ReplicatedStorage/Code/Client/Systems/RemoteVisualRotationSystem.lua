-- RemoteVisualRotationSystem.lua — Smoothly lerps remote entity rotation toward YAW.
-- Runs on non-PREDICTED entities. Preserves position set by RemoteVisualInterpolator.
-- Both systems write to rootPart.CFrame but on orthogonal axes — order-independent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local phase = require(ReplicatedStorage.Packages["planck-runservice"]).Phases

local ROTATION_SPEED = 12.0
local MAX_RENDER_DT = 0.100
local DT_SMOOTHING = 0.8

local lastFrameTime = os.clock()
local smoothedDt = 1 / 60

local rotationQuery = world:query(
	components.ROOTPART,
	components.YAW
):without(tags.PREDICTED):cached()

local function remoteVisualRotationSystem()
	local now = os.clock()
	local rawDt = now - lastFrameTime
	lastFrameTime = now
	smoothedDt = smoothedDt * DT_SMOOTHING + rawDt * (1 - DT_SMOOTHING)
	local dt = math.min(smoothedDt, MAX_RENDER_DT)

	for _entity, rootPart, yaw in rotationQuery do
		local currentRot = rootPart.CFrame.Rotation
		local targetRot = CFrame.Angles(0, yaw, 0)
		local newRot = currentRot:Lerp(targetRot, math.min(ROTATION_SPEED * dt, 1.0))

		-- Preserve position (set by RemoteVisualInterpolator)
		rootPart.CFrame = CFrame.new(rootPart.Position) * newRot
	end
end

return {
	name = "RemoteVisualRotationSystem",
	phase = phase.PreRender,
	system = remoteVisualRotationSystem,
}
