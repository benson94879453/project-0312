extends Node
class_name CustomerSpawnExecutor

const CUSTOMER_SCENE: PackedScene = preload("res://game/playground/customer.tscn")

@export var registry_path: NodePath
@export var spawn_parent_path: NodePath
@export var default_table_path: NodePath

var _day_plans: Array[CustomerDayPlan] = []
var _active_customers: Dictionary = {}
var _served_plan_ids: Dictionary = {}
var _registry: PlaceableRuntimeRegistry = null
var _spawn_parent: Node = null
var _is_executing: bool = false
var _day_time_accumulator: float = 0.0
var _plan_generator: CustomerPlanGenerator = null

func _ready() -> void:
	_resolve_references()
	_connect_signals()

func _process(delta: float) -> void:
	if not _is_executing:
		return
	_day_time_accumulator += delta * _get_day_speed_multiplier()
	_check_and_spawn_pending_customers()

func start_day_execution(day_index: int) -> void:
	print("[CustomerSpawnExecutor] Starting day %d execution" % day_index)
	_day_time_accumulator = 0.0
	_is_executing = true
	_active_customers.clear()
	_served_plan_ids.clear()
	_clear_runtime_customers()

	if _plan_generator == null:
		_plan_generator = CustomerPlanGenerator.new()
		add_child(_plan_generator)

	_day_plans = _plan_generator.generate_day_plans(day_index, _registry)
	if _day_plans.is_empty():
		push_warning("[CustomerSpawnExecutor] No plans generated for day %d" % day_index)
		if SaveManager != null:
			SaveManager.clear_day_plans()
			SaveManager.save_current_boundary()
		return

	print("[CustomerSpawnExecutor] Loaded %d plans for execution" % _day_plans.size())

func stop_execution() -> void:
	print("[CustomerSpawnExecutor] Stopping execution")
	_is_executing = false

func settle_for_day_close() -> void:
	_is_executing = false
	for plan in _day_plans:
		if plan.status == SaveConstants.STATUS_PENDING or plan.status == SaveConstants.STATUS_ACTIVE:
			plan.status = SaveConstants.STATUS_LOST
	_active_customers.clear()
	_served_plan_ids.clear()
	_clear_runtime_customers()
	_persist_plan_statuses()

func get_execution_stats() -> Dictionary:
	var pending: int = 0
	var active: int = 0
	var completed: int = 0
	var lost: int = 0
	for plan in _day_plans:
		match plan.status:
			SaveConstants.STATUS_PENDING:
				pending += 1
			SaveConstants.STATUS_ACTIVE:
				active += 1
			SaveConstants.STATUS_COMPLETED:
				completed += 1
			SaveConstants.STATUS_LOST:
				lost += 1
	return {
		"pending": pending,
		"active": active,
		"completed": completed,
		"lost": lost,
		"total": _day_plans.size(),
	}

func force_spawn_customer(plan_index: int) -> Dictionary:
	if plan_index < 0 or plan_index >= _day_plans.size():
		return {"ok": false, "message": "Invalid plan index"}
	return _spawn_customer_from_plan(_day_plans[plan_index])

func _resolve_references() -> void:
	if not registry_path.is_empty():
		_registry = get_node_or_null(registry_path) as PlaceableRuntimeRegistry
	if not spawn_parent_path.is_empty():
		_spawn_parent = get_node_or_null(spawn_parent_path)
	if _spawn_parent == null:
		_spawn_parent = get_tree().current_scene

func _connect_signals() -> void:
	if SignalManager != null:
		if not SignalManager.day_started.is_connected(_on_day_started):
			SignalManager.day_started.connect(_on_day_started)
		if not SignalManager.day_ended.is_connected(_on_day_ended):
			SignalManager.day_ended.connect(_on_day_ended)

func _on_day_started(day_count: int) -> void:
	start_day_execution(day_count)

func _on_day_ended() -> void:
	stop_execution()

func _check_and_spawn_pending_customers() -> void:
	for plan in _day_plans:
		if plan.status != SaveConstants.STATUS_PENDING:
			continue
		if _day_time_accumulator >= plan.arrival_time_seconds:
			_spawn_customer_from_plan(plan)

