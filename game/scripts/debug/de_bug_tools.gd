extends Node2D

@export var player_path: NodePath = NodePath("../Player")
@export var table_path: NodePath = NodePath("../NavigationRegion2D/Object/Table")
@export var customer_path: NodePath = NodePath("../Customer")
@export var leave_target_path: NodePath = NodePath("../LeavePosition")

@onready var world_de_bug: Node2D = get_node_or_null("WorldDeBug") as Node2D
@onready var message_hud: CanvasLayer = get_node_or_null("MessageHUD") as CanvasLayer

func _ready() -> void:
	var player: Node = get_node_or_null(player_path)
	var table: Table = get_node_or_null(table_path) as Table
	var customer: Node = get_node_or_null(customer_path)
	var leave_target: Node2D = get_node_or_null(leave_target_path) as Node2D
	var spawn_parent: Node = get_parent()

	if world_de_bug != null and world_de_bug.has_method("setup"):
		world_de_bug.call("setup", player, table, customer, leave_target, spawn_parent)
	if message_hud != null and message_hud.has_method("setup"):
		message_hud.call("setup", player, table, customer, DayManager)

	if message_hud != null:
		if message_hud.has_signal("spawn_customer_requested") and not message_hud.is_connected("spawn_customer_requested", Callable(self, "_on_spawn_customer_requested")):
			message_hud.connect("spawn_customer_requested", Callable(self, "_on_spawn_customer_requested"))
		if message_hud.has_signal("edit_mode_requested") and not message_hud.is_connected("edit_mode_requested", Callable(self, "_on_edit_mode_requested")):
			message_hud.connect("edit_mode_requested", Callable(self, "_on_edit_mode_requested"))
		if message_hud.has_signal("save_requested") and not message_hud.is_connected("save_requested", Callable(self, "_on_save_requested")):
			message_hud.connect("save_requested", Callable(self, "_on_save_requested"))
		if message_hud.has_signal("load_requested") and not message_hud.is_connected("load_requested", Callable(self, "_on_load_requested")):
			message_hud.connect("load_requested", Callable(self, "_on_load_requested"))
		if message_hud.has_signal("day_speed_selected") and not message_hud.is_connected("day_speed_selected", Callable(self, "_on_day_speed_selected")):
			message_hud.connect("day_speed_selected", Callable(self, "_on_day_speed_selected"))

func _on_spawn_customer_requested() -> void:
	if world_de_bug == null or not world_de_bug.has_method("spawn_customer"):
		return

	var result: Dictionary = world_de_bug.call("spawn_customer") as Dictionary
	if message_hud == null:
		return

	if message_hud.has_method("append_debug_event"):
		message_hud.call("append_debug_event", String(result.get("message", "生成顧客操作完成")))
	if result.get("ok", false) and message_hud.has_method("set_tracked_customer"):
		message_hud.call("set_tracked_customer", result.get("customer", null))

func _on_day_speed_selected(multiplier: float) -> void:
	if world_de_bug == null or not world_de_bug.has_method("set_day_speed_multiplier"):
		return

	var result: Dictionary = world_de_bug.call("set_day_speed_multiplier", multiplier) as Dictionary
	if message_hud == null:
		return

	if message_hud.has_method("update_day_speed"):
		message_hud.call("update_day_speed", float(result.get("multiplier", multiplier)))
	if message_hud.has_method("append_debug_event"):
		message_hud.call("append_debug_event", String(result.get("message", "已更新時間倍率")))

func _on_edit_mode_requested() -> void:
	var ui_manager: UIManager = get_tree().get_first_node_in_group("ui_manager") as UIManager
	if ui_manager == null:
		if message_hud != null and message_hud.has_method("append_debug_event"):
			message_hud.call("append_debug_event", "找不到 UIManager，無法進入編輯模式")
		return

	var success: bool = ui_manager.enter_edit_mode()
	if message_hud != null and message_hud.has_method("append_debug_event"):
		message_hud.call("append_debug_event", "已進入編輯模式" if success else "營業中無法進入編輯模式")

func _on_save_requested() -> void:
	var success: bool = SaveManager != null and SaveManager.save_current_boundary()
	if message_hud != null and message_hud.has_method("append_debug_event"):
		message_hud.call("append_debug_event", "已手動存檔" if success else "存檔失敗：%s" % _get_save_error())

func _on_load_requested() -> void:
	var success: bool = SaveManager != null and SaveManager.load_latest_snapshot()
	if message_hud != null and message_hud.has_method("append_debug_event"):
		message_hud.call("append_debug_event", "已載入最新存檔" if success else "讀檔失敗：%s" % _get_save_error())

func _get_save_error() -> String:
	if SaveManager == null or not SaveManager.has_method("get_last_error_message"):
		return "save_manager_unavailable"
	return String(SaveManager.get_last_error_message())
