extends CanvasLayer
# UIManager - 遊戲 UI 的根控制器
#
# 職責：
# 1. 管理 HUD_Layer（遊戲進行中顯示）
# 2. 管理 Menu_Layer（暫停/選單畫面）
# 3. 協調各 UI 層級的顯示/隱藏
# 4. 接收全局信號並分派給子層

@onready var hud_layer: Control = $HUD_Layer
@onready var menu_layer: Control = $Menu_Layer
@onready var end_of_day_panel: PanelContainer = $Menu_Layer/EndOfDayPanel

func _ready() -> void:
	# 連接全局信號
	if not SignalManager.day_started.is_connected(_on_day_started):
		SignalManager.day_started.connect(_on_day_started)

	if not SignalManager.day_ended.is_connected(_on_day_ended):
		SignalManager.day_ended.connect(_on_day_ended)

	print("[UIManager] 初始化完成")

func _on_day_started(_day_count: int) -> void:
	show_hud()
	if end_of_day_panel:
		end_of_day_panel.hide()

func _on_day_ended() -> void:
	hide_hud()
	# EndOfDayPanel 會自動顯示（它自己連接了 day_ended 信號）

func show_hud() -> void:
	if hud_layer:
		hud_layer.show()

func hide_hud() -> void:
	if hud_layer:
		hud_layer.hide()
