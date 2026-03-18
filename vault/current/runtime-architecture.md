# Runtime Architecture (Current State)

## 概述

這份文件描述目前 `project-0312` 的實際執行中架構，重點放在正在使用的場景入口、全域服務、餐廳運營循環、家具格線/編輯模式、存讀檔邊界，以及 debug / UI 疊層之間的責任分工。

此文件是 `vault/current` 版本的「現況快照」。
它補齊 repo root `ARCHITECTURE.md` 的總覽，並把最近已經收斂到程式碼中的 edit mode / placement / save-load / debug overlay 行為一併寫清楚。

---

## 1. 執行入口與畫面呈現

### 1.1 入口鏈路

實際入口是 `game/playground/main.tscn`，其場景鏈路為：

```text
project.godot
  -> game/playground/main.tscn
      -> SubViewportContainer
          -> SubViewport
              -> game/playground/test.tscn
```

### 1.2 Main 的責任

`game/playground/main.tscn`

- 提供 `SubViewportContainer` 外殼，而不是直接把世界場景掛在 root window。
- `SubViewportContainer` 套用 `subpixel.gdshader`，負責最終畫面輸出偏移。
- `SubViewport` 尺寸目前是 `640x360`。
- `SubViewportContainer.scale = Vector2(3, 3)`，也就是實際顯示被放大三倍。
- `SubViewport.handle_input_locally = false`，代表輸入不是留在 SubViewport 內自行消化，而會沿既有輸入路徑往下傳。

### 1.3 TestScene 的責任

`game/playground/test.tscn`

- 是目前真正的 gameplay composition root。
- 內含：相機、導航/格線、玩家、桌椅物件容器、離場錨點、放置 registry、edit mode controller、customer executor、debug tools、UIManager。
- `NavigationRegion2D/Floor` 和 `NavigationRegion2D/Wall` 共同定義世界可走區與牆體阻擋。
- `Floor` 與 `Wall` 都有 `position = Vector2(2, 43)`，這是所有世界座標 <-> 格座標轉換必須經過的局部偏移。

---

## 2. 全域服務層 (Autoload)

目前可視為全域服務的核心如下：

| 服務 | 檔案 | 角色 |
|---|---|---|
| `SignalManager` | `game/scripts/systems/signal_manager.gd` | 全域事件匯流排 |
| `ItemDatabase` | `game/scripts/systems/item_database.gd` | 食物/物品資料查詢 |
| `EconomyManager` | `game/scripts/systems/economy_manager.gd` | 金錢與每日統計 SSOT |
| `DayManager` | `game/scripts/systems/day_manager.gd` | 營業日循環與時間推進 |
| `SaveManager` | `game/scripts/systems/save_manager.gd` | pre-open 快照 bootstrap / save / load |

### 2.1 SignalManager

`SignalManager` 不直接做遊戲協調，只定義跨系統事件，例如：

- `sub_pixel_offset_updated(offset)`
- `customer_paid(base_amount, tips)`
- `customer_lost()`
- `money_updated(current_money, daily_earnings)`
- `time_ticked(formatted_time)`
- `day_started(day_count)`
- `day_ended()`

### 2.2 EconomyManager

`EconomyManager` 是金錢與當日統計唯一真值來源，管理：

- `current_money`
- `total_earnings_today`
- `customers_served_today`
- `customers_lost_today`

它透過 `SignalManager.customer_paid` 與 `SignalManager.customer_lost` 更新統計，再透過 `money_updated` 回推 HUD。

### 2.3 DayManager

`DayManager` 管理營業天數、營業時長、時間格式化與 day start/day end 邊界。

- day 開始時會重置每日統計。
- day 結束時發 `day_ended()`。
- 目前仍支援 debug day speed multiplier，被 `CustomerSpawnExecutor` 取用來同步顧客生成時間。

### 2.4 SaveManager

`SaveManager` 是目前「pre-open 邊界」的唯一快照入口。

- `_ready()` 會 deferred bootstrap from disk。
- 若有快照，會還原家具、天數、金錢、當日顧客計畫。
- 若沒有快照，會準備 default pre-open state。
- `save_current_boundary()` / `load_latest_snapshot()` 操作的是 `DaySnapshot` JSON 邊界，而不是隨時保存整棵 scene tree。

---

## 3. 世界層與互動層

### 3.1 世界結構

