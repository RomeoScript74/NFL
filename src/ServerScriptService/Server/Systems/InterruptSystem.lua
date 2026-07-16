-- InterruptSystem.lua — Server: owns cancelling a target's in-progress interaction. Drains the
-- Interrupt queue (any cause — TackleSweep on a landed hit today, future strips/parries later —
-- requests that a target's active chain be cancelled) and clears their INTERACTION_MANAGER.active
-- table outright, so nothing silently resumes later.
--
-- Deliberately its OWN consequence, separate from StunSystem: being stunned (a movement/status state)
-- and having your action cancelled (an interaction-system state) are independent — a future ability
-- might stun without interrupting, or interrupt without stunning. Mirrors Hytale's InterruptInteraction
-- being its own node an attacking chain explicitly adds, not an automatic side effect of a stun/status
-- system (see the hytale-source-comparison memory).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)
local EventTypes = require(ReplicatedStorage.Code.Shared.EventTypes)

local function interruptSystem()
	for _, event in EventTypes.Interrupt:drain() do
		local target = event.target
		if not target or not world:contains(target) then continue end

		local manager = world:get(target, components.INTERACTION_MANAGER)
		if manager then
			table.clear(manager.active)
		end
	end
end

return {
	name = "InterruptSystem",
	phase = pipelines.Phases.Impulse,
	system = interruptSystem,
}
