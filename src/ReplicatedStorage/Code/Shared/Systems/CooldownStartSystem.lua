-- CooldownStartSystem.lua — Applies interaction cooldowns. Drains StartCooldown events (pushed
-- by the TriggerCooldown node) and sets pair(COOLDOWN, CD_*) = duration on BOTH sides — the
-- cooldown is client-PREDICTED. The client must know exactly when it's off cooldown to re-fire;
-- it can't read that off the replicated server value, because a cooldown that clears and re-arms
-- within one tick never appears "clear" to 20 Hz replication. Reconciliation restores it on replay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local world = require(ReplicatedStorage.Code.Shared.World)
local EventTypes = require(ReplicatedStorage.Code.Shared.EventTypes)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)

local pair = jecs.pair

local function cooldownStartSystem()
	for _, entry in EventTypes.StartCooldown:drain() do
		if world:contains(entry.user) then
			world:set(entry.user, pair(components.COOLDOWN, entry.cooldown), entry.duration)
		end
	end
end

return {
	name = "CooldownStartSystem",
	phase = pipelines.Phases.Impulse,
	system = cooldownStartSystem,
}
