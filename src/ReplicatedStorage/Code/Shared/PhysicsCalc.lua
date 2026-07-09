-- PhysicsCalc.lua — Shared physics math functions.
-- Ported from FPS reference. Stateless: pure functions of inputs → outputs.

local PhysicsCalc = {}

local BASE_GRAVITY = 196.2
local STEP_UP_SPEED = 24
local MAX_STEP_HEIGHT = 1.25
local FLOOR_PROBE_RADIUS = 0.5

local FLOOR_PROBE_OFFSETS = {
	Vector3.zero,
	Vector3.new(FLOOR_PROBE_RADIUS, 0, 0),
	Vector3.new(-FLOOR_PROBE_RADIUS, 0, 0),
	Vector3.new(0, 0, FLOOR_PROBE_RADIUS),
	Vector3.new(0, 0, -FLOOR_PROBE_RADIUS),
}

function PhysicsCalc.calculateMovement(
	currentVel: Vector3,
	moveDir: Vector3,
	speed: number,
	accel: number,
	decel: number,
	dt: number
): Vector3
	local targetVelX = moveDir.X * speed
	local targetVelZ = moveDir.Z * speed

	local isAccel = moveDir.Magnitude > 0
	local accelDelta = accel * dt
	local decelDelta = decel * dt

	local function moveTowards(current: number, target: number): number
		if not isAccel then
			local diff = 0 - current
			if math.abs(diff) <= decelDelta then return 0 end
			return current + (math.sign(diff) * decelDelta)
		end

		if math.sign(current) == math.sign(target) and math.abs(current) > math.abs(target) then
			local diff = target - current
			if math.abs(diff) <= decelDelta then return target end
			return current + (math.sign(diff) * decelDelta)
		else
			local diff = target - current
			if math.abs(diff) <= accelDelta then return target end
			return current + (math.sign(diff) * accelDelta)
		end
	end

	local newX = moveTowards(currentVel.X, targetVelX)
	local newZ = moveTowards(currentVel.Z, targetVelZ)

	return Vector3.new(newX, currentVel.Y, newZ)
end

function PhysicsCalc.calculateGravity(
	currentVel: Vector3,
	scale: number,
	dt: number
): Vector3
	local change = BASE_GRAVITY * scale * dt
	return Vector3.new(currentVel.X, currentVel.Y - change, currentVel.Z)
end

function PhysicsCalc.resolveFloorCollision(
	pos: Vector3,
	vel: Vector3,
	hipHeight: number,
	rootPart: BasePart,
	dt: number
): (Vector3, Vector3, boolean, Vector3?)
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = { rootPart.Parent }
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local halfSize = rootPart.Size.Y / 2
	local distFromCenterToFeet = halfSize + hipHeight

	local hSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local slopeGap = hSpeed * dt
	local fallDist = (vel.Y < 0) and math.abs(vel.Y * dt) or 0
	local extraReach = math.max(0, slopeGap - 1.0)
	local originY = pos.Y + math.max(halfSize, fallDist + 1.0 + extraReach)
	local totalDist = originY - (pos.Y - distFromCenterToFeet) + fallDist + 1.0 + extraReach
	local rayDir = Vector3.new(0, -totalDist, 0)

	local centerOrigin = Vector3.new(pos.X, originY, pos.Z)
	local result = workspace:Raycast(centerOrigin, rayDir, rayParams)

	if not result then
		for i = 2, #FLOOR_PROBE_OFFSETS do
			local offset = FLOOR_PROBE_OFFSETS[i]
			local origin = Vector3.new(pos.X + offset.X, originY, pos.Z + offset.Z)
			local hit = workspace:Raycast(origin, rayDir, rayParams)
			if hit then
				if not result or hit.Position.Y > result.Position.Y then
					result = hit
				end
			end
		end
	end

	if result then
		local floorY = result.Position.Y
		local distToFloor = (pos.Y - (2.0 + hipHeight)) - floorY
		local targetY = floorY + distFromCenterToFeet
		local stepHeight = targetY - pos.Y
		local isSlope = result.Normal.Y < 0.97 and result.Normal.Y > 0.3

		if isSlope and math.abs(stepHeight) < 5.0 and vel.Y < 20 then
			local newPos = Vector3.new(pos.X, targetY, pos.Z)
			local newVel = Vector3.new(vel.X, -0.1, vel.Z)
			return newPos, newVel, true, result.Normal
		end

		if distToFloor <= (fallDist + 0.1) then
			if vel.Y > 0 or distToFloor > 0.3 then
				return pos, vel, false
			end

			if stepHeight > MAX_STEP_HEIGHT and vel.Y > -5 then
				return pos, vel, false
			end

			local maxStep = STEP_UP_SPEED * dt
			local nextY = pos.Y

			if targetY > pos.Y then
				nextY = math.min(pos.Y + maxStep, targetY)
			else
				nextY = targetY
			end

			local newPos = Vector3.new(pos.X, nextY, pos.Z)

			local newVel = vel
			if vel.Y < 0 then
				newVel = Vector3.new(vel.X, -0.1, vel.Z)
			end

			return newPos, newVel, true, result.Normal
		end
	end

	return pos, vel, false, nil
end

return PhysicsCalc
