extends CharacterBody2D
class_name Customer

@export var preferred_food_ids: Array[String] = ["coffee"]
@export var auto_start_on_ready: bool = false
@export var target_table_path: NodePath
@export var leave_target_path: NodePath
@export var seat_target_random_offset: float = 12.0
@export var auto_start_retry_interval_sec: float = 0.25
@export var auto_start_max_attempts: int = 12

@export var navigation_agent: NavigationAgent2D
@export var customer_state_machine: CustomerStateMachine
@export var customer_movement_component: CustomerMovementComponent
@export var customer_visual_component: CustomerVisualComponent

var assigned_table: Table = null
var current_order: OrderData = null
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

	if customer_state_machine != null and not customer_state_machine.leaving_started.is_connected(_on_leaving_started):
		customer_state_machine.leaving_started.connect(_on_leaving_started)

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
	move_and_slide()

	if customer_movement_component.consume_target_reached():
		_on_reached_move_target()

func start_lifecycle(target_table: Table) -> bool:
	if target_table == null:
		push_warning("[Customer] Missing target table")
		return false

	if not target_table.reserve_seat(self):
		return false

	assigned_table = target_table
	assigned_table.add_customer(self)
	if not assigned_table.order_served.is_connected(_on_order_served):
		assigned_table.order_served.connect(_on_order_served)

	var seat_target: Vector2 = _compute_seat_target(assigned_table)
	if customer_state_machine != null:
		customer_state_machine.start_lifecycle(assigned_table, seat_target)

	if customer_movement_component != null:
		customer_movement_component.set_target(seat_target)
	else:
		_on_reached_move_target()
	return true

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

	# Chairs register their seats a little later (after physics frames),
	# so retry briefly instead of failing permanently in _ready().
	var retry_delay: float = max(auto_start_retry_interval_sec, 0.05)
	_auto_start_retry_timer.start(retry_delay)

func _on_auto_start_retry_timeout() -> void:
	_try_auto_start_once()

func _create_and_submit_order() -> void:
	if assigned_table == null:
		return

	var food_to_order: FoodData = _pick_food_from_database()
	if food_to_order == null:
		push_warning("[Customer] Failed to pick food")
		_begin_leaving()
		return

	current_order = OrderData.new()
	current_order.customer = self
	current_order.food = food_to_order

	if not assigned_table.register_order(current_order):
		push_warning("[Customer] Failed to register order")
		_begin_leaving()
		return

	if customer_state_machine != null:
		customer_state_machine.on_order_registered(current_order)

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

func _begin_leaving() -> void:
	if customer_state_machine != null:
		customer_state_machine.begin_leaving()
	else:
		_finish_leaving()

func _finish_leaving() -> void:
	if assigned_table != null:
		assigned_table.release_seat(self)
		assigned_table.remove_customer(self)
		if assigned_table.order_served.is_connected(_on_order_served):
			assigned_table.order_served.disconnect(_on_order_served)

	assigned_table = null
	current_order = null

	if customer_state_machine != null:
		customer_state_machine.complete_lifecycle()

	velocity = Vector2.ZERO
	if customer_movement_component != null:
		customer_movement_component.clear_target()

func _on_reached_move_target() -> void:
	if customer_state_machine == null:
		_create_and_submit_order()
		return

	match customer_state_machine.state:
		CustomerStateMachine.CustomerState.MOVING_TO_SEAT:
			if customer_state_machine.on_reached_seat():
				_create_and_submit_order()
		CustomerStateMachine.CustomerState.LEAVING:
			_finish_leaving()

func _on_leaving_started() -> void:
	var leave_target: Node2D = get_node_or_null(leave_target_path) as Node2D
	if leave_target == null:
		_finish_leaving()
		return

	if customer_movement_component == null:
		_finish_leaving()
		return

	customer_movement_component.set_target(leave_target.global_position)

func _compute_seat_target(target_table: Table) -> Vector2:
	if target_table == null:
		return global_position
	if seat_target_random_offset <= 0.0:
		return target_table.global_position

	var jitter := Vector2(
		randf_range(-seat_target_random_offset, seat_target_random_offset),
		randf_range(-seat_target_random_offset * 0.35, seat_target_random_offset * 0.35)
	)
	return target_table.global_position + jitter

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
