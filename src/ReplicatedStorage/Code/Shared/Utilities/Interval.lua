-- Interval.lua -- Timestep-accumulating throttle.
-- Returns true once every `s` seconds of accumulated wall-clock time.

local function interval(s: number)
	local last: number? = nil
	local acc = 0

	local function throttle(): boolean
		local now = os.clock()
		if not last then
			last = now
			return false
		end

		acc += (now - last)
		last = now

		if acc >= s then
			acc -= s
			return true
		end

		return false
	end

	return throttle
end

return interval
