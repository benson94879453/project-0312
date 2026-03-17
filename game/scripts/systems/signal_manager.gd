extends Node
# 檔案名稱：signal_manager.gd (Autoload 名稱為 SignalManager)

# 定義信號名稱與攜帶的參數型別 (Resource)
# 注意：這裡不寫任何邏輯，只負責「宣告」
@warning_ignore("unused_signal")
signal sub_pixel_offset_updated(offset: Vector2)

# ============================================
# Task 1: 經濟與時間管理系統信號
# ============================================

## 顧客付款時發射 (Task 2, 4)
# @param base_amount: 餐點基本價格
# @param tips: 小費金額
@warning_ignore("unused_signal")
signal customer_paid(base_amount: int, tips: int)

## 顧客流失時發射 (Task 4)
# 當顧客耐心歸零憤怒離開時觸發
@warning_ignore("unused_signal")
signal customer_lost()

## 金錢更新時發射 (Task 2)
# @param current_money: 玩家目前總金錢
# @param daily_earnings: 今日總收入
@warning_ignore("unused_signal")
signal money_updated(current_money: int, daily_earnings: int)

## 遊戲時間更新時發射 (Task 3)
# @param formatted_time: 格式化時間字串 (如 "12:30 PM")
@warning_ignore("unused_signal")
signal time_ticked(formatted_time: String)

## 新的一天開始時發射 (Task 3)
# @param day_count: 第幾天 (從 1 開始)
@warning_ignore("unused_signal")
signal day_started(day_count: int)

## 一天結束時發射 (Task 3)
@warning_ignore("unused_signal")
signal day_ended()
