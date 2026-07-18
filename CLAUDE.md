# NFL Roblox Game — Agent Rulebook

Roblox NFL game. Stack: jecs ECS, Replecs replication, Planck scheduling, Zap networking, Fusion UI.
Reference FPS project: `C:\Users\ptmer\Downloads\Roblox\Fps` — read actual source before implementing any system.

---

## Project

This project is a Roblox NFL game. It uses jecs ECS, Replecs replication, Planck scheduling, Zap for client-to-server, Fusion for UI, jecs-utils for jecs helpers. Structured for easy modification while maintaining a clean, organized codebase.

---

## Architectural Philosophy

This is a **reference framework**, not a one-off game. Every pattern must be reusable across future projects. The gold standard is Hytale's ECS + Interaction architecture.

- **Structural purity over functional equivalence.** Don't make something work just because it works. Make it architecturally correct and reusable.
- **Interaction layer fires off events.** Interactions handle timing/animation. They add events in the event queue. ECS systems process those events. Interactions never mutate ECS state directly.
- **No hedging.** Never say "it works fine because Roblox is single-threaded." The question is always whether it's architecturally correct.
- **Hytale is the reference.** For interactions, use Hytale's architecture as a guide.
- **Build for the next game.** If a pattern is coupled to this specific project, it's wrong. Prefer generic, composable, ECS-native solutions.

---

## Wanted Layer Structure

1. **Interaction Layer** — outside ECS. Handles timing/animation, fires events into EventQueue. Never calls world:set/add/remove directly.
2. **EventQueue Layer** — bridge between interaction layer and ECS. Ring buffer. Ensures correct ordering.
3. **ECS Layer** — truth of the world. Only layer that mutates state. Systems process events and components.
4. **Visual Layer** — UI (Fusion), VFX, SFX, animations. Reads ECS state, never writes it. Free functions called by ECS/interaction layer (hired devs unfamiliar with jecs write here).

---

## Project Structure

```
src/ReplicatedStorage/Code/
├── Client/Systems/     -- Client prediction, input, interpolation
├── Shared/             -- Components.lua, Tags.lua, World.lua, Scheduler.lua, InputFlags.lua
src/ServerScriptService/Server/Systems/  -- Server authoritative systems
```

Single jecs world in `Shared/World.lua`. Components in `Shared/Components.lua`. Tags in `Shared/Tags.lua`.

## Validation — Run After Every File Change

```bash
selene src/
```

All errors must be fixed before finishing. Never leave failing lint.

## Exact System Template — No Deviations

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local tags = require(ReplicatedStorage.Code.Shared.Tags)
local world = require(ReplicatedStorage.Code.Shared.World)

-- Cache queries OUTSIDE the system function
local query = world:query(components.COMPONENT_A, components.COMPONENT_B)
    :with(tags.SOME_TAG):cached()

local function mySystem()
    for entity, compA, compB in query do
        world:set(entity, components.COMPONENT_A, newValue)
    end
end

return {
    name = "MySystem",
    phase = somePhase,
    system = mySystem,
}
```

## Non-Negotiable Rules

### Rule 1: Query is the filter
Never use `world:has()` or `world:get()` inside a system body to check component presence. Put it in the query.

```lua
-- WRONG
for entity, pos in query do
    if world:has(entity, tags.IS_GROUNDED) then ...

