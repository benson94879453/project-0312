extends Node
class_name CustomerTestDataCollector

## 真機測試資料收集器
## 收集 Customer 完整生命週期的運行時數據

const OUTPUT_FILE := "user://customer_test_results.json"

var _customer: Customer = null
var _table: Table = null
var _state_machine: CustomerStateMachine = null
var _movement_component: CustomerMovementComponent = null
var _visual_component: CustomerVisualComponent = null
var _sprite: Sprite2D = null

var _test_data: Dictionary = {
	"script_validation": {},
	"state_transitions": [],
	"visual_bob_moving": [],
	"visual_bob_eating": [],
	"final_verdict": {}
}

var _is_collecting: bool = false
var _test_complete: bool = false
var _frames_collected_moving: int = 0
var _frames_collected_eating: int = 0
var _has_reached_eating: bool = false
var _seat_position: Vector2 = Vector2.ZERO
var _seat_direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	print("[TestCollector] 測試資料收集器啟動")
	_call_deferred_setup()

func _call_deferred_setup() -> void:
	await get_tree().process_frame
	_find_test_subjects()
	_setup_state_tracking()
	_start_collection()

func _find_test_subjects() -> void:
	# 尋找場景中的 Customer 和 Table
	var root := get_tree().current_scene
	_customer = root.get_node_or_null("Customer") as Customer
	_table = root.get_node_or_null("NavigationRegion2D/Object/Table") as Table

	if _customer == null:
		push_error("[TestCollector] 找不到 Customer 節點")
		return

	_state_machine = _customer.customer_state_machine
	_movement_component = _customer.customer_movement_component
	_visual_component = _customer.customer_visual_component
	_sprite = _customer.get_node_or_null("Sprite2D") as Sprite2D

	print("[TestCollector] 測試對象已連結: Customer=", _customer != null, ", Table=", _table != null)

func _setup_state_tracking() -> void:
	if _state_machine == null:
		return
	if not _state_machine.state_changed.is_connected(_on_state_changed):
		_state_machine.state_changed.connect(_on_state_changed)

func _on_state_changed(prev: int, next: int) -> void:
	var state_name := _state_machine.get_state_name()
	var record := _create_state_record(state_name)
	_test_data["state_transitions"].append(record)
	print("[TestCollector] 狀態切換: ", _state_to_name(prev), " -> ", state_name)

	if state_name == "EATING":
		_has_reached_eating = true
		# 獲取座位資訊
		if _table != null:
			var seat_info := _table.get_reserved_seat_info(_customer)
			if seat_info.get("ok", false):
				_seat_position = seat_info.get("position", Vector2.ZERO)
				_seat_direction = seat_info.get("direction", Vector2.ZERO)

	# 自動上菜：當進入 WAITING_FOOD 時，自動提供咖啡
	if state_name == "WAITING_FOOD":
		_call_deferred_serve_food()

	if state_name == "IDLE" and _has_reached_eating:
		# 測試完成
		_call_deferred_complete()

func _call_deferred_serve_food() -> void:
	await get_tree().create_timer(0.5).timeout
	if _table != null and _customer != null:
		var food := ItemDatabase.get_item("coffee")
		if food != null:
			var result := _table.try_receive_food(food)
			print("[TestCollector] 自動上菜: coffee, 結果: ", result.get("ok", false))

func _call_deferred_complete() -> void:
	await get_tree().process_frame
	_complete_test()

func _start_collection() -> void:
	_is_collecting = true
	print("[TestCollector] 開始收集資料")

func _process(delta: float) -> void:
	if not _is_collecting or _customer == null:
		return

	var current_state := _state_machine.get_state_name() if _state_machine else "UNKNOWN"
	var is_moving := _movement_component != null and _movement_component.move_direction != Vector2.ZERO

	# 收集移動中視覺擺動資料 (20幀)
	if _frames_collected_moving < 20 and current_state == "MOVING_TO_SEAT":
		_test_data["visual_bob_moving"].append(_create_visual_record(is_moving))
		_frames_collected_moving += 1

	# 收集 EATING 靜止中視覺擺動資料 (20幀)
	if _frames_collected_eating < 20 and current_state == "EATING":
		_test_data["visual_bob_eating"].append(_create_visual_record(is_moving))
		_frames_collected_eating += 1

func _create_state_record(state_name: String) -> Dictionary:
	var record := {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"state": state_name,
		"customer_position": var_to_str(_customer.global_position),
		"customer_velocity": var_to_str(_customer.velocity),
	}

	if _movement_component != null:
		record["movement_velocity"] = var_to_str(_movement_component.current_velocity)
		record["movement_direction"] = var_to_str(_movement_component.move_direction)

	record["facing_direction"] = var_to_str(_customer.facing_direction)

	# 獲取座位資訊
	if _table != null:
		var seat_info := _table.get_reserved_seat_info(_customer)
		if seat_info.get("ok", false):
			record["seat_position"] = var_to_str(seat_info.get("position", Vector2.ZERO))
			record["seat_direction"] = var_to_str(seat_info.get("direction", Vector2.ZERO))

	return record

