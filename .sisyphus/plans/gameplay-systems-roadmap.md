# Gameplay Systems Roadmap

## TL;DR
> **Summary**: Add a reusable placeable architecture for table/chair editing, persist committed world and day data in a single-slot save, and drive daily customer generation from saved per-customer plans through the existing day loop.
> **Deliverables**:
> - Generic placeable data/runtime/save contracts for table and chair
> - Dedicated build/edit mode with place, move, delete, rotation, and runtime validation
> - Single-slot save/load with manual save and end-of-day autosave
> - Day transition pipeline that settles, saves, advances, generates, and restores the next day state
> - Persisted daily customer-plan generation and production spawning flow
> **Effort**: Large
> **Parallel**: YES - 3 waves
> **Critical Path**: 1 -> 2 -> 4 -> 6 -> 7

## Context
### Original Request
Plan four integrated gameplay systems for `C:/Users/user/Documents/GitHub/project-0312`: dynamic placement of tables/chairs with future decor extensibility inside the floor area, next-day progression, save support, and automatic daily customer generation stored as data.

### Interview Summary
- Placement v1 must support place, move, delete, grid snapping, and rotation.
- Architecture must introduce a generic `Placeable` foundation now; decor support is architectural, not a shipped decor feature.
- Tables and chairs remain independently placed objects.
- Placement is only allowed in a dedicated build/edit mode and only while business is not active.
- Placement validation must reject out-of-floor, overlapping, and blocked-navigation layouts.
- Save v1 is single-slot, supports manual save plus end-of-day autosave, and persists day count, money, placeables, and daily customer records.
- Load v1 restores the latest completed/generated day boundary, not mid-day runtime state.
- Daily customer data is generated at day start, stored per customer, and includes arrival timing, order or order-pool data, status markers, and patience/attribute parameters.
- End-of-day remains manual from the settlement panel; transition order is settle current day first, then generate the next day's customer data.
- Verification stays on debug/manual runtime scenarios rather than adding automated test infrastructure.

### Metis Review (gaps addressed)
- Added a hard requirement for stable IDs and explicit chair-table rebind logic so runtime move/delete cannot depend on `_ready()` overlap registration.
- Constrained save/load to durable domain data only; runtime nodes must be rebuilt from serialized records.
- Fixed the day-boundary contract to one ordered pipeline instead of scattered calls.
- Added edge-case coverage for blocked routes, deleted bindings, rotated footprints, corrupted saves, and invalid resource references.
- Kept decor extensibility architectural only to prevent v1 scope creep.

## Work Objectives
### Core Objective
Produce an execution-ready architecture that lets the game edit furniture layouts safely, carry those layouts across days and saves, and use the resulting world state to generate and run each day's customer plan.

### Deliverables
- Generic placeable contracts and registries for table/chair runtime instances and serialized records.
- Build/edit mode flow for place, move, rotate, delete, confirm, and cancel.
- Placement validation against floor bounds, occupied cells, and required navigation routes.
- Save snapshot schema, single-slot repository, manual save trigger, and end-of-day autosave trigger.
- Day-transition orchestrator layered on top of `DayManager` and `EndOfDayPanel`.
- Daily customer-plan generator, persisted customer-plan storage, and runtime spawn executor.
- Debug verification procedures and evidence outputs for every task.

### Definition of Done (verifiable conditions with commands)
- Running the project scene shows a dedicated edit mode where a table and chair can be placed, moved, rotated, and deleted, with invalid placements rejected.
- After manual save and reload, money, current day boundary, placed furniture, and generated day-plan data match the saved snapshot.
- After ending a day from the settlement panel, the game autosaves, advances state, generates the next day plan once, and loads that next day boundary without duplicated customers.
- Runtime customer spawning during a day consumes the persisted day plan rather than debug-only ad hoc spawning.
- Corrupt or missing save data fails gracefully and falls back to a safe default boot path.

### Must Have
- Preserve `project.godot` autoload architecture and existing signal-driven day/economy flow.
- Preserve resource-driven furniture config via `TableData` and `ChairData`.
- Use stable persisted IDs for placeables and any saved table/chair references.
- Keep editing outside active business hours only.
- Rebuild runtime nodes from save records instead of serializing live scene instances.

### Must NOT Have (guardrails, AI slop patterns, scope boundaries)
- No decor behavior implementation beyond the shared placeable architecture.
- No multi-slot save UX.
- No mid-day resume system.
- No editing while customers are actively being served.
- No reliance on `NodePath` persistence, editor-only assumptions, or manual designer policing for placement validity.