-- RIGHT
local groundedQuery = world:query(components.POSITION):with(tags.IS_GROUNDED):cached()
```

### Rule 2: Systems own their state end-to-end
The system that adds a component/tag is the ONLY system that removes it.
- `FloorCollisionSystem` owns `IS_GROUNDED` — no other system removes it
- `WallCollisionSystem` owns `WALL_NORMAL` — no other system removes it
- If system B needs a tag gone, system B must own that tag, not depend on system A to remove it

### Rule 3: Observers are not events
Never toggle a component just to trigger an observer. Observers react to archetype transitions only.
Use EventQueue for events.

### Rule 4: Interaction layer never mutates ECS directly
Interactions → EventQueue → ECS systems read queue → mutate state.
Interaction code never calls `world:set`, `world:add`, or `world:remove` directly.

### Rule 5: No IS_NPC negative detection
Use explicit `IS_NPC` tag. Never use `not world:has(entity, components.INPUT_FLAGS)` to detect NPCs.

## Naming Conventions

- Components: `UPPER_SNAKE_CASE`
- Tags: `UPPER_SNAKE_CASE`
- System file export: `PascalCaseSystem`
- Files: `PascalCase.lua`

## Always bit32, Never Operators

```lua
-- WRONG: bit32.band(a, b) can be replaced by &  -- NO
-- RIGHT:
bit32.band(flags, InputFlags.JUMP)
bit32.bor(flags, InputFlags.SHOOT)
bit32.bnot(flags)
```

## Architecture Layers (top to bottom)

1. **Interaction Layer** — handles input timing, animations, fires events into EventQueue. No ECS mutation.
2. **EventQueue** — bridge between interactions and ECS. Ring buffer.
3. **ECS Layer** — truth of the world. Systems process events and components. Only layer that mutates state.
4. **Visual Layer** — UI (Fusion), VFX, SFX, animations. Reads ECS state, never writes it.

## Read These Files First Before Implementing

Always read before writing any system:
- `src/ReplicatedStorage/Code/Shared/Components.lua` — what components exist
- `src/ReplicatedStorage/Code/Shared/Tags.lua` — what tags exist
- `src/ReplicatedStorage/Code/Shared/World.lua` — world setup
- Reference FPS system closest to what you're implementing

---

## jecs ECS Patterns

**Singleton**: `world:set(C, C, value)` / `world:get(C, C)` — component entity is its own storage.

**Cached queries** — always cache hot queries outside the system function:
```lua
local query = world:query(components.POSITION, components.VELOCITY):with(tags.PREDICTED):cached()
```

**Relationships**: `jecs.pair(A, B)` — e.g. `world:add(entity, jecs.pair(jecs.ChildOf, parent))`.

**Monitors** — jecs has no native `on_add` observer; use `query_changed` or polling wrappers. Look in jecs-utils for observers, monitors, and query wrappers.

**`IsA` warning** — jecs `IsA` traverses to a prefab for reads, but Replecs replicates concrete component values only. Do not rely on `IsA` inheritance for anything that must be replicated. Use `StandardEntities` free functions instead of bundle tables with `deepCopy`.

**Tags vs Components** — tags are zero-size markers (`world:add`). Components hold data (`world:set`). Never store data in a tag.

---

## Scheduling

Two Planck schedulers:
- **MainScheduler** — frame-rate driven (RunService). Runs input collection, replication, reconciliation, interpolation, rendering.
- **PhysicsScheduler** — 60 Hz fixed-step, gated by an accumulator in the physics driver systems. Runs the physics pipeline.

`PhysicsPhaseSet` is exported for routing systems to the correct scheduler in StartUp.

---

## Physics Pipeline Phases

Both client and server run the **same** pipeline at 60 Hz:

`ReadInput` → `Move` → `Gravity` → `WallCollision` → `Integration` → `Collision` → `Record`

PhysicsScheduler also has a Visuals pipeline: `VisualSmoothing` → `VisualsIK`.

---

## Input System

### InputFlags bitmask
Reference: `C:\Users\ptmer\Downloads\Roblox\Fps\src\ReplicatedStorage\Code\Shared\InputFlags.lua`

Flags are a `u32` bitmask stored in `INPUT_FLAGS` component (integer, not table — no GC allocation):
```
FORWARD=1, BACKWARD=2, LEFT=4, RIGHT=8, JUMP=16, DASH=32,
CROUCH=64, RELOAD=128, SHOOT=256, SHOOT_SECONDARY=512
```
Helpers: `InputFlags.has(mask, flag)`, `InputFlags.set(mask, ...)`, `InputFlags.clear(mask, ...)`.
Always use `bit32.band/bor/bnot` — never the `&` operator (Luau version-gated).

### Input pipeline
1. `InputBridgeSystem` (PreRender) — polls `UserInputService`, writes bitmask to `INPUT_FLAGS`
2. `InputToIntentSystem` (PreCombat) — bitmask → `INPUT_STATE` with `pressed/held/released` per named action
3. `InteractionSystem` (Combat) — reads `INPUT_STATE.pressed` to start interaction chains

**Tap event latch warning**: `InputBridgeSystem` rebuilds flags from scratch each render frame. At 144fps a 7ms tap can be missed by the 16.7ms physics tick. Fix: read existing flags from entity, latch tap bits (never clear in Bridge), clear in `InputToIntentSystem` after consuming.

---

## Netcode Architecture

### Two replication channels
- **Reliable (20 Hz)** — `SERVER_TICK`, `SERVER_POSITION`, `SERVER_VELOCITY`, gameplay params (`WALK_SPEED`, `GRAVITY_SCALE`, etc.), `CLOCK_SYNC`. Sent to every client including owner.
- **Unreliable (30 Hz)** — `POSITION`, `VELOCITY`, `REMOTE_TICK` with `ignoreOwner = true`. Sent to everyone except the entity owner.

Never mix them: reconciliation reads `SERVER_*`, interpolation reads `POSITION/VELOCITY/REMOTE_TICK`.

### Clock sync
```
error = bufferSize - TargetSize
Scale = 1.0 - (error * 0.003)
if |error| <= 2 then Scale = 1.0   -- dead zone
Scale = clamp(Scale, 0.995, 1.005) -- max +/-0.5% time dilation
```
Replicated reliably. Client applies `CLOCK_SYNC.Scale` to physics accumulator: `accumulator += dt * timeScale`.

### Server input buffer management
- Anti-flood: trims buffer to `MaxSize` (10) from front
- Starvation: repeats last input up to 10 frames, then zeroes
- Adaptive sizing: grows `TargetSize` on starvation (cooldown 30 frames), shrinks after 60 stable frames

---

## Client-Side Prediction & Reconciliation

Reference: `C:\Users\ptmer\Downloads\Roblox\Fps\src\ReplicatedStorage\Code\Client\Systems\Networking\EntityTickingSystems\ReconciliationSystem.lua`

Read that file before modifying any reconciliation code.

**Pattern (Overwatch-style replay):**
1. `query_changed` fires on `SERVER_TICK / SERVER_POSITION / SERVER_VELOCITY`
2. Find matching history entry for that server tick
3. Compare server pos vs predicted pos at that tick
4. If desync exceeds threshold: snap to server state, replay all history entries after that tick via `PhysicsScheduler:run(Simulation)`
5. `VISUAL_OFFSET += oldClientPos - newCorrectedPos` (smoothed to zero over ~100ms)

**Desync thresholds:** horizontal 1.5 studs, vertical grounded 1.1 studs, vertical airborne 0.5 studs.

History recorder (`HistoryRecorderSystem`) stores: `{ Tick, X, Z, PredictedPos, PredictedVel, Flags, Timestamp }`. Keeps 120 entries (2s window). `Flags` is an integer bitmask.

---

## Interaction System (BT-style execution graph)

Reference: `C:\Users\ptmer\Downloads\Roblox\Fps\src\ReplicatedStorage\Code\Shared\Systems\InteractionSystem.lua`
Node types: `C:\Users\ptmer\Downloads\Roblox\Fps\src\ReplicatedStorage\Code\Shared\Interactions\Nodes\`

Read InteractionSystem.lua and the node files before porting or adding interaction types.

**Pattern:**
- Interactions are chains of nodes (Serial, Parallel, Condition, Repeat, etc.)
- Each node returns `SUCCESS`, `FAILURE`, or `RUNNING`
- Chains hold a `currentNode` pointer — NOT re-evaluated from root each tick (triggered-once, not BT-polling)
- `NodeRegistry.register(typeName, constructor)` — registers a node type
- `NodeRegistry.build(config)` — builds live tree from data config
- `NodeRegistry.deepClone(node)` — fresh chain state per interaction instance
- `InteractionManager` holds per-character state: active chains, cooldowns, chaining windows, speed multiplier, cached inventory

**Five phases per tick:** dead check → tick cooldowns → tick chaining windows → tick active chains → process intents

---

## StandardEntities Pattern

Reference: `C:\Users\ptmer\Downloads\Roblox\Fps\src\ReplicatedStorage\Code\Shared\StandardEntities.lua`

Free functions for entity initialization — NOT bundle tables with `deepCopy`:
```lua
StandardEntities.Character(world, entity, rootPart, humanoid)
StandardEntities.PredictedCharacter(world, entity)
```
- Direct `world:set` calls per component — type-checkable, no generic loop, no GC overhead
- Composable: `PredictedCharacter` layers on top of `Character`
- Never use `Bundles.lua` / `applyBundle` — deprecated

---

## Remote Player Interpolation

Reference: `C:\Users\ptmer\Downloads\Roblox\Fps\src\ReplicatedStorage\Code\Client\Systems\ClientVisualInterpolator.lua`

- Entities **without** `PREDICTED` tag use interpolation
- Stores `SNAPSHOT_BUFFER` (max 20 entries): `{ Time = tick/60, Pos, Vel }`
- `INTERPOLATION_CLOCK` runs 100ms behind newest snapshot
- Drift correction: slow down if ahead, speed up if behind, hard snap if > 0.5s drift
- Extrapolates via velocity for up to 0.25s past newest snapshot

---

## Animation Layer

Pure Visual layer — **client-only**, reads ECS state, never writes it. The server never plays tracks.

**Setup reality**: characters are Roblox rigs but `CharacterSetup.lua` sets `Anchored=true`, `PlatformStand=true`, `EvaluateStateMachine=false` — the Humanoid is a dead pose-holder and CFrame is driven directly from ECS. Roblox's default `Animate` script is inert. You own animation 100% via the Humanoid's `Animator` (still plays tracks with the state machine off).

**Two categories, two mechanisms:**
1. **Locomotion (idle/walk/run/jump/fall)** — *continuous* state → **polling** visual system (`LocomotionAnimationSystem`, PreRender). State chosen from **velocity alone** (no `IS_GROUNDED` dependency — remotes aren't simulated and never have that tag): vertical speed → jump/fall, horizontal speed → idle/walk/run with playback speed scaled to velocity (no foot skate).
2. **Interaction anims (tackle/brace/dash)** — *discrete* → **observer plugin** on the gameplay state tag the interaction already sets (`TACKLING`, `BRACED`, …). Tag added → play, removed → blend back. This is the legitimate observer-as-plugin use (not toggling to trigger — the tag exists for gameplay). Driving off the **replicated tag** means the same code path fires on the local predictor (instant) AND every remote when it replicates — a node calling `:Play()` would only animate one machine.

**Velocity source is realm-split**: local predicted player uses live `VELOCITY`; remotes use `SERVER_VELOCITY` (plain `VELOCITY` isn't set on interpolated remotes). Two drive queries, one shared `driveLocomotion()`.

**Storage**: `ANIMATION_TRACKS` — client-only component `{ tracks = {name -> AnimationTrack}, current = stateName }`, loaded from the model's Animator when `ROOTPART` resolves, never replicated (Instances → pitfall #2). `LocomotionAnimationSystem` owns it (load query `:without(ANIMATION_TRACKS)` + drive queries `:with`). Asset ids + tuning live in `Client/AnimationConfig.lua` (NOT `Client/Systems/` — that folder auto-registers every module as a Planck system; NOT a `*Calc` — animation is single-realm, nothing to keep bit-identical).

## EventQueue

Reference: `C:\Users\ptmer\Downloads\Roblox\Fps\src\ReplicatedStorage\Code\Shared\Utilities\EventQueue.lua`

Fixed-capacity ring buffer for typed ECS events. Use `bit32.band` not `&` for index masking.

---

## Networking Stack

- **ZAP** — generated binary protocol. `OnReliableUpdates`, `OnUnreliableUpdates`, input events
- **Replecs** — ECS component replication. Configured in `ReplicationPrefabs.lua`
- **ByteNet** — packet definitions for non-ECS messages

---

## Timing Budget Reference

| Layer | Rate | Latency |
|-------|------|---------|
| Client input send | 60 Hz | ~0 ms |
| Network RTT | variable | ~50–150 ms |
| Server input buffer | TargetSize=2 ticks | ~33 ms |
| Reliable send throttle | 20 Hz | 0–50 ms |
| Unreliable send throttle | 30 Hz | 0–33 ms |
| Interpolation buffer delay | fixed | 100 ms |

---

## Known Pitfalls & Debugging Lessons

### 1. `replicator:after_replication` fires immediately before `apply_full`

**The trap**: `after_replication(callback)` runs the callback **immediately** when `is_replicating` is false. Since it's usually registered before `apply_full`, it fires before entities exist. The callback is then **cleared** (`table.clear` in `finish_replication`) and **never fires again** after `apply_full`.

**Wrong**:
```lua
replicator:after_replication(function() -- fires NOW, entities don't exist yet
    resolveRootParts()
end)
local buf = WaitForServer.Call()
replicator:apply_full(buf, variants)    -- callback already cleared, never fires here
```

**Right**:
```lua
local buf = WaitForServer.Call()
replicator:apply_full(buf, variants)
-- Call DIRECTLY after apply_full — entities exist.
resolveRootParts()
-- For ongoing updates, use replicator:added + dirty flag + after_replication
-- (see RootPartResolver pattern in Client/Init/Networking.lua)
```

### 2. Never replicate Roblox Instance references

**The trap**: Raw `ROOTPART` (HumanoidRootPart Instance) replicated via Zap's Instance table causes `"received instance is nil!"` crash when the character model hasn't streamed to the client yet. Zap serializes Instances as indices into `incoming_inst`; if the Instance doesn't exist on the client, it's nil → crash.

**Rule**: Instance references (BaseParts, Models) must **never** go on the wire. Resolve them locally from the `PLAYER` component:
```lua
local player = world:get(playerEntity, components.PLAYER)
local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
```
The `PLAYER` component (Player Instance) IS safe to replicate — it's a UserId-backed reference, not a streaming-dependent Instance.

### 3. jecs 0.10.4: `world:query(pair(Rel, Wildcard))` target iteration variable is nil

**The trap**: `for entity, target in world:query(pair(OwnedBy, jecs.Wildcard))` — the **second** iteration variable (`target`) can be **nil** even though the pair exists. The query correctly finds entities; only the target extraction via iteration variable is unreliable. This happens when entities are created out of order during `apply_full` (target entity doesn't exist yet when the pair is processed).

**Wrong**:
```lua
for charEntity, playerEntity in world:query(pair(components.OwnedBy, jecs.Wildcard)) do
    -- playerEntity may be nil!
    local player = world:get(playerEntity, components.PLAYER) -- CRASH
