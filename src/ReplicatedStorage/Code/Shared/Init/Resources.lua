--[[
	Resources.lua — Central loadup module.
	Guarantees initialization order: jecs → tags → world → components

	Usage:
	  local Resources = require(Shared.Init.Resources)
	  local world = Resources.world
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 1. ECS engine
local jecs = require(ReplicatedStorage.Packages.jecs)

-- 2. Tags (jecs.tag() runs now — BEFORE world creation)
local tags = require(ReplicatedStorage.Code.Shared.Tags)

-- 2. Replecs (replecs.create(world) runs now — AFTER world creation)
local replecs = require(ReplicatedStorage.Packages.replecs)

-- 3. World (jecs.World.new() runs now — AFTER tags exist)
local world = require(ReplicatedStorage.Code.Shared.World)

-- 4. Components (world:component() runs now — AFTER world exists)
local components = require(ReplicatedStorage.Code.Shared.Components)

return {
	jecs = jecs,
	world = world,
	tags = tags,
	components = components,
	replecs = replecs,
}
