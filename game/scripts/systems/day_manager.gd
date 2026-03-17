extends Node
# DayManager - 營業時間管理
#
# 職責：
# 1. 控制遊戲節奏，管理一天的開始與結束
# 2. 追蹤遊戲內時間並格式化顯示
# 3. 時間到達時自動結束一天

# ============================================
# 設定參數
# ============================================

## 一天的實際持續時間（秒）
@export var day_duration_seconds: float = 180.0  # 預設 3 分鐘

## 遊戲內開始時間（小時，24小時制）
@export var day_start_hour: float = 9.0  # 上午 9 點

## 遊戲內結束時間（小時，24小時制）
@export var day_end_hour: float = 21.0  # 晚上 9 點

# ============================================
# 執行時變數
# ============================================

## 已進行的天數（從 1 開始）
var current_day: int = 1

## 當天已過時間（秒）
var time_elapsed: float = 0.0

## 是否正在營業中
var is_day_active: bool = false

# ============================================
# Lifecycle
# ============================================

func _ready() -> void:
	print("[DayManager] 初始化完成，預設營業時間: %.0f 秒 (%.1f 小時 ~ %.1f 小時)" % [
		day_duration_seconds, day_start_hour, day_end_hour
	])

func _process(delta: float) -> void:
	if not is_day_active:
		return

	# 累積時間
	time_elapsed += delta

	# 格式化並發射時間更新
	var formatted_time: String = _get_formatted_time()
	SignalManager.time_ticked.emit(formatted_time)

	# 檢查是否到達結束時間
	if time_elapsed >= day_duration_seconds:
		end_day()

# ============================================
# 公開接口
# ============================================

## 開始新的一天
func start_day() -> void:
	if is_day_active:
		push_warning("[DayManager] 嘗試在營業中開始新的一天")
		return

	# 重置時間
	time_elapsed = 0.0
	is_day_active = true

	# 重置經濟統計
	EconomyManager.reset_daily_stats()

	print("[DayManager] 第 %d 天開始！營業時間 %.1f 小時 ~ %.1f 小時" % [
		current_day, day_start_hour, day_end_hour
	])

	# 發射信號
	SignalManager.day_started.emit(current_day)

	# 立即發射一次時間更新（顯示開始時間）
	SignalManager.time_ticked.emit(_get_formatted_time())

## 結束當天
func end_day() -> void:
	if not is_day_active:
		return

	is_day_active = false

	print("[DayManager] 第 %d 天結束")

	# 發射信號
	SignalManager.day_ended.emit()

## 手動進入下一天（從結算面板呼叫）
func advance_to_next_day() -> void:
	current_day += 1
	print("[DayManager] 準備進入第 %d 天" % current_day)

# ============================================
# 內部工具
# ============================================

## 取得格式化時間字串（如 "09:00 AM"）
func _get_formatted_time() -> String:
	var progress: float = time_elapsed / day_duration_seconds
	var current_hour: float = day_start_hour + (day_end_hour - day_start_hour) * progress

	var hour_24: int = int(current_hour)
	var minute: int = int((current_hour - hour_24) * 60.0)

	# 轉換為 12 小時制
	var period: String = "AM" if hour_24 < 12 else "PM"
	var hour_12: int = hour_24
	if hour_12 == 0:
		hour_12 = 12
	elif hour_12 > 12:
		hour_12 -= 12

	return "%02d:%02d %s" % [hour_12, minute, period]

## 取得當天進度（0.0 ~ 1.0）
func get_day_progress() -> float:
	if day_duration_seconds <= 0.0:
		return 0.0
	return clampf(time_elapsed / day_duration_seconds, 0.0, 1.0)

## 取得剩餘時間（秒）
func get_remaining_time() -> float:
	return maxf(0.0, day_duration_seconds - time_elapsed)