## Verification Strategy
> ZERO HUMAN INTERVENTION - all verification is agent-executed.
- Test decision: `none` for automated framework; use runtime debug/manual verification through `game/playground/test.tscn`, debug HUD/tools, and Godot diagnostics.
- QA policy: Every task includes happy-path and failure-path scenarios with exact state checks.
- Evidence: `.sisyphus/evidence/task-{N}-{slug}.{ext}`

## Execution Strategy
### Parallel Execution Waves
> Target: 5-8 tasks per wave. Shared contracts land first, then dependent systems.

Wave 1: data contracts, placeable runtime backbone, day-transition contract
Wave 2: edit-mode UX, save repository, customer-plan generation
Wave 3: full integration, load/bootstrap, hardening

### Dependency Matrix (full, all tasks)
- 1 blocks 2, 3, 4, 5
- 2 blocks 3, 4, 7
- 3 blocks 7
- 4 blocks 6, 7
- 5 blocks 6, 7
- 6 blocks 7
- 7 blocks final verification

### Agent Dispatch Summary (wave -> task count -> categories)
- Wave 1 -> 3 tasks -> `deep`, `unspecified-high`
- Wave 2 -> 3 tasks -> `visual-engineering`, `deep`, `unspecified-high`
- Wave 3 -> 1 task -> `deep`

## TODOs
> Implementation + Test = ONE task. Never separate.
> EVERY task MUST have: Agent Profile + Parallelization + QA Scenarios.

- [x] 1. Define shared placeable and snapshot contracts

  **What to do**: Add the core data contracts for v1 architecture before any behavior work. Define a generic placeable data contract for runtime placement candidates and a serialized placeable record contract that stores at minimum: stable `placeable_id`, type key, source resource ID/path, grid coordinate, rotation step, and any type-specific metadata needed to recreate table/chair instances. Define save snapshot and customer-day-plan record schemas, include save versioning constants, and define the exact load target as "latest completed/generated day boundary in pre-open state". Explicitly require chair/table references inside saved day data to use stable IDs, never scene paths.
  **Must NOT do**: Do not add decor behaviors, multi-slot support, or mid-day resume fields. Do not serialize live nodes, `NodePath`s, or editor-only resource handles.

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: contract design affects every downstream system.
  - Skills: `[]` - no extra skill required.
  - Omitted: `[]` - no omission needed.

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 2, 3, 4, 5 | Blocked By: none

  **References**:
  - Pattern: `project.godot:18` - existing autoload architecture to preserve.
  - Pattern: `game/scripts/resources/table_data.gd:1` - resource-driven table configuration pattern.
  - Pattern: `game/scripts/resources/chair_data.gd:1` - resource-driven chair configuration pattern.
  - Pattern: `game/scripts/resources/seat_slot_data.gd:1` - subresource pattern for nested seat data.
  - API/Type: `game/scripts/systems/day_manager.gd:29` - current day fields and lifecycle baseline.
  - API/Type: `game/scripts/systems/economy_manager.gd:14` - persisted money/stat fields baseline.

  **Acceptance Criteria**:
  - [ ] Placeable, day snapshot, and customer-day-plan schemas exist with version field and stable-ID support.
  - [ ] The schema explicitly models pre-open load state and excludes mid-day runtime restoration.
  - [ ] Chair/table relationships in saved records are represented by stable IDs, not scene-relative paths.

  **QA Scenarios**:
  ```text
  Scenario: Schema supports committed day-boundary save state
    Tool: Read
    Steps: Inspect the new data-contract files and confirm they include fields for day index, money, placeable records, and per-customer day-plan records with stable IDs.
    Expected: All required fields are present and comments/contracts describe pre-open boundary restore semantics.
    Evidence: .sisyphus/evidence/task-1-placeable-contracts.txt

  Scenario: Schema does not overreach into mid-day resume
    Tool: Read
    Steps: Inspect the same contracts for forbidden live-runtime fields such as NodePath persistence, active NavigationAgent state, or in-progress seated customer runtime refs.
    Expected: Forbidden runtime-only fields are absent.
    Evidence: .sisyphus/evidence/task-1-placeable-contracts-error.txt
  ```

  **Commit**: YES | Message: `feat(core): define placeable and day snapshot contracts` | Files: `game/scripts/**`, `game/data/**`