`game/playground/test.tscn` 目前主要節點如下：

```text
TestScene
  -> Camera2D
  -> NavigationRegion2D
      -> Floor
      -> Wall
      -> Object
  -> Player
  -> LeavePosition
  -> PlaceableRuntimeRegistry
  -> DeBugTools
  -> UIManager
  -> EditModeController
  -> CustomerSpawnExecutor
```

### 3.2 Object 容器

`NavigationRegion2D/Object` 是所有桌椅 runtime placeables 的掛載點。

這件事很重要，因為：

- `PlaceableRuntimeRegistry` 只掃這個容器重建 registry。
- `SaveManager` 還原家具時，也是把桌椅掛回這個容器。
- edit mode placement / move / delete 的真正世界操作對象，也都以這個容器為邊界。

### 3.3 Camera / Subpixel 呈現

目前呈現鏈路是：

```text
Player movement
  -> subpixel_camera.gd 更新 actual_cam_pos
  -> emit SignalManager.sub_pixel_offset_updated(cam_subpixel_offset)
  -> sub_viewport_container.gd 寫入 shader parameter cam_offset
  -> SubViewportContainer material 偏移畫面輸出
```

這個 render offset 是畫面層效果，不應成為 edit mode business logic 的真值來源。

---

## 4. Actor Domains

### 4.1 Player Domain

主要檔案：

- `game/scripts/actors/player.gd`
- `game/scripts/components/player_movement_component.gd`
- `game/scripts/components/player_state_machine.gd`
- `game/scripts/components/player_interact.gd`
- `game/scripts/components/player_held_item.gd`
- `game/scripts/components/player_visual_component.gd`

責任切分：

- `Player`：擁有 actor-level runtime state
- `MovementComponent`：讀輸入、計算速度
- `PlayerStateMachine`：移動狀態分類
- `InteractionComponent`：互動掃描與路由
- `PlayerHeldItem`：手持食物視覺
- `VisualComponent`：浮動/視覺偏移

### 4.2 Customer / Table / Chair Domain

主要檔案：

- `game/scripts/actors/customer.gd`
- `game/scripts/components/customer_state_machine.gd`
- `game/scripts/components/customer_movement_component.gd`
- `game/scripts/components/customer_visual_component.gd`
- `game/scripts/actors/table.gd`
- `game/scripts/actors/chair.gd`

責任切分：

- `Chair`
  - 定義 seat slots
  - 管理 seat occupancy
  - 負責 bind / unbind nearby table
- `Table`
  - 收集 chairs 提供的 seats
  - 管理 expected orders / foods_on_table
  - 作為本地 seating / order / serve hub
- `Customer`
  - 擁有 actor runtime context
  - 呼叫 state machine、movement、visual component
- `CustomerStateMachine`
  - 管理 seating -> waiting -> eating -> leaving lifecycle
  - 在等待超時與付款時透過 `SignalManager` 回報經濟事件

### 4.3 Data Resources

目前與家具/餐廳運作相關的 resource data 主要在：

- `game/scripts/resources/table_data.gd`
- `game/scripts/resources/chair_data.gd`
- `game/scripts/resources/seat_slot_data.gd`
- `game/scripts/resources/order_data.gd`
- `game/scripts/resources/food_data.gd`

目前已明確存在、且已接入 runtime 的家具資料欄位包含：

- `sprite_offset`
- `hitbox_size`
- `hitbox_offset` (table)
- `interactbox_size` (table)
- `footprint_cells`
- `seats` / `slot_positions`

---

## 5. Furniture Placement / Edit Mode Architecture

這一塊是目前 repo 最值得特別寫清楚的部分，因為它同時牽涉場景、SubViewport、格座標、preview、UI、save/load。

### 5.1 核心元件

| 元件 | 檔案 | 責任 |
|---|---|---|
| `PlaceableRuntimeRegistry` | `game/scripts/systems/placeable_runtime_registry.gd` | 家具 registry、佔格、floor/wall/route 驗證、chair-table 重綁 |
| `EditModeController` | `game/scripts/systems/edit_mode_controller.gd` | edit mode state machine、target pipeline、selection/confirm/delete/move |
| `PlacementPreview` | `game/scripts/systems/placement_preview.gd` | ghost sprite + footprint indicator 視覺 |
| `UIManager` | `game/scripts/systems/ui_manager.gd` | 將 edit UI 訊號轉成 controller 動作 |
| `EditModeUI` | `game/scripts/ui/edit_mode_ui.gd` | edit mode toolbar 顯示與按鈕狀態 |

