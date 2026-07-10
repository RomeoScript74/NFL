-- Carry.lua — Shared carry geometry, so server and client agree on where a carried
-- ball sits. OFFSET is carrier-local (forward/up). The hand position uses YAW only —
-- the character body doesn't pitch when you look up, so the held ball tracks the body's
-- facing (matching how the client renders rootPart.CFrame). Throw *direction* uses pitch
-- separately (see ThrowSystem); only the launch origin comes from here.

local Carry = {}

Carry.OFFSET = Vector3.new(0, 0.5, -2.5)  -- 2.5 studs in front, 0.5 up

function Carry.handPosition(carrierPos: Vector3, yaw: number): Vector3
	return carrierPos + CFrame.fromEulerAnglesYXZ(0, yaw, 0):VectorToWorldSpace(Carry.OFFSET)
end

return Carry
