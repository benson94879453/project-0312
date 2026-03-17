# Customer-Chair-Table 架構職責說明

## 概述

此系統實現顧客入座、點餐、用餐、離席的完整流程。三個主要腳本分工如下：

- **Chair** (椅子)：靜態場景物件，負責座位位置/方向定義與佔位管理
- **Table** (桌子)：管理座位註冊、訂單、上菜、顧客列表
- **Customer** (顧客)：狀態機驅動的角色，執行移動、點餐、用餐行為

---

## Chair (椅子)

**檔案**：`game/scripts/actors/chair.gd`

### 職責
1. 定義座位槽位位置與面向（相對於椅子的偏移量）
2. 偵測並綁定鄰近的 Table
3. 管理座位佔用狀態（available/occupied）
4. 提供座位預訂/釋放接口

### 關鍵屬性

| 屬性 | 型別 | 說明 |
|------|------|------|
| `data` | ChairData | 椅子資料資源（含 seats 陣列） |
| `facing_direction` | Vector2 | 椅子整體面向 |
| `registered_table` | Table | 綁定的桌子實體 |
| `seat_state` | StringName | 佔用狀態 (available/occupied) |
| `occupied_by` | Node | 當前佔用者（Customer） |

### 函數詳細說明

#### `_ready() -> void`
- 初始化：從 data 載入 sprite/hitbox
- 延遲綁定桌子（等待 2 個 physics frame 確保碰撞資料就緒）

#### `_attempt_register_to_table() -> void`
- 查詢 `TableDetector` Area2D 的重疊物體
- 找到第一個 Table 後呼叫 `_bind_to_table()`

#### `_bind_to_table(table: Table) -> void`
- 建立 `registered_table` 引用
- 遍歷 `data.seats` 建立座位資訊陣列
- 呼叫 `table.register_new_seats(self, seat_info_list)`

**座位資訊結構**：
```gdscript
{
    "chair": self,                              # Chair 實體引用
    "position": global_position + slot.seat_slot_position,  # 世界座標
    "direction": slot.seat_slot_direction       # 座位面向（朝桌子）
}
```

#### `is_available() -> bool`
- 回傳 `seat_state == STATE_AVAILABLE`

#### `is_occupied_by(actor: Node) -> bool`
- 檢查指定 actor 是否為當前佔用者

#### `reserve(actor: Node) -> bool`
- 預訂座位（佔用狀態管理）
- 若已被其他人佔用回傳 false
- 成功時設定 `seat_state = STATE_OCCUPIED`, `occupied_by = actor`

#### `release(actor: Node) -> bool`
- 釋放座位（僅限佔用者呼叫）
- 重設 `seat_state = STATE_AVAILABLE`, `occupied_by = null`

---

## Table (桌子)

**檔案**：`game/scripts/actors/table.gd`

### 職責
1. 從 Chair 收集並管理座位列表
2. 處理座位預訂請求
3. 管理訂單註冊與食物接收
4. 維護顧客列表與食物槽位

### 關鍵屬性

| 屬性 | 型別 | 說明 |
|------|------|------|
| `data` | TableData | 桌子資料資源 |
| `available_seats` | Array[Dictionary] | 所有座位資訊（從 Chairs 收集） |
| `connected_chairs` | Array[Chair] | 綁定的椅子實體列表 |
| `current_customers` | Array[Node] | 當前顧客列表 |
| `expected_orders` | Array[OrderData] | 待處理訂單 |
| `foods_on_table` | Array[FoodData] | 桌上的食物 |

### 函數詳細說明

#### `_ready() -> void`
- 初始化 sprite/hitbox/interactbox
- 初始化食物槽位 sprites

#### `register_new_seats(chair: Chair, seat_info_list: Array[Dictionary]) -> void`
- Chair 註冊時呼叫
- 將座位資訊加入 `available_seats`
- 記錄 chair 到 `connected_chairs`
- 呼叫 `queue_redraw()` 更新除錯繪製

#### `try_seat_customer(customer: Node) -> Dictionary`
- **顧客入座的主要入口**
- 嘗試預訂座位，回傳結果字典：
```gdscript
{
    "success": true/false,
    "reason": "ok"/"table_full",
    "chair": chair,
    "position": Vector2,      # 座位世界座標
    "direction": Vector2      # 座位面向
}
```

