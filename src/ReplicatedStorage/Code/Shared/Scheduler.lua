local ReplicatedStorage = game:GetService("ReplicatedStorage")
local planck = require(ReplicatedStorage.Packages.planck)
local Scheduler = planck.Scheduler
local world = require(ReplicatedStorage.Code.Shared.World)
local runServicePlugin = require(ReplicatedStorage.Packages["planck-runservice"]).Plugin.new()
local PlanckJabby = require(ReplicatedStorage.Packages["planck-jabby"])
local jabbyPlugin = PlanckJabby.new()
local physicsJabbyPlugin = PlanckJabby.new()

local MainScheduler = Scheduler.new(world)
	:addPlugin(runServicePlugin)
	:addPlugin(jabbyPlugin)

local PhysicsScheduler = Scheduler.new(world)
PhysicsScheduler:addPlugin(physicsJabbyPlugin)

return {
	MainScheduler = MainScheduler,
	PhysicsScheduler = PhysicsScheduler,
}