- [ ] 2. Build placeable runtime registry and validation backbone

  **What to do**: Introduce the non-UI runtime services that own placeable registration, stable-ID lookup, occupancy tracking, floor-bound checks, rotation footprint checks, required-route validation, and explicit chair-table rebind hooks after place/move/delete. The registry must rebuild table-chair relationships after any committed edit instead of relying on `Chair._ready()` overlap registration alone. Define one required-route policy for v1: placement is valid only if entrance -> at least one free seat area -> leave target remains connected after commit.
  **Must NOT do**: Do not add player-facing edit controls yet. Do not fall back to physics-overlap-only registration after an edit commit.

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: runtime identity, collision, and navigation rules are the architectural backbone.
  - Skills: `[]` - no extra skill required.
  - Omitted: `[]` - no omission needed.

  **Parallelization**: Can Parallel: NO | Wave 1 | Blocks: 3, 4, 7 | Blocked By: 1

  **References**:
  - Pattern: `game/playground/test.tscn:179` - current navigation region and floor ownership.
  - Pattern: `game/playground/test.tscn:183` - current floor tile layer used as placement boundary source.
  - Pattern: `game/playground/test.tscn:194` - current object container for furniture instances.
  - API/Type: `game/scripts/actors/chair.gd:31` - current startup-only registration path that must be replaced/supplemented after runtime edits.
  - API/Type: `game/scripts/actors/table.gd:61` - explicit seat registration contract to keep using.
  - API/Type: `game/scripts/actors/table.gd:131` - free-seat count API needed for route/availability checks.

  **Acceptance Criteria**:
  - [ ] Runtime placeables register with stable IDs and can be looked up after reload or edit commit.
  - [ ] A placement candidate is rejected when outside floor bounds, overlapping committed placeables, or disconnecting the required route policy.
  - [ ] Committed move/delete operations trigger chair-table rebinding and leave no orphaned seat registrations.

  **QA Scenarios**:
  ```text
  Scenario: Valid commit rebuilds placeable bindings
    Tool: interactive_bash
    Steps: Run the game scene, invoke debug/build hooks to commit a table and a chair on valid grid cells, then inspect runtime logs and scene tree state.
    Expected: New placeables receive stable IDs, chair binds to a nearby table through the registry/rebind path, and free-seat count increases.
    Evidence: .sisyphus/evidence/task-2-placeable-runtime.txt

  Scenario: Invalid placement is rejected before commit
    Tool: interactive_bash
    Steps: Attempt to commit one placeable partially outside the floor and one that blocks the required route.
    Expected: Both commits fail with explicit rejection reasons and do not mutate the committed registry state.
    Evidence: .sisyphus/evidence/task-2-placeable-runtime-error.txt
  ```

  **Commit**: YES | Message: `feat(world): add placeable registry and validation backbone` | Files: `game/scripts/**`, `game/playground/**`

- [ ] 3. Add dedicated build/edit mode with place, move, rotate, delete

  **What to do**: Add a dedicated build/edit mode that is only enterable while `DayManager.is_day_active` is false. Provide a minimal but explicit UX for selecting table or chair placement, previewing the ghost on the snapped grid, rotating in fixed increments, confirming/canceling, selecting an existing committed placeable, moving it, and deleting it. All actions must route through the placeable runtime services from Task 2. Keep the scene boot path clear: pre-open state may enter edit mode, active day may not.
  **Must NOT do**: Do not piggyback core editing onto the existing generic interaction key only. Do not allow edits while customers are active or while the day is running.

  **Recommended Agent Profile**:
  - Category: `visual-engineering` - Reason: dedicated gameplay UX and stateful preview interactions.
  - Skills: `[]` - no extra skill required.
  - Omitted: `[]` - no omission needed.

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 7 | Blocked By: 1, 2

  **References**:
  - Pattern: `game/scripts/systems/day_manager.gd:35` - business-active flag gating edit availability.
  - Pattern: `game/scripts/systems/end_of_day_panel.gd:46` - existing next-day button flow that should return to gameplay outside edit mode.
  - Pattern: `game/scripts/actors/table.gd:214` - current actor interaction shape and existing interaction channel.
  - Test: `game/playground/test.tscn:222` - debug-tool scene already present for runtime verification.

  **Acceptance Criteria**:
  - [ ] Edit mode can place, move, rotate, cancel, and delete table/chair instances on snapped grid positions.
  - [ ] Entering edit mode is blocked while business is active.
  - [ ] UI feedback exposes why a candidate placement is invalid before commit.

  **QA Scenarios**:
  ```text
  Scenario: Edit mode supports full furniture lifecycle
    Tool: interactive_bash
    Steps: Launch the playable scene in pre-open state, enter build/edit mode, place a table, rotate it once, place a chair, move the chair to another valid cell, then delete the chair.
    Expected: Visual preview snaps to grid, each commit updates world state exactly once, and the deleted chair is removed from registry and scene tree.
    Evidence: .sisyphus/evidence/task-3-edit-mode.txt

  Scenario: Edit mode is blocked during business hours
    Tool: interactive_bash
    Steps: Start the day, attempt to enter build/edit mode from the same UI controls.
    Expected: Edit mode does not open and the user receives a clear blocked-state message.
    Evidence: .sisyphus/evidence/task-3-edit-mode-error.txt
  ```

  **Commit**: YES | Message: `feat(ui): add dedicated build edit mode for furniture` | Files: `game/playground/**`, `game/scripts/**`

