-- BallAttachmentSystem.lua — Client: renders a carried ball at its carrier's hand.
-- A carried ball is PHYSICS_DISABLED (so RemoteVisualInterpolator skips it) and carries a
-- replicated CARRIED_BY relation to its carrier. Each frame we place the ball at the
-- carrier's rendered rootpart + carry offset — which is the carrier's PREDICTED transform
-- if it's the local player, or its INTERPOLATED transform if remote. So the held ball
-- inherits the right smoothness for free, with no ball prediction. PreRender phase.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local phase = require(ReplicatedStorage.Packages["planck-runservice"]).Phases
local Carry = require(ReplicatedStorage.Code.Shared.Carry)

-- Yaw-only offset (rootpart CFrame already carries the carrier's facing, no pitch).
local OFFSET_CF = CFrame.new(Carry.OFFSET)

local carriedQuery = world:query(
	components.ROOTPART
):with(tags.BALL, tags.PHYSICS_DISABLED):cached()

local function ballAttachmentSystem()
	for ball, ballPart in carriedQuery do
		local carrier = world:target(ball, components.CARRIED_BY)
		if not carrier then continue end

		local carrierRoot = world:get(carrier, components.ROOTPART)
		if not carrierRoot then continue end

		ballPart.CFrame = carrierRoot.CFrame * OFFSET_CF
	end
end

return {
	name = "BallAttachmentSystem",
	phase = phase.PreRender,
	system = ballAttachmentSystem,
}
