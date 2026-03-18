# Draft: Gameplay Systems Roadmap

## Requirements (confirmed)
- task output location: `C:\Users\user\Documents\GitHub\project-0312\vault\current\task.md`
- dynamic furniture placement: user wants an in-game system for dynamically placing tables and chairs
- placement extensibility: the placement system must preserve future extensibility for decorative objects
- placement boundary: placeable area is currently the floor range
- next day flow: the game must be able to advance to the next day
- save support: the game must be able to save progress
- daily customer planning: customer counts should be planned/generated automatically each day and stored as data
- scope baseline: current planning scope is these four major points
- interview preference: user prefers broader questioning to ensure the architecture direction is correct

## Technical Decisions
- planning mode only: produce a single execution plan, not implementation
- draft slug: `gameplay-systems-roadmap`
- architecture baseline: existing project already has `DayManager`, `EconomyManager`, signal bus, resource-driven table/chair data, and debug-only customer spawn tooling
- verification baseline: current repo has no automated tests; practical verification currently depends on playable scene + debug HUD/tools + Godot MCP/editor diagnostics
- placement v1 scope: include place, move, and delete flows
- placement rule: grid-snapped placement with rotation support
- extensibility strategy: design v1 around a generic `Placeable` architecture now, with table/chair as the first adopters
- furniture ownership model: tables and chairs are independently placed objects
- save v1 scope: persist day count, money, placed objects, and daily customer data
- save mode: single save slot with manual save plus automatic save at day-end
- customer-data strategy: generate on day start and persist the generated data
- customer data granularity: persist per-customer records for each day rather than only totals or waves
- customer data minimum fields: arrival timing/wave, order or order-pool data, status markers, and patience or customer-attribute parameters
- next-day strategy: manual advance from end-of-day flow
- day-boundary strategy: finish current day and settlement first, then generate the next day's customer data
- verification strategy: stay with debug/manual verification rather than adding automated test infra in this plan
- artifact strategy: save formal plan under `.sisyphus/plans/` and also write a task-friendly version to `vault/current/task.md`
- placement validation baseline: must reject outside-floor placements and overlapping placeables
- plan depth target: medium detail, but still architecture-safe

## Research Findings
- `project.godot` autoloads `SignalManager`, `ItemDatabase`, `EconomyManager`, and `DayManager`
- `game/playground/test.tscn` is the effective gameplay scene and currently contains static floor, static table/chair instances, player, customers, and debug tooling
- furniture config is already resource-driven through `game/scripts/resources/table_data.gd`, `game/scripts/resources/chair_data.gd`, and `game/scripts/resources/seat_slot_data.gd`
- table/chair behavior already exists in `game/scripts/actors/table.gd` and `game/scripts/actors/chair.gd`, with runtime chair-to-table seat registration
- day flow already exists in `game/scripts/systems/day_manager.gd`, `game/scripts/systems/end_of_day_panel.gd`, and `game/scripts/systems/ui_manager.gd`
- save/load persistence for gameplay state is currently missing in `game/`
- production customer generation/storage is currently missing; only debug spawn exists in `game/scripts/debug/world_de_bug.gd`
- automated test framework/CI is absent; existing verification relies on `game/playground/de_bug_tools.tscn`, `game/scripts/debug/message_hud.gd`, and MCP diagnostics

## Open Questions
- whether placement validation must also enforce navigation/path-access checks in v1, or can defer that to a later iteration
- whether save/load should support resuming mid-day, or only restore the latest committed world state plus day data
- whether deleting/moving furniture while customers are active is allowed, blocked, or restricted to edit mode outside active service
- whether there should be a dedicated build/edit mode UI, or if placement actions should piggyback on existing interaction/debug controls initially

## Scope Boundaries
- INCLUDE: planning for the four requested systems and their integration points
- EXCLUDE: implementation work during this session
