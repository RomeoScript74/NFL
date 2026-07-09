-- PrintTestSystem.lua -- Verifies the full ECS pipeline works.
-- Prints once to confirm: init -> scheduler -> systems -> queries.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local world = require(ReplicatedStorage.Code.Shared.World)
local components = require(ReplicatedStorage.Code.Shared.Components)

local ran = false

local function printTestSystem()
	if ran then return end
	ran = true

	print("=== NFL Infrastructure Test ===")
	print("World exists:", world ~= nil)
	print("Components:", #table.clone(components))
end

return {
	name = "PrintTestSystem",
	phase = nil,
	system = printTestSystem,
}
