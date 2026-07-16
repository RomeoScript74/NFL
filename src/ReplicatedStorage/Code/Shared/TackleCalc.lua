-- TackleCalc.lua — Shared tackle LAUNCH math + the shared coast/contact window (mirrors DashCalc).
-- Everything here runs on BOTH realms and must stay bit-identical: TackleLaunchSystem (client
-- prediction AND server authority) applies launchVelocity and starts a TACKLE_WINDOW_TICKS coast, and
-- the server's TackleSweep node sweeps for contact over that SAME window — a mismatch would desync
-- every tackle. The launch is a forward velocity burst held for the window (TACKLING excludes the
-- tackler from CharGroundVelocitySystem, so nothing decelerates it), giving a deterministic lunge
-- distance ≈ LAUNCH_SPEED * TACKLE_WINDOW_TICKS / 60.
--
-- Server-only RESOLVE tuning (stun duration, grab reach, favor-the-runner lead) is deliberately NOT
-- here — it has a single server-side consumer (the TackleSweep node) with no cross-realm value to
-- keep in sync, so it lives as locals in that node, not in this shared module.

local TackleCalc = {}

-- Tuning (gameplay feel — safe to change).
local LAUNCH_SPEED = 40  -- studs/s forward burst applied to the tackler on fire

TackleCalc.LAUNCH_SPEED        = LAUNCH_SPEED
TackleCalc.TACKLE_WINDOW_TICKS = 12   -- ticks the launch coasts (~0.2s @60Hz); also the dive's contact window

-- Horizontal facing unit vector from a yaw angle (matches DashCalc's yaw form / CFrame LookVector).
function TackleCalc.forwardFromYaw(yaw: number): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

-- Forward launch burst along facing; vertical velocity is preserved so the lunge never cancels
-- gravity or an in-progress jump.
function TackleCalc.launchVelocity(vel: Vector3, yaw: number): Vector3
	local f = TackleCalc.forwardFromYaw(yaw)
	return Vector3.new(f.X * LAUNCH_SPEED, vel.Y, f.Z * LAUNCH_SPEED)
end

return TackleCalc
