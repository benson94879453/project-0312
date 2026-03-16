# game 系統與玩法架構說明

## 1. 專案定位
- 引擎：Godot 4.6
- 主場景：`game/playground/main.tscn`
- 核心方向：2D 俯視角餐廳原型，包含移動、桌椅座位註冊、互動、Subpixel 渲染。

## 2. 系統架構

### 2.1 分層
- 場景層
  - `main.tscn`：SubViewport 與 Shader 組裝
  - `test.tscn`：測試地圖與玩家/桌椅實例
  - `player.tscn`、`table.tscn`、`chair.tscn`：單體場景
- 邏輯層
  - `actors`：實體行為（Player/Table/Chair）
  - `components`：可重用元件（Movement/StateMachine/Interact/Visual）
  - `systems`：跨場景系統（SignalManager/ItemDatabase/Camera/Viewport）
  - `resources`：資料結構腳本（FoodData/TableData/ChairData/SeatSlotData）
- 資料層
  - `game/data/*/*.tres` 作為內容配置
- 全域層（Autoload）
  - `SignalManager`
  - `ItemDatabase`

### 2.2 通訊方式
- 場景內依賴：NodePath / onready 注入
- 跨系統通訊：SignalManager 訊號
- 內容資料：Resource 驅動（`*.tres`）

## 3. 玩法架構

### 3.1 玩家循環
1. `MovementComponent` 讀取輸入與跑步鍵
2. 回傳 velocity 給 `Player`
3. `Player` 在 `_physics_process` 內 `move_and_slide()`
4. `PlayerStateMachine` 更新 `IDLE/WALK/RUN`
5. `VisualComponent` 做浮動與左右翻面

### 3.2 互動循環
1. `InteractionComponent` 監聽 `interact` action（目前為 E）
2. 呼叫 `request_interaction(interactor)`
3. 掃描重疊 bodies/areas
4. 若目標有 `interact(actor)` 方法，直接呼叫
5. 目前 `Table` 已有最小 `interact(actor)` 行為（輸出座位與空槽資訊）

### 3.3 桌椅座位循環
1. `Chair` 在 `_ready` 後等待 physics frame
2. 用 `TableDetector` 找重疊 `Table`
3. 將 `SeatSlotData` 轉換為世界座標
4. 註冊到 `Table.available_seats`

### 3.4 Subpixel 視覺流程
1. `subpixel_camera.gd` 以 `target_path` 跟隨目標
2. 計算 subpixel offset
3. `SignalManager` 發送 offset
4. `sub_viewport_container.gd` 寫入 shader 參數 `cam_offset`

## 4. 腳本職責明細

### actors/player.gd
- 角色物理移動控制中心
- 套用 MovementComponent 輸出
- 更新朝向與狀態機

### actors/table.gd
- 讀取 `TableData` 初始化碰撞/互動範圍/食物槽
- 管理 `available_seats`、`connected_chairs`
- 實作 `interact(actor)` 供互動元件呼叫

### actors/chair.gd
- 讀取 `ChairData`
- 偵測鄰近 Table 並註冊座位資訊

### components/movement_component.gd
- 輸入 -> 速度模型（加速/摩擦/跑步）

### components/state_machine.gd
- 輸入狀態 -> MoveState

### components/interact.gd
- 統一互動入口
- 發送 `interaction_requested`
- 呼叫目標 `interact(actor)`

### components/visual_component.gd
- 視覺浮動與朝向翻面

### systems/item_database.gd
- 掃描 `game/data/foods` 的 `.tres`
- 防呆：無效資源、空 id、重複 id、查無 id

### systems/subpixel_camera.gd
- 相機平滑與 offset 計算
- 已支援 `target_path` 注入

### systems/sub_viewport_container.gd
- 監聽 offset 訊號並更新材質

## 5. 已完成的風險處理
- `chair.gd` 從 assets 移到 scripts/actors
- `scripts` 目錄完成分層（actors/components/systems/resources）
- 清除 `main.tscn*.tmp` 並加上 `.gitignore` 規則
- `InteractionComponent` 已有可用契約與基本邏輯
- `ItemDatabase` 已補防呆
- `project.godot` 已加入 `interact` action
- 關鍵腳本已改為明確型別（避免 Variant 推導）

## 6. 目前剩餘技術債
- `subpixel_camera.gd` 仍保留 fallback 目標查找（可後續移除）
- 互動介面尚未正式抽象為 `IInteractable` 規格
- 缺少最小自動化或 smoke test 清單

## 7. 建議下一步
1. 定義互動規格文件
- 明確規定 `interact(actor)` 參數與回傳行為
2. 做 Seat 佔位模型
- `available` / `occupied` / `occupied_by`
3. 串接上菜流程
- `FoodData` -> table slot 顯示 -> 訂單狀態
4. 建立 smoke test
- 移動、互動、資料載入、相機 offset 四項最小驗證
