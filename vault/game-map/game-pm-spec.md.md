# game PM 規格與里程碑

## 文件目的
- 將目前 `game` 專案拆成可執行任務。
- 區分已完成與待完成項目，方便 sprint 追蹤。

## 當前狀態摘要
- 已完成：目錄重構、互動 action、互動基本契約、ItemDatabase 防呆、tmp 清理、型別顯式化。
- 進行中：互動規格標準化、座位佔用模型、玩法閉環。

## Milestone 1 基礎架構整頓（已完成）
### 完成標準
- 目錄分層清楚
- 互動元件有統一入口
- 場景暫存檔清理完成

### 任務
- [x] `chair.gd` 移至 `game/scripts/actors/chair.gd`
- [x] 分層為 `actors/components/systems/resources`
- [x] 更新場景引用路徑
- [x] `InteractionComponent` 增加互動契約入口
- [x] 移除 `game/playground/*.tmp`
- [x] `.gitignore` 新增 `*.tscn*.tmp`

## Milestone 2 可玩核心迴圈 v1（部分完成）
### 完成標準
- 玩家可觸發互動
- 至少一個目標物件有 `interact(actor)`

### 任務
- [x] 新增 InputMap action：`interact`（E）
- [x] `InteractionComponent` 可掃描並呼叫目標互動
- [x] `Table` 實作最小 `interact(actor)`
- [ ] 將互動結果接到實際玩法（放置食物/狀態改變）

## Milestone 3 座位系統產品化（待開始）
### 任務
- [ ] Seat 狀態模型：`available` / `occupied` / `occupied_by`
- [ ] `Table.reserve_seat(actor)`
- [ ] `Table.release_seat(actor)`
- [ ] 防重複占位檢查

## Milestone 4 NPC 服務流程 v1（待開始）
### 任務
- [ ] NPC state machine（Enter -> FindSeat -> Sit -> Order -> WaitFood -> Leave）
- [ ] NPC 尋位與入座
- [ ] 上菜後狀態切換
- [ ] 離席釋放座位

## Milestone 5 經營循環 v1（待開始）
### 任務
- [ ] 以 `FoodData.price` 做結算
- [ ] UI 顯示收入與服務狀態
- [ ] 計時局與結算畫面

## 技術任務橫向清單
- [x] 關鍵腳本顯式型別化（避免 Variant 推導）
- [ ] 相機 fallback 依賴移除（完全改為 target_path 注入）
- [ ] 定義 `IInteractable` 文件規格
- [ ] 建立最小 smoke test 清單

## Sprint 建議
- Sprint A：完成 Milestone 2 未完成項 + 座位佔用 API
- Sprint B：NPC 入座與服務流程
- Sprint C：經營回饋與 UI 結算
