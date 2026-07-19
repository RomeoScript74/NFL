--[[
	InputToIntentSystem — Bridges player INPUT_FLAGS → INPUT_STATE.
	Matches the FPS reference pattern.

	Hytale's interaction system is trigger-agnostic: the chain runner doesn't
	care whether input comes from a keyboard press or NPC AI. This system is
	the player-side adapter.

	Runs in PreCombat phase so state is ready before InteractionDispatchSystem
	reads it in Combat phase.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local InputType = require(ReplicatedStorage.Code.Shared.InputType)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local FLAG_TO_ACTION = {
	JUKE   = "Juke",
	DIVE   = "Dive",
	TACKLE = "Tackle",
	PASS   = "Throw",
	GRAB   = "Grab",
	DASH   = "Dash",
	HURDLE = "Hurdle",
}

local stateQuery = world:query(
	components.INTERACTION_MANAGER,
	components.INPUT_FLAGS,
	components.INPUT_STATE
):cached()

local function inputToIntentSystem()
	for character, _manager, flags, inputState in stateQuery do

		for flagKey, actionName in FLAG_TO_ACTION do
			local slot = inputState[actionName]
			if not slot then continue end

			local bit = InputType[flagKey]
			local isDown = bit and bit32.band(flags, bit) ~= 0
			local wasDown = slot.held

			slot.pressed = isDown and not wasDown
			slot.held = isDown
			slot.released = not isDown and wasDown
		end

		world:set(character, components.INPUT_STATE, inputState)
	end
end

return {
	name = "InputToIntentSystem",
	phase = pipelines.Phases.PreCombat,
	system = inputToIntentSystem,
}