#### `reserve_seat_with_info(actor: Node) -> Dictionary`
- 內部實作：遍歷 `available_seats` 找可用 chair
- 呼叫 `chair.reserve(actor)` 嘗試預訂
- 回傳完整座位資訊（含 position/direction）

#### `get_reserved_seat_info(actor: Node) -> Dictionary`
- 查詢指定 actor 的預訂座位資訊
- 遍歷 chairs 找 `is_occupied_by(actor)`
- 用於 Customer 取得座位位置/方向進行對齊

#### `release_seat(actor: Node) -> bool`
- 遍歷 `connected_chairs` 呼叫 `chair.release(actor)`
- 顧客離席時清理座位佔用

#### `register_order(order: OrderData) -> bool`
- 註冊新訂單到 `expected_orders`
- 發射 `order_registered` 信號

#### `try_receive_food(food_item: FoodData) -> Dictionary`
- **上菜的主要接口**
- 檢查：食物非空、有匹配訂單、有空槽位
- 成功時：放置食物、移除訂單、發射 `order_served`
- 回傳結果字典：
```gdscript
{
    "ok": true/false,
    "reason": "served"/"no_matching_order"/"table_full",
    "customer": served_order.customer,
    "food_id": food_item.id
}
```

#### `interact(actor: Node) -> void`
- 玩家互動處理
- 若 actor 手持食物 → 嘗試上菜
- 否則 → 嘗試預訂/釋放座位

---

## Customer (顧客)

**檔案**：`game/scripts/actors/customer.gd`

### 職責
1. 執行狀態機驅動的生命週期
2. 移動到座位、點餐、等待、用餐、離席
3. 與 Table/Chair 協作完成座位對齊
4. 管理面向與視覺呈現

### 關鍵屬性

| 屬性 | 型別 | 說明 |
|------|------|------|
| `assigned_table` | Table | 指定的桌子 |
| `current_order` | OrderData | 當前訂單 |
| `facing_direction` | Vector2 | 當前面向 |
| `customer_state_machine` | CustomerStateMachine | 狀態機 |
| `customer_movement_component` | CustomerMovementComponent | 移動控制 |
| `customer_visual_component` | CustomerVisualComponent | 視覺擺動 |

### 函數詳細說明

#### `_ready() -> void`
- 解析/建立子元件引用
- 設定 movement_component 與 visual_component
- 設定 state_machine 的 owner

#### `_physics_process(delta: float) -> void`
- 每幀執行：
  1. `customer_state_machine.tick(delta)`
  2. 從 movement_component 取得 velocity
  3. 若移動中，更新 `facing_direction`
  4. `move_and_slide()`
  5. 若到達目標，通知 state_machine

#### `start_lifecycle(target_table: Table) -> bool`
- **生命週期啟動入口**
- 檢查 table 與 chairs 就緒
- 設定 `assigned_table` 並連接信號
- 呼叫 `state_machine.start_lifecycle()`

#### `enter_moving_to_seat(seat_info: Dictionary) -> void`
- **State: MOVING_TO_SEAT 的進入動作**
- 加入 table 的顧客列表
- 取得座位座標與面向
- 設定 movement_component 移動目標

#### `enter_waiting_food(seat_info: Dictionary) -> OrderData`
- **State: WAITING_FOOD 的進入動作**
- 會令z_index = 1,使其在椅子上層
- 停止移動（`stop_movement_immediately`）
- **關鍵：對齊座位**（`_snap_to_seat_slot`）
- 建立並提交訂單

#### `prepare_for_leaving() -> void`
- 清理 table 上的食物
- 釋放座位（`release_seat`）

#### `enter_leaving(reason: String) -> void`
- **State: LEAVING 的進入動作**
- 會令z_index = 0,重製圖層位置
- 設定移動目標到離場位置
- 原因可以包含耐心值歸零

#### `finish_lifecycle_and_despawn() -> void`
- 從 table 移除顧客
- 斷開信號連接
- `queue_free()` 刪除節點

#### `_create_and_submit_order() -> OrderData`
- 從 `preferred_food_ids` 選擇食物
- 建立 OrderData 實例
- 呼叫 `table.register_order()`

#### `_snap_to_seat_slot(seat_info: Dictionary) -> void`
- **座位對齊核心邏輯**
- `global_position = seat_info.position`（或從 table 查詢）
- `facing_direction = seat_info.direction`
- 停止移動

#### `_stop_movement_immediately() -> void`
- `velocity = Vector2.ZERO`
- 呼叫 `movement_component.stop_movement_immediately()`

