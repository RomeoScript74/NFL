-- InteractionDispatchSystem — Hytale-style interaction chain runtime.
--
-- Single system that handles ALL interactions: pass, tackle, juke, dive, jump.
-- Queries characters with INTERACTION_MANAGER + INPUT_STATE. Per frame:
--   1. Dead check -> cancel all active chains
--   2. Tick cooldowns -> decrement remaining / restore charges
--   3. Tick chaining window timers -> expire stale combos
--   4. Tick active chains -> advance through node graph (Next/Failed navigation)
--   5. Process intents -> lookup interaction def -> check rules -> start chain
--
-- Chain execution model:
--   - Each chain tracks a `currentNode` pointer (starts at root)
--   - SUCCESS: follow node.Next if present, else chain completes
--   - FAILURE: follow node.Failed if present, else chain fails
--   - RUNNING: stay on currentNode next frame
--   - Container nodes (Serial, Repeat) manage children internally
--
-- Adding a new action = one definition file + node registrations. This file never
-- needs editing.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local jecs = require(ReplicatedStorage.Packages.jecs)
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)
local pipelines = require(ReplicatedStorage.Code.Shared.PipeLines)
local NodeRegistry = require(ReplicatedStorage.Code.Shared.Interactions.NodeRegistry)

local IS_CLIENT = RunService:IsClient()
local pair = jecs.pair
local DT = 1 / 60

-- ═══════════════ Query ═══════════════

local characterQuery = world:query(
	components.INTERACTION_MANAGER,
	components.INPUT_STATE
):cached()

-- ═══════════════ Lifecycle Hooks ═══════════════

local function fireHook(manager, hookName, chain)
	local callbacks = manager[hookName]
	if not callbacks then return end
	for _, cb in callbacks do
		cb(chain)
	end
end

-- ═══════════════ Node Filter Predicates ═══════════════

local FilterEvaluators = {
	HasTag = function(filter, ctx)
		return world:has(ctx.user, filter.Tag)
	end,
	NotTag = function(filter, ctx)
		return not world:has(ctx.user, filter.Tag)
	end,
	HasComponent = function(filter, ctx)
		return world:has(ctx.user, filter.Component)
			or world:get(ctx.user, filter.Component) ~= nil
	end,
	IsGrounded = function(_filter, ctx)
		return world:has(ctx.user, tags.IS_GROUNDED)
	end,
	IsAirborne = function(_filter, ctx)
		return not world:has(ctx.user, tags.IS_GROUNDED)
	end,
}

local function evaluateFilter(filter, ctx)
	local evaluator = FilterEvaluators[filter.Type]
	if not evaluator then
		warn("[InteractionSystem] Unknown filter type: " .. tostring(filter.Type))
		return true
	end
	return evaluator(filter, ctx)
end

-- ═══════════════ Asset Tag Helpers ═══════════════

local function hasAssetTag(interactionDef, tag)
	local assetTags = world:get(interactionDef, components.ASSET_TAGS)
	if not assetTags then return false end
	for _, t in assetTags do
		if t == tag then return true end
	end
	return false
end

-- ═══════════════ Rule Helpers ═══════════════
-- Rules live in INTERACTION_RULES tables on definition entities:
--   { BlockedBy = { entity, ... }, Blocks = { entity, ... },
--     Interrupts = { entity, ... }, InterruptedBy = { entity, ... },
--     BlockedByBypass = "tag", ... }
-- Table-based: no pair fragmentation, one component per definition entity.

local function isBlockedByRules(incomingDef, activeChains)
	local rules = world:get(incomingDef, components.INTERACTION_RULES)
	if not rules or not rules.BlockedBy then return false end
	for _, blockedType in rules.BlockedBy do
		if activeChains[blockedType] then
			local bypass = rules.BlockedByBypass
			if not bypass
				or not hasAssetTag(activeChains[blockedType].interactionDef, bypass)
			then
				return true
			end
		end
	end
	return false
