# JataYuk

An AR educational app for kids built with SwiftUI + ARKit + RealityKit. Players place a virtual volcano and ingredient stations on a real flat surface, mix chemicals, and watch an elephant toothpaste eruption — right on their table.

---

## Table of Contents

1. [What It Does](#what-it-does)
2. [Architecture: Micro-TCA](#architecture-micro-tca)
3. [Feature Deep-Dives](#feature-deep-dives)
   - [AR Placement System](#ar-placement-system)
   - [Asset Loading & the sGeometryModifier Bug Bypass](#asset-loading--the-sgeometrymodifier-bug-bypass)
   - [Proximity System](#proximity-system)
   - [Carry & Placeback System](#carry--placeback-system)
   - [Motion System (Tilt + Shake)](#motion-system-tilt--shake)
   - [Instruction System](#instruction-system)
   - [Explosion Pipeline](#explosion-pipeline)
   - [Audio Architecture](#audio-architecture)
4. [Key Technical Decisions](#key-technical-decisions)
5. [Requirements](#requirements)
6. [GitHub Collaboration Rules](#github-collaboration-rules)

---

## What It Does

| Phase | Description |
|---|---|
| **Loading / Onboarding** | Animated intro with guide cards explaining the elephant toothpaste experiment |
| **Main Page** | Experiment card selection |
| **AR Placement** | Tap a flat surface to place the volcano and both ingredient stations at once |
| **Experiment** | Pick up ingredients, tilt to pour into the beaker, shake to mix, then trigger the volcano |
| **Explosion** | SPH-based foam simulation erupts from the volcano — color reflects poured food coloring |
| **End Screen** | Success overlay appears 3 seconds after eruption; eye button lets players admire the mess |

### Experiment Rules

- **Side A** holds: H₂O₂ (hydrogen peroxide), dish soap, and food coloring
- **Side B** holds: yeast (spoon) and warm water (kettle)
- Every non-depleted ingredient on a side must be poured at least once before that beaker can be shaken
- **Food colorings are a group** — pouring any one of the three bottles satisfies the requirement; up to 5 pours per bottle, blended additively into the foam color (red+green → yellow, etc.)
- Tilt the device forward to pour a held ingredient; shake to mix a locked-in beaker
- Releasing an ingredient without pouring animates it back to its resting spot with a cubic ease-out

---

## Architecture: Micro-TCA

This project follows a hand-rolled **Micro-TCA** pattern — same unidirectional data flow as The Composable Architecture, without the library dependency.

### Folder Structure

```
JataYuk/
├── Core/
│   ├── MicroTCA/               # Store<State, Action>, Effect primitives
│   ├── Environment/            # Clients: ARClient, MotionClient, SoundClient, ShaderDevAssets
│   └── Models/                 # Shared model types (ARModels, ExperimentModels, etc.)
│
└── Features/
    ├── App/
    │   ├── RootReducer.swift   # Composes all feature reducers
    │   ├── RootView.swift      # Navigation entry point (route switcher)
    │   └── RootState.swift     # Global state tree
    │
    ├── AR/                     # ARExperimentView + ARCoordinator (7 extension files)
    ├── End/                    # EndView + EndState
    ├── Instructions/           # InstructionView, InstructionDerivation, InstructionModel
    ├── Sandbox/                # Explosion ECS: SPH solver, emission, chemistry, GPU compute
    └── <Feature>/              # LoadingPage, MainPage, Onboarding, ItemInfo, Pause
```

### Data Flow

```
View → Action → Reducer ──→ update State → re-render View
                       └──→ [Effect] (async, AR, CoreMotion, AVFoundation)
```

1. **View** dispatches an **Action** (tap, tilt gesture, proximity change, timer tick)
2. **Reducer** receives `(inout State, Action)` and returns `[Effect]`
3. **Effects** handle side effects and feed new Actions back in
4. **Store** holds State and drives Views reactively via `@ObservedObject`

### Feature Layer Example — Experiment

| Layer | Responsibility |
|---|---|
| `ExperimentModels` | `Ingredient`, `MixingBeaker`, `FoamModel`, `StationSide` |
| `ARAction` | `.pickupIngredient`, `.pourIngredient`, `.shakeMixingBeaker`, `.interactWithVolcano` |
| `RootReducer` | Validates pours, tracks `foodColorPours[colorIndex]`, advances `volcanoState` |
| `ARCoordinator` | Bridges ARKit/RealityKit frame events → Store actions |

---

## Feature Deep-Dives

### AR Placement System

**Files:** `ARCoordinator+Placement.swift`, `ARCoordinator+Session.swift`

When the player taps the screen, `handleTap(_:)` raycasts from that screen point into the real world. It prefers `existingPlaneInfinite` results (ARKit already detected a plane) and falls back to `estimatedPlane`. If the result is too close to an already-placed object, it fires a warning haptic and returns.

On a valid tap:
1. `preloadSFX()` — audio files are loaded in parallel before anything spawns
2. `placeScene(at:planeAnchor:in:)` — builds the entire layout under **one shared `AnchorEntity`**:
   - If a real `ARPlaneAnchor` was hit, the root anchor tracks that plane anchor. All child entities (volcano + both stations) move with the plane as ARKit refines it, preventing independent drift
   - The camera's X-axis is projected onto the horizontal plane to find `camRight` — station A goes to the player's physical left, station B to the right, regardless of world orientation
   - Station offsets are deliberately asymmetric (0.90 m vs 0.60 m) because Side A carries more ingredients
3. Three `placementAdvanced` actions are fired in sequence, advancing the state machine from `.placingVolcano` → `.placingSideA` → `.placingSideB` → `.allPlaced` in a single tap — everything lands at once
4. On `.allPlaced`: plane detection is disabled (frozen config), plane overlays are hidden, motion monitoring and proximity subscriptions are started, and interactive entities are spawned

**Plane visualization:** `ARCoordinator+Session.swift` implements `ARSessionDelegate` and renders a semi-transparent `SimpleMaterial` plane mesh for each detected `ARPlaneAnchor`. These meshes grow/shrink with ARKit updates and are hidden once placement succeeds.

---

### Asset Loading & the sGeometryModifier Bug Bypass

**Files:** `ShaderDevAssets.swift`, `ShaderDev` package (USDC + RCP shaders)

All 3D models live in the `ShaderDev` local Swift package as USDC assets. Their materials are authored in Reality Composer Pro using custom PBR shader graphs.

**The sGeometryModifier vertex bug:**
RealityKit's `sGeometryModifier` (the vertex-stage shader in a custom material) displaces mesh vertices in *object space* using offsets and vectors authored at a specific entity scale. The bug: if you change `entity.scale` at runtime after the material is compiled and attached, the object-space vertex positions seen by the modifier shift, but the displacement values in the shader do not compensate. This causes visually wrong vertex positions — vertices appear displaced in the wrong direction or by the wrong magnitude relative to the mesh surface.

**The bypass — wrapper entity pattern in `ShaderDevAssets.wrap()`:**

```
                ┌─ wrapper (Entity, scale = 1.0 at load; runtime scale applied here) ─┐
                │                                                                       │
                │    ┌─ loaded (Entity, scale set ONCE by fit(); never changed again) ─┤
                │    │                                                                  │
                │    │   ← sGeometryModifier always sees the same vertex positions ─── │
                └────┴──────────────────────────────────────────────────────────────────┘
```

1. `fit(loaded, maxExtent:)` — scales the inner entity **once** at load time to normalize it to a consistent world size (e.g. 0.15 m max extent). This is a permanent, one-time change. The geometry modifier is authored assuming this exact scale, so it works correctly.
2. A plain `wrapper = Entity()` is created and `loaded` becomes its child.
3. `generateCollisionShapes(recursive: true)` is called on the wrapper so collision fits the actual geometry.
4. All runtime scale changes — proximity highlight (`1.18×`), visual feedback, depleted gray-out — are applied to `wrapper.scale`, **never** to `loaded.scale`.

Because `loaded.scale` is frozen after `fit()`, the geometry modifier always processes the vertex positions it was designed for, and the visual results are correct. Changing `wrapper.scale` only affects the transform hierarchy above the modifier's input — the modifier itself sees the same object-space vertices every frame.

---

### Proximity System

**Files:** `ARCoordinator+Proximity.swift`, `ARComponents.swift`

Every ingredient entity has an `IngredientComponent(side:ingredientIndex:)` tag, and every beaker entity has a `MixingBeakerComponent(side:)` tag. These link back to the store indices with zero lookup overhead.

The system runs inside a `SceneEvents.Update` subscription (every RealityKit render frame) with two tiers of work:

| Tier | Frequency | Work |
|---|---|---|
| **Every frame** | ~60 Hz | Tick the explosion ECS/TCA pipeline (`explosionStore?.tick(deltaTime:)`) |
| **Proximity check** | ~6 Hz (every 10th frame) | `updateProximity()` — camera-distance checks, state dispatch |

**Ingredient proximity** uses two distance thresholds measured from the camera:

| State | Distance | Visual |
|---|---|---|
| `.far` | > 0.35 m | Scale `1.0×` |
| `.highlighted` | ≤ 0.35 m, closest interactive entity | Scale `1.18×` (wrapper entity, not inner model) |
| `.inHand` | ≤ 0.15 m / picked up by tap | Scale `1.0×`, reparented to `cameraAnchor` |

**Solo-highlight rule:** Only the single closest interactive entity gets the `.highlighted` state at any moment. If anything is already `.inHand`, highlighting is suppressed entirely — the player can only hold one thing at a time.

**Beaker proximity** behaves slightly differently: the `.inHand` state is sticky (stays until the camera moves beyond `highlightedDistanceM`), because locking into the beaker is intentional — the player needs to physically shake.

**External release detection:** Each proximity tick checks whether a `carriedEntity` exists on the `cameraAnchor` but the store no longer shows it as `.inHand`. This detects "external releases" (e.g. debug buttons) and triggers `placebackEntity()` automatically.

**Sound-on-proximity events:**
- Yeast picked up → `.scoopSand` SFX fires immediately on `inHand` transition
- Soap / food coloring returned without a pour → `.placeDishSoapOrFoodColoring` SFX fires
- Beaker set down → `.placeGlass(side)` SFX fires

---

### Carry & Placeback System

**Files:** `ARCoordinator.swift` (`attachEntityToCamera`, `placebackEntity`), `ARCoordinator+Proximity.swift`, `ARCoordinator+Motion.swift`

**Pickup:** `attachEntityToCamera()` reparents the ingredient entity to the `cameraAnchor` (an anchor locked to the camera transform) at position `(0, -0.05, -0.3)` — 30 cm in front and slightly below the lens. The entity follows the player's movements as a held object.

**Placeback animation:** When an ingredient is released (with or without a pour), `placebackEntity()` runs instead of a snap-back:

1. `setParent(originalParent, preservingWorldTransform: true)` — the entity is reparented back to its station, but its world position is preserved so it visually stays where it was floating
2. The entity's new *local* position (`startLocalPos`) is captured
3. A `Task { @MainActor }` runs a 15-step cubic-ease-out interpolation over ≈ 0.4 s:

```
eased = 1 - (1 - t)³        // cubic ease-out: fast start, slow landing
position = start + (target - start) × eased
```

Each step sleeps 26.7 ms (≈ one frame at 60 Hz). The task guards `entity.parent === originalParent` each step — if the entity gets picked up again mid-animation, the task exits silently.

**Why not `entity.move(to:relativeTo:duration:)`?** RealityKit's `move()` animation is unreliable when called immediately after `setParent` — the animation system can use the pre-reparent transform as the start, producing a jump or flicker. The manual Task lerp avoids this entirely.

---

### Motion System (Tilt + Shake)

**File:** `ARCoordinator+Motion.swift`, `MotionClient.swift`

**Tilt (pour):** `MotionClient.startTiltMonitoring` streams `CMDeviceMotion` updates and fires a callback when pitch exceeds ~45°. `ARCoordinator` receives this and calls `activePourTarget()`:
- Iterates both sides looking for an ingredient `.inHand` whose same-side beaker is `.highlighted` or `.inHand`
- Returns `(side, index)` only when those conditions are met

On a successful pour:
1. `store.send(.ar(.pourIngredient(side, index)))` — reducer increments `pourCount`, records `foodColorPours` for color tinting, checks depletion
2. `playPourSFX(for: type, entity:)` — yeast gets `.pourSand`, all others get `.pourLiquid`
3. `store.send(.ar(.releaseIngredient(side, index)))`
4. `placebackEntity()` — ingredient animates back

**Shake (mix):** `startShakeMonitoring` fires when `userAcceleration` magnitude exceeds ~1.0 g. `activeShakerTarget()` returns a side only when:
- That side's beaker is `.inHand` (locked in)
- `allIngredientsPoured(side:)` is true
- Beaker mixture state is `.prepared`

On shake: the beaker gets a quick 4-cycle left-right oscillation (`animateBeakerMix`), the `.mixOrShake` SFX plays, and the beaker proximity is reset to `.far`.

---

### Instruction System

**Files:** `InstructionDerivation.swift`, `InstructionModel.swift`, `InstructionView.swift`

`InstructionDerivation.currentInstruction(for: state)` is a pure function that maps the entire `RootState` to a single `InstructionStep?`. It runs on every SwiftUI render pass (no extra subscriptions). Priority order:

1. **Placement phase** — `placingVolcano` / `placingSideA` / `placingSideB` each show a dedicated step
2. **Volcano phase** — both beakers mixed: shows the volcano interaction prompt, reaction text, or done message depending on `volcanoState`
3. **Active station** — determined by `state.ar.activeStation`; falls through to station instructions
4. **Station instructions** (per side, 7-level priority waterfall):
   - Beaker already mixed → "side complete"
   - Holding beaker + prepared → "shake to mix"
   - Holding an ingredient → context-sensitive pour prompts (bring to beaker, tilt to pour, offer more, max pours)
   - Near (highlighted) an ingredient → ingredient-specific intro copy
   - Beaker ready + all slots poured → "ready to mix"
   - Some progress but nothing active → "offer more" or "max pours reached"
   - No progress → side intro (shown once) then "move closer to bench"

Ingredient grouping for instruction purposes uses `Slot` objects — food colorings are a single slot (any one index satisfies the slot), yeast and water are individual slots.

---

### Explosion Pipeline

**Files:** `Sandbox/` folder — `FoamChemistry`, `EmissionSystem`, `SPHSystem`, `GPUSPHSolver`, `ExplosionStore`, `ARCoordinator+Explosion.swift`

The explosion runs as a parallel ECS/TCA hybrid alongside the main store, driven by the same `SceneEvents.Update` subscription.

#### Chemistry Layer (`FoamChemistry.swift`)
Takes the `FoamModel` (amounts of H₂O₂, soap, yeast, water temperature, container geometry) and produces a `FoamChemistryResult`:
- **Reaction rate** — yeast Michaelis-Menten kinetics × Q10 temperature factor (peaks ~37 °C, denatures above ~47 °C)
- **Peak volume & height** — inflow/decay ODE model with soap-bubble half-life and momentum scaling for plume height
- **Total particles** — mapped from peak gas volume, capped at `maxParticles`
- **Stop time** — when foam height decays to a fraction of peak

#### Emission Layer (`EmissionSystem.swift`)
Progress-proportional spawning: `target = totalParticles × (elapsed / emissionDuration)`. New particles are spawned into `SPHSystem` at the volcano rim with upward launch velocity derived from foam peak height, and random radial spread.

#### SPH Layer (`SPHSystem.swift` + `GPUSPHSolver.swift`)
- Particles are maintained in Metal shared-memory buffers — no CPU↔GPU copy on Apple Silicon
- `GPUSPHSolver` runs two compute passes per frame: **density/pressure**, then **forces** (pressure gradient + viscosity + gravity + gas-lift during emission)
- After emission stops, viscosity and cohesion relax over `rheologyRelaxSpan` seconds so the foam settles naturally
- Every N frames, a Marching Cubes pass (`FoamSurfaceBuilder`) runs on a **background thread** and uploads the resulting `MeshResource` to a `ModelEntity` on the main thread. Stale meshes from interrupted passes are discarded via a generation counter.

#### Phase State Machine (`ExplosionReducer.swift`)

```
idle → settingUp → emitting → simulating → settled
```

#### Foam Color
Before `pipelineStarted`, `ARCoordinator+Explosion.swift` reads `store.state.experiment.foam.foodColorPours: [Int: Int]` (color index → pour count), sums R/G/B channels, normalizes by the max channel, and calls `sphSystem.setFoamColor(_:)`. This replaces the `PhysicallyBasedMaterial.baseColor` on the surface entity before any particles render.

---

### Audio Architecture

Two parallel systems handle all sound:

| System | Used for |
|---|---|
| `SoundClient` (AVFoundation) | BGM (loading, main page, experiment), button-press SFX |
| `AudioFileResource` (RealityKit) | Spatial ingredient SFX anchored to 3D entities (`.wav` files) |
| `AVPlayer` fallback | `.mov` video-container files + explosion/placement sounds |

**Why the fallback?** `AudioFileResource` applies HRTF spatial processing. For explosion sounds (`VolcanoReact.mp3`, `VolcanoDUARRRRR.mov`, `VolcanoPlacementNew.mov`) this produces a distorted "telephone/toilet flush" effect because the sounds are meant to fill the whole scene, not appear to come from a specific point. These are listed in `nonSpatialEffects` and are routed to `AVPlayer` (flat 2D mixing) regardless of file type.

**Why `.mov` files?** Several SFX were exported as QuickTime video containers (`.mov`) — RealityKit's `AudioFileResource` calls these "VideoFile" and crashes. All `.mov` files go to `AVPlayer` automatically.

**Preloading:** All SFX are preloaded in `preloadSFX()` (async, parallel) before the first entity spawns. At playback, `playSFX(_:on:)` checks `preloadedSFX` first (spatial, anchored to an entity), then falls back to `sfxAVPlayers` with a seek-to-zero before play.

---

## Key Technical Decisions

### sGeometryModifier Wrapper — keep authored scale immutable
Runtime scaling of an entity whose material uses a `sGeometryModifier` (vertex-stage shader) breaks visual output because object-space vertex positions seen by the shader change. The wrapper entity pattern (inner entity scaled once at load, outer wrapper scaled at runtime) keeps the modifier's input invariant. See [Asset Loading](#asset-loading--the-sgeometrymodifier-bug-bypass) for the full explanation.

### ARKit Session — Never Pause
Calling `session.pause()` + `session.run()` forces ARKit re-localization, causing world-anchor drift and a multi-second restart delay. `pauseARSession()` only stops `MotionClient` monitoring and removes the `SceneEvents.Update` subscription — ARKit tracking runs continuously. `resumeARSession()` simply restarts those two listeners.

### Placeback Animation — Task Lerp, not `entity.move()`
`entity.move(to:relativeTo:duration:)` can read the pre-reparent transform as the animation start when called immediately after `setParent`, producing a visual jump. A manual `Task { @MainActor }` with 15 steps × 26.7 ms (≈ 0.4 s) and cubic ease-out is reliable and easy to cancel.

### Food Coloring Gate — Three-File Consistency
"Any one food coloring pour satisfies the group" must be identical in:
- `ARCoordinator.allIngredientsPoured(side:)` — tilt-to-pour gate
- `ARExperimentView.mixableBeakerSide` — shake lock-in gate
- `InstructionDerivation` Slot system — instruction step advancement

### Explosion Color — Additive RGB Normalization
`foodColorPours: [colorIndex: pourCount]` is summed per R/G/B channel and normalized by the max channel. This keeps colors vivid at any combination (1 red + 1 green = pure yellow at 100% brightness) rather than averaging down to gray.

---

## Requirements

- **Xcode 16+**
- **iOS 18+ / iPadOS 18+**
- Physical device with LiDAR or standard TrueDepth camera (ARKit horizontal plane detection)
- Package dependency: `ShaderDev` (local Swift package — RealityKit shader graph + USDC assets)

---

## GitHub Collaboration Rules

### Branch Protection — `main`

- **Never push directly to `main`** — all changes go through a Pull Request
- **Require at least 1 approval** before merging
- **Dismiss stale reviews** — new commits invalidate previous approvals
- **Branch must be up to date** with `main` before merging
- Only leads / admins can force-merge in an emergency

### Branch Naming

```
feature/<what-youre-building>      feature/experiment-ar-placement
fix/<what-youre-fixing>            fix/tilt-detection-threshold
chore/<maintenance-task>           chore/update-readme
refactor/<what-youre-changing>     refactor/tca-experiment-feature
```

### Commit Message Convention

```
feat: add yeast shake gesture
fix: tilt fires immediately on pickup
refactor: split coordinator into separate file
chore: update gitignore
style: clean up comments and headers
```

### Pull Request Rules

- PR title must follow the commit convention above
- Reference the related issue: `Closes #12`
- Keep PRs small and focused — one feature or fix per PR
- No self-merging — you cannot approve your own PR
- Must build without errors before requesting review

### Issues & Tasks

- Create a GitHub Issue before starting any work
- Assign every issue to a specific person — no orphan work
- Use labels: `feature` `bug` `chore` `refactor` `discussion`

### What NOT to Do

- Never commit directly to `main`
- Never commit API keys, secrets, or `.env` files
- Never commit `DerivedData/`, `.DS_Store`, or `xcuserdata/`
- Never merge your own PR without a review

### Recommended `.gitignore`

```
DerivedData/
*.xcuserstate
xcuserdata/
.DS_Store
*.moved-aside
```
