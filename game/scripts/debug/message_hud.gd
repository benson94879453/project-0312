extends CanvasLayer

signal spawn_customer_requested()
signal day_speed_selected(multiplier: float)
signal edit_mode_requested()
signal save_requested()
signal load_requested()

@export_category("Debug Panel Layout")
@export var panel_offset: Vector2 = Vector2(0.0, 70.0):
	set(value):
		panel_offset = value
		_apply_panel_layout()
@export var panel_size: Vector2 = Vector2(560.0, 320.0):
	set(value):
		panel_size = Vector2(maxf(value.x, 1.0), maxf(value.y, 1.0))
		_apply_panel_layout()
@export var snapshot_min_height: float = 44.0:
	set(value):
		snapshot_min_height = maxf(value, 0.0)
		_apply_panel_layout()
@export var table_min_height: float = 44.0:
	set(value):
		table_min_height = maxf(value, 0.0)
		_apply_panel_layout()
@export var log_min_size: Vector2 = Vector2(520.0, 170.0):
	set(value):
		log_min_size = Vector2(maxf(value.x, 0.0), maxf(value.y, 0.0))
		_apply_panel_layout()

@export_category("Debug Panel Behavior")
@export var max_log_entries: int = 16
@export var refresh_interval_sec: float = 0.15

@onready var debug_panel: PanelContainer = $DeBugPanel
@onready var snapshot_label: Label = $DeBugPanel/Margin/Content/SnapshotLabel
@onready var table_label: Label = $DeBugPanel/Margin/Content/TableLabel
@onready var log_out_label: RichTextLabel = $DeBugPanel/Margin/Content/LogOutLabel
@onready var spawn_customer_button: Button = $DeBugPanel/Margin/Content/ControlsRow/SpawnCustomerButton
@onready var edit_mode_button: Button = $DeBugPanel/Margin/Content/ControlsRow/EditModeButton
@onready var save_button: Button = $DeBugPanel/Margin/Content/ControlsRow/SaveButton
@onready var load_button: Button = $DeBugPanel/Margin/Content/ControlsRow/LoadButton
@onready var day_speed_label: Label = $DeBugPanel/Margin/Content/ControlsRow/DaySpeedLabel
@onready var day_speed_option_button: OptionButton = $DeBugPanel/Margin/Content/ControlsRow/DaySpeedOptionButton

var _player: Node = null
var _table: Table = null
var _customer: Node = null
var _day_manager: Node = null
var _interaction_component: Area2D = null
var _log_entries: Array[String] = []
var _refresh_accumulator: float = 0.0
var _is_initialized: bool = false
var _day_speed_values: Array[float] = [1.0, 2.0, 4.0, 8.0]

func setup(player: Node, table: Table, customer: Node, day_manager: Node = null) -> void:
	_player = player
	_table = table
	_customer = customer
	_day_manager = day_manager
	if is_node_ready():
		_initialize_runtime()

func _ready() -> void:
	_apply_panel_layout()
	_initialize_runtime()

func _apply_panel_layout() -> void:
	if not is_node_ready():
		return

	if debug_panel != null:
		debug_panel.offset_left = panel_offset.x
		debug_panel.offset_top = panel_offset.y
		debug_panel.offset_right = panel_offset.x + panel_size.x
		debug_panel.offset_bottom = panel_offset.y + panel_size.y

	if snapshot_label != null:
		snapshot_label.custom_minimum_size = Vector2(0.0, snapshot_min_height)
	if table_label != null:
		table_label.custom_minimum_size = Vector2(0.0, table_min_height)
	if log_out_label != null:
		log_out_label.custom_minimum_size = log_min_size

func _initialize_runtime() -> void:
	if _is_initialized:
		return
	if _player == null and _table == null and _customer == null and _day_manager == null:
		return
	_is_initialized = true

	if _player != null:
		_interaction_component = _player.get_node_or_null("InteractionComponent") as Area2D
	_setup_controls()
	_connect_signals()
	_append_log("除錯面板已就緒（互動=E，奔跑=Shift）")
	_refresh_text()