end

local function isBlockedByActiveBlocking(interactionType, activeChains, incomingDef)
	for _, chain in activeChains do
		local rules = world:get(chain.interactionDef, components.INTERACTION_RULES)
		if not rules or not rules.Blocks then continue end
		if not table.find(rules.Blocks, interactionType) then continue end
		local bypass = rules.BlockingBypass
		if bypass and hasAssetTag(incomingDef, bypass) then continue end
		return true
	end
	return false
end

local function applyInterrupting(incomingDef, activeChains, manager)
	local rules = world:get(incomingDef, components.INTERACTION_RULES)
	if not rules or not rules.Interrupts then return end
	for _, interruptedType in rules.Interrupts do
		if activeChains[interruptedType] then
			local bypass = rules.InterruptingBypass
			if not bypass
				or not hasAssetTag(activeChains[interruptedType].interactionDef, bypass)
			then
				fireHook(manager, "onChainEnded", activeChains[interruptedType])
				activeChains[interruptedType] = nil
			end
		end
	end
end

local function applyInterruptedBy(interactionType, activeChains, manager, incomingDef)
	for chainType, chain in activeChains do
		local rules = world:get(chain.interactionDef, components.INTERACTION_RULES)
		if not rules or not rules.InterruptedBy then continue end
		if not table.find(rules.InterruptedBy, interactionType) then continue end
		local bypass = rules.InterruptedByBypass
		if bypass and hasAssetTag(incomingDef, bypass) then continue end
		fireHook(manager, "onChainEnded", chain)
		activeChains[chainType] = nil
	end
end

-- ═══════════════ InteractionContext (Hytale DynamicMetaStore pattern) ═══════════════

local ContextMeta = {}
ContextMeta.__index = ContextMeta

function ContextMeta:setMeta(key, value)
	self._meta[key] = value
end

function ContextMeta:getMeta(key)
	return self._meta[key]
end

function ContextMeta:getTargetEntity()
	return self._meta.TargetEntity
end

function ContextMeta:getTarget()
	if self._meta.TargetEntity then
		local hit = self._meta.TargetHitData or {}
		hit.entity = self._meta.TargetEntity
		return hit
	end
	return self._meta.TargetBlock
end

-- Creates a request to swap the running chain to a new root node.
-- Called by Replace node. The runner picks this up after execute returns.
function ContextMeta:replaceChain(newRoot)
	self._chainReplace = newRoot
end

-- Creates an independent clone with a fresh _meta store.
function ContextMeta:fork()
	local clone = setmetatable({}, ContextMeta)
	clone.user = self.user
	clone.owner = self.owner
	clone.interactionDef = self.interactionDef
	clone.manager = self.manager
	clone.chain = self.chain
	clone.interactionType = self.interactionType
	clone._meta = {}
	clone._commandBuffer = self._commandBuffer
	return clone
end

local function buildContext(character, chain)
	local commandBuffer = {
		getComponent = function(_entity, component)
			return world:get(_entity, component)
		end,
		hasComponent = function(_entity, component)
			return world:has(_entity, component)
				or world:get(_entity, component) ~= nil
		end,
		setComponent = function(_entity, component, value)
			world:set(_entity, component, value)
		end,
		removeComponent = function(_entity, component)
			world:remove(_entity, component)
		end,
		addEntity = function()
			return world:entity()
		end,
		deleteEntity = function(_entity)
			world:delete(_entity)
		end,
	}

	local ctx = setmetatable({
		user = character,
		owner = character,
		interactionDef = chain.interactionDef,
		manager = chain.manager,
		chain = chain,
		interactionType = chain.interactionType,
		_meta = {},
		_commandBuffer = commandBuffer,
	}, ContextMeta)

	return ctx
end

-- ═══════════════ Chain Runner ═══════════════

local function tickChain(character, chain)
	local ctx = buildContext(character, chain)
	local node = chain.currentNode

	-- RunTime enforcement: if active node has a min duration, hold until elapsed
	if node.RunTime and node.RunTime > 0 then
		if not chain._runTimeRemaining then
			chain._runTimeRemaining = node.RunTime
		end
	end

	-- HorizontalSpeedMultiplier: apply movement speed reduction while executing
	if node.HorizontalSpeedMultiplier and node.HorizontalSpeedMultiplier ~= 1.0 then
		chain._speedMult = node.HorizontalSpeedMultiplier
	end

	-- Side gate: restrict node execution to one environment
	local skipNode = (node.side == "server" and IS_CLIENT)
		or (node.side == "client" and not IS_CLIENT)
	if skipNode then
		chain._speedMult = nil
		chain._runTimeRemaining = nil
		if node.Next then
			chain.currentNode = node.Next
		else
			chain.completed = true
		end
		return
	end

	-- Filter predicates (Hytale node-level conditions)
	if node.Filters then
		for _, filter in node.Filters do
			if not evaluateFilter(filter, ctx) then
				chain._speedMult = nil
				chain._runTimeRemaining = nil
				if node.FilterFailed then
					chain.currentNode = node.FilterFailed
				elseif node.Next then
					chain.currentNode = node.Next
				else
					chain.completed = true
				end
				return
			end
		end
	end

	local status = node:execute(ctx)

	-- Handle chain replacement (Replace node swapped the root)
	if ctx._chainReplace then
		chain.currentNode = ctx._chainReplace
		chain._speedMult = nil
		chain._runTimeRemaining = nil
		ctx._chainReplace = nil
		return
	end

	-- RunTime gate: hold node even if finished before min duration
	if (
		status == NodeRegistry.SUCCESS or status == NodeRegistry.FAILURE
	) and chain._runTimeRemaining then
		chain._runTimeRemaining = chain._runTimeRemaining - DT
		if chain._runTimeRemaining > 0 then
			return
		end
		chain._runTimeRemaining = nil
	end

	if status == NodeRegistry.SUCCESS then
		chain._speedMult = nil
		chain._runTimeRemaining = nil
		if node.Next then
			chain.currentNode = node.Next
		else
			chain.completed = true
		end
	elseif status == NodeRegistry.FAILURE then
		chain._speedMult = nil
		chain._runTimeRemaining = nil
		if node.Failed then
			chain.currentNode = node.Failed
		else
			chain.failed = true
		end
	end
	-- RUNNING: chain continues next frame on same node
end

-- ═══════════════ INTERACTIONS Cache Merge ═══════════════
-- Rebuilds the character's INTERACTIONS cache from character-level
-- pair(HAS_INTERACTION, iType) pairs. NFL has no guns/inventory,
-- so this is simpler than the FPS version.

local function mergeInteractionsForCharacter(character, manager)
	local interactions = {}

	-- Character-level interactions (e.g. Jump, Dodge, Pass, Tackle)
	local ci = 0
	while true do
		local iType = world:target(character, components.HAS_INTERACTION, ci)
		if not iType then break end
		interactions[iType] = world:get(character, pair(components.HAS_INTERACTION, iType))
		ci += 1
	end

	world:set(character, components.INTERACTIONS, interactions)
	manager._cachedInventory = {}
end

-- ═══════════════ Main System ═══════════════

