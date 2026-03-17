extends CharacterBody2D
class_name Customer

@export var preferred_food_ids: Array[String] = ["coffee"]
@export var auto_start_on_ready: bool = false
@export var target_table_path: NodePath
@export var leave_target_path: NodePath
@export var auto_start_retry_interval_sec: float = 0.25
@export var auto_start_max_attempts: int = 12
@export var navigation_agent: NavigationAgent2D
@export var customer_state_machine: CustomerStateMachine
@export var customer_movement_component: CustomerMovementComponent
@export var customer_visual_component: CustomerVisualComponent

var assigned_table: Table = null
var current_order: OrderData = null
var facing_direction: Vector2 = Vector2.DOWN

var _auto_start_table: Table = null
var _auto_start_attempts: int = 0
var _auto_start_retry_timer: Timer = null

func _ready() -> void:
	_setup_auto_start_retry_timer()

	if navigation_agent == null:
		navigation_agent = get_node_or_null("NavigationAgent2D") as NavigationAgent2D
	if customer_state_machine == null:
		customer_state_machine = _resolve_state_machine()
	if customer_movement_component == null:
		customer_movement_component = _resolve_movement_component()
	if customer_visual_component == null:
		customer_visual_component = _resolve_visual_component()

	if customer_movement_component != null:
		customer_movement_component.setup(navigation_agent)

	if customer_visual_component != null:
		var sprite: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
		customer_visual_component.configure(sprite, customer_movement_component)

	if customer_state_machine != null:
		customer_state_machine.setup(self)

	if not auto_start_on_ready:
		return

	var table: Table = get_node_or_null(target_table_path) as Table
	_begin_auto_start(table)

func _physics_process(delta: float) -> void:
	if customer_state_machine != null:
		customer_state_machine.tick(delta)

	if customer_movement_component == null:
		return

	velocity = customer_movement_component.get_velocity(global_position, delta)
	if customer_movement_component.move_direction != Vector2.ZERO:
		_set_facing_direction(customer_movement_component.move_direction)
	move_and_slide()

	if customer_movement_component.consume_target_reached() and customer_state_machine != null:
		customer_state_machine.on_move_target_reached()

func start_lifecycle(target_table: Table) -> bool:
	if target_table == null:
		push_warning("[Customer] Missing target table")
		return false
	if target_table.connected_chairs.is_empty():
		# Chair->Table registration may not be ready yet during early startup.
		return false

	assigned_table = target_table
	_connect_table_signals(assigned_table)

	if customer_state_machine != null:
		return customer_state_machine.start_lifecycle(target_table)

	var seat_result: Dictionary = target_table.try_seat_customer(self)
	if not seat_result.get("success", false):
		enter_leaving(String(seat_result.get("reason", "seat_unavailable")))
		return true

	enter_moving_to_seat(seat_result)
	return true

func enter_moving_to_seat(seat_info: Dictionary) -> void:
	if assigned_table != null:
		assigned_table.add_customer(self)

	var seat_position: Vector2 = _get_seat_position(seat_info)
	_set_facing_direction(_get_seat_direction(seat_info))

	if customer_movement_component != null:
		customer_movement_component.set_target(seat_position)
	elif customer_state_machine != null:
		customer_state_machine.on_move_target_reached()

func enter_waiting_food(seat_info: Dictionary) -> OrderData:
	z_index = 1
	_stop_movement_immediately()
	_snap_to_seat_slot(seat_info)
	return _create_and_submit_order()

func prepare_for_leaving() -> void:
	if assigned_table == null:
		return
	assigned_table.clear_food_for_customer(self)
	assigned_table.release_seat(self)

func enter_leaving(reason: String = "") -> void:
	z_index = 0
	if customer_movement_component == null:
		finish_lifecycle_and_despawn()
		return

	var leave_target: Node2D = get_node_or_null(leave_target_path) as Node2D
	if leave_target == null:
		finish_lifecycle_and_despawn()
		return

	if not reason.is_empty():
		print("[Customer] Start leaving: %s" % reason)
	customer_movement_component.set_target(leave_target.global_position)

func finish_lifecycle_and_despawn() -> void:
	if assigned_table != null:
		assigned_table.remove_customer(self)
		_disconnect_table_signals(assigned_table)

	assigned_table = null
	current_order = null
	_stop_movement_immediately()
	queue_free()

