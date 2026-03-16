待辦/後續考量：處理桌子與椅子動態生成的先後順序問題。目前椅子在 _ready() 使用 get_overlapping_bodies() 找桌子。若未來開放動態擺放家具，需考慮：

  

1.  晚生成的物件（如桌子）主動尋找周圍椅子。

2.  導入 Event Bus 全域廣播機制。

3.  使用 Manager 節點統一管理生成與綁定順序。

---

本輪測試產生的技術債（Debug 與暫時性方案）：

1. `Customer` 自動開單目前用 Timer 重試（`auto_start_retry_*`）解決 seats 註冊時序，屬 workaround。長期應改為事件驅動（Chair/Table 註冊完成後通知 Customer）。
2. `ServiceDebugHUD` 直接掛在測試場景，且會同時記錄 body/area 互動，按一次 `E` 可能看到兩筆 `Interact pressed`，需要後續去重或分層。
3. 測試期間可能有 `debug_start_food_id` 覆寫殘留在場景（如 `player.tscn`），容易造成「玩家預設持物」誤判，需在正式流程切乾淨。
4. `Table.interaction_processed` 是為測試可觀測性加入的訊號；若進正式版，應評估是否改成獨立 telemetry/debug bus，避免 gameplay 腳本混入過多調試責任。
