-- EventQueue.lua -- Fixed-capacity ring buffer for typed ECS events.
-- Zero-allocation after init. Push/drain are O(1). Capacity must be
-- a power of two (bitwise mask wrap).

local function nextPowerOfTwo(n: number): number
	local p = 1
	while p < n do
		p = p * 2
	end
	return p
end

local EventQueue = {}
EventQueue.__index = EventQueue

function EventQueue.new(capacity: number?)
	local cap = nextPowerOfTwo(capacity or 64)
	return setmetatable({
		_buffer = table.create(cap),
		_head = 1,
		_tail = 1,
		_mask = cap - 1,
		_count = 0,
		_capacity = cap,
	}, EventQueue)
end

function EventQueue:push(entry: any)
	if self._count >= self._capacity then
		return -- silently drop (overflow)
	end
	self._buffer[self._tail] = entry
	self._tail = bit32.band(self._tail, self._mask) + 1
	self._count += 1
end

function EventQueue:isEmpty(): boolean
	return self._count == 0
end

function EventQueue:isFull(): boolean
	return self._count >= self._capacity
end

-- Returns an iterator that yields each entry in FIFO order.
-- The queue is emptied after drain -- no entries persist across ticks.
function EventQueue:drain(): () -> any
	local buffer = self._buffer
	local head = self._head
	local tail = self._tail
	local mask = self._mask
	local count = self._count

	-- Reset queue state before iterating so re-entrant pushes
	-- during drain go into a fresh cycle.
	self._head = 1
	self._tail = 1
	self._count = 0

	local i = 0
	return function()
		if i >= count then
			return nil
		end
		i += 1
		local idx = head
		head = bit32.band(head, mask) + 1
		return i, buffer[idx]
	end
end

return EventQueue
