local ReplicatedStorage = game:GetService("ReplicatedStorage")
local _replecs = require(ReplicatedStorage.Packages.replecs)
local jecs = require(ReplicatedStorage.Packages.jecs)

local world = jecs.World.new()

return world
