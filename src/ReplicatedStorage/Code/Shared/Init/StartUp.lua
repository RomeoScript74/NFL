local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local scheduler = require(ReplicatedStorage.Code.Shared.Scheduler)
local world = require(ReplicatedStorage.Code.Shared.World)
local jabby = require(ReplicatedStorage.Packages.jabby)

-- Pipeline registration (side-effect)
local _initSharedPipelines = require(ReplicatedStorage.Code.Shared.Init.InitPipelines)

return function(systems)
	if #systems > 0 then
		-- Planck routes each system to its matching phase automatically.
		-- Systems with a physics phase run on PhysicsScheduler;
		-- systems with a visual phase run on MainScheduler.
		-- Systems whose phase doesn't match either are skipped.
		scheduler.PhysicsScheduler:addSystems(systems)
		scheduler.MainScheduler:addSystems(systems)
	end

	if RunService:IsClient() then
		local client = jabby.obtain_client()

		local function createWidget(_, state: Enum.UserInputState)
			if state ~= Enum.UserInputState.Begin then
				return
			end
			client.spawn_app(client.apps.home, nil)
		end

		ContextActionService:BindAction("Open Jabby", createWidget, false, Enum.KeyCode.F4)
	end

	jabby.register({
		applet = jabby.applets.world,
		name = "Jecs World",
		configuration = { world = world },
	})
end