- [ ] 4. Implement single-slot save repository and bootstrap load path

  **What to do**: Implement the single-slot save/load path using a durable repository under `user://` with explicit versioning, corruption handling, and a clean bootstrap sequence. Manual save must write the latest committed pre-open world state and generated customer-day-plan data. Load must restore to the latest completed/generated day boundary: rebuild placeables from records, restore day number and money totals, restore persisted day-plan data, and keep runtime customer instances absent until the day actually starts.
  **Must NOT do**: Do not attempt mid-day state restoration. Do not silently ignore version/corruption failures; surface safe fallback behavior.

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: persistence and bootstrap sequencing need careful state ownership.
  - Skills: `[]` - no extra skill required.
  - Omitted: `[]` - no omission needed.

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 6, 7 | Blocked By: 1, 2

  **References**:
  - Pattern: `game/scripts/systems/day_manager.gd:71` - start-day contract that load bootstrap must not accidentally trigger too early.
  - Pattern: `game/scripts/systems/economy_manager.gd:69` - daily stats reset behavior that load/bootstrap must respect.
  - Pattern: `project.godot:18` - autoload ownership and likely save-manager registration location.
  - Test: `game/scripts/debug/world_de_bug.gd:50` - current runtime spawn path shows why load must avoid creating customer nodes until production flow is ready.

  **Acceptance Criteria**:
  - [ ] Manual save writes a single-slot snapshot with version, day boundary state, money, placeables, and per-customer day-plan records.
  - [ ] Loading a valid snapshot restores world layout and save data without spawning live customers automatically.
  - [ ] Missing, corrupt, or incompatible save data falls back to a safe boot path with an explicit error message.

  **QA Scenarios**:
  ```text
  Scenario: Manual save and load restore committed world state
    Tool: interactive_bash
    Steps: In pre-open state place a table and chair, set a known money amount, trigger manual save, restart/load, and inspect restored scene/data state.
    Expected: Current day boundary, money total, placeable positions/rotations, and customer day-plan record count match the save snapshot exactly.
    Evidence: .sisyphus/evidence/task-4-save-load.txt

  Scenario: Corrupt save is handled safely
    Tool: interactive_bash
    Steps: Replace the single-slot save file with malformed or version-mismatched content, then boot/load.
    Expected: The game logs a clear load failure, ignores the invalid save, and falls back to a safe default state without crashing.
    Evidence: .sisyphus/evidence/task-4-save-load-error.txt
  ```

  **Commit**: YES | Message: `feat(save): add single slot snapshot repository` | Files: `game/scripts/**`, `project.godot`

