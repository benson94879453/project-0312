extends Node
# EconomyManager - 金錢與每日統計的單一真理點 (SSOT)
#
# 職責：
# 1. 管理玩家總金錢 (current_money)
# 2. 追蹤每日統計 (收入、服務客數、流失客數)
# 3. 接收顧客付款與流失事件，發射金錢更新通知

# ============================================
# 核心變數
# ============================================

## 玩家目前總金錢
var current_money: int = 0

## 今日總收入
var total_earnings_today: int = 0

## 今日服務客數
var customers_served_today: int = 0

## 今日流失客數
var customers_lost_today: int = 0

# ============================================
# Lifecycle
# ============================================

func _ready() -> void:
	_connect_signals()
	print("[EconomyManager] 初始化完成，目前金錢: $%d" % current_money)

func _connect_signals() -> void:
	# 連接顧客付款信號
	if not SignalManager.customer_paid.is_connected(_on_customer_paid):
		SignalManager.customer_paid.connect(_on_customer_paid)

	# 連接顧客流失信號
	if not SignalManager.customer_lost.is_connected(_on_customer_lost):
		SignalManager.customer_lost.connect(_on_customer_lost)

# ============================================
# 事件處理
# ============================================

## 處理顧客付款事件
func _on_customer_paid(base_amount: int, tips: int) -> void:
	var total_amount: int = base_amount + tips
	current_money += total_amount
	total_earnings_today += total_amount
	customers_served_today += 1

	print("[EconomyManager] 收到付款: $%d (餐點: $%d, 小費: $%d), 總計: $%d" % [
		total_amount, base_amount, tips, current_money
	])

	# 發射金錢更新通知
	SignalManager.money_updated.emit(current_money, total_earnings_today)

## 處理顧客流失事件
func _on_customer_lost() -> void:
	customers_lost_today += 1
	print("[EconomyManager] 顧客流失，今日流失數: %d" % customers_lost_today)

# ============================================
# 公開接口
# ============================================

## 重置每日統計
## 應在每天開始時由 DayManager 呼叫
func reset_daily_stats() -> void:
	total_earnings_today = 0
	customers_served_today = 0
	customers_lost_today = 0
	print("[EconomyManager] 每日統計已重置")

## 取得完整統計資料
## 供 EndOfDayPanel 等 UI 使用
func get_daily_stats() -> Dictionary:
	return {
		"total_earnings": total_earnings_today,
		"customers_served": customers_served_today,
		"customers_lost": customers_lost_today
	}

## 直接增加金錢 (用於作弊或特殊事件)
func add_money(amount: int) -> void:
	current_money += amount
	SignalManager.money_updated.emit(current_money, total_earnings_today)

func set_current_money(amount: int) -> void:
	current_money = max(amount, 0)
	SignalManager.money_updated.emit(current_money, total_earnings_today)

## 嘗試花費金錢，回傳是否成功
func try_spend_money(amount: int) -> bool:
	if current_money < amount:
		return false
	current_money -= amount
	SignalManager.money_updated.emit(current_money, total_earnings_today)
	return true