### 5.2 格線與 world/cell 轉換

目前系統共識：

- 基礎格線是 `48x48`
- `Floor` TileMapLayer 是唯一格線來源
- world -> cell：`Floor.local_to_map(Floor.to_local(world_position))`
- cell -> world：`Floor.to_global(Floor.map_to_local(cell))`

`PlaceableRuntimeRegistry` 已提供：

- `world_to_map(world_position)`
- `map_to_world(cell)`

### 5.3 Registry 的角色

`PlaceableRuntimeRegistry` 負責：

- 掃描 `Object` 容器中的 table / chair
- 確保每個家具有 stable `placeable_id`
- 依 `footprint_cells` 建立 `_occupied_cells`
- 驗證候選家具是否 out-of-floor / hit wall / occupied / block route
- registry rebuild 後重綁 chair -> table

其設計重點是：

- **cell-based 為主**
- **preview / placement / save-load 共用同一份 footprint 語意**
- **BFS route validation 是弱保底，不是完整 runtime 保證**

### 5.4 EditModeController 的目前真值設計

最近已收斂成單一 authoritative target pipeline，存在 `EditModeController` 內：

- `_target_cell`
- `_target_world_position`
- `_has_target`

其核心原則是：

- preview 不再是 placement 邏輯真值
- confirm 不再直接信任 `_current_preview.global_position`
- selection / preview / validation / confirm 共用同一份 snapped target state
- pointer 來源統一從 `_floor_layer.get_global_mouse_position()` 取值，再做 floor snapping

### 5.5 Preview 的角色

`PlacementPreview` 是被動視覺層。

它目前負責：

- 顯示 ghost sprite
- 顯示 footprint diamond indicator
- 顯示 validity 顏色
- 從 source placeable 對應 data 裡讀 `sprite_offset`

它目前不負責：

- floor 驗證
- commit target authority
- save/load 決策

### 5.6 Selection / Delete / UI enablement

流程目前是：

```text
EditModeUI button state
  <- EditModeController selected state / mode
  <- UIManager 只做轉發
```

也就是說：

- `Delete` 能不能點，本質取決於 selection 是否成功
- `Move` 能不能點，也取決於 selection 是否成功
- 這些 UI enablement 不應自行推導世界座標，只依 controller 狀態刷新

### 5.7 Debug overlay 與 edit mode 點擊

`game/playground/de_bug_tools.tscn` 的半透明背景目前已調整成 pass-through：

- `DeBugPanel`
- `Margin`
- `Content`
- `ControlsRow`
- 純顯示 `Label` / `RichTextLabel`

都設為 `mouse_filter = 2`，因此：

- debug 按鈕仍可操作
- panel 空白區與文字區不再攔截 edit-mode selection 點擊

---

## 6. Save / Load Boundary

### 6.1 Save 單位

目前快照格式是：

- `DaySnapshot`
- `PlaceableRecord`
- `CustomerDayPlan`

其資料結構檔案位於：

- `game/scripts/data/day_snapshot.gd`
- `game/scripts/data/placeable_record.gd`
- `game/scripts/data/customer_day_plan.gd`
- `game/scripts/data/save_constants.gd`

### 6.2 Save 策略

不是直接存 world 浮點，而是存：

- `grid_x`
- `grid_y`
- `rotation_step`
- `resource_id`
- `linked_placeable_id`

這保證：

- save/load 與 placement 共用同一格線契約
- 減少浮點誤差
- 桌椅 chair-table 綁定可以靠 stable IDs 重建

### 6.3 Load 策略

`SaveManager._apply_snapshot()` 流程：

1. 清理 runtime customers
2. 清空已註冊家具
3. 依 `PlaceableRecord` instantiate table/chair scene
4. 用 `registry.restore_placeable_state()` 掛回 world
5. `registry.rebuild_registry()`
6. 依 `linked_placeable_id` 顯式重綁 chair -> table
7. 還原 `DayManager`、`EconomyManager`、`_current_day_plans`

重要語意：

- `commit_placeable_state()` 是 edit-time 提交入口，會跑完整驗證
- `restore_placeable_state()` 是 save-load 重建入口，不跑同樣的 edit-time 阻擋流程