func _process(delta: float) -> void:
	_refresh_accumulator += delta
	if _refresh_accumulator < refresh_interval_sec:
		return
	_refresh_accumulator = 0.0
	_refresh_text()

func _connect_signals() -> void:
	if spawn_customer_button != null and not spawn_customer_button.pressed.is_connected(_on_spawn_customer_button_pressed):
		spawn_customer_button.pressed.connect(_on_spawn_customer_button_pressed)
	if edit_mode_button != null and not edit_mode_button.pressed.is_connected(_on_edit_mode_button_pressed):
		edit_mode_button.pressed.connect(_on_edit_mode_button_pressed)
	if save_button != null and not save_button.pressed.is_connected(_on_save_button_pressed):
		save_button.pressed.connect(_on_save_button_pressed)
	if load_button != null and not load_button.pressed.is_connected(_on_load_button_pressed):
		load_button.pressed.connect(_on_load_button_pressed)
	if day_speed_option_button != null and not day_speed_option_button.item_selected.is_connected(_on_day_speed_option_selected):
		day_speed_option_button.item_selected.connect(_on_day_speed_option_selected)

	if _interaction_component != null and not _interaction_component.interaction_requested.is_connected(_on_interaction_requested):
		_interaction_component.interaction_requested.connect(_on_interaction_requested)

	if _table == null:
		return

	if not _table.order_registered.is_connected(_on_order_registered):
		_table.order_registered.connect(_on_order_registered)
	if not _table.food_received.is_connected(_on_food_received):
		_table.food_received.connect(_on_food_received)
	if not _table.order_served.is_connected(_on_order_served):
		_table.order_served.connect(_on_order_served)
	if not _table.interaction_processed.is_connected(_on_interaction_processed):
		_table.interaction_processed.connect(_on_interaction_processed)


func _setup_controls() -> void:
	if day_speed_label != null:
		day_speed_label.text = "時間倍率"

	if day_speed_option_button == null:
		return
	if day_speed_option_button.item_count == 0:
		for multiplier in _day_speed_values:
			day_speed_option_button.add_item("%.0fx" % multiplier)

	update_day_speed(_get_current_day_speed())

func _refresh_text() -> void:
	if snapshot_label != null:
		snapshot_label.text = _build_player_customer_snapshot_text()
	if table_label != null:
		table_label.text = _build_table_snapshot_text()

func _build_player_customer_snapshot_text() -> String:
	var player_name: String = _safe_name(_player)
	var held_food_id: String = _get_player_food_id()
	var in_range: bool = _is_player_in_table_range()
	var customer_state: String = _get_customer_state_text()

	return "玩家=%s | 在桌邊範圍內=%s | 手持食物=%s\n顧客狀態=%s" % [
		player_name,
		"是" if in_range else "否",
		held_food_id,
		customer_state,
	]

func _build_table_snapshot_text() -> String:
	if _table == null:
		return "桌子：找不到節點"

	var pending: Array[String] = []
	for item in _table.expected_orders:
		var order: OrderData = item as OrderData
		if order == null or order.food == null:
			pending.append("?")
			continue
		var customer_name: String = _safe_name(order.customer)
		pending.append("%s:%s" % [customer_name, order.food.id])

	var on_table: Array[String] = []
	for item in _table.foods_on_table:
		var food: FoodData = item as FoodData
		on_table.append(food.id if food != null else "-")

	return "桌子.待處理訂單(%d)=[%s]\n桌子.桌上食物=[%s]\n營業時間倍率=%.1fx" % [
		pending.size(),
		", ".join(pending),
		", ".join(on_table),
		_get_current_day_speed(),
	]

func _get_player_food_id() -> String:
	if _player == null or not _player.has_method("get_held_food"):
		return "-"

	var food: FoodData = _player.call("get_held_food") as FoodData
	if food == null:
		return "（空）"
	return food.id

