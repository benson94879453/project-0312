extends Node
class_name CustomerStateMachine

signal state_changed(previous_state: int, next_state: int)

enum CustomerState {
	IDLE,
	MOVING_TO_SEAT,
	WAITING_FOOD,
	EATING,
	LEAVING
}

@export var eating_duration_sec: float = 4.0
@export var max_patience_sec: float = 30.0  # 最大耐心值（秒）

var state: int = CustomerState.IDLE
var customer: Customer = null
var assigned_table: Table = null
var current_order: OrderData = null
var seat_info: Dictionary = {}
var failure_reason: String = ""

# 耐心系統
var current_patience: float = 0.0  # 當前耐心值
var _patience_depleted: bool = false  # 標記是否已因耐心歸零離開

# 小費計算
var _tips_multiplier: float = 0.0  # 耐心比例（用於小費計算）

var _eating_timer: Timer = null

func _ready() -> void:
	_ensure_eating_timer()

func setup(owner_customer: Customer) -> void:
	customer = owner_customer
	_ensure_eating_timer()

func start_lifecycle(target_table: Table) -> bool:
	if target_table == null:
		push_warning("[CustomerStateMachine] Missing target table")
		return false
	if customer == null:
		push_warning("[CustomerStateMachine] Missing customer owner")
		return false

	reset_runtime()
	assigned_table = target_table
	seat_info = assigned_table.try_seat_customer(customer)
	if seat_info.get("success", false):
		_transition(CustomerState.MOVING_TO_SEAT)
	else:
		failure_reason = String(seat_info.get("reason", "seat_unavailable"))
		_transition(CustomerState.LEAVING)
	return true

func tick(delta: float) -> void:
	# WAITING_FOOD 狀態時衰減耐心
	if state == CustomerState.WAITING_FOOD:
		_update_patience(delta)

func on_move_target_reached() -> void:
	match state:
		CustomerState.MOVING_TO_SEAT:
			_transition(CustomerState.WAITING_FOOD)
		CustomerState.LEAVING:
			if customer != null:
				customer.finish_lifecycle_and_despawn()

func try_accept_served_food(food: FoodData) -> bool:
	if state != CustomerState.WAITING_FOOD:
		return false
	if current_order == null or current_order.food == null:
		return false
	if food == null or food.id != current_order.food.id:
		return false

	_transition(CustomerState.EATING)
	return true

func begin_leaving(reason: String = "manual_leave") -> void:
	if state == CustomerState.LEAVING:
		return
	failure_reason = reason
	_transition(CustomerState.LEAVING)

func reset_runtime() -> void:
	assigned_table = null
	current_order = null
	seat_info = {}
	failure_reason = ""
	current_patience = 0.0
	_patience_depleted = false
	_tips_multiplier = 0.0
	if _eating_timer != null:
		_eating_timer.stop()

func get_state_name() -> String:
	return _state_to_text(state)

func _ensure_eating_timer() -> void:
	if _eating_timer != null:
		return
	_eating_timer = Timer.new()
	_eating_timer.one_shot = true
	add_child(_eating_timer)
	_eating_timer.timeout.connect(_on_eating_timer_timeout)

func _transition(next_state: int) -> void:
	if state == next_state:
		return
	var previous_state: int = state
	state = next_state
	state_changed.emit(previous_state, state)
	print("[CustomerStateMachine] %s -> %s" % [_state_to_text(previous_state), _state_to_text(state)])
	_enter_state(state)

func _enter_state(next_state: int) -> void:
	if customer == null:
		return

	match next_state:
		CustomerState.MOVING_TO_SEAT:
			customer.enter_moving_to_seat(seat_info)
		CustomerState.WAITING_FOOD:
			_initialize_patience()  # 初始化耐心值
			var order: OrderData = customer.enter_waiting_food(seat_info)
			if order == null:
				failure_reason = "order_failed"
				_transition(CustomerState.LEAVING)
				return
			current_order = order
		CustomerState.EATING:
			_freeze_patience_and_calc_tips()  # 凍結耐心並計算小費
			var duration: float = max(eating_duration_sec, 0.0)
			if duration <= 0.0:
				_on_eating_timer_timeout()
				return
			_eating_timer.start(duration)
		CustomerState.LEAVING:
			if failure_reason == "patience_depleted" and assigned_table != null:
				assigned_table.cancel_order_for_customer(customer)
				current_order = null
				customer.current_order = null
			customer.prepare_for_leaving()
			customer.enter_leaving(failure_reason)

func _on_eating_timer_timeout() -> void:
	if state != CustomerState.EATING:
		return
	# 用餐結束，處理付款
	_process_payment()
	_transition(CustomerState.LEAVING)

func _state_to_text(value: int) -> String:
	match value:
		CustomerState.IDLE:
			return "IDLE"
		CustomerState.MOVING_TO_SEAT:
			return "MOVING_TO_SEAT"
		CustomerState.WAITING_FOOD:
			return "WAITING_FOOD"
		CustomerState.EATING:
			return "EATING"
		CustomerState.LEAVING:
			return "LEAVING"
		_:
			return "UNKNOWN"

# ============================================
# 耐心與付款系統 (Task 4)
# ============================================

## 更新耐心值（在 WAITING_FOOD 狀態時每幀呼叫）
func _update_patience(delta: float) -> void:
	current_patience -= delta

	# 檢查耐心是否歸零
	if current_patience <= 0.0 and not _patience_depleted:
		_patience_depleted = true
		print("[CustomerStateMachine] 耐心歸零，顧客憤怒離開")
		SignalManager.customer_lost.emit()
		begin_leaving("patience_depleted")

## 進入 WAITING_FOOD 時初始化耐心
func _initialize_patience() -> void:
	current_patience = max_patience_sec
	_patience_depleted = false
	_tips_multiplier = 1.0

## 收到餐點時凍結耐心並計算小費乘數
func _freeze_patience_and_calc_tips() -> void:
	# 計算小費乘數（剩餘耐心比例）
	_tips_multiplier = clampf(current_patience / max_patience_sec, 0.0, 1.0)
	print("[CustomerStateMachine] 收到餐點，小費乘數: %.2f" % _tips_multiplier)

## 處理付款（在 EATING 結束時呼叫）
func _process_payment() -> void:
	if current_order == null or current_order.food == null:
		return

	var base_price: int = current_order.food.price
	var tips: int = int(base_price * _tips_multiplier * 0.2)  # 小費最高 20%

	print("[CustomerStateMachine] 付款: $%d (餐點: $%d, 小費: $%d)" % [
		base_price + tips, base_price, tips
	])

	SignalManager.customer_paid.emit(base_price, tips)
