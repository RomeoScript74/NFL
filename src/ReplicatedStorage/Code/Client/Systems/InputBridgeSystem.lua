-- InputBridgeSystem.lua — Reads Input.lua, writes INPUT_DIRECTION/INPUT_FLAGS/YAW/PITCH
-- to client ECS, and sends input frame to server via ZAP.
-- Runs inside the physics tick (InputBridge phase), wrapped by ClientPhysicsDriverSystem's
-- Input.runPhase, so Input.pressed()/clamped2d() return live values.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Input = require(ReplicatedStorage.Code.Client.Input)
local components = require(ReplicatedStorage.Code.Shared.Components)
local InputType = require(ReplicatedStorage.Code.Shared.InputType)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local zap = require(ReplicatedStorage.Code.Client.ZapClient)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local query = world:query(components.INPUT_DIRECTION):with(tags.PREDICTED):cached()

local tickCounter = 0

local function inputBridgeSystem()
	local camera = workspace.CurrentCamera
	local cameraPitch, cameraYaw, _ = camera.CFrame:ToEulerAnglesYXZ()

	-- Build camera-relative movement direction
	local look = camera.CFrame.LookVector
	local right = camera.CFrame.RightVector
	local flatForward = Vector3.new(look.X, 0, look.Z)
	if flatForward.Magnitude > 0 then
		flatForward = flatForward.Unit
	else
		flatForward = Vector3.new(0, 0, -1)
	end
	
	local flatRight = Vector3.new(right.X, 0, right.Z)
	if flatRight.Magnitude > 0 then
		flatRight = flatRight.Unit
	else
		flatRight = Vector3.new(1, 0, 0)
	end

	tickCounter += 1

	for entity in query do
		local move = Input.clamped2d("move")
		local dir = flatForward * move.Y + flatRight * move.X
		if dir.Magnitude > 0 then
			dir = dir.Unit
		end

		-- Build flags bitmask from raw input
		local flags = 0
		if move.Y > 0 then
			flags = bit32.bor(flags, InputType.FORWARD)
		end
		if move.Y < 0 then
			flags = bit32.bor(flags, InputType.BACKWARD)
		end
		if move.X > 0 then
			flags = bit32.bor(flags, InputType.RIGHT)
		end
		if move.X < 0 then
			flags = bit32.bor(flags, InputType.LEFT)
		end
		if Input.pressed("pass") then
			flags = bit32.bor(flags, InputType.PASS)
		end
		if Input.pressed("tackle") then
			flags = bit32.bor(flags, InputType.TACKLE)
		end
		if Input.pressed("juke") then
			flags = bit32.bor(flags, InputType.JUKE)
		end
		if Input.pressed("sprint") then
			flags = bit32.bor(flags, InputType.SPRINT)
		end
		if Input.pressed("dive") then
			flags = bit32.bor(flags, InputType.DIVE)
		end
		if Input.pressed("grab") then
			flags = bit32.bor(flags, InputType.GRAB)
		end
		if Input.pressed("dash") then
			flags = bit32.bor(flags, InputType.DASH)
		end
		if Input.pressed("brace") then
			flags = bit32.bor(flags, InputType.BRACE)
		end

		if Input.pressed("hurdle") then
			flags = bit32.bor(flags, InputType.HURDLE)
		end

		-- Write to client ECS (for local prediction use)
		world:set(entity, components.YAW, cameraYaw)
		world:set(entity, components.PITCH, cameraPitch)
		world:set(entity, components.INPUT_DIRECTION, dir)
		world:set(entity, components.INPUT_FLAGS, flags)

		-- Send to server via ZAP
		local frame = {
			X = dir.X,
			Z = dir.Z,
			Tick = tickCounter,
			Yaw = cameraYaw,
			Pitch = cameraPitch,
			Flags = flags,
			-- for lag-compensated hit detection
			RenderFrame = 0,
		}

		zap.MoveInput.Fire({
			History = { frame }
		})
	end
end

return {
	name = "InputBridgeSystem",
	phase = pipelines.Phases.InputBridge,
	system = inputBridgeSystem,
}
