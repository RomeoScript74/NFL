-- InitInteractions.lua — Requires all interaction node modules.
-- Each node registers itself with NodeRegistry at require time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nodes = ReplicatedStorage.Code.Shared.Interactions.Nodes

for _, module in Nodes:GetChildren() do
	if module:IsA("ModuleScript") then
		require(module)
	end
end

return {}