func _get_customer_state_text() -> String:
	if _customer == null:
		return "-"

	var sm: CustomerStateMachine = _customer.get("customer_state_machine") as CustomerStateMachine
	if sm == null:
		var node: Node = _customer.get_node_or_null("CustomerStateMachine")
		sm = node as CustomerStateMachine
	if sm == null:
		return "（沒有狀態機）"

	return sm.get_state_name()

func _is_player_in_table_range() -> bool:
	if _interaction_component == null or _table == null:
		return false

	for body in _interaction_component.get_overlapping_bodies():
		if body == _table:
			return true

	for area in _interaction_component.get_overlapping_areas():
		if area == null:
			continue
		if area == _table:
			return true
		if area.get_parent() == _table:
			return true

	return false

func _safe_name(node: Node) -> String:
	return String(node.name) if node != null else "空"

func _append_log(message: String) -> void:
	var stamp: String = Time.get_time_string_from_system()
	_log_entries.append("[%s] %s" % [stamp, message])
	while _log_entries.size() > max_log_entries:
		_log_entries.remove_at(0)
	_rebuild_log_text()

func _rebuild_log_text() -> void:
	if log_out_label == null:
		return
	log_out_label.clear()
	for line in _log_entries:
		log_out_label.append_text(line + "\n")

func append_debug_event(message: String) -> void:
	_append_log(message)

func set_tracked_customer(customer: Node) -> void:
	_customer = customer
	_refresh_text()

func update_day_speed(multiplier: float) -> void:
	if day_speed_option_button == null:
		return
	for i in range(_day_speed_values.size()):
		if is_equal_approx(_day_speed_values[i], multiplier):
			day_speed_option_button.select(i)
			return

func _on_interaction_requested(target: Node, interactor: Node) -> void:
	var is_table_target: bool = target == _table or (target != null and target.get_parent() == _table)
	if not is_table_target:
		return
	_append_log("%s 按下互動鍵 -> 桌子" % _safe_name(interactor))

func _on_order_registered(customer: Node, food_id: String) -> void:
	_append_log("訂單已建立：%s 想要 %s" % [_safe_name(customer), food_id])

func _on_food_received(food: FoodData) -> void:
	var food_id: String = food.id if food != null else "空"
	_append_log("桌上收到食物：%s" % food_id)

func _on_order_served(customer: Node, food: FoodData) -> void:
	var food_id: String = food.id if food != null else "空"
	_append_log("訂單已送達：%s <- %s（預期進入用餐）" % [_safe_name(customer), food_id])

func _on_interaction_processed(result: Dictionary) -> void:
	var actor: String = String(result.get("actor", "未知"))
	var ok: bool = result.get("success", false)
	var reason: String = String(result.get("reason", "未知"))
	var food_id: String = String(result.get("food_id", ""))
	var pending_orders: int = int(result.get("pending_orders", -1))
	var foods_on_table: Array = result.get("foods_on_table", [])
	var foods_on_table_text: String = str(foods_on_table)
	_append_log("%s 操作者=%s 食物=%s 原因=%s 待處理=%d 桌面=%s" % [
		"成功" if ok else "失敗",
		actor,
		food_id if not food_id.is_empty() else "-",
		reason,
		pending_orders,
		foods_on_table_text,
	])

func _on_spawn_customer_button_pressed() -> void:
	spawn_customer_requested.emit()

func _on_edit_mode_button_pressed() -> void:
	edit_mode_requested.emit()

func _on_save_button_pressed() -> void:
	save_requested.emit()

func _on_load_button_pressed() -> void:
	load_requested.emit()

func _on_day_speed_option_selected(index: int) -> void:
	if index < 0 or index >= _day_speed_values.size():
		return
	day_speed_selected.emit(_day_speed_values[index])

func _get_current_day_speed() -> float:
	if _day_manager != null and _day_manager.has_method("get_debug_day_speed_multiplier"):
		return float(_day_manager.call("get_debug_day_speed_multiplier"))
	return 1.0
