# Project Guidelines

Roblox game built on the same framework as the FPS reference project. Uses jecs ECS, Replecs replication, and Planck scheduling.

**Reference project (FPS):** `C:\Users\ptmer\Downloads\Roblox\Fps`
When asked about porting, implementing, or understanding any system below, read the actual source from that path before answering.

## Project
This project is a Roblox game, Its a Nfl game. It uses jecs ECS, Replecs replication, and Planck scheduling, Zap for client to server, Fusion for Ui, jecs utils for some handy things for jecs. The project is structured in a way that allows for easy modification and extension of the game mechanics, while maintaining a clean and organized codebase.

---

## Architectural Philosophy

This is a **reference framework**, not a one-off game. Every pattern must be reusable across future projects. The gold standard is Hytale's ECS + Interaction architecture.

Core principles:
- **Structural purity over functional equivalence.** Dont make something work just because it works. Make it work in a way that is architecturally correct and reusable.
- **Interaction layer fire off events** Interactions handle timing/animation. They add events in the event queue. ECS systems process those events. Interactions never mutate ECS state directly.
- **No hedging.** Never say "it works fine because Roblox is single-threaded." The question is always whether it's architecturally correct.
- **Hytale is the reference.** For interactions, use Hytale's architecture as a guide. If Hytale does it with a dedicated system type, prefer that pattern.
- **Build for the next game.** If a pattern is coupled to this specific project, it's wrong. Prefer generic, composable, ECS-native solutions.

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

### 6. jecs 0.10.4: `:with(TAG)` filter silently ignored

**Documented in memory**: `:with(TAG)` on cached AND non-cached queries is silently ignored. Non-cached stored queries compute `compatible_archetypes` once and never refresh (entities arriving later are missed). **Workaround**: body-level `world:has(entity, tag)` checks when needed for reliability.

### 9. Monitors fire before relationship targets are resolved

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

---

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

---

## Code Style

- **Components**: `UPPER_SNAKE_CASE` (e.g., `POSITION`, `VELOCITY`, `INPUT_BUFFER`)
- **Tags**: `UPPER_SNAKE_CASE` (e.g., `IS_GROUNDED`, `PREDICTED`)
- **Systems**: `PascalCaseSystem` for exports, `camelCase` for locals
- **Files**: `PascalCase.lua`

Import pattern:
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local components = require(ReplicatedStorage.Code.Shared.Components)
local world = require(ReplicatedStorage.Code.Shared.World)
```

---

## Architecture

```
ReplicatedStorage/Code/
├── Client/Systems/    -- Prediction, input, reconciliation, interpolation
├── Shared/            -- Components, Tags, World, Scheduler, PipeLines
└── Packages/          -- jecs, Planck, Replecs, jecs-utils, ByteNet
ServerScriptService/Server/
├── Systems/           -- Authoritative physics, input processing
└── Listeners/         -- Network event handlers
```

- Single jecs world in `Shared/World.lua`
- Components defined in `Shared/Components.lua`
- Tags defined in `Shared/Tags.lua`

---

## Build Commands

```bash
aftman install    # Install Rojo
rojo serve        # Live sync to Roblox Studio
rojo build -o game.rbxl
```

---

## jecs ECS Patterns

**Singleton**: `world:set(C, C, value)` / `world:get(C, C)` — component entity is its own storage.

**Cached queries** — always cache hot queries outside the system function:
```lua
local query = world:query(components.POSITION, components.VELOCITY):with(tags.PREDICTED):cached()
```

**Relationships**: `jecs.pair(A, B)` — e.g. `world:add(entity, jecs.pair(jecs.ChildOf, parent))`.

**Monitors** — jecs has no native `on_add` observer; use `query_changed` or polling wrappers. look in jecs-utils for observers and monitors and query wrappers.

**`IsA` warning** — jecs `IsA` traverses to a prefab for reads, but Replecs replicates concrete component values only. Do not rely on `IsA` inheritance for anything that must be replicated. Use `StandardEntities` free functions instead of bundle tables with `deepCopy`.

**Tags vs Components** — tags are zero-size markers (`world:add`). Components hold data (`world:set`). Never store data in a tag.

---

## System Pattern

All systems return a table with `name`, `phase`, `system`, and optional `runConditions`:

```lua
local query = world:query(components.POSITION, components.VELOCITY)
    :with(tags.PREDICTED):cached()