func _spawn_customer_from_plan(plan: CustomerDayPlan) -> Dictionary:
	if plan.status != SaveConstants.STATUS_PENDING:
		return {"ok": false, "message": "Plan already processed"}
	if CUSTOMER_SCENE == null:
		plan.status = SaveConstants.STATUS_LOST
		return {"ok": false, "message": "Customer scene not loaded"}
	if _spawn_parent == null:
		plan.status = SaveConstants.STATUS_LOST
		return {"ok": false, "message": "Spawn parent not available"}

	var target_table: Table = _resolve_target_table(plan)
	if target_table == null:
		plan.status = SaveConstants.STATUS_LOST
		_persist_plan_statuses()
		return {"ok": false, "message": "No available table"}
	if target_table.get_free_seat_count() <= 0:
		target_table = _find_any_available_table()
		if target_table == null:
			plan.status = SaveConstants.STATUS_LOST
			_persist_plan_statuses()
			return {"ok": false, "message": "No free seats available"}

	var spawn_position: Vector2 = _get_spawn_position()
	var leave_target: Node2D = _get_leave_target()
	if leave_target == null:
		plan.status = SaveConstants.STATUS_LOST
		_persist_plan_statuses()
		return {"ok": false, "message": "Leave target not available"}

	var instance: Node = CUSTOMER_SCENE.instantiate()
	var customer: Customer = instance as Customer
	if customer == null:
		if instance != null:
			instance.queue_free()
		plan.status = SaveConstants.STATUS_LOST
		_persist_plan_statuses()
		return {"ok": false, "message": "Failed to instantiate customer"}

	customer.auto_start_on_ready = false
	if not plan.order_pool.is_empty():
		customer.preferred_food_ids = plan.order_pool.duplicate()

	_spawn_parent.add_child(customer)
	customer.global_position = spawn_position
	customer.target_table_path = customer.get_path_to(target_table)
	customer.leave_target_path = customer.get_path_to(leave_target)
	if customer.customer_state_machine != null:
		customer.customer_state_machine.max_patience_sec = plan.patience_seconds

	if not customer.start_lifecycle(target_table):
		customer.queue_free()
		plan.status = SaveConstants.STATUS_LOST
		_persist_plan_statuses()
		return {"ok": false, "message": "Failed to start customer lifecycle"}

	plan.status = SaveConstants.STATUS_ACTIVE
	_active_customers[plan.customer_plan_id] = customer
	_connect_customer_signals(customer, plan)
	_persist_plan_statuses()

	print("[CustomerSpawnExecutor] Spawned customer %s at time %.1f" % [plan.customer_plan_id, _day_time_accumulator])
	return {
		"ok": true,
		"message": "Customer spawned",
		"customer": customer,
		"plan_id": plan.customer_plan_id,
	}

func _resolve_target_table(plan: CustomerDayPlan) -> Table:
	if not plan.preferred_table_id.is_empty() and _registry != null:
		var preferred: Node2D = _registry.get_placeable(plan.preferred_table_id)
		if preferred is Table:
			var table: Table = preferred as Table
			if table.get_free_seat_count() > 0:
				return table
	return _find_any_available_table()

func _find_any_available_table() -> Table:
	if _registry == null:
		return _find_table_in_scene()

	var best_table: Table = null
	var best_free_seats: int = 0
	for placeable in _registry.get_registered_placeables():
		if placeable is Table:
			var table: Table = placeable as Table
			var free_seats: int = table.get_free_seat_count()
			if free_seats > best_free_seats:
				best_free_seats = free_seats
				best_table = table
	return best_table

func _find_table_in_scene() -> Table:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return null
	if not default_table_path.is_empty():
		var table: Table = current_scene.get_node_or_null(default_table_path) as Table
		if table != null:
			return table
	return _find_first_table_recursive(current_scene)

func _find_first_table_recursive(root: Node) -> Table:
	for child in root.get_children():
		if child is Table:
			return child as Table
		var found: Table = _find_first_table_recursive(child)
		if found != null:
			return found
	return null

func _get_spawn_position() -> Vector2:
	if _registry != null:
		var entry_anchor: Node2D = _registry.get_entry_anchor()
		if entry_anchor != null:
			return entry_anchor.global_position
	var player: Node = get_tree().get_first_node_in_group("player")
	if player is Node2D:
		return (player as Node2D).global_position + Vector2(100, 0)
	return Vector2.ZERO

func _get_leave_target() -> Node2D:
	if _registry != null:
		var leave_anchor: Node2D = _registry.get_leave_anchor()
		if leave_anchor != null:
			return leave_anchor
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return null
	var leave: Node2D = current_scene.get_node_or_null("LeavePosition") as Node2D
	if leave != null:
		return leave
	return current_scene.get_node_or_null("ExitPosition") as Node2D

func _connect_customer_signals(customer: Customer, plan: CustomerDayPlan) -> void:
	if customer.customer_state_machine == null:
		return
	var on_state_changed: Callable = func(_previous_state: int, next_state: int) -> void:
		_on_customer_state_changed(plan, next_state)
	customer.customer_state_machine.state_changed.connect(on_state_changed)

func _on_customer_state_changed(plan: CustomerDayPlan, new_state: int) -> void:
	match new_state:
		CustomerStateMachine.CustomerState.EATING:
			_served_plan_ids[plan.customer_plan_id] = true
		CustomerStateMachine.CustomerState.LEAVING:
			if plan.status == SaveConstants.STATUS_ACTIVE:
				if _served_plan_ids.get(plan.customer_plan_id, false):
					plan.status = SaveConstants.STATUS_COMPLETED
					print("[CustomerSpawnExecutor] Plan %s completed" % plan.customer_plan_id)
				else:
					plan.status = SaveConstants.STATUS_LOST
					print("[CustomerSpawnExecutor] Plan %s lost" % plan.customer_plan_id)
				_active_customers.erase(plan.customer_plan_id)
				_persist_plan_statuses()

func _persist_plan_statuses() -> void:
	if SaveManager != null:
		SaveManager.set_current_day_plans(_day_plans)

func _clear_runtime_customers() -> void:
	if _spawn_parent == null:
		return
	for child in _spawn_parent.get_children():
		if child is Customer:
			child.queue_free()

func _get_day_speed_multiplier() -> float:
	if DayManager != null:
		return DayManager.get_debug_day_speed_multiplier()
	return 1.0
