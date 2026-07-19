-- HurdleCalc.lua — Shared hurdle LAUNCH math + the airborne window (mirrors DashCalc/TackleCalc).
-- Runs on BOTH realms and must stay bit-identical: HurdleLaunchSystem (client prediction AND server
-- authority) applies launchVelocity + starts a HURDLE_WINDOW_TICKS window, and the server's TackleSweep
-- node reads HURDLING (which lives for that window) to resolve a hurdle-over instead of a takedown — a
-- mismatch would desync every hurdle.
--
-- A hurdle is a VERTICAL launch: preserve horizontal momentum (you keep running forward), add an upward
-- burst, then gravity + integration make the parabola naturally. Unlike dash/tackle there is NO
-- ground-velocity exclusion — the launch leaves the ground immediately, and normal air control while
-- airborne is fine. The window is purely the anim/gate/immune duration, NOT a physics coast.
--
-- Slice 1: the WHOLE HURDLE_WINDOW is the tackle-immune window (no startup phase yet). The anti-reaction
-- tightening — a startup slice where you're airborne but still vulnerable, so only a PREDICTED hurdle
-- (committed before the dive) has its immune window open at contact — is the natural next tuning step:
-- split HURDLING into a startup tag then an immune tag. Ship the single window first, feel it, then split.

local HurdleCalc = {}

-- Tuning (gameplay feel — safe to change). Apex ≈ UP_SPEED^2 / (2 * gravity=196.2); UP_SPEED=50 → ~6.4
-- studs, clearing a defender (character vertical half-extent is 2.5, so >5 clears the collision cylinder).
HurdleCalc.HURDLE_UP_SPEED = 50               -- studs/s upward burst on fire (horizontal momentum preserved)
HurdleCalc.HURDLE_COOLDOWN_DURATION = 1.5     -- seconds before hurdle can re-fire (ticked by CooldownSystem)
-- HURDLING now ends on the ACTUAL landing (HurdleLaunchSystem removes it when IS_GROUNDED returns), so
-- the airborne arc is covered automatically regardless of UP_SPEED or terrain — no more tuning the window
-- to the arc. This value is only a SAFETY CAP: if a hurdler never lands (off the map), the tag can't leak
-- forever. Keep it comfortably longer than any real hurdle's air time (≈31 ticks @ UP_SPEED=50).
HurdleCalc.HURDLE_WINDOW_TICKS = 90

-- Vertical launch: keep the runner's horizontal velocity (carry your run into the vault), set Y to the
-- upward burst. Standing still hurdles straight up.
function HurdleCalc.launchVelocity(vel: Vector3): Vector3
	return Vector3.new(vel.X, HurdleCalc.HURDLE_UP_SPEED, vel.Z)
end

return HurdleCalc