func _create_visual_record(is_moving: bool) -> Dictionary:
	var record := {
		"timestamp": Time.get_ticks_msec() / 1000.0,
		"is_moving": is_moving,
		"sprite_offset": var_to_str(_sprite.offset) if _sprite else "(0, 0)",
		"base_offset": var_to_str(_visual_component._base_offset) if _visual_component else "(0, 0)",
		"state": _state_machine.get_state_name() if _state_machine else "UNKNOWN"
	}
	return record

func _complete_test() -> void:
	if _test_complete:
		return
	_test_complete = true
	_is_collecting = false

	print("[TestCollector] 測試完成，產生報告...")
	_generate_final_verdict()
	_save_results()

func _generate_final_verdict() -> void:
	var verdict := {
		"test_timestamp": Time.get_datetime_string_from_system(),
		"checks": {}
	}

	# Check 1: EATING 時 velocity 是否為 ZERO
	var eating_velocity_zero := true
	var eating_records := []
	for record in _test_data["state_transitions"]:
		if record["state"] == "EATING":
			eating_records.append(record)
			var vel := str_to_var(record.get("customer_velocity", "(0, 0)"))
			if vel is Vector2 and vel != Vector2.ZERO:
				eating_velocity_zero = false

	verdict["checks"]["eating_velocity_zero"] = {
		"pass": eating_velocity_zero,
		"evidence": "EATING state records: " + str(eating_records.size()) + " entries"
	}

	# Check 2: 下單前後位置是否對齊 seat slot
	var position_aligned := true
	var position_error := 999.0
	for i in range(_test_data["state_transitions"].size()):
		var record := _test_data["state_transitions"][i]
		if record["state"] == "ORDERING" or record["state"] == "WAITING_FOOD":
			if record.has("seat_position"):
				var pos := str_to_var(record["customer_position"])
				var seat_pos := str_to_var(record["seat_position"])
				if pos is Vector2 and seat_pos is Vector2:
					position_error = pos.distance_to(seat_pos)
					if position_error > 0.5:
						position_aligned = false

	verdict["checks"]["position_aligned"] = {
		"pass": position_aligned,
		"position_error": position_error,
		"threshold": 0.5
	}

	# Check 3: 入座後 facing_direction 是否與 seat_direction 一致
	var direction_aligned := true
	var direction_diff := 999.0
	for record in _test_data["state_transitions"]:
		if record["state"] in ["ORDERING", "WAITING_FOOD", "EATING"]:
			if record.has("seat_direction"):
				var facing := str_to_var(record["facing_direction"])
				var seat_dir := str_to_var(record["seat_direction"])
				if facing is Vector2 and seat_dir is Vector2:
					# 計算角度差異
					direction_diff = abs(facing.angle_to(seat_dir))
					if direction_diff > 0.1:  # 允許約 5.7 度誤差
						direction_aligned = false

	verdict["checks"]["direction_aligned"] = {
		"pass": direction_aligned,
		"direction_diff_rad": direction_diff,
		"threshold_rad": 0.1
	}

	# Check 4: 靜止時 sprite.offset 是否回到 base_offset
	var bob_returned_to_base := true
	if _test_data["visual_bob_eating"].size() > 0:
		var last_record := _test_data["visual_bob_eating"][-1]
		var offset := str_to_var(last_record["sprite_offset"])
		var base := str_to_var(last_record["base_offset"])
		if offset is Vector2 and base is Vector2:
			var bob_error := offset.distance_to(base)
			if bob_error > 2.0:  # 允許 2 pixel 誤差
				bob_returned_to_base = false
			verdict["checks"]["bob_returned_to_base"] = {
				"pass": bob_returned_to_base,
				"final_offset_error": bob_error,
				"threshold": 2.0
			}

	# 整體結果
	var all_pass := eating_velocity_zero and position_aligned and direction_aligned and bob_returned_to_base
	verdict["overall_result"] = "PASS" if all_pass else "FAIL"

	_test_data["final_verdict"] = verdict

func _save_results() -> void:
	var file := FileAccess.open(OUTPUT_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_test_data, "\t"))
		file.close()
		print("[TestCollector] 結果已儲存至: ", OUTPUT_FILE)
		print("[TestCollector] 絕對路徑: ", ProjectSettings.globalize_path(OUTPUT_FILE))
	else:
		push_error("[TestCollector] 無法寫入結果檔案")

func _state_to_name(state_val: int) -> String:
	match state_val:
		0: return "IDLE"
		1: return "SEEKING_SEAT"
		2: return "MOVING_TO_SEAT"
		3: return "ORDERING"
		4: return "WAITING_FOOD"
		5: return "EATING"
		6: return "LEAVING"
		_: return "UNKNOWN"