end
```

**Right** — query finds entities, extract target separately:
```lua
-- Pattern A: single iteration variable + world:target
for charEntity in world:query(pair(components.OwnedBy, jecs.Wildcard)) do
    local playerEntity = world:target(charEntity, components.OwnedBy)
    if not playerEntity then continue end
    local player = world:get(playerEntity, components.PLAYER)
end

-- Pattern B: collectTargets utility (for multi-target pairs like TIMER, COOLDOWN)
for entity in world:query(pair(components.TIMER, jecs.Wildcard)) do
    for _, target in collectTargets(entity, components.TIMER) do
        -- safe mutation during iteration
    end
end
```

**Existing valid usage**: `CooldownSystem` and `TimerSystem` use `for entity in world:query(pair(X, Wildcard))` (single variable) + `collectTargets()` — this is correct and safe.

### 4. jecs 0.10.4: `jecsUtils.monitor` misses new archetypes

**The trap**: `jecsUtils.monitor(query).added(callback)` pre-computes which archetypes match the query at **registration time**. If the target archetype (e.g. entity with `OwnedBy + ROOTPART`) doesn't exist yet, transitions into it are **never detected**.

**Wrong**:
```lua
-- Registered when no entity has OwnedBy+ROOTPART yet → archetype doesn't exist
jecsUtils.monitor(world:query(pair(OwnedBy, playerEntity), components.ROOTPART))
    .added(function(entity) ... end) -- NEVER fires
