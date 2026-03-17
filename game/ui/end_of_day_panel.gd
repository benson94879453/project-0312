extends PanelContainer
# EndOfDayPanel - 每日結算面板
#
# 職責：
# 1. 在每日結束時顯示統計資訊
# 2. 暫停遊戲迴圈
# 3. 提供「開始下一天」按鈕恢復遊戲

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var stats_grid: GridContainer = $MarginContainer/VBoxContainer/StatsGrid
@onready var income_value: Label = $MarginContainer/VBoxContainer/StatsGrid/IncomeValue
@onready var served_value: Label = $MarginContainer/VBoxContainer/StatsGrid/ServedValue
@onready var lost_value: Label = $MarginContainer/VBoxContainer/VBoxContainer/LostValue
@onready var next_day_button: Button = $MarginContainer/VBoxContainer/NextDayButton

func _ready() -> void:
	# 預設隱藏
	hide()

	# 連接按鈕信號
	if next_day_button:
		next_day_button.pressed.connect(_on_next_day_pressed)

	# 連接全局信號
	if not SignalManager.day_ended.is_connected(_on_day_ended):
		SignalManager.day_ended.connect(_on_day_ended)

	print("[EndOfDayPanel] 初始化完成")

func _on_day_ended() -> void:
	show_panel()

func show_panel() -> void:
	# 從 EconomyManager 抓取統計資料
	var stats: Dictionary = EconomyManager.get_daily_stats()

	# 更新 UI
	if income_value:
		income_value.text = "$%d" % stats.get("total_earnings", 0)
	if served_value:
		served_value.text = "%d" % stats.get("customers_served", 0)
	if lost_value:
		lost_value.text = "%d" % stats.get("customers_lost", 0)

	# 顯示面板
	show()

	# 暫停遊戲
	get_tree().paused = true

	print("[EndOfDayPanel] 顯示結算面板，遊戲已暫停")

func _on_next_day_pressed() -> void:
	# 隱藏面板
	hide()

	# 恢復遊戲
	get_tree().paused = false

	# 進入下一天
	DayManager.advance_to_next_day()
	DayManager.start_day()

	print("[EndOfDayPanel] 開始下一天")
