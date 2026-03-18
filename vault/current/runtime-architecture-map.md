# Runtime Architecture Map

## 快速地圖

這份文件提供目前 repo 的快速導航圖與資料/控制流摘要，方便在讀碼前先知道「哪個系統管哪件事」。

---

## 1. 入口地圖

```text
project.godot
  -> game/playground/main.tscn
      -> SubViewportContainer
          -> SubViewport
              -> game/playground/test.tscn
```

```text
main.tscn
  -> SubViewportContainer (shader output shell)
      -> SubViewport (640x360, handle_input_locally=false)
          -> TestScene
```

---

## 2. TestScene 結構圖

```text
TestScene
  -> Camera2D
      -> subpixel_camera.gd

  -> NavigationRegion2D
      -> Floor (TileMapLayer, 48x48, position=(2,43))
      -> Wall  (TileMapLayer, position=(2,43))
      -> Object
          -> Table / Chair runtime instances

  -> Player
  -> LeavePosition

  -> PlaceableRuntimeRegistry
  -> EditModeController
  -> CustomerSpawnExecutor

  -> DeBugTools
      -> WorldDeBug
      -> MessageHUD

  -> UIManager
      -> HUD_Layer
      -> Menu_Layer
          -> EndOfDayPanel
          -> EditModeUI
```

---

## 3. 系統分層圖

```text
[Presentation Layer]
  - SubViewportContainer + shader
  - UIManager / HUD / EditModeUI / EndOfDayPanel
  - DeBugTools / MessageHUD

[Scene Runtime Layer]
  - TestScene
  - Camera2D
  - NavigationRegion2D / Floor / Wall / Object
  - Player / Table / Chair / Customer

[Scene Logic Layer]
  - EditModeController
  - PlaceableRuntimeRegistry
  - CustomerSpawnExecutor
  - CustomerPlanGenerator

[Global Service Layer]
  - SignalManager
  - ItemDatabase
  - EconomyManager
  - DayManager
  - SaveManager
```

---

## 4. 家具系統關係圖

```text
TableData / ChairData
  -> Table / Chair scenes
      -> PlaceableRuntimeRegistry rebuilds IDs + occupied cells
      -> Chair binds to nearest Table
      -> SaveManager serializes as PlaceableRecord

EditModeUI
  -> UIManager
      -> EditModeController
          -> PlacementPreview
          -> PlaceableRuntimeRegistry.validate_placeable_candidate()
          -> PlaceableRuntimeRegistry.commit_placeable_state()
```

### 家具資料欄位目前已進 runtime 的部分

```text
TableData
  - texture
  - sprite_offset
  - hitbox_size
  - hitbox_offset
  - interactbox_size
  - slot_positions
  - footprint_cells

ChairData
  - texture
  - sprite_offset
  - hitbox_size
  - seats
  - footprint_cells
```

---

## 5. Edit Mode 流程圖

### 5.1 現況權責

```text
EditModeUI
  -> emits button intent only

UIManager
  -> forwards intent to EditModeController

EditModeController
  -> owns authoritative snapped target
  -> owns current mode / selection / preview lifecycle

PlacementPreview
  -> visual ghost only

PlaceableRuntimeRegistry
  -> validates and commits by target_position
```

### 5.2 目前 target pipeline

```text
floor_layer.get_global_mouse_position()
  -> floor.to_local(pointer_world)
  -> floor.local_to_map(...)
  -> target_cell
  -> floor.map_to_local(target_cell)
  -> floor.to_global(...)
  -> target_world_position

target_world_position
  -> preview position
  -> validation target
  -> confirm commit target

target_cell
  -> selection matching against footprint cells
```

### 5.3 目前 edit mode 不變條件

```text
preview is not the authority
confirm does not infer from preview transform
selection/delete enablement depends on selected_placeable
placement/save-load all remain cell-based
```

---

## 6. Save / Load 流程圖

```text
SaveManager.save_current_boundary()
  -> find registry
  -> build DaySnapshot
      -> money
      -> day_index
      -> placeable_records[]
      -> customer_day_plans[]
  -> JSON write to user://save_slot_1.json
```

```text
SaveManager.load_latest_snapshot()
  -> parse DaySnapshot
  -> clear runtime customers
  -> clear registered placeables
  -> instantiate placeables from PlaceableRecord
  -> registry.restore_placeable_state(...)
  -> registry.rebuild_registry()
  -> explicit chair-table relink by linked_placeable_id
  -> restore day / money / plans
```