```

**Right** — use `world:added(component, callback)` directly (reactive, no pre-computation):
```lua
local conn = world:added(components.ROOTPART, function(entity)
    if entity ~= targetEntity then return end
    conn() -- world:added returns a disconnect FUNCTION, not an object
    -- handle the component being added
end)
```

### 5. `world:added` returns a function, not an object

**The trap**: `world:added(component, callback)` returns a **disconnect function**, not an object with a `:disconnect()` method.

**Wrong**: `conn:disconnect()` — crashes with "attempt to index function with 'disconnect'"
**Right**: `conn()` — calls the disconnect function directly

### 6. Monitors fire before relationship targets are resolved

**The trap**: During `apply_full`, entities are created and components are applied in server-serialized order. A `jecsUtils.monitor(query).added(callback)` fires the instant the entity matches the query (e.g. has `REMOTE_TICK + SERVER_POSITION`). But at that moment, `world:target(entity, OwnedBy)` returns **nil** — the pair's target entity hasn't been mapped from server ID to client ID yet. Replecs entity remapping happens asynchronously within the batch.

**Symptom**: `[RemoteInterp] playerEntity: nil` — monitor fires, entity found, but relationship target not resolved. ROOTPART can't be set because OwnedBy → PLAYER → Character chain is broken.

**Why polling works**: A system that runs every frame at `PreSimulation` retries `world:target(entity, OwnedBy)` until the relationship resolves (usually next frame). It doesn't care about entity creation order within `apply_full`.

**Rule**: Monitors are for **intra-component** reactions (entity gained `SERVER_POSITION` — seed interpolation). Polling systems are for **cross-entity** initialization (entity has OwnedBy → need to find the PLAYER entity → need to find the Character → need to find the HRP).

**Pattern used in `InitCharacterSystem`**:
```lua
-- Monitor: seeds interpolation (single-entity, no relationships needed)
jecsUtils.monitor(remoteQuery).added(function(entity)
    world:set(entity, SNAPSHOT_BUFFER, {...})  -- reads SERVER_POSITION directly
end)

