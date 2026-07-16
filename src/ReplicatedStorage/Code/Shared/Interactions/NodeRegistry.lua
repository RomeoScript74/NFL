-- NodeRegistry — Hytale-style type registry for interaction nodes.
--
-- Central registry where node types are registered by string key.
-- External code can register custom node types without editing this file:
--
--   local NodeRegistry = require(path.to.NodeRegistry)
--   NodeRegistry.register("MyCustomNode", function(config)
--       return { execute = function(self, ctx) ... end }
--   end)
--
-- Definitions reference nodes by type string:
--   { Type = "Serial", Children = { { Type = "HasAmmo" }, { Type = "Fire" } } }
--
-- The registry builds nodes from config tables via NodeRegistry.build(config).

local RunService = game:GetService("RunService")
local IS_CLIENT = RunService:IsClient()

local NodeRegistry = {}

-- ═══════════════ Internal State ═══════════════

-- { [typeName] = constructorFn(config) -> node }
local registry = {}

-- ═══════════════ Status Constants ═══════════════

NodeRegistry.SUCCESS = "success"
NodeRegistry.FAILURE = "failure"
NodeRegistry.RUNNING = "running"

-- ═══════════════ Realm Gating ═══════════════
-- A node's `side` field ("server" or "client") means "only execute in this realm." This is the ONE
-- place that decision is made — every execute() call site (tickChain's top-level dispatch, and every
-- container node: Serial, Parallel, Repeat-via-Serial) MUST route through this before calling
-- child:execute(), or `side` silently does nothing for nodes nested at that depth.
function NodeRegistry.isSkipped(node)
	return (node.side == "server" and IS_CLIENT)
		or (node.side == "client" and not IS_CLIENT)
end

-- ═══════════════ Registration ═══════════════

function NodeRegistry.register(typeName, constructor)
	if registry[typeName] then
		warn("[NodeRegistry] Overwriting existing node type: " .. typeName)
	end
	registry[typeName] = constructor
end

function NodeRegistry.create(config)
	-- If already a live node (has execute), return as-is
	if type(config) == "table" and type(config.execute) == "function" then
		return config
	end

	local typeName = config.Type
	if not typeName then
		error("[NodeRegistry] Config missing Type field: " .. tostring(config))
	end

	local constructor = registry[typeName]
	if not constructor then
		error("[NodeRegistry] Unknown node type: " .. typeName .. " -- register it via NodeRegistry.register()")
	end

	local node = constructor(config)

	-- Propagate structural fields the constructor may not include
	for _, field in { "Next", "Failed", "FilterFailed", "Guard", "Children" } do
		if config[field] ~= nil and node[field] == nil then
			node[field] = config[field]
		end
	end

	return node
end

function NodeRegistry.build(config)
	if not config then return nil end

	-- Pre-built node: return as-is
	if type(config) == "table" and type(config.execute) == "function" then
		return config
	end

	-- Recursively build children
	local built = table.clone(config)

	if built.Children then
		local builtChildren = {}
		for i, child in built.Children do
			builtChildren[i] = NodeRegistry.build(child)
		end
		built.Children = builtChildren
	end

	if built.Next then
		built.Next = NodeRegistry.build(built.Next)
	end

	if built.Failed then
		built.Failed = NodeRegistry.build(built.Failed)
	end

	if built.FilterFailed then
		built.FilterFailed = NodeRegistry.build(built.FilterFailed)
	end

	if built.Guard then
		built.Guard = NodeRegistry.build(built.Guard)
	end

	local node = NodeRegistry.create(built)

	-- Propagate Hytale base fields
	if config.RunTime then
		node.RunTime = config.RunTime
	end
	if config.HorizontalSpeedMultiplier then
		node.HorizontalSpeedMultiplier = config.HorizontalSpeedMultiplier
	end
	if config.Effects then
		node.Effects = config.Effects
	end
	-- side: "server" or "client" — read by tickChain to skip this node entirely on the other realm.
	-- Only takes effect on a TOP-LEVEL node (a chain's currentNode, reached via Next/Failed); a
	-- container (Serial/Parallel/Repeat) calls child:execute() directly and never checks child.side.
	if config.side then
		node.side = config.side
	end

	return node
end

function NodeRegistry.has(typeName)
	return registry[typeName] ~= nil
end

function NodeRegistry.getRegisteredTypes()
	local types = {}
	for name in registry do
		table.insert(types, name)
	end
	return types
end

-- ═══════════════ Deep Clone ═══════════════

function NodeRegistry.deepClone(node)
	if not node then return nil end

	local clone = {}
	for k, v in node do
		if k == "children" or k == "Children" then
			local clonedChildren = {}
			for i, child in v do
				clonedChildren[i] = NodeRegistry.deepClone(child)
			end
			clone[k] = clonedChildren
	elseif k == "child" or k == "Child" or k == "guard" or k == "Guard" then
			clone[k] = NodeRegistry.deepClone(v)
		elseif k == "Next" then
			clone.Next = NodeRegistry.deepClone(v)
		elseif k == "Failed" then
			clone.Failed = NodeRegistry.deepClone(v)
		elseif type(v) ~= "function" then
			clone[k] = v
		end
	end

	-- Copy functions (shared, safe -- they use self via first arg)
	for k, v in node do
		if type(v) == "function" then
			clone[k] = v
		end
	end

	return clone
end

return NodeRegistry
