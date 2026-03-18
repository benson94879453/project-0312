extends CanvasLayer
class_name UIManager
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
@onready var edit_mode_ui: EditModeUI = $Menu_Layer/EditModeUI

var _edit_mode_controller: EditModeController = null

func _ready() -> void:
	add_to_group("ui_manager")
	
	if end_of_day_panel:
		end_of_day_panel.hide()
	
	if edit_mode_ui:
		edit_mode_ui.hide()

	# 連接全局信號
	if not SignalManager.day_started.is_connected(_on_day_started):
		SignalManager.day_started.connect(_on_day_started)

	if not SignalManager.day_ended.is_connected(_on_day_ended):
		SignalManager.day_ended.connect(_on_day_ended)

	# Defer controller setup to allow scene to fully load
	call_deferred("_setup_edit_mode_controller")

	print("[UIManager] 初始化完成")

func _setup_edit_mode_controller() -> void:
	# Find the EditModeController in the scene
	var parent = get_parent()
	if parent != null:
		var controller = parent.get_node_or_null("EditModeController") as EditModeController
		if controller != null:
			setup_edit_mode_controller(controller)
			print("[UIManager] EditModeController connected")

func setup_edit_mode_controller(controller: EditModeController) -> void:
	_edit_mode_controller = controller
	if not _edit_mode_controller.edit_mode_exited.is_connected(_on_edit_mode_controller_exited):
		_edit_mode_controller.edit_mode_exited.connect(_on_edit_mode_controller_exited)
	if edit_mode_ui:
		edit_mode_ui.setup(controller)
		_connect_edit_mode_signals()

func _connect_edit_mode_signals() -> void:
	if edit_mode_ui == null or _edit_mode_controller == null:
		return
	
	edit_mode_ui.table_selected.connect(_on_table_selected)
	edit_mode_ui.chair_selected.connect(_on_chair_selected)
	edit_mode_ui.move_pressed.connect(_on_move_pressed)
	edit_mode_ui.rotate_pressed.connect(_on_rotate_pressed)
	edit_mode_ui.confirm_pressed.connect(_on_confirm_pressed)
	edit_mode_ui.cancel_pressed.connect(_on_cancel_pressed)
	edit_mode_ui.delete_pressed.connect(_on_delete_pressed)
	edit_mode_ui.exit_edit_mode_pressed.connect(_on_exit_edit_mode_pressed)

func _on_table_selected() -> void:
	if _edit_mode_controller:
		_edit_mode_controller.start_placing_new("table", "")

func _on_chair_selected() -> void:
	if _edit_mode_controller:
		_edit_mode_controller.start_placing_new("chair", "")

func _on_move_pressed() -> void:
	if _edit_mode_controller == null:
		return
	var selected_placeable: Node2D = _edit_mode_controller.get_selected_placeable()
	if selected_placeable == null:
		if edit_mode_ui:
			edit_mode_ui.show_message("Select furniture before moving", true)
		return
	_edit_mode_controller.start_moving_existing(selected_placeable)

func _on_rotate_pressed() -> void:
	if _edit_mode_controller:
		_edit_mode_controller.rotate_preview()

func _on_confirm_pressed() -> void:
	if _edit_mode_controller:
		var success: bool = _edit_mode_controller.confirm_placement()
		if not success and edit_mode_ui:
			edit_mode_ui.show_message("Cannot place: Invalid position", true)

func _on_cancel_pressed() -> void:
	if _edit_mode_controller:
		_edit_mode_controller.cancel_operation()

func _on_delete_pressed() -> void:
	if _edit_mode_controller:
		var success: bool = _edit_mode_controller.delete_selected_placeable()
		if not success and edit_mode_ui:
			edit_mode_ui.show_message("Nothing selected to delete", true)

func _on_exit_edit_mode_pressed() -> void:
	if _edit_mode_controller:
		_edit_mode_controller.exit_edit_mode()

func enter_edit_mode() -> bool:
	if _edit_mode_controller == null:
		return false
	
	var success: bool = _edit_mode_controller.enter_edit_mode()
	if success:
		hide_hud()
		if end_of_day_panel:
			end_of_day_panel.hide()
	return success

func _on_edit_mode_controller_exited() -> void:
	show_hud()

func _on_day_started(_day_count: int) -> void:
	show_hud()
	if end_of_day_panel:
		end_of_day_panel.hide()
	if edit_mode_ui:
		edit_mode_ui.hide()

func _on_day_ended() -> void:
	hide_hud()
	if end_of_day_panel:
		end_of_day_panel.show_panel()

func show_hud() -> void:
	if hud_layer:
		hud_layer.show()

func hide_hud() -> void:
	if hud_layer:
		hud_layer.hide()