local function interactionDispatchSystem()
	for character, manager, inputState in characterQuery do
		local interactions = world:get(character, components.INTERACTIONS)
		local isNPC = not world:has(character, components.INPUT_FLAGS)

		-- Rebuild INTERACTIONS when missing (inventory-less: done once)
		if not interactions or not manager._cachedInventory then
			mergeInteractionsForCharacter(character, manager)
			interactions = world:get(character, components.INTERACTIONS)
		end

		-- 1. Dead check: cancel all active chains
		-- TODO: add IS_DEAD tag when health system is implemented
		-- if world:has(character, tags.IS_DEAD) then ...

		-- 1b. Remote entity skip (Overwatch model)
		if IS_CLIENT and not world:has(character, tags.PREDICTED) then
			continue
		end

		-- 2. Tick cooldowns (charge-based: each charge has independent timer)
		for cdId, cd in manager.cooldowns do
			cd.remaining = cd.remaining - DT

			if cd.remaining <= 0 then
				if cd.charges and cd.maxCharges and cd.charges < cd.maxCharges then
					cd.charges = cd.charges + 1
					if cd.charges < cd.maxCharges then
						cd.remaining = cd.chargeDuration or cd.baseDuration or 0
					else
						manager.cooldowns[cdId] = nil
					end
				else
					manager.cooldowns[cdId] = nil
				end
			end
		end

		-- 3. Tick chaining window timers
		if manager.chainingState then
			for chainId, state in manager.chainingState do
				state.windowTimer = state.windowTimer - DT
				if state.windowTimer <= 0 then
					manager.chainingState[chainId] = nil
				end
			end
		end

		-- 4a. Signal release on active chains BEFORE ticking
		for activeType, chain in manager.active do
			local actionName = world:get(activeType, jecs.Name)
			local state = actionName and inputState[actionName]
			if state and state.released then
				chain.state.inputReleased = true
				chain.state.held = false
			elseif state and (state.held or state.pressed) then
				chain.state.held = true
			end
		end

		-- 4b. Tick active chains
		for interactionType, chain in manager.active do
			if chain.cancelled then
				fireHook(manager, "onChainEnded", chain)
				manager.active[interactionType] = nil
			else
				tickChain(character, chain)
				if chain.completed or chain.failed then
					fireHook(manager, "onChainEnded", chain)
					manager.active[interactionType] = nil
				end
			end
		end

		-- 4c. Apply combined HorizontalSpeedMultiplier
		local combinedSpeedMult = 1.0
		local hasSpeedMult = false
		for _, chain in manager.active do
			if chain._speedMult then
				combinedSpeedMult = combinedSpeedMult * chain._speedMult
				hasSpeedMult = true
			end
		end
		manager._speedMultiplier = if hasSpeedMult then combinedSpeedMult else nil

		-- 5. Process intents -> start new chains
		if not interactions then continue end

		for interactionType, _interactionDef in interactions do
			local actionName = world:get(interactionType, jecs.Name)
			local state = actionName and inputState[actionName]
			if not state or not state.pressed then continue end

			if manager.active[interactionType] then continue end

			local interactionDef = interactions[interactionType]
			if not interactionDef then continue end

			if isBlockedByRules(interactionDef, manager.active) then continue end
			if isBlockedByActiveBlocking(interactionType, manager.active, interactionDef) then continue end

			if not isNPC and manager.cooldowns[interactionDef] then continue end

			applyInterrupting(interactionDef, manager.active, manager)
			applyInterruptedBy(interactionType, manager.active, manager, interactionDef)

			local chainDef = world:get(interactionDef, components.CHAIN_DEF)
			if not chainDef then continue end

			-- Build root node from config or deep-clone pre-built node
			local root
			if chainDef.Type and not chainDef.execute then
				root = NodeRegistry.build(chainDef)
			else
				root = NodeRegistry.deepClone(chainDef)
			end

			local chain = {
				interactionDef = interactionDef,
				root = root,
				currentNode = root,
				interactionType = interactionType,
				manager = manager,
				isNPC = isNPC,
				state = {},
				completed = false,
				failed = false,
				cancelled = false,
			}
			manager.active[interactionType] = chain

			fireHook(manager, "onChainStarted", chain)

			-- Evaluate first frame immediately
			tickChain(character, chain)
			if chain.completed or chain.failed then
				fireHook(manager, "onChainEnded", chain)
				manager.active[interactionType] = nil
			end
		end
	end
end

return {
	name = "InteractionDispatchSystem",
	phase = pipelines.Phases.Combat,
	system = interactionDispatchSystem,
}