---

## 7. Customer Plan / Spawn Architecture

### 7.1 Generator

`game/scripts/systems/customer_plan_generator.gd`

責任：

- 依 day index 建 deterministic plan seed
- 依 seating capacity 推估目標 customer 數量
- 產生 `CustomerDayPlan[]`
- 若 `SaveManager` 已有當日對應計畫，則直接重用

### 7.2 Executor

`game/scripts/systems/customer_spawn_executor.gd`

責任：

- 監聽 `SignalManager.day_started` / `day_ended`
- 於 day start 時生成或載入 plans
- 依 `arrival_time_seconds` 在 runtime 生成 customers
- 指定 table、leave target、patience
- 追蹤 plan 狀態 `pending/active/completed/lost`
- 將 plan 狀態回寫到 `SaveManager`

### 7.3 目前生成邊界

當前 production 路徑已收斂成：

```text
Day started
  -> CustomerSpawnExecutor.start_day_execution(day_index)
      -> CustomerPlanGenerator.generate_day_plans(...)
      -> runtime spawn by arrival time
```

這表示顧客生成不再依賴場景內預先擺好的 `Customer` 節點。

---

## 8. UI / Debug Architecture

### 8.1 UIManager

`UIManager` 是目前 UI root coordinator。

它目前同時管理：

- `HUD_Layer`
- `Menu_Layer/EndOfDayPanel`
- `Menu_Layer/EditModeUI`

並且：

- 監聽 `day_started` / `day_ended`
- deferred 連接 `EditModeController`
- 轉發 edit mode toolbar action 到 controller

### 8.2 EditModeUI

`EditModeUI` 是 control-only toolbar，不做 placement business logic。

它透過 controller signals 更新：

- 是否顯示
- 是否有 selection
- 目前 validity 顏色 / 文案
- 按鈕 enable/disable 狀態

### 8.3 Debug Tools

debug tooling 目前分成：

- `game/scripts/debug/de_bug_tools.gd`
- `game/scripts/debug/world_de_bug.gd`
- `game/scripts/debug/message_hud.gd`

定位是：

- debug panel 發出操作意圖
- world debug / UIManager / SaveManager / DayManager 接手真正執行
- debug tools 不直接成為 gameplay authority

---

## 9. 目前關鍵設計原則

以下原則是目前 repo 實作已經收斂出的事實，不是理想化規劃：

1. **Floor TileMap 是唯一格線真值來源**
2. **placement / preview / save-load 全部是 cell-based**
3. **家具 footprint 明確由 data 定義，不靠 hitbox 自動推導**
4. **registry 負責最小安全驗證與重綁，不負責 UI 或 preview 呈現**
5. **preview 是視覺層，不應再兼任 placement authority**
6. **save/load 以 pre-open boundary 為邊界，不是任意時點全狀態快照**
7. **顧客生成以 day plans 為唯一正式來源**

---

## 10. 已知且可接受的現況限制

以下是目前架構上已知、但仍屬可接受範圍的限制：

- 家具旋轉資產仍偏向單圖 + step 邏輯，未完整進入多方向貼圖資料格式
- `footprint_cells` 尚未由所有 `.tres` 資源完整覆寫
- BFS route validation 只保證弱保底，不保證最佳動線
- `vault/current` 既有文檔仍有部分任務式描述，這份文件作為 current-state runtime snapshot 補足總覽

---

## 11. 建議閱讀順序

如果要快速進入目前專案，建議順序如下：

1. `game/playground/main.tscn`
2. `game/playground/test.tscn`
3. `game/scripts/systems/placeable_runtime_registry.gd`
4. `game/scripts/systems/edit_mode_controller.gd`
5. `game/scripts/systems/save_manager.gd`
6. `game/scripts/systems/customer_spawn_executor.gd`
7. `game/scripts/actors/table.gd`
8. `game/scripts/actors/chair.gd`
9. `game/scripts/actors/customer.gd`
10. `game/scripts/systems/ui_manager.gd`

---

## 更新記錄

| 日期 | 版本 | 說明 |
|---|---|---|
| 2026-03-18 | v1.0 | 建立 `vault/current` 版 runtime architecture，補齊 current scene graph、edit mode、save/load、customer plan、debug overlay 現況 |