---

## CustomerStateMachine (狀態機)

**檔案**：`game/scripts/components/customer_state_machine.gd`

### 職責
- 管理顧客生命週期的狀態轉換
- 處理狀態進入時的行為委派
- 提供統一的狀態查詢接口
- **Task 4 新增：管理顧客耐心值與小費計算**

### 狀態定義
```gdscript
enum CustomerState {
    IDLE,           # 閒置
    MOVING_TO_SEAT, # 移動到座位
    WAITING_FOOD,   # 等待上菜
    EATING,         # 用餐中
    LEAVING         # 離席中
}
```

### 關鍵屬性 (Task 4 新增)

| 屬性 | 型別 | 說明 |
|------|------|------|
| `max_patience_sec` | float | 最大耐心值（秒），預設 30.0 |
| `current_patience` | float | 當前耐心值，WAITING_FOOD 時衰減 |
| `_patience_depleted` | bool | 標記是否已因耐心歸零離開 |
| `_tips_multiplier` | float | 小費乘數（0.0 ~ 1.0），基於剩餘耐心比例 |

### 關鍵函數

#### `setup(owner_customer: Customer) -> void`
- 設置 `customer` 引用（Customer 實體）
- 確保 `_eating_timer` 已初始化

#### `start_lifecycle(target_table: Table) -> bool`
- 嘗試入座：`table.try_seat_customer()`
- 成功 → `MOVING_TO_SEAT`
- 失敗 → `LEAVING`

#### `tick(delta: float) -> void`
- **Task 4 新增：耐心衰減邏輯**
- 僅在 `WAITING_FOOD` 狀態時執行 `_update_patience(delta)`
- 若耐心歸零 → 發射 `customer_lost` → `begin_leaving("patience_depleted")`

#### `on_move_target_reached() -> void`
- MOVING_TO_SEAT → WAITING_FOOD
- LEAVING → `customer.finish_lifecycle_and_despawn()`

#### `try_accept_served_food(food: FoodData) -> bool`
- 僅在 WAITING_FOOD 狀態有效
- 驗證食物匹配 current_order
- 成功 → `EATING`，啟動計時器
- **Task 4：進入 EATING 時呼叫 `_freeze_patience_and_calc_tips()` 凍結耐心並計算小費乘數**

#### `_enter_state(next_state: int) -> void`
- 狀態進入時委派給 Customer 對應方法：
  - MOVING_TO_SEAT → `customer.enter_moving_to_seat()`
  - WAITING_FOOD → `_initialize_patience()` → `customer.enter_waiting_food()`
  - EATING → `_freeze_patience_and_calc_tips()` → 啟動 `_eating_timer`
  - LEAVING → `customer.prepare_for_leaving()` + `enter_leaving()`

#### `_update_patience(delta: float) -> void` (Task 4 新增)
- 每幀減少 `current_patience`
- 若 `current_patience <= 0`：
  - 標記 `_patience_depleted = true`
  - 發射 `SignalManager.customer_lost.emit()`
  - 呼叫 `begin_leaving("patience_depleted")`

#### `_initialize_patience() -> void` (Task 4 新增)
- 重置 `current_patience = max_patience_sec`
- 重置 `_patience_depleted = false`
- 預設 `_tips_multiplier = 1.0`

#### `_freeze_patience_and_calc_tips() -> void` (Task 4 新增)
- 計算小費乘數：`current_patience / max_patience_sec` (clamp 0.0~1.0)
- 收到餐點時凍結耐心，不再衰減

#### `_process_payment() -> void` (Task 4 新增)
- 用餐結束時呼叫（`_eating_timer.timeout`）
- 計算小費：`tips = base_price * _tips_multiplier * 0.2`（最高 20%）
- 發射 `SignalManager.customer_paid.emit(base_price, tips)`

---

### 其他函數

#### `begin_leaving(reason: String = "manual_leave") -> void`
- 外部呼叫以強制顧客離開
- 設定 `failure_reason` 並轉換到 `LEAVING` 狀態
- 用於耐心歸零或訂單失敗時

#### `reset_runtime() -> void`
- 重置所有運行時變數（assigned_table, current_order, seat_info, failure_reason）
- 重置耐心相關變數（Task 4）
- 停止 `_eating_timer`

#### `get_state_name() -> String`
- 回傳當前狀態的文字名稱（如 "WAITING_FOOD"）

