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

## EventQueue

Reference: `C:\Users\ptmer\Downloads\Roblox\Fps\src\ReplicatedStorage\Code\Shared\Utilities\EventQueue.lua`

Fixed-capacity ring buffer for typed ECS events. Use `bit32.band` not `&` for index masking.

---

## Networking Stack

- **ZAP** — generated binary protocol. `OnReliableUpdates`, `OnUnreliableUpdates`, input events
- **Replecs** — ECS component replication. Configured in `ReplicationPrefabs.lua`
- **ByteNet** — packet definitions for non-ECS messages

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
