extends CanvasLayer
class_name ServiceDebugHud

@export var player_path: NodePath = NodePath("../Player")
@export var table_path: NodePath = NodePath("../Object/Table")
@export var customer_path: NodePath = NodePath("../Customer")
@export var max_log_entries: int = 16
@export var refresh_interval_sec: float = 0.15

var _player: Node = null
var _table: Table = null
var _customer: Node = null
var _interaction_component: Area2D = null

var _snapshot_label: Label = null
var _table_label: Label = null
var _log_label: RichTextLabel = null

var _log_entries: Array[String] = []
var _refresh_accumulator: float = 0.0

func _ready() -> void:
	_build_ui()
	_resolve_refs()
	_connect_signals()
	_append_log("Debug HUD ready (Interact=E, Run=Shift)")
	_refresh_text()

func _process(delta: float) -> void:
	_refresh_accumulator += delta
	if _refresh_accumulator < refresh_interval_sec:
		return
	_refresh_accumulator = 0.0
	_refresh_text()

func _build_ui() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.position = Vector2(10, 10)
	panel.custom_minimum_size = Vector2(560, 320)
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox: VBoxContainer = VBoxContainer.new()
	margin.add_child(vbox)

	var title: Label = Label.new()
	title.text = "[Service Flow Debug HUD]"
	vbox.add_child(title)

	_snapshot_label = Label.new()
	_snapshot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_snapshot_label)

	_table_label = Label.new()
	_table_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_table_label)

	var logs_title: Label = Label.new()
	logs_title.text = "Event Log"
	vbox.add_child(logs_title)

	_log_label = RichTextLabel.new()
	_log_label.custom_minimum_size = Vector2(520, 170)
	_log_label.scroll_following = true
	_log_label.bbcode_enabled = false
	vbox.add_child(_log_label)

func _resolve_refs() -> void:
	_player = get_node_or_null(player_path)
	_table = get_node_or_null(table_path) as Table
	_customer = get_node_or_null(customer_path)
	if _player != null:
		_interaction_component = _player.get_node_or_null("InteractionComponent") as Area2D

func _connect_signals() -> void:
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

func _refresh_text() -> void:
	_snapshot_label.text = _build_player_customer_snapshot_text()
	_table_label.text = _build_table_snapshot_text()

func _build_player_customer_snapshot_text() -> String:
	var player_name: String = _safe_name(_player)
	var held_food_id: String = _get_player_food_id()
	var in_range: bool = _is_player_in_table_range()
	var customer_state: String = _get_customer_state_text()

	return "Player=%s | InTableRange=%s | HeldFood=%s\nCustomerState=%s" % [
		player_name,
		"YES" if in_range else "NO",
		held_food_id,
		customer_state,
	]

func _build_table_snapshot_text() -> String:
	if _table == null:
		return "Table: (not found)"

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

	return "Table.PendingOrders(%d)=[%s]\nTable.FoodsOnTable=[%s]" % [
		pending.size(),
		", ".join(pending),
		", ".join(on_table),
	]

func _get_player_food_id() -> String:
	if _player == null or not _player.has_method("get_held_food"):
		return "-"

	var food: FoodData = _player.call("get_held_food") as FoodData
	if food == null:
		return "(empty)"
	return food.id

func _get_customer_state_text() -> String:
	if _customer == null:
		return "-"

	var sm: CustomerStateMachine = _customer.get("customer_state_machine") as CustomerStateMachine
	if sm == null:
		var node: Node = _customer.get_node_or_null("CustomerStateMachine")
		sm = node as CustomerStateMachine
	if sm == null:
		return "(no_state_machine)"

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
	return String(node.name) if node != null else "null"

func _append_log(message: String) -> void:
	var stamp: String = Time.get_time_string_from_system()
	_log_entries.append("[%s] %s" % [stamp, message])
	while _log_entries.size() > max_log_entries:
		_log_entries.remove_at(0)
	_rebuild_log_text()

func _rebuild_log_text() -> void:
	if _log_label == null:
		return
	_log_label.clear()
	for line in _log_entries:
		_log_label.append_text(line + "\n")

func _on_interaction_requested(target: Node, interactor: Node) -> void:
	var is_table_target: bool = target == _table or (target != null and target.get_parent() == _table)
	if not is_table_target:
		return
	_append_log("Interact pressed by %s -> Table" % _safe_name(interactor))

func _on_order_registered(customer: Node, food_id: String) -> void:
	_append_log("Order registered: %s wants %s" % [_safe_name(customer), food_id])

func _on_food_received(food: FoodData) -> void:
	var food_id: String = food.id if food != null else "null"
	_append_log("Food received on table: %s" % food_id)

func _on_order_served(customer: Node, food: FoodData) -> void:
	var food_id: String = food.id if food != null else "null"
	_append_log("Order served: %s <- %s (expect EATING)" % [_safe_name(customer), food_id])

func _on_interaction_processed(result: Dictionary) -> void:
	var actor: String = String(result.get("actor", "Unknown"))
	var ok: bool = result.get("success", false)
	var reason: String = String(result.get("reason", "unknown"))
	var food_id: String = String(result.get("food_id", ""))
	var pending_orders: int = int(result.get("pending_orders", -1))
	var foods_on_table: Array = result.get("foods_on_table", [])
	var foods_on_table_text: String = str(foods_on_table)
	_append_log("%s actor=%s food=%s reason=%s pending=%d table=%s" % [
		"SUCCESS" if ok else "FAIL",
		actor,
		food_id if not food_id.is_empty() else "-",
		reason,
		pending_orders,
		foods_on_table_text,
	])
