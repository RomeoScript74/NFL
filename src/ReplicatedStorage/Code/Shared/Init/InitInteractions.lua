-- InitInteractions.lua — Registers all interaction node types with the NodeRegistry.
-- Each node module self-registers on require (NodeRegistry.register runs at module
-- load). This must run once per environment before any chain is built by
-- InteractionDispatchSystem. Add a require here when adding a new node type.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Nodes = ReplicatedStorage.Code.Shared.Interactions.Nodes

require(Nodes.Serial)
require(Nodes.Parallel)
require(Nodes.Repeat)
require(Nodes.Condition)
require(Nodes.CooldownCondition)
require(Nodes.TriggerCooldown)
require(Nodes.HoldToCharge)
require(Nodes.SelectNearby)
require(Nodes.SelectCarried)
require(Nodes.PushEvent)
require(Nodes.TackleSweep)
require(Nodes.Interrupt)

return {}