- [ ] 5. Add daily customer-plan generation and runtime spawn executor

  **What to do**: Create a production customer-plan generator that runs once at day start using the current day index and current committed layout. It must persist a per-customer record list for that day with arrival timing/wave, order or order-pool data, status markers, patience/attribute parameters, and stable references only where safe. Add a runtime executor/spawner that consumes those saved records during the active day and instantiates customers through a production system rather than `world_de_bug.gd`. If seating capacity is insufficient for the requested plan, clamp or regenerate the day plan according to a documented fallback rule before the day starts.
  **Must NOT do**: Do not keep pre-authored customer scene instances as the production source of truth. Do not generate extra ad hoc customers after day start outside the saved plan.

  **Recommended Agent Profile**:
  - Category: `unspecified-high` - Reason: this is mostly orchestration and gameplay data flow across several systems.
  - Skills: `[]` - no extra skill required.
  - Omitted: `[]` - no omission needed.

  **Parallelization**: Can Parallel: YES | Wave 2 | Blocks: 6, 7 | Blocked By: 1

  **References**:
  - Pattern: `game/scripts/debug/world_de_bug.gd:50` - existing instantiation path to promote into a production-owned spawner.
  - Pattern: `game/scripts/actors/table.gd:73` - seat reservation output contract used by customer seating flow.
  - Pattern: `game/scripts/systems/day_manager.gd:88` - `day_started` signal as generation/execution trigger.
  - API/Type: `game/scripts/systems/signal_manager.gd:35` - centralized day signals to extend if more events are needed.
  - Test: `game/playground/test.tscn:209` - current scene-authored customers that should stop being the source of truth.

  **Acceptance Criteria**:
  - [ ] Starting a day creates or loads exactly one persisted customer-plan dataset for that day.
  - [ ] Runtime customer spawning is driven by that dataset and updates each customer record status as progression occurs.
  - [ ] The plan generator handles insufficient seating through a deterministic fallback and never schedules impossible customer counts silently.

  **QA Scenarios**:
  ```text
  Scenario: Day plan drives runtime customer arrivals
    Tool: interactive_bash
    Steps: Start a day with a known layout and seed inputs, inspect generated day-plan records, wait through at least one arrival window, and verify spawned customers map back to those records.
    Expected: Customer nodes appear only when scheduled, each spawned customer matches one persisted record, and status markers advance from pending to active/completed or lost.
    Evidence: .sisyphus/evidence/task-5-customer-plan.txt

  Scenario: Impossible plan is corrected before service starts
    Tool: interactive_bash
    Steps: Configure a layout with too few seats for the requested daily volume, then start the day.
    Expected: The generator clamps/regenerates according to the documented fallback, logs the adjustment, and persists only feasible records.
    Evidence: .sisyphus/evidence/task-5-customer-plan-error.txt
  ```

  **Commit**: YES | Message: `feat(customers): add persisted day plan generation and spawning` | Files: `game/scripts/**`, `game/playground/**`

- [ ] 6. Refactor day transition into a single deterministic orchestration pipeline

  **What to do**: Replace the current loose end-of-day handoff with one orchestrated transition pipeline that runs in this exact order: close service, settle any outstanding end-of-day bookkeeping according to explicit rules, autosave final current-day results, increment to the next day boundary, generate the next day's persisted customer plan, restore the game into pre-open state for that next day, and wait for the manual next-day/start-day path. Keep `DayManager` as the authoritative day owner, but move coordination into a dedicated system or helper with explicit signal ordering.
  **Must NOT do**: Do not leave generation split between `EndOfDayPanel` button logic and unrelated systems. Do not start the next day twice.

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: this is the most failure-prone integration point.
  - Skills: `[]` - no extra skill required.
  - Omitted: `[]` - no omission needed.

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: 7 | Blocked By: 4, 5

  **References**:
  - Pattern: `game/scripts/systems/day_manager.gd:95` - current day-end emission point.
  - Pattern: `game/scripts/systems/day_manager.gd:106` - current next-day increment function.
  - Pattern: `game/scripts/systems/end_of_day_panel.gd:46` - current button flow that must become orchestration-aware.
  - API/Type: `game/scripts/systems/signal_manager.gd:38` - day lifecycle signal declarations.
  - API/Type: `game/scripts/systems/economy_manager.gd:79` - current settlement stats provider for day-close snapshotting.

  **Acceptance Criteria**:
  - [ ] End-of-day transition follows one documented order and cannot double-generate or double-save the next day.
  - [ ] Autosave occurs at the end-of-day boundary before the next day's pre-open state is exposed.
  - [ ] After transition, the next day is loaded with its plan persisted and no active customer nodes yet.

  **QA Scenarios**:
  ```text
  Scenario: End-of-day creates exactly one next-day boundary
    Tool: interactive_bash
    Steps: Run a day to completion, trigger the settlement panel next-day action, and inspect logs/save data before and after the transition.
    Expected: Autosave happens once, current day increments once, one next-day plan is generated, and the scene returns to pre-open state for the new day.
    Evidence: .sisyphus/evidence/task-6-day-transition.txt

  Scenario: Repeated next-day input cannot duplicate progression
    Tool: interactive_bash
    Steps: Spam the next-day action during the transition window.
    Expected: Guard logic prevents duplicate day increments, duplicate saves, and duplicate customer-plan generation.
    Evidence: .sisyphus/evidence/task-6-day-transition-error.txt
  ```

  **Commit**: YES | Message: `feat(day): orchestrate deterministic day transition pipeline` | Files: `game/scripts/**`, `game/playground/**`

