-- StunSystem.lua — Server: owns the STUNNED state end-to-end. Drains the Stun queue (any source —
-- TackleSweep today, blocks/trips/abilities later — requests a stun on a target for a duration),
-- applies STUNNED + a pair(TIMER, STUN_WINDOW) countdown, and freezes the target's horizontal
-- velocity (movement excludes STUNNED, so it can't re-accelerate). A second query removes STUNNED
-- when TimerSystem has run the window out.
--
-- STUNNED is server-authoritative + replicated: the client reflects it (gating movement and
-- interactions) but never adds or removes it. Keeping a single owner means any future stun cause just
-- pushes a Stun event — nobody else touches the tag.
--
-- Deliberately does NOT cancel the target's active interaction — that's InterruptSystem's job,
-- requested independently. Being stunned and having your action cancelled are different consequences;
-- a cause that wants both (like a landed tackle) pushes both a Stun and an Interrupt event.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)
local EventTypes = require(ReplicatedStorage.Code.Shared.EventTypes)

local STUN_WINDOW_TIMER = jecs.pair(components.TIMER, components.STUN_WINDOW)

-- Expiry: TimerSystem removes the pair when it hits 0, then we drop the tag.
local expiredQuery = world:query():with(tags.STUNNED):without(STUN_WINDOW_TIMER):cached()

local function stunSystem()
	for entity in expiredQuery do
		world:remove(entity, tags.STUNNED)
	end

	for _, event in EventTypes.Stun:drain() do
		local target = event.target
		if not target or not world:contains(target) then continue end

		-- Freeze in place: kill horizontal velocity (movement excludes STUNNED, so no re-accel).
		local vel = world:get(target, components.VELOCITY)
		if vel then
			world:set(target, components.VELOCITY, Vector3.new(0, vel.Y, 0))
		end
		world:set(target, STUN_WINDOW_TIMER, event.duration)
		world:add(target, tags.STUNNED)
	end
end

return {
	name = "StunSystem",
	phase = pipelines.Phases.Impulse,
	system = stunSystem,
}
