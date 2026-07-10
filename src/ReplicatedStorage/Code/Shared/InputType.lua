--[[
	InputType — bitmask constants and helpers for INPUT_FLAGS component.

	One atomic bit32 integer per tick, no GC allocation, cheap comparison.

	Bit layout (NFL):
	  bit 0: FORWARD
	  bit 1: BACKWARD
	  bit 2: LEFT
	  bit 3: RIGHT
	  bit 4: JUMP
	  bit 5: PASS
	  bit 6: TACKLE
	  bit 7: JUKE
	  bit 8: SPRINT
	  bit 9: DIVE
	  bit 10: GRAB
]]

local bit32 = bit32

local InputType = {
	-- Movement (bits 0-3)
	FORWARD  = 1,
	BACKWARD = 2,
	LEFT     = 4,
	RIGHT    = 8,

	-- Actions (bits 4+)
	JUMP     = 16,
	PASS     = 32,
	TACKLE   = 64,
	JUKE     = 128,
	SPRINT   = 256,
	DIVE     = 512,
	GRAB     = 1024,
}

-- Check if a flag is set in the mask.
function InputType.has(mask: number, flag: number): boolean
	return bit32.band(mask, flag) ~= 0
end

-- Set one or more flags on the mask. Pass multiple flags.
function InputType.set(mask: number, ...: number): number
	local result = mask
	for i = 1, select("#", ...) do
		result = bit32.bor(result, select(i, ...))
	end
	return result
end

-- Clear one or more flags from the mask.
function InputType.clear(mask: number, ...: number): number
	local result = mask
	for i = 1, select("#", ...) do
		result = bit32.band(result, bit32.bnot(select(i, ...)))
	end
	return result
end

return InputType