### Save 契約資料

```text
DaySnapshot
  - day_index
  - money
  - placeable_records[]
  - customer_day_plans[]

PlaceableRecord
  - placeable_id
  - type_key
  - resource_id
  - grid_x / grid_y
  - rotation_step
  - linked_placeable_id
```

---

## 7. 顧客生成流程圖

```text
SignalManager.day_started(day_index)
  -> CustomerSpawnExecutor.start_day_execution(day_index)
      -> CustomerPlanGenerator.generate_day_plans(day_index, registry)
      -> _day_plans[]
      -> _process(delta)
          -> day_time_accumulator
          -> spawn pending plan when arrival time reached
              -> instantiate customer.tscn
              -> configure target table + leave target + patience
              -> customer.start_lifecycle(table)
```

```text
Customer lifecycle result
  -> CustomerStateMachine emits payment / loss consequences
  -> EconomyManager updates stats
  -> CustomerSpawnExecutor marks plan completed/lost
  -> SaveManager stores current day plans
```

---

## 8. UI / Debug 關係圖

```text
SignalManager.day_started/day_ended
  -> UIManager
      -> show/hide HUD
      -> show EndOfDayPanel

EditModeController signals
  -> EditModeUI
      -> status text
      -> confirm/delete/move button state
```

```text
MessageHUD buttons
  -> de_bug_tools.gd
      -> UIManager.enter_edit_mode()
      -> SaveManager.save_current_boundary()
      -> SaveManager.load_latest_snapshot()
      -> DayManager.start_day()
      -> WorldDeBug helper actions
```

### Debug overlay input 規則

```text
DeBugPanel background / layout / labels
  -> mouse_filter = 2 (pass-through)

Buttons / OptionButton
  -> remain interactive

Result
  -> panel controls are clickable
  -> empty translucent panel area does not block edit-mode selection
```

---

## 9. 檔案導航表

| 主題 | 主要檔案 |
|---|---|
| 入口與呈現 | `game/playground/main.tscn`, `game/scripts/systems/sub_viewport_container.gd`, `game/scripts/systems/subpixel_camera.gd`, `game/shader/subpixel.gdshader` |
| 世界組裝 | `game/playground/test.tscn` |
| 玩家 | `game/scripts/actors/player.gd`, `game/scripts/components/player_*` |
| 顧客/桌椅 | `game/scripts/actors/customer.gd`, `game/scripts/components/customer_*`, `game/scripts/actors/table.gd`, `game/scripts/actors/chair.gd` |
| 家具資料 | `game/scripts/resources/table_data.gd`, `game/scripts/resources/chair_data.gd`, `game/scripts/resources/seat_slot_data.gd` |
| placement/edit mode | `game/scripts/systems/edit_mode_controller.gd`, `game/scripts/systems/placeable_runtime_registry.gd`, `game/scripts/systems/placement_preview.gd`, `game/scripts/ui/edit_mode_ui.gd` |
| save/load | `game/scripts/systems/save_manager.gd`, `game/scripts/data/*.gd` |
| customer plan | `game/scripts/systems/customer_plan_generator.gd`, `game/scripts/systems/customer_spawn_executor.gd` |
| UI | `game/scripts/systems/ui_manager.gd`, `game/scripts/systems/hud_layer.gd`, `game/scripts/systems/end_of_day_panel.gd`, `game/playground/ui/*.tscn` |
| debug | `game/playground/de_bug_tools.tscn`, `game/scripts/debug/de_bug_tools.gd`, `game/scripts/debug/message_hud.gd`, `game/scripts/debug/world_de_bug.gd` |

---

## 10. 當前應記住的架構結論

```text
Main view is a SubViewport presentation shell.
TestScene is the actual gameplay composition root.
Floor TileMap is the single grid authority.
Registry is the single placement validation authority.
EditModeController is the single edit target authority.
Preview is visual only.
Save/load is a pre-open boundary snapshot, not whole-scene serialization.
Customer plans are the production spawn source.
```

---

## 更新記錄

| 日期 | 版本 | 說明 |
|---|---|---|
| 2026-03-18 | v1.0 | 建立 runtime architecture map，補上 scene graph、資料流、edit mode、save/load、debug overlay 快速地圖 |
