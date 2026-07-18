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

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsCalc = require(ReplicatedStorage.Code.Shared.PhysicsCalc)

local TackleCalc = {}

-- Tuning (gameplay feel — safe to change).
local LAUNCH_SPEED = 40  -- studs/s forward burst applied to the tackler on fire

TackleCalc.LAUNCH_SPEED        = LAUNCH_SPEED
TackleCalc.TACKLE_WINDOW_TICKS = 24   -- ticks the launch coasts forward = the whole dive (~0.4s @60Hz); also the contact window. Distance ≈ LAUNCH_SPEED*this/60 (=16 studs). Tune BOTH to your dive animation: raise for a longer/further dive that's easier to land, lower for a quick lunge.

-- Launch burst along the movement heading (where the body faces), input dir then camera yaw as
-- fallbacks — see PhysicsCalc.launchHeading (shared with DashCalc). Vertical velocity is preserved so
-- the lunge never cancels gravity or an in-progress jump.
function TackleCalc.launchVelocity(vel: Vector3, inputDir: Vector3, yaw: number): Vector3
	local dir = PhysicsCalc.launchHeading(vel, inputDir, yaw)
	return Vector3.new(dir.X * LAUNCH_SPEED, vel.Y, dir.Z * LAUNCH_SPEED)
end

return TackleCalc
