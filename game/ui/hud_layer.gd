extends Control
# HUD_Layer - 遊戲進行中的實時信息显示
#
# 顯示內容：
# - 當前金錢 (MoneyLabel)
# - 遊戲內時間 (TimeLabel)

@onready var money_label: Label = $MarginContainer/HBoxContainer/MoneyLabel
@onready var time_label: Label = $MarginContainer/HBoxContainer/TimeLabel

func _ready() -> void:
	# 初始化顯示
	_update_money_display(0)
	_update_time_display("09:00 AM")

	# 連接 SignalManager 信號
	if not SignalManager.money_updated.is_connected(_on_money_updated):
		SignalManager.money_updated.connect(_on_money_updated)

	if not SignalManager.time_ticked.is_connected(_on_time_ticked):
		SignalManager.time_ticked.connect(_on_time_ticked)

	print("[HUDLayer] 初始化完成")

func _on_money_updated(current_money: int, _daily_earnings: int) -> void:
	_update_money_display(current_money)

func _on_time_ticked(formatted_time: String) -> void:
	_update_time_display(formatted_time)

func _update_money_display(amount: int) -> void:
	if money_label:
		money_label.text = "$%d" % amount

func _update_time_display(time_str: String) -> void:
	if time_label:
		time_label.text = time_str