-- Polling system: resolves cross-entity chain (OwnedBy → PLAYER → Character → HRP)
local function initCharacterSystem()
    for charEntity in world:query(SERVER_POSITION) do
        local playerEntity = world:target(charEntity, OwnedBy)  -- may be nil frame 1, ok frame 2
        if not playerEntity then continue end
        -- ...
    end
end
```

### 7. `Character:FindFirstChild` can return nil before streaming

**The trap**: `player.Character:FindFirstChild("HumanoidRootPart")` can return nil if the character model hasn't fully streamed. Use `CharacterAdded` event to retry.

**Pattern used in `RootPartResolver`**:
```lua
local function tryResolve()
    if not player.Character then return false end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    world:set(charEntity, components.ROOTPART, hrp)
    return true
end
if not tryResolve() then
    player.CharacterAdded:Connect(function()
        if tryResolve() then ... end  -- retry when character spawns
    end)
end
```

### 8. jecs 0.10.4: `:with()`/`:without()` do not chain — a second call silently overwrites the first

**The trap**: `query:with(A):with(B)` and `query:without(A):without(B)` each REPLACE the previous filter — they don't merge. Only the LAST call's arguments survive (for `:with`, plus the base components passed to `world:query(...)`). Confirmed in the vendored source (`query_with`/`query_without` in `jecs.luau`): both unconditionally do `query.filter_with = {...}` / `query.filter_without = {...}` from only the current call's args — neither ever reads the query's existing filter to merge into it.

**Wrong**:
```lua
local query = world:query(components.VELOCITY, ...)
    :with(tags.IS_GROUNDED)
    :with(tags.PREDICTED)     -- SILENTLY drops IS_GROUNDED from the filter
    :cached()
