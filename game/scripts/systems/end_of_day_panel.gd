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
@onready var lost_value: Label = $MarginContainer/VBoxContainer/StatsGrid/LostValue
@onready var next_day_button: Button = $MarginContainer/VBoxContainer/NextDayButton
@onready var edit_mode_button: Button = $MarginContainer/VBoxContainer/EditModeButton

func _ready() -> void:
	# 預設隱藏
	hide()

	# 連接按鈕信號
	if next_day_button and not next_day_button.pressed.is_connected(_on_next_day_pressed):
		next_day_button.pressed.connect(_on_next_day_pressed)
	
	if edit_mode_button and not edit_mode_button.pressed.is_connected(_on_edit_mode_pressed):
		edit_mode_button.pressed.connect(_on_edit_mode_pressed)

	print("[EndOfDayPanel] 初始化完成")

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
	if DayManager == null or not DayManager.transition_to_next_day_pre_open():
		push_warning("[EndOfDayPanel] Failed to transition to next day pre-open")
		return

	hide()
	get_tree().paused = false

	var ui_manager: UIManager = get_tree().get_first_node_in_group("ui_manager") as UIManager
	if ui_manager != null:
		ui_manager.show_hud()

	print("[EndOfDayPanel] 已切換到下一天的 pre-open 狀態")

func _on_edit_mode_pressed() -> void:
	# Hide the panel
	hide()
	
	# Resume game (edit mode handles its own pause state if needed)
	get_tree().paused = false
	
	# Request UIManager to enter edit mode
	var ui_manager: UIManager = get_tree().get_first_node_in_group("ui_manager") as UIManager
	
	if ui_manager != null:
		var success: bool = ui_manager.enter_edit_mode()
		if not success:
			print("[EndOfDayPanel] Failed to enter edit mode")
			# Show panel again if failed
			show()
	else:
		push_warning("[EndOfDayPanel] UIManager not found")
