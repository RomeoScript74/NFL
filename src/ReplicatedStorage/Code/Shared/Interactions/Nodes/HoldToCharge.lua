-- HoldToCharge node — accumulates charge while the interaction button is held,
-- fires when released. Returns RUNNING every tick the button is down, then SUCCESS
-- on the release tick with the normalized charge (0..1) written to ctx meta.
--
-- Config: { Type = "HoldToCharge", MaxChargeTime = 1.2, MetaKey = "Charge" }

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local RUNNING = NodeRegistry.RUNNING
local SUCCESS = NodeRegistry.SUCCESS

local DT = 1 / 60

NodeRegistry.register("HoldToCharge", function(config)
	local maxChargeTime = config.MaxChargeTime or 1.0
	local metaKey = config.MetaKey or "Charge"

	return {
		Type = "HoldToCharge",
		_chargeTime = 0,

		execute = function(self, ctx)
			self._chargeTime = math.min(self._chargeTime + DT, maxChargeTime)

			if ctx.chain.state.inputReleased then
				local charge = math.clamp(self._chargeTime / maxChargeTime, 0, 1)
				ctx:setMeta(metaKey, charge)
				return SUCCESS
			end

			return RUNNING
		end,

		reset = function(self)
			self._chargeTime = 0
		end,
	}
end)

return nil