- [ ] 7. Integrate load/bootstrap cleanup and edge-case hardening

  **What to do**: Remove scene-authored production dependencies that conflict with the new architecture, especially static customer-source assumptions in the playable scene. Ensure bootstrap logic can create a safe default world when no save exists, restore saved layouts cleanly, and reconcile layout-driven constraints before each day starts. Harden deletion/move edge cases, stale resource IDs, impossible saved bindings, and validation messaging. Update debug verification helpers only as needed to inspect the new systems.
  **Must NOT do**: Do not keep static scene customers as a hidden fallback source of gameplay truth. Do not leave stale stable-ID references unresolved after load.

  **Recommended Agent Profile**:
  - Category: `deep` - Reason: final integration spans scene composition, persistence, placement, and day logic.
  - Skills: `[]` - no extra skill required.
  - Omitted: `[]` - no omission needed.

  **Parallelization**: Can Parallel: NO | Wave 3 | Blocks: Final Verification | Blocked By: 2, 3, 4, 5, 6

  **References**:
  - Pattern: `game/playground/test.tscn:197` - current static table/chair instances that may become bootstrap defaults instead of authored truth.
  - Pattern: `game/playground/test.tscn:209` - current static customer instances to remove from production flow.
  - Pattern: `game/scripts/debug/message_hud.gd` - existing observability surface to extend rather than replace.
  - Pattern: `addons/godot_mcp/tools/project_tools.gd` - available diagnostics for scene/log inspection during hardening.

  **Acceptance Criteria**:
  - [ ] The playable scene no longer depends on scene-authored production customers for normal gameplay.
  - [ ] Missing save, invalid resource IDs, and stale bindings all degrade safely to a recoverable state.
  - [ ] Debug observability is sufficient to inspect placeable registry, current save boundary, and customer-plan counts during runtime verification.

  **QA Scenarios**:
  ```text
  Scenario: Fresh boot and saved boot both enter valid pre-open state
    Tool: interactive_bash
    Steps: Boot once with no save present and once with a valid save present, then inspect scene tree, placeable registry, and customer-plan summary output.
    Expected: Both paths produce a stable pre-open state with no duplicate production customers and with correct layout/day data.
    Evidence: .sisyphus/evidence/task-7-hardening.txt

  Scenario: Stale references are repaired or rejected safely
    Tool: interactive_bash
    Steps: Load a save that references a removed furniture resource ID or a non-existent linked placeable ID.
    Expected: The game logs the inconsistency, skips or repairs the invalid record according to policy, and remains playable.
    Evidence: .sisyphus/evidence/task-7-hardening-error.txt
  ```

  **Commit**: YES | Message: `fix(integration): harden bootstrap and saved world edge cases` | Files: `game/playground/**`, `game/scripts/**`

## Final Verification Wave (MANDATORY - after ALL implementation tasks)
> 4 review agents run in PARALLEL. ALL must APPROVE. Present consolidated results to user and get explicit "okay" before completing.
> **Do NOT auto-proceed after verification. Wait for user's explicit approval before marking work complete.**
> **Never mark F1-F4 as checked before getting user's okay.** Rejection or user feedback -> fix -> re-run -> present again -> wait for okay.
- [ ] F1. Plan Compliance Audit - oracle
- [ ] F2. Code Quality Review - unspecified-high
- [ ] F3. Real Manual QA - unspecified-high (+ playwright if UI)
- [ ] F4. Scope Fidelity Check - deep

## Commit Strategy
- Commit 1: data contracts and stable-ID plumbing only
- Commit 2: placeable runtime/validation backbone
- Commit 3: build-edit mode interactions and UX
- Commit 4: save/load repository and bootstrap
- Commit 5: day transition orchestration and autosave
- Commit 6: customer-plan generation and runtime spawning
- Commit 7: integration hardening and edge-case fixes

## Success Criteria
- The codebase can add future decor types by implementing the shared placeable contract instead of rewriting placement/save systems.
- Furniture layout changes survive save/load and day transitions without broken chair-table bindings.
- Day advancement is single-path, deterministic, and free of duplicate generation.
- Customer traffic for a day is driven by persisted plan data rather than scene-authored customer nodes.
