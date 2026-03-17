## Task 1: 擴充 SignalManager 契約 (Prerequisite)

在實作各個 Manager 之前，必須先定義好它們之間的溝通橋樑。

- **目標檔案**：`game/scripts/systems/signal_manager.gd`
    
- **Action Items**：
    
    - [ ] 新增信號 `signal customer_paid(base_amount: int, tips: int)`
        
    - [ ] 新增信號 `signal customer_lost()`
        
    - [ ] 新增信號 `signal money_updated(current_money: int, daily_earnings: int)`
        
    - [ ] 新增信號 `signal time_ticked(formatted_time: String)`
        
    - [ ] 新增信號 `signal day_started(day_count: int)`
        
    - [ ] 新增信號 `signal day_ended()`
        

---

## Task 2: 實作 EconomyManager (SSOT)

建立處理金錢與每日統計的單一真理點。

- **目標路徑**：`game/scripts/systems/economy_manager.gd` (設為 Autoload)
    
- **Action Items**：
    
    - [ ] 定義內部變數：`current_money` (int), `total_earnings_today` (int), `customers_served_today` (int), `customers_lost_today` (int)。
        
    - [ ] 在 `_ready()` 連結 `SignalManager.customer_paid` 與 `SignalManager.customer_lost`。
        
    - [ ] 實作 `_on_customer_paid(amount, tips)`：
        
        - 邏輯：增加 `current_money` 與 `total_earnings_today`。
            
        - 邏輯：`customers_served_today += 1`。
            
        - 發送更新：`SignalManager.money_updated.emit(current_money, total_earnings_today)`。
            
    - [ ] 實作 `_on_customer_lost()`：增加流失客數計數。
        
    - [ ] 實作 `reset_daily_stats()`：在每天開始時歸零 `total_earnings_today` 等日統計變數。
        

---

## Task 3: 實作 DayManager (營業時間管理)

控制遊戲節奏，負責觸發一天的開始與結束。

- **目標路徑**：`game/scripts/systems/day_manager.gd` (設為 Autoload)
    
- **Action Items**：
    
    - [ ] 定義變數：`day_duration_seconds` (例如 180 秒 = 3 分鐘), `time_elapsed` (float), `current_day` (int), `is_day_active` (bool)。
        
    - [ ] 實作 `start_day()`：
        
        - 重置 `time_elapsed`，標記 `is_day_active = true`。
            
        - 觸發 `EconomyManager.reset_daily_stats()`（可透過信號或直接呼叫）。
            
        - 發射 `SignalManager.day_started`。
            
    - [ ] 實作 `_process(delta)` 或內部 `Timer`：
        
        - 當 `is_day_active` 為 true 時累積時間。
            
        - 將經過時間轉換為遊戲內字串（例如 "09:00 AM" 到 "05:00 PM"）並發射 `time_ticked`。
            
        - 時間到達時自動呼叫 `end_day()`。
            
    - [ ] 實作 `end_day()`：標記 `is_day_active = false` 並發射 `SignalManager.day_ended`。
        

---

## Task 4: 實作顧客耐心與小費機制 (Patience System)

將經濟壓力實作到現有的 Customer 狀態機中。

- **目標檔案**：`game/scripts/actors/customer.gd` & `customer_state_machine.gd`
    
- **Action Items**：
    
    - [ ] 在 `CustomerData` (若已建立) 或 `Customer` 中新增變數：`max_patience` (float, 預設例如 30.0 秒), `current_patience`。
        
    - [ ] **耐心衰減**：在狀態機的 `WAITING_FOOD` 階段的 `Update` (或 tick) 中，隨時間扣減 `current_patience`。
        
    - [ ] **耐心歸零處理**：若 `WAITING_FOOD` 時 `current_patience <= 0`：
        
        - 清空對應的桌子座位。
            
        - 觸發 `SignalManager.customer_lost.emit()`。
            
        - 強制切換到 `LEAVING` 狀態（憤怒離開）。
            
    - [ ] **結算小費**：在進入 `EATING` 狀態時（收到餐點），凍結耐心值。
        
        - 計算小費乘數：`tips_multiplier = current_patience / max_patience`。
            
    - [ ] **支付餐費**：在 `EATING` 結束準備 `LEAVING` 時，讀取 `FoodData.price`，計算 `tips`，並發射 `SignalManager.customer_paid.emit(price, tips)`。
        
    - [ ] (Optional) **視覺提示**：在 `CustomerVisualComponent` 上方加一個簡單的 `ProgressBar` 顯示耐心條。
        

---

## Task 5: 實作 UIManager 與 HUD Layer

接管並正式化原有的 `ServiceDebugHud`。

- **目標路徑**：`game/ui/ui_manager.tscn` (建議掛載在 Main 場景，或設為 Autoload CanvasLayer)
    
- **Action Items**：
    
    - [ ] 建立 `UIManager` 根節點 (CanvasLayer)。
        
    - [ ] 建立子節點 `HUD_Layer` (Control)。
        
        - 包含 `MoneyLabel` (顯示 `$100`)。
            
        - 包含 `TimeLabel` (顯示 `12:00 PM` 或倒數進度條)。
            
    - [ ] 撰寫 `hud_layer.gd`：
        
        - 連接 `SignalManager.money_updated` 更新金錢文字。
            
        - 連接 `SignalManager.time_ticked` 更新時間文字。
            
    - [ ] 移除/廢棄舊的 `ServiceDebugHud`。
        

---

## Task 6: 實作每日結算畫面 (End of Day Panel)

提供玩家營業回饋，並暫停遊戲迴圈。

- **目標路徑**：`game/ui/end_of_day_panel.tscn`
    
- **Action Items**：
    
    - [ ] 在 `UIManager` 底下建立 `Menu_Layer`，並放入 `EndOfDayPanel` (Control/PanelContainer)，預設為隱藏。
        
    - [ ] 排版 UI：標題「營業結束」、文字標籤（今日收入、服務客數、流失客數）、按鈕「開始下一天」。
        
    - [ ] 撰寫 `end_of_day_panel.gd` 邏輯：
        
        - 監聽 `SignalManager.day_ended` -> 顯示此面板，並呼叫 `get_tree().paused = true` 暫停遊戲。
            
        - 從 `EconomyManager` 抓取統計資料填入 UI 文字。
            
        - 連接「開始下一天」按鈕：隱藏面板、`get_tree().paused = false`、呼叫 `DayManager.start_day()`。