-- BallInterpolationSystem.lua — Renders the ball smoothly from the SERVER_* snapshot
-- stream. Split from RemoteVisualInterpolator so the ball is tuned independently of
-- characters (it moves far faster and re-enters interpolation after a throw). Same
-- snapshot-buffer + Hermite approach; the one ball-specific bit today is clamping the
-- single-snapshot extrapolation to elapsed >= 0, so a freshly-thrown ball (its clock seeded
-- at launch by BallInterpolationInit) extrapolates FORWARD, never backward toward the
-- thrower. This file is where future ball-only interpolation tuning goes. PreRender.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local phase = require(ReplicatedStorage.Packages["planck-runservice"]).Phases

local FIXED_DT = 1 / 60
local BUFFER_DELAY = 0.150
local MAX_RENDER_DT = 0.100
local MAX_CATCHUP_SPEED = 1.3
local CATASTROPHIC_THRESHOLD = 0.5
local DRIFT_GAIN = 0.8
local DRIFT_SMOOTHING = 0.05
local DT_SMOOTHING = 0.8
local MAX_EXTRAP_TIME = 0.5
local TELEPORT_THRESHOLD = 20
local MAX_SNAPSHOTS = 30

local lastFrameTime = os.clock()
local smoothedDt = FIXED_DT

-- Ball gravity, for parabolic single-snapshot extrapolation. Must match
-- PhysicsCalc.BASE_GRAVITY (196.2) * the ball's GRAVITY_SCALE (1.0) so an extrapolated
-- frame lands exactly on the arc the server computed.
local BALL_GRAVITY = Vector3.new(0, -196.2, 0)

-- Throw re-entry blend: when the ball leaves the carrier it jumps from the hand to where
-- the authoritative ball already is (~150ms into the arc, because that's how long the
-- throw took to replicate back). Slide across that gap over BLEND_TIME so it reads as the
-- ball shooting out of the hand, instead of teleporting.
local BLEND_TIME = 0.12
local blendFrom: { [any]: Vector3 } = {}  -- entity -> hand position while blending, nil otherwise
local blendT: { [any]: number } = {}      -- entity -> elapsed blend seconds
local seenFrame: { [any]: number } = {}   -- entity -> frame index last rendered (detects re-entry)
local frameIndex = 0

local function hermiteLerp(p0: Vector3, v0: Vector3, p1: Vector3, v1: Vector3, gap: number, t: number): Vector3
	local t2 = t * t
	local t3 = t2 * t
	return  p0  *   (2 * t3 - 3 * t2 + 1)
		+   v0  *   gap * (t3 - 2 * t2 + t)
		+   p1  *   (-2 * t3 + 3 * t2)
		+   v1  *   gap * (t3 - t2)
end

local ballQuery = world:query(
	components.REMOTE_TICK,
	components.SERVER_POSITION,
	components.SERVER_VELOCITY,
	components.SNAPSHOT_BUFFER,
	components.INTERPOLATION_CLOCK,
	components.INTERP_DRIFT,
	components.INTERP_LAST_CLOCK,
	components.ROOTPART
):with(tags.BALL):without(tags.PREDICTED, tags.PHYSICS_DISABLED):cached()

