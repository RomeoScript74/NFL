-- RemoteVisualInterpolator.lua — Renders non-predicted (remote) entities smoothly using
-- a snapshot buffer with 150ms delay. Hermite interpolation between snapshots.
-- Drift correction keeps the render clock locked ~150ms behind the newest snapshot.
-- Extrapolates via velocity for up to 0.25s past the newest data point.

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

local function hermiteLerp(p0: Vector3, v0: Vector3, p1: Vector3, v1: Vector3, gap: number, t: number): Vector3
	local t2 = t * t
	local t3 = t2 * t
	return  p0  *   (2 * t3 - 3 * t2 + 1)
		+   v0  *   gap * (t3 - 2 * t2 + t)
		+   p1  *   (-2 * t3 + 3 * t2)
		+   v1  *   gap * (t3 - t2)
end

local remoteQuery = world:query(
	components.REMOTE_TICK,
	components.SERVER_POSITION,
	components.SERVER_VELOCITY,
	components.SNAPSHOT_BUFFER,
	components.INTERPOLATION_CLOCK,
	components.INTERP_DRIFT,
	components.INTERP_LAST_CLOCK,
	components.ROOTPART
):without(tags.PREDICTED):cached()

local function remoteVisualInterpolator()
	local now = os.clock()
	local rawDt = now - lastFrameTime
	lastFrameTime = now
	smoothedDt = smoothedDt * DT_SMOOTHING + rawDt * (1 - DT_SMOOTHING)
	local dt = math.min(smoothedDt, MAX_RENDER_DT)

	for entity, tick, pos, vel, buffer, renderClock, avgDrift, lastClock, rootPart in remoteQuery do
		local serverTime = tick * FIXED_DT

		-- New snapshot arrived (buffer is already initialized by RemoteInterpolationInit)
		if #buffer == 0 or buffer[#buffer].Time < serverTime then
			-- Teleport check: if entity jumped, clear buffer and reset clock
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
			-- Extrapolate past single snapshot via velocity (damped)
			local snap = buffer[1]
			local elapsed = renderClock - snap.Time
			if elapsed < MAX_EXTRAP_TIME then
				local damp = 1.0 - elapsed / MAX_EXTRAP_TIME
				targetPos = snap.Pos + snap.Vel * elapsed * damp
			else
				targetPos = snap.Pos + snap.Vel * MAX_EXTRAP_TIME * 0.5
			end
		else
			continue
		end

		-- Preserve rotation (set by RemoteVisualRotationSystem)
		rootPart.CFrame = CFrame.new(targetPos) * rootPart.CFrame.Rotation
	end
end

return {
	name = "RemoteVisualInterpolator",
	phase = phase.PreRender,
	system = remoteVisualInterpolator,
}
