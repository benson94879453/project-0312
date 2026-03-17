# game 系統與玩法架構說明

> 參見：[game-diagrams.md.md](./game-diagrams.md.md) 查看所有 Mermaid 圖表

## 1. 專案定位
- 引擎：Godot 4.6
- 主場景：`game/playground/main.tscn`
- 核心方向：2D 俯視角餐廳原型，包含玩家移動、桌椅座位系統、顧客生命周期、點餐送餐流程、Subpixel 渲染。

## 2. 系統架構

### 2.1 分層結構

| 層級 | 內容 |
|------|------|
| 場景層 | main.tscn, test.tscn, player.tscn, table.tscn, chair.tscn, customer.tscn |
| 邏輯層-Actors | player.gd, table.gd, chair.gd, customer.gd |
| 邏輯層-Components | Player: movement, state_machine, visual, interact, held_item<br>Customer: state_machine, movement, visual |
| 邏輯層-Systems | signal_manager, item_database, subpixel_camera, sub_viewport_container, service_debug_hud |
| 邏輯層-Resources | food_data, table_data, chair_data, seat_slot_data, order_data |
| 資料層 | game/data/foods/*.tres, tables/*.tres, chairs/*.tres |
| 全域層 | SignalManager (Autoload), ItemDatabase (Autoload) |

### 2.2 通訊方式
- 場景內依賴：NodePath / onready / @export 注入
- 跨系統通訊：SignalManager 訊號、Node 信號
- 內容資料：Resource 驅動（`*.tres`）

## 3. 核心玩法循環

### 3.1 玩家循環
1. `MovementComponent` 讀取輸入與跑步鍵
2. 回傳 velocity 給 `Player`
3. `Player` 在 `_physics_process` 內 `move_and_slide()`
4. `PlayerStateMachine` 更新 `IDLE/WALK/RUN`
5. `VisualComponent` 做浮動與左右翻面

### 3.2 互動循環（送餐）
1. `InteractionComponent` 監聽 `interact` action（E）
2. 呼叫 `request_interaction(interactor)`
3. 掃描重疊 bodies/areas
4. 若目標有 `interact(actor)` 方法，直接呼叫
5. `Table` 檢查 `get_held_food()` 並驗證訂單匹配
6. 放置食物後發射 `order_served` 信號
7. `Customer` 接收食物並進入 `EATING` 狀態

### 3.3 顧客生命周期循環
1. **IDLE** -> **SEEKING_SEAT**: `start_lifecycle()` 被呼叫
2. **SEEKING_SEAT** -> **MOVING_TO_SEAT**: 設定座位目標
3. **MOVING_TO_SEAT** -> **ORDERING**: 到達座位
4. **ORDERING** -> **WAITING_FOOD**: 創建並提交訂單
5. **WAITING_FOOD** -> **EATING**: 收到送達的食物
6. **EATING** -> **LEAVING**: 用餐計時結束
7. **LEAVING** -> 結束: 離開並釋放座位

### 3.4 桌椅座位系統
1. `Chair` 在 `_ready` 後等待 physics frame
2. 用 `TableDetector` 找重疊 `Table`
3. 將 `SeatSlotData` 轉換為世界座標
4. 註冊到 `Table.available_seats`
5. `Customer` 透過 `Table.reserve_seat()` 預約
6. `Chair` 標記 `occupied_by` 與 `seat_state`
7. 離開時呼叫 `Table.release_seat()` 釋放

### 3.5 Subpixel 視覺流程
1. `subpixel_camera.gd` 以 `target_path` 跟隨目標
2. 計算 subpixel offset
3. `SignalManager` 發送 offset
4. `sub_viewport_container.gd` 寫入 shader 參數 `cam_offset`

## 4. 腳本職責明細

### actors/player.gd
- 角色物理移動控制中心
- 套用 MovementComponent 輸出
- 更新朝向與狀態機
- 手持食物管理 (get_held_food, try_consume_held_food, set_held_food)

### actors/table.gd
- 讀取 `TableData` 初始化碰撞/互動範圍/食物槽
- 管理 `available_seats`、`connected_chairs`、`current_customers`
- 管理 `expected_orders`、`foods_on_table`
- 實作 `interact(actor)` 處理送餐與座位預約
- 信號：order_registered, food_received, order_served, interaction_processed

### actors/chair.gd
- 讀取 `ChairData` 初始化
- 偵測鄰近 Table 並註冊座位資訊
- 管理座位狀態：available / occupied / occupied_by
- 提供 reserve(actor) / release(actor) API

### actors/customer.gd
- 顧客生命周期管理（尋座→入座→點餐→等待→用餐→離開）
- 協調 CustomerStateMachine、CustomerMovementComponent、CustomerVisualComponent
- 訂單創建與提交
- 自動開始重試機制（因 Chair 註冊有延遲）

### components/player_movement_component.gd
- 輸入 -> 速度模型（加速/摩擦/跑步）

### components/player_state_machine.gd
- 輸入狀態 -> MoveState (IDLE/WALK/RUN)

### components/player_interact.gd
- 統一互動入口
- 發送 `interaction_requested`
- 呼叫目標 `interact(actor)`

### components/player_visual_component.gd
- 視覺浮動與朝向翻面

### components/player_held_item.gd
- 顯示玩家手持物品
- 根據面向更新位置與翻轉

### components/customer_state_machine.gd
- 顧客狀態管理（IDLE/SEEKING_SEAT/MOVING_TO_SEAT/ORDERING/WAITING_FOOD/EATING/LEAVING）
- 用餐計時 (eating_duration_sec)
- 信號：state_changed, leaving_started

### components/customer_movement_component.gd
- 顧客導航移動
- 支援 NavigationAgent2D
- 到達目標偵測

### components/customer_visual_component.gd
- 顧客漂浮動畫
- 根據移動方向翻轉

### systems/item_database.gd
- 掃描 `game/data/foods` 的 `.tres`
- 防呆：無效資源、空 id、重複 id、查無 id

### systems/subpixel_camera.gd
- 相機平滑與 offset 計算
- target_path 注入

### systems/sub_viewport_container.gd
- 監聽 offset 訊號並更新材質

### systems/service_debug_hud.gd
- 調試 UI 顯示玩家、顧客、桌子狀態
- 顯示待處理訂單與桌上食物
- 事件日誌記錄

### resources/food_data.gd
- 食物定義：id, food_name, texture, price

### resources/table_data.gd
- 桌子定義：table_id, texture, hitbox, interactbox, slot_positions

### resources/chair_data.gd
- 椅子定義：chair_id, texture, hitbox, seats (Array[SeatSlotData])

### resources/seat_slot_data.gd
- 座位槽位：seat_slot_position, seat_slot_direction

### resources/order_data.gd
- 訂單資料：customer, food
- matches_food(food_item) 比對方法

## 5. 已完成的風險處理
- `chair.gd` 從 assets 移到 scripts/actors
- `scripts` 目錄完成分層（actors/components/systems/resources）
- 清除 `main.tscn*.tmp` 並加上 `.gitignore` 規則
- `InteractionComponent` 已有可用契約與基本邏輯
- `ItemDatabase` 已補防呆
- `project.godot` 已加入 `interact` action
- 關鍵腳本已改為明確型別（避免 Variant 推導）
- Customer 系統完整實作（狀態機、移動、視覺）
- Table-Chair-Customer 交互閉環完成
- Order/Food 送餐流程完成
- ServiceDebugHud 調試系統

## 6. 目前剩餘技術債
- `subpixel_camera.gd` 仍保留 fallback 目標查找（可後續移除）
- 互動介面尚未正式抽象為 `IInteractable` 規格（目前用 has_method("interact")）
- 缺少最小自動化或 smoke test 清單
- Customer 與 Player 的視覺組件可進一步統一抽象

## 7. 建議下一步
1. 經濟系統
   - 實作 FoodData.price 結算
   - 收入統計與日結算
2. 更多顧客類型
   - 不同 patience 值
   - 多食物偏好順序
3. 存檔系統
   - 每日營業資料儲存
