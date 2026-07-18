-- DashCalc.lua — Pure dash helpers + tuning, used by the shared DashImpulseSystem so client
-- prediction and server authority run identical burst math (mirrors PhysicsCalc).
--
-- Dash = a horizontal velocity burst held for a fixed window, then released. Distance is
-- deterministic (DASH_SPEED * DASH_WINDOW_TICKS / 60) because the DASHING tag excludes the
-- character from CharGroundVelocitySystem for the window, so nothing decelerates the burst.
-- The window is a pair(TIMER, DASH_WINDOW) counted down by the generic TimerSystem; the re-fire
-- cooldown is a separate pair(COOLDOWN, CD_DASH). Both are independent.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsCalc = require(ReplicatedStorage.Code.Shared.PhysicsCalc)

local DashCalc = {}

-- Tuning (gameplay feel — safe to change).
DashCalc.DASH_SPEED = 70                -- studs/s horizontal burst
DashCalc.DASH_COOLDOWN_DURATION = 1.0   -- seconds before dash can re-fire (ticked by CooldownSystem)
DashCalc.DASH_WINDOW_TICKS = 12         -- physics ticks the burst is held (0.2s @ 60Hz); distance ≈ SPEED * TICKS/60 ≈ 14 studs

-- Horizontal burst along the movement heading (where the body faces), input dir then camera yaw as
-- fallbacks — see PhysicsCalc.launchHeading. Vertical velocity is preserved so the dash never cancels
-- jumps or gravity.
function DashCalc.dashVelocity(vel: Vector3, inputDir: Vector3, yaw: number): Vector3
	local dashDir = PhysicsCalc.launchHeading(vel, inputDir, yaw)
	return Vector3.new(dashDir.X * DashCalc.DASH_SPEED, vel.Y, dashDir.Z * DashCalc.DASH_SPEED)
end

return DashCalc