func _setup_auto_start_retry_timer() -> void:
	if _auto_start_retry_timer != null:
		return

	_auto_start_retry_timer = Timer.new()
	_auto_start_retry_timer.one_shot = true
	add_child(_auto_start_retry_timer)
	_auto_start_retry_timer.timeout.connect(_on_auto_start_retry_timeout)

func _begin_auto_start(target_table: Table) -> void:
	_auto_start_table = target_table
	_auto_start_attempts = 0
	_try_auto_start_once()

func _try_auto_start_once() -> void:
	if _auto_start_table == null:
		push_warning("[Customer] Auto start failed: target table path is empty/invalid")
		return

	_auto_start_attempts += 1
	if start_lifecycle(_auto_start_table):
		if _auto_start_attempts > 1:
			print("[Customer] Auto start succeeded after %d attempts" % _auto_start_attempts)
		return

	var max_attempts: int = max(auto_start_max_attempts, 1)
	if _auto_start_attempts >= max_attempts:
		push_warning("[Customer] Auto start failed after %d attempts (no available seat yet)" % max_attempts)
		return

	var retry_delay: float = max(auto_start_retry_interval_sec, 0.05)
	_auto_start_retry_timer.start(retry_delay)

func _on_auto_start_retry_timeout() -> void:
	_try_auto_start_once()

func _create_and_submit_order() -> OrderData:
	if assigned_table == null:
		return null

	var food_to_order: FoodData = _pick_food_from_database()
	if food_to_order == null:
		push_warning("[Customer] Failed to pick food")
		return null

	var new_order: OrderData = OrderData.new()
	new_order.customer = self
	new_order.food = food_to_order

	if not assigned_table.register_order(new_order):
		push_warning("[Customer] Failed to register order")
		return null

	current_order = new_order
	return new_order

func _pick_food_from_database() -> FoodData:
	for food_id in preferred_food_ids:
		var item: FoodData = ItemDatabase.get_item(food_id)
		if item != null:
			return item
	return null

func _on_order_served(customer: Node, food: FoodData) -> void:
	if customer != self:
		return
	if customer_state_machine == null:
		return
	customer_state_machine.try_accept_served_food(food)

func _stop_movement_immediately() -> void:
	velocity = Vector2.ZERO
	if customer_movement_component != null:
		customer_movement_component.stop_movement_immediately(global_position)

func _snap_to_seat_slot(seat_info: Dictionary = {}) -> void:
	global_position = _get_seat_position(seat_info)
	_set_facing_direction(_get_seat_direction(seat_info))
	_stop_movement_immediately()

func _get_seat_position(seat_info: Dictionary) -> Vector2:
	if seat_info.has("position"):
		return seat_info["position"] as Vector2
	if assigned_table != null:
		var reserved: Dictionary = assigned_table.get_reserved_seat_info(self)
		if reserved.get("ok", false) and reserved.has("position"):
			return reserved["position"] as Vector2
		return assigned_table.global_position
	return global_position

func _get_seat_direction(seat_info: Dictionary) -> Vector2:
	if seat_info.has("direction"):
		return seat_info["direction"] as Vector2
	if assigned_table != null:
		var reserved: Dictionary = assigned_table.get_reserved_seat_info(self)
		if reserved.get("ok", false) and reserved.has("direction"):
			return reserved["direction"] as Vector2
	return Vector2.DOWN

func _set_facing_direction(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	facing_direction = direction.normalized()

func _connect_table_signals(table: Table) -> void:
	if table == null:
		return
	if not table.order_served.is_connected(_on_order_served):
		table.order_served.connect(_on_order_served)

func _disconnect_table_signals(table: Table) -> void:
	if table == null:
		return
	if table.order_served.is_connected(_on_order_served):
		table.order_served.disconnect(_on_order_served)

func _resolve_state_machine() -> CustomerStateMachine:
	var node: Node = get_node_or_null("CustomerStateMachine")
	if node == null:
		node = get_node_or_null("StateMachine")
	return node as CustomerStateMachine

func _resolve_movement_component() -> CustomerMovementComponent:
	var node: Node = get_node_or_null("CustomerMovementComponent")
	if node == null:
		node = get_node_or_null("MovementComponent")
	return node as CustomerMovementComponent

func _resolve_visual_component() -> CustomerVisualComponent:
	var node: Node = get_node_or_null("CustomerVisualComponent")
	if node == null:
		node = get_node_or_null("VisualComponent")
	return node as CustomerVisualComponent