```

**Right** — pass every filter to ONE call:
```lua
local query = world:query(components.VELOCITY, ...)
    :with(tags.IS_GROUNDED, tags.PREDICTED)
    :cached()
```
Same rule for `:without(A, B, C)` — never chain, always one call with all args.

**Real incidents this caused**:
1. `RemoteVisualInterpolator`'s `:without(PREDICTED):without(PHYSICS_DISABLED)` dropped the PREDICTED exclusion, so the local predicted character matched the remote-interpolation query and rendered ~150ms behind — looked like "my character stopped predicting."
2. `ClientCharGroundVelocitySystem`'s `:with(IS_GROUNDED):with(PREDICTED)` dropped IS_GROUNDED, applying ground-movement acceleration to the predicted character even while airborne — a client/server physics mismatch that surfaced as reconciliation churn around jumps.

---

## No Defensive Checks

In systems don't add defensive checks that can be filtered by queries. If you have a system that processes entities with components A and B, do not add a check to see if the entity has component A or B — make sure the query only returns entities that have both. Also in observers, defensive checks usually aren't needed — the query should filter fine-grained enough. Only use defensive checks when truly needed and unavoidable.

---

## Systems Should Own Their State

Systems should own their own state tag/component. Other systems shouldn't remove it or add it. The system that owns the state should have a second query that also removes it.

Example: `FloorCollisionSystem` owns `IS_GROUNDED` — `WallRunSystem` should NOT remove `IS_GROUNDED`. Keep state logic centralized in the owning system. If a system needs to know about a state, it should query for it and react, not manage it directly.

---

## Observers Should Not Be Used as Events

Observers should react to changes in ECS state, not be used as an event system. If you find yourself toggling a component or tag to trigger an observer, use an EventQueue or a dedicated system instead.

Observers are mostly used to keep invariants stable — for example, adding a coyote timer when a player leaves the ground, because no other system can actively know when that transition happens. It's a plugin: remove the observer and the feature disappears cleanly, nothing else breaks.

---

## Bug Fixing Rules

- **Don't patch, find the root cause.** Patching leads to more bugs. Find why it's wrong and fix that.
- **After repeated fixing:** Check if previous fixes were patches or misunderstandings. Remove code that isn't needed. Keep it clean.

---

## References

- Jecs: https://github.com/Ukendio/jecs/tree/main/how_to
- Hytale architecture: https://github.com/RomeoScript74/HytaleServer/tree/main/com/hypixel/hytale
- Replecs: https://pepeeltoro41.github.io/replecs/guides/networking-entity/
- Planck: https://yetanotherclown.github.io/planck/docs/getting_started/introduction
- ZAP: https://zap.redblox.dev/intro/getting-started.html
- Fusion: https://elttob.uk/Fusion/0.4/tutorials/fundamentals/your-first-project/