#### `_ready() -> void`
- 初始化時呼叫 `_ensure_eating_timer()`

#### `_ensure_eating_timer() -> void`
- 建立並設定 `_eating_timer`（one-shot Timer）
- 連接 `timeout` 信號到 `_on_eating_timer_timeout()`

#### `_transition(next_state: int) -> void`
- 狀態轉換的核心邏輯
- 發射 `state_changed` 信號
- 呼叫 `_enter_state()` 執行進入動作

#### `_on_eating_timer_timeout() -> void`
- `_eating_timer` 時間到時呼叫
- **Task 4**：先呼叫 `_process_payment()` 處理付款
- 然後轉換到 `LEAVING` 狀態

#### `_state_to_text(value: int) -> String`
- 將狀態列舉值轉換為文字（IDLE, MOVING_TO_SEAT, ...）

---

## 協作流程圖

```
Chair._ready()
    └── _attempt_register_to_table()
            └── _bind_to_table(Table)
                    └── Table.register_new_seats(Chair, seat_info_list)
                            └── available_seats.append(seat_info)

Customer.start_lifecycle(Table)
    └── StateMachine.start_lifecycle()
            └── Table.try_seat_customer()
                    └── Chair.reserve(Customer)  ← 座位佔用
            └── State = MOVING_TO_SEAT
                    └── Customer.enter_moving_to_seat()
                            └── Movement.set_target(seat_position)

(移動到達後)
StateMachine.on_move_target_reached()
    └── State = WAITING_FOOD
            └── Customer.enter_waiting_food()
                    └── _snap_to_seat_slot()     ← 對齊座位+面向
                    └── _create_and_submit_order()
                            └── Table.register_order()

(上菜時)
Table.try_receive_food(Food)
    └── order_served.emit(Customer, Food)
            └── Customer._on_order_served()
                    └── StateMachine.try_accept_served_food()
                            └── State = EATING (啟動計時器)

(耐心衰減 - Task 4)
StateMachine.tick(delta) [WAITING_FOOD]
    └── _update_patience(delta)
            └── current_patience -= delta
                    └── current_patience <= 0
                            └── SignalManager.customer_lost.emit()
                            └── begin_leaving("patience_depleted")
                                    └── State = LEAVING

(用餐結束 - Task 4 更新)
_eating_timer.timeout
    └── _process_payment()
            ├── base_price = current_order.food.price
            ├── tips = base_price * _tips_multiplier * 0.2
            └── SignalManager.customer_paid.emit(base_price, tips)
                    └── EconomyManager._on_customer_paid()
                            └── current_money += base_price + tips
    └── State = LEAVING
            └── Customer.prepare_for_leaving()
                    └── Table.release_seat()     ← 釋放座位
            └── Customer.enter_leaving(failure_reason)
                    └── Movement.set_target(leave_position)

(離場到達)
StateMachine.on_move_target_reached()
    └── Customer.finish_lifecycle_and_despawn()
            └── Table.remove_customer()
            └── queue_free()
```

---

## 資料流向

| 資料 | 來源 | 流向 | 用途 |
|------|------|------|------|
| seat_position | Chair.global_position + SeatSlotData.seat_slot_position | Table → Customer | 顧客入座對齊目標 |
| seat_direction | SeatSlotData.seat_slot_direction | Table → Customer | 顧客入座後面向 |
| OrderData | Customer._create_and_submit_order() | Customer → Table | 註冊待處理訂單 |
| FoodData | 外部（玩家/系統） | → Table.try_receive_food() | 完成訂單，通知 Customer |
| `customer_paid` 信號 | CustomerStateMachine | → EconomyManager | 更新金錢與統計 |
| `customer_lost` 信號 | CustomerStateMachine | → EconomyManager | 增加流失計數 |

---

## 更新記錄

| 日期 | 版本 | 變更內容 |
|------|------|----------|
| 2026-03-17 | 初始 | 建立文件 |
| 2026-03-17 | v1.1 | **Task 4 更新**：新增耐心系統與小費機制 |
| 2026-03-18 | v1.2 | **文件修正**：補齊所有函數說明 (`setup`, `begin_leaving`, `reset_runtime`, `get_state_name`, `_ready`, `_ensure_eating_timer`, `_transition`, `_on_eating_timer_timeout`, `_state_to_text`) |

---

*文件建立時間：2026-03-17*
*對應程式碼版本：Git commit 2a7eac5 之後*
*最新更新：Task 4 實作完成*
