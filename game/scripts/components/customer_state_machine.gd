extends Node
class_name CustomerStateMachine

signal state_changed(previous_state: int, next_state: int)
signal leaving_started

enum CustomerState {
	IDLE,
	SEEKING_SEAT,
	MOVING_TO_SEAT,
	ORDERING,
	WAITING_FOOD,
	EATING,
	LEAVING
}

@export var eating_duration_sec: float = 4.0

var state: int = CustomerState.IDLE
var assigned_table: Table = null
var current_order: OrderData = null
var move_target_global: Vector2 = Vector2.ZERO
var has_move_target: bool = false
var _eat_timer_sec: float = 0.0

func start_lifecycle(target_table: Table, seat_target: Vector2) -> bool:
	if target_table == null:
		push_warning("[CustomerStateMachine] Missing target table")
		return false

	reset_runtime()
	assigned_table = target_table
	_transition(CustomerState.SEEKING_SEAT)
	set_seat_target(seat_target)
	_transition(CustomerState.MOVING_TO_SEAT)
	return true

func set_seat_target(seat_target: Vector2) -> void:
	move_target_global = seat_target
	has_move_target = true

func on_reached_seat() -> bool:
	if state != CustomerState.MOVING_TO_SEAT:
		return false
	has_move_target = false
	_transition(CustomerState.ORDERING)
	return true

func on_order_registered(order: OrderData) -> bool:
	if order == null:
		return false
	current_order = order
	_transition(CustomerState.WAITING_FOOD)
	return true

func try_accept_served_food(food: FoodData) -> bool:
	if state != CustomerState.WAITING_FOOD:
		return false
	if current_order == null or current_order.food == null:
		return false
	if food == null or food.id != current_order.food.id:
		return false

	_eat_timer_sec = max(eating_duration_sec, 0.0)
	_transition(CustomerState.EATING)
	return true

func tick(delta: float) -> bool:
	if state != CustomerState.EATING:
		return false

	_eat_timer_sec -= delta
	if _eat_timer_sec <= 0.0:
		begin_leaving()
		return true
	return false

func begin_leaving() -> bool:
	if state == CustomerState.LEAVING:
		return false

	_eat_timer_sec = 0.0
	has_move_target = false
	_transition(CustomerState.LEAVING)
	leaving_started.emit()
	return true

func complete_lifecycle() -> void:
	reset_runtime()
	_transition(CustomerState.IDLE)

func reset_runtime() -> void:
	assigned_table = null
	current_order = null
	move_target_global = Vector2.ZERO
	has_move_target = false
	_eat_timer_sec = 0.0

func get_state_name() -> String:
	return _state_to_text(state)

func _transition(next_state: int) -> void:
	if state == next_state:
		return
	var previous_state: int = state
	state = next_state
	state_changed.emit(previous_state, state)
	print("[CustomerStateMachine] %s -> %s" % [_state_to_text(previous_state), _state_to_text(state)])

func _state_to_text(value: int) -> String:
	match value:
		CustomerState.IDLE:
			return "IDLE"
		CustomerState.SEEKING_SEAT:
			return "SEEKING_SEAT"
		CustomerState.MOVING_TO_SEAT:
			return "MOVING_TO_SEAT"
		CustomerState.ORDERING:
			return "ORDERING"
		CustomerState.WAITING_FOOD:
			return "WAITING_FOOD"
		CustomerState.EATING:
			return "EATING"
		CustomerState.LEAVING:
			return "LEAVING"
		_:
			return "UNKNOWN"