local function mySystem()
    for entity, pos, vel in query do
        world:set(entity, components.POSITION, newPos)
    end
end

return {
    name = "MySystem",
    phase = physicsPipeLine.Phases.Move,
    system = mySystem,
}
```

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
Scale = clamp(Scale, 0.995, 1.005) -- max ±0.5% time dilation
```
Replicated reliably. Client applies `CLOCK_SYNC.Scale` to physics accumulator: `accumulator += dt * timeScale`.

### Server input buffer management
- Anti-flood: trims buffer to `MaxSize` (10) from front
- Starvation: repeats last input up to 10 frames, then zeroes
- Adaptive sizing: grows `TargetSize` on starvation (cooldown 30 frames), shrinks after 60 stable frames

---

## Client-Side Prediction & Reconciliation

Reference implementation: `C:\Users\ptmer\Downloads\Roblox\Fps\src\ReplicatedStorage\Code\Client\Systems\Networking\EntityTickingSystems\ReconciliationSystem.lua`

When porting or modifying reconciliation, read that file first.

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

Reference implementation: `C:\Users\ptmer\Downloads\Roblox\Fps\src\ReplicatedStorage\Code\Shared\Systems\InteractionSystem.lua`
Node types: `C:\Users\ptmer\Downloads\Roblox\Fps\src\ReplicatedStorage\Code\Shared\Interactions\Nodes\`

When porting interactions or adding new interaction types, read InteractionSystem.lua and the node files first.

**Pattern:**
- Interactions are chains of nodes (Serial, Parallel, Condition, Repeat, etc.)
- Each node returns `SUCCESS`, `FAILURE`, or `RUNNING`
- Chains hold a `currentNode` pointer — NOT re-evaluated from root each tick (triggered-once, not BT-polling)
- `NodeRegistry.register(typeName, constructor)` — registers a node type
- `NodeRegistry.build(config)` — builds live tree from data config
- `NodeRegistry.deepClone(node)` — fresh chain state per interaction instance
- `InteractionManager` holds per-character state: active chains, cooldowns, chaining windows, speed multiplier, cached inventory

**Five phases per tick:** dead check → tick cooldowns → tick chaining windows → tick active chains → process intents

**NPC detection:** use explicit `IS_NPC` tag, not `not world:has(character, components.INPUT_FLAGS)`.

---

## StandardEntities Pattern

Reference: `C:\Users\ptmer\Downloads\Roblox\Fps\src\ReplicatedStorage\Code\Shared\StandardEntities.lua`

Free functions for entity initialization — NOT bundle tables with `deepCopy`:
```lua
StandardEntities.Character(world, entity, rootPart, humanoid)   -- server character
StandardEntities.PredictedCharacter(world, entity)              -- adds client prediction
```
- Direct `world:set` calls per component — type-checkable, no generic loop, no GC overhead
- Composable: `PredictedCharacter` layers on top of `Character`
- Never use `Bundles.lua` / `applyBundle` — that pattern is deprecated

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

## Timing Budget Reference

| Layer | Rate | Latency |
|-------|------|---------|
| Client input send | 60 Hz | ~0 ms |
| Network RTT | variable | ~50–150 ms |
| Server input buffer | TargetSize=2 ticks | ~33 ms |
| Reliable send throttle | 20 Hz | 0–50 ms |
| Unreliable send throttle | 30 Hz | 0–33 ms |
| Interpolation buffer delay | fixed | 100 ms |

## Wanted structure
This is the wanted structure for the project.
Interaction Layer this is a layer outside of the ecs that handles interactions between entities. It is responsible for managing the state of interactions, triggering events, and coordinating the execution of interaction chains.
Event queue layer this layer is the bridge between the interaction layer and the ecs. It is responsible for queuing events generated by interactions and ensuring that they are processed in the correct order.
Ecs layer this is the core of the system, where entities, components, and systems are defined and managed. It handles the processing of components and systems based on the events queued by the event queue layer. Also this layer is the truth he decides what is the state of the world and what is not. It is responsible for maintaining the integrity of the game state and ensuring that all interactions are processed correctly.
Visual Layer this layer is responsible for UI, Vfx, sfx and animations. It is responsible for rendering the game world and providing feedback to the player based on the state of the ECS and the events processed by the event queue layer. It ensures that the visual representation of the game world is consistent with the underlying ECS state. Also this layer is outside of the ecs because people that i hired are not familiar with jecs so they write just free functions that are called by the ecs and the interaction layer. This layer is responsible for providing a visual representation of the game world and ensuring that it is consistent with the underlying ECS state.

## Dont patch find the root cause
When you find a bug, do not patch it. Find the root cause and fix it. This is important because patching a bug can lead to more bugs in the future. It is better to take the time to find the root cause and fix it properly.

## Repeated bug fixing
After a while of trying to fix a bug there will be code that is not needed, if you found the solution check if the other fixes were part of the real bug or just a patch or a misunderstanding of the bug. If they are not needed remove them. This is important because it will make the code cleaner and easier to understand.

## No defensive checks
In systems dont add defensive checks what can be filtered by queries. For example if you have a system that processes entities with components A and B, do not add a check to see if the entity has component A or B. Instead, make sure that the query only returns entities that have both components A and B. This is important because it will make the code cleaner and more efficient. Also in observers usually defensive checks arent needed again the query should filter fine grained enough to not require defensive checks. If you find yourself adding a lot of defensive checks, it may be a sign that your queries are not well defined and you should consider restructuring your components and systems to better fit the data flow of your game. only use when really needed for example if it has to know if its in reconciliation state but even for that its not needed.

## Systems should own their state
Systems should own their own state tag/component a other systems shouldnt remove it or add it. the system who owns that state should have a second query who also removes it. for example floor collision should own is_grounded tag wallrunsystem shouldnt remove is_grounded tag to keep data in one placed and not scattered across multiple systems. This is important because it will make the code cleaner and easier to understand. It also makes it easier to debug and maintain the code in the future. If a system needs to know about a state, it should query for it and react to it, not manage it directly. This way the logic for that state is centralized in one system, making it easier to reason about and modify in the future.

## observers shouldnt be used as a event
Observers should not be used as an event system. They should be used to react to changes in the ECS state. if you find yourself toggling a component or tag to trigger a observer, it may be a sign that you should be using a different pattern, such as an event queue or a dedicated system for handling that logic. Observers are mostly used to keep invariants stable. or in fps case to add and remove coyotetimer because no system can actively know when the player left the ground but the floorcollision system. Its cool to use as a plugin for example if we remove the observer we dont have a coyotetimer nothing else breaks.

**references:**
Jecs documentation: https://github.com/Ukendio/jecs/tree/main/how_to
Hytale's Interactions and more: https://github.com/RomeoScript74/HytaleServer/tree/main/com/hypixel/hytale
Replecs documentation: https://pepeeltoro41.github.io/replecs/guides/networking-entity/
Planck documentation: https://yetanotherclown.github.io/planck/docs/getting_started/introduction
ZAP documentation: https://zap.redblox.dev/intro/getting-started.html
Fusion documentation: https://elttob.uk/Fusion/0.4/tutorials/fundamentals/your-first-project/
Flecs documentation: https://www.flecs.dev/flecs/md_docs_2Docs.html
Possible datasaving Packages: https://github.com/paradoxum-games/lyra, Profilestore