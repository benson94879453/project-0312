# Gameplay Systems Roadmap - Learnings

## 2026-03-18 Task 1: Define Placeable and Snapshot Contracts

### Files Created
1. `game/scripts/data/placeable_data.gd` - Generic placeable data contract for runtime placement candidates
2. `game/scripts/data/placeable_record.gd` - Serialized placeable record for save/load
3. `game/scripts/data/customer_day_plan.gd` - Per-customer day plan record
4. `game/scripts/data/day_snapshot.gd` - Save snapshot schema for single-slot save system
5. `game/scripts/data/save_constants.gd` - Save system constants and versioning

### Key Design Decisions

#### Stable IDs Architecture
- All placeables use `placeable_id: String` as stable identifiers
- Chair-table relationships use `linked_placeable_id` instead of NodePaths
- This allows proper save/load without scene path dependencies

#### Pre-Open Boundary Semantics
- Save snapshot represents state AFTER day completion/generation
- NOT mid-day runtime state
- Load target: `DayManager.is_day_active = false` (pre-open state)
- Placeables rebuilt from records, not deserialized live instances
- Customer plans exist as data but NO live customer nodes spawned yet

#### Resource-Based Classes
- All data contracts extend `Resource` for Godot serialization
- Only `SaveConstants` extends `RefCounted` (no serialization needed)
- All fields use `@export` for proper serialization support

#### Type Safety
- `type_key` field distinguishes placeable types ("table", "chair", "decor")
- Constants defined in `SaveConstants` for type keys and statuses
- Rotation steps: 0-3 representing 0°, 90°, 180°, 270°

### Integration Points
- `PlaceableRecord.resource_id` references `TableData.table_id` or `ChairData.chair_id`
- `DaySnapshot` includes arrays of `PlaceableRecord` and `CustomerDayPlan`
- Save version field allows future migration

### Pattern Consistency
Following existing codebase patterns from:
- `TableData`, `ChairData`, `SeatSlotData` - @export resource pattern
- `DayManager`, `EconomyManager` - autoload singleton pattern
