-- ChainSnapshot.lua — capture/restore a predicted character's INTERACTION EXECUTION STATE for
-- reconciliation rollback (Phase 1 of the rollback-native chains plan).
--
-- Phase 0 made a running chain's state plain per-chain DATA — `scratch` keyed by node, `currentNode` a
-- reference into the SHARED, stable, immutable node tree — so a snapshot copies only the mutable bits
-- and KEEPS the tree references (never copies the tree). That's the whole reason this is cheap and
-- possible: nodes hold no state, so the tree is shared and its refs are stable across the session.
--
-- What rolls back: `manager.active` (the chains) + `INPUT_STATE` (so the replay's pressed/held/released
-- edge-detection reproduces and a chain that already fired isn't re-started). NOT manager.cooldowns
-- (dead — never populated; real cooldowns are the reconciled pair(COOLDOWN,*)) nor _speedMultiplier
-- (re-derived from active chains each tick). See [[rollback-native-chains-plan]].
--
-- Correctness note: the history snapshot must stay IMMUTABLE while the live state mutates, and the
-- restored live state must be independent of the history, so BOTH capture and restore deep-copy the
-- mutable data. Only refs into the shared tree (currentNode/root) and static refs (interactionDef,
-- interactionType) are shared — those never change.

local ChainSnapshot = {}

-- Deep copy of pure DATA (nested tables of primitives / Vector3 / entity-ids). Non-tables (numbers,
-- Vector3 userdata, entity ids, node refs) are returned as-is — Vector3 is immutable and node/entity
-- refs into the stable shared tree/world are meant to be shared, not cloned.
local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local c = {}
	for k, val in v do
		c[k] = deepCopy(val)
	end
	return c
end

-- Copy one live chain into a snapshot (or a snapshot back into a fresh live chain — same shape both
-- ways). Static refs are shared; mutable state (scratch/meta/state/flags/cursor-value) is deep-copied.
-- `currentNode`/`root` stay REFS into the shared tree; `manager` is intentionally omitted (re-linked on
-- restore) to avoid snapshotting the whole manager graph.
local function copyChain(chain)
	return {
		interactionDef = chain.interactionDef,
		root = chain.root,
		currentNode = chain.currentNode,
		interactionType = chain.interactionType,
		isNPC = chain.isNPC,
		scratch = deepCopy(chain.scratch),
		_meta = chain._meta and deepCopy(chain._meta) or nil,
		_runTimeRemaining = chain._runTimeRemaining,
		_speedMult = chain._speedMult,
		state = deepCopy(chain.state),
		completed = chain.completed,
		failed = chain.failed,
		cancelled = chain.cancelled,
	}
end

-- Snapshot the character's active chains + input intent state at the current tick (called by
-- HistoryRecorderSystem each tick). Note `scratch` is keyed by node REFERENCE — deepCopy preserves
-- those keys (the shared node objects are stable), so a restored chain's nodes find their state.
function ChainSnapshot.capture(active, inputState)
	local chains = {}
	for iType, chain in active do
		chains[iType] = copyChain(chain)
	end
	return {
		chains = chains,
		inputState = deepCopy(inputState),
	}
end

-- Restore active chains + return a fresh INPUT_STATE (caller world:set's it). Replaces manager.active
-- wholesale — a chain that COMPLETED after the snapshot tick is re-added; one that STARTED after is
-- dropped — so the manager is exactly as it was at the snapshot tick, ready for replay to re-advance it.
-- copyChain again so the live chains are independent of the (immutable) stored snapshot.
function ChainSnapshot.restore(manager, snap)
	table.clear(manager.active)
	for iType, chainSnap in snap.chains do
		local chain = copyChain(chainSnap)
		chain.manager = manager
		manager.active[iType] = chain
	end
	return deepCopy(snap.inputState)
end

return ChainSnapshot