local function ballInterpolationSystem()
	local now = os.clock()
	local rawDt = now - lastFrameTime
	lastFrameTime = now
	smoothedDt = smoothedDt * DT_SMOOTHING + rawDt * (1 - DT_SMOOTHING)
	local dt = math.min(smoothedDt, MAX_RENDER_DT)
	frameIndex += 1

	for entity, tick, pos, vel, buffer, renderClock, avgDrift, lastClock, rootPart in ballQuery do
		local serverTime = tick * FIXED_DT

		-- New snapshot arrived (buffer is already initialized by BallInterpolationInit)
		if #buffer == 0 or buffer[#buffer].Time < serverTime then
			-- Teleport check: if the ball jumped, clear buffer and reset clock
			if #buffer > 0 and (pos - buffer[#buffer].Pos).Magnitude > TELEPORT_THRESHOLD then
				table.clear(buffer)
				renderClock = serverTime - BUFFER_DELAY
				avgDrift = 0
			end

			table.insert(buffer, { Time = serverTime, Pos = pos, Vel = vel })
			while #buffer > MAX_SNAPSHOTS do
				table.remove(buffer, 1)
			end
		end

		if #buffer == 0 then continue end

		-- Advance render clock toward target (newest snapshot - delay)
		local newestSnap = buffer[#buffer]
		local targetTime = newestSnap.Time - BUFFER_DELAY
		local rawDrift = targetTime - renderClock
		avgDrift = avgDrift + (rawDrift - avgDrift) * DRIFT_SMOOTHING

		if math.abs(avgDrift) > CATASTROPHIC_THRESHOLD then
			-- Hard snap — drift is too large for gradual correction
			renderClock = targetTime
			avgDrift = 0
		else
			local speed = math.clamp(1.0 + avgDrift * DRIFT_GAIN, 0.5, MAX_CATCHUP_SPEED)
			renderClock = renderClock + dt * speed
		end

		-- Monotonic guard: clock never goes backward
		if renderClock < lastClock then
			renderClock = lastClock
		end

		world:set(entity, components.INTERPOLATION_CLOCK, renderClock)
		world:set(entity, components.INTERP_DRIFT, avgDrift)
		world:set(entity, components.INTERP_LAST_CLOCK, renderClock)

		-- Discard snapshots older than render clock
		while #buffer >= 2 and buffer[2].Time < renderClock do
			table.remove(buffer, 1)
		end

		local targetPos: Vector3

		if #buffer >= 2 then
			-- Hermite interpolation between two snapshots
			local older, newer = buffer[1], buffer[2]
			local gap = newer.Time - older.Time
			if gap > 0.0001 then
				local alpha = math.clamp((renderClock - older.Time) / gap, 0, 1)
				targetPos = hermiteLerp(older.Pos, older.Vel, newer.Pos, newer.Vel, gap, alpha)
			else
				targetPos = newer.Pos
			end
		elseif #buffer == 1 then
			-- Extrapolate past a single snapshot along the ACTUAL parabola (velocity +
			-- gravity), not a damped straight line. The ball is under constant gravity, so
			-- linear extrapolation sags below the arc and snaps back up when the next
			-- snapshot lands — the "jerking down". The parabolic form stays exactly on the
			-- arc, so buf==1 frames render seamlessly with the Hermite segments around them.
			-- elapsed clamped to [0, MAX_EXTRAP_TIME]: negative would render before launch;
			-- capped so a stalled stream freezes on the arc instead of flinging off it.
			local snap = buffer[1]
			local elapsed = math.clamp(renderClock - snap.Time, 0, MAX_EXTRAP_TIME)
			targetPos = snap.Pos + snap.Vel * elapsed + BALL_GRAVITY * (0.5 * elapsed * elapsed)
		else
			continue
		end

		-- Re-entry (e.g. a thrown ball leaving the carrier) makes the ball reappear in this
		-- query after being absent. Blend from where it was (the hand) into the arc so the
		-- ~150ms replication jump slides instead of teleporting.
		if seenFrame[entity] ~= frameIndex - 1 then
			blendFrom[entity] = rootPart.Position
			blendT[entity] = 0
		end
		seenFrame[entity] = frameIndex

		local renderPos = targetPos
		local from = blendFrom[entity]
		if from then
			blendT[entity] += dt
			local alpha = math.clamp(blendT[entity] / BLEND_TIME, 0, 1)
			renderPos = from:Lerp(targetPos, alpha)
			if alpha >= 1 then
				blendFrom[entity] = nil
			end
		end

		-- Preserve rotation (set by RemoteVisualRotationSystem)
		rootPart.CFrame = CFrame.new(renderPos) * rootPart.CFrame.Rotation
	end
end

return {
	name = "BallInterpolationSystem",
	phase = phase.PreRender,
	system = ballInterpolationSystem,
}
