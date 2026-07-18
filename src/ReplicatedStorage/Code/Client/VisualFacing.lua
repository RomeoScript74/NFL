-- VisualFacing.lua — Client visual helper. Smoothly turns a character's RENDERED rotation toward its
-- MOVEMENT direction (velocity), not its aim. YAW stays the gameplay aim (dash/tackle/throw/carry read
-- it); this only decides which way the body model points. Shared by the local (ClientVisualOffsetSystem)
-- and remote (RemoteVisualRotationSystem) render paths so both turn identically.
--
-- Convention matches CFrame.Angles(0, yaw, 0).LookVector = (-sin, 0, -cos): to face a horizontal
-- direction d, yaw = atan2(-d.X, -d.Z). Below a small speed the body HOLDS its last facing (a near-still
-- velocity has no meaningful direction to point at).

local VisualFacing = {}

local FACE_THRESHOLD = 0.5  -- horizontal studs/s below which facing holds (no movement direction)

-- Lerp currentRot toward the heading implied by vel; alpha is the fraction to move this frame (0..1).
function VisualFacing.rotateToward(currentRot: CFrame, vel: Vector3, alpha: number): CFrame
	local h = Vector3.new(vel.X, 0, vel.Z)
	if h.Magnitude < FACE_THRESHOLD then
		return currentRot
	end
	local targetYaw = math.atan2(-h.X, -h.Z)
	return currentRot:Lerp(CFrame.Angles(0, targetYaw, 0), alpha)
end

return VisualFacing
