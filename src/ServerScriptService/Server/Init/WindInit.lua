-- WindInit.lua — Initializes the global WIND singleton at startup.
-- Wind is a per-tick acceleration (Vector3, studs/s^2) applied to all WIND_AFFECTED
-- entities. Retune at runtime via world:set(components.WIND, components.WIND, vec).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local world = require(ReplicatedStorage.Code.Shared.World)
local components = require(ReplicatedStorage.Code.Shared.Components)

local WindInit = {}

function WindInit.init(windVector)
	windVector = windVector or Vector3.new(0, 0, 0)
	world:set(components.WIND, components.WIND, windVector)
end

return WindInit
