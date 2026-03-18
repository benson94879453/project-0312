extends Node

const TABLE_SCENE: PackedScene = preload("res://game/playground/table.tscn")
const CHAIR_SCENE: PackedScene = preload("res://game/playground/chair.tscn")

var _skip_initial_day_start: bool = true
var _current_day_plans: Array[CustomerDayPlan] = []
var _last_error_message: String = ""
var _bootstrap_complete: bool = false
var _bootstrap_attempts: int = 0

func _ready() -> void:
	call_deferred("_bootstrap_from_disk")

func should_skip_initial_day_start() -> bool:
	return _skip_initial_day_start and not _bootstrap_complete

func is_bootstrap_complete() -> bool:
	return _bootstrap_complete

func get_last_error_message() -> String:
	return _last_error_message

func get_current_day_plans() -> Array[CustomerDayPlan]:
	return _current_day_plans.duplicate()

func set_current_day_plans(day_plans: Array[CustomerDayPlan]) -> void:
	_current_day_plans = day_plans.duplicate()

## Clear current day plans (called when starting a fresh day)
func clear_day_plans() -> void:
	_current_day_plans.clear()

func get_runtime_registry() -> PlaceableRuntimeRegistry:
	return _find_registry()

func save_current_boundary() -> bool:
	var registry: PlaceableRuntimeRegistry = _find_registry()
	if registry == null:
		_last_error_message = "missing_placeable_registry"
		push_warning("[SaveManager] Missing placeable registry")
		return false

	var snapshot: DaySnapshot = _build_snapshot_from_runtime(registry)
	var payload: Dictionary = _snapshot_to_dictionary(snapshot)
	var json_text: String = JSON.stringify(payload, "\t")
	var file: FileAccess = FileAccess.open(SaveConstants.SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		_last_error_message = "save_open_failed"
		push_warning("[SaveManager] Failed to open save file for write")
		return false
	file.store_string(json_text)
	_last_error_message = ""
	print("[SaveManager] Saved snapshot to %s" % SaveConstants.SAVE_FILE_PATH)
	return true

func load_latest_snapshot() -> bool:
	if not FileAccess.file_exists(SaveConstants.SAVE_FILE_PATH):
		_last_error_message = "save_missing"
		return false

	var file: FileAccess = FileAccess.open(SaveConstants.SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		_last_error_message = "save_open_failed"
		return false

	var parse_result: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parse_result) != TYPE_DICTIONARY:
		_last_error_message = "save_parse_failed"
		push_warning("[SaveManager] Save parse failed")
		return false

	var snapshot: DaySnapshot = _dictionary_to_snapshot(parse_result as Dictionary)
	if snapshot.save_version < SaveConstants.MIN_COMPATIBLE_VERSION or snapshot.save_version > SaveConstants.SAVE_VERSION:
		_last_error_message = "save_version_incompatible"
		push_warning("[SaveManager] Save version incompatible: %d" % snapshot.save_version)
		return false

	var applied: bool = _apply_snapshot(snapshot)
	if applied:
		_last_error_message = ""
	return applied

func _bootstrap_from_disk() -> void:
	var registry: PlaceableRuntimeRegistry = _find_registry()
	if registry == null and _bootstrap_attempts < 10:
		_bootstrap_attempts += 1
		call_deferred("_bootstrap_from_disk")
		return

	var loaded: bool = load_latest_snapshot()
	if not loaded:
		if _last_error_message != "save_missing" and not _last_error_message.is_empty():
			push_warning("[SaveManager] Bootstrap load failed: %s" % _last_error_message)
		_prepare_default_pre_open_state()
	_skip_initial_day_start = false
	_bootstrap_complete = true

func _prepare_default_pre_open_state() -> void:
	if DayManager != null:
		DayManager.restore_pre_open_day(DayManager.current_day)
	if EconomyManager != null:
		EconomyManager.set_current_money(EconomyManager.current_money)

func _apply_snapshot(snapshot: DaySnapshot) -> bool:
	var registry: PlaceableRuntimeRegistry = _find_registry()
	if registry == null:
		_last_error_message = "missing_placeable_registry"
		return false

	_clear_runtime_customers()
	_clear_registered_placeables(registry)
	var loaded_placeables: Dictionary = {}
	for record in snapshot.placeable_records:
		var placeable: Node2D = _instantiate_placeable_from_record(record)
		if placeable == null:
			push_warning("[SaveManager] Skipped invalid placeable record: %s" % record.placeable_id)
			continue
		var target_position: Vector2 = registry.map_to_world(Vector2i(record.grid_x, record.grid_y))
		var result: Dictionary = registry.restore_placeable_state(placeable, target_position, record.rotation_step)
		if not result.get("ok", false):
			placeable.queue_free()
			push_warning("[SaveManager] Failed to restore placeable %s (%s)" % [record.placeable_id, String(result.get("reason", "unknown"))])
			continue
		loaded_placeables[record.placeable_id] = placeable

	registry.rebuild_registry()
	loaded_placeables.clear()
	for placeable in registry.get_registered_placeables():
		if placeable != null:
			loaded_placeables[String(placeable.get("placeable_id"))] = placeable
	for record in snapshot.placeable_records:
		if record.type_key != SaveConstants.TYPE_CHAIR or record.linked_placeable_id.is_empty():
			continue
		var chair: Chair = loaded_placeables.get(record.placeable_id, null) as Chair
		var table: Table = loaded_placeables.get(record.linked_placeable_id, null) as Table
		if chair != null and table != null:
			chair.bind_to_table(table)

	if DayManager != null:
		DayManager.restore_pre_open_day(snapshot.day_index)
	if EconomyManager != null:
		EconomyManager.reset_daily_stats()
		EconomyManager.set_current_money(snapshot.money)
	_current_day_plans = snapshot.customer_day_plans.duplicate()
	return true

func _clear_registered_placeables(registry: PlaceableRuntimeRegistry) -> void:
	for placeable in registry.get_registered_placeables():
		if placeable == null:
			continue
		var parent: Node = placeable.get_parent()
		if parent != null:
			parent.remove_child(placeable)
		placeable.free()
	registry.rebuild_registry()

func _clear_runtime_customers() -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return
	for customer in _collect_customers(current_scene):
		customer.queue_free()

func _collect_customers(root: Node) -> Array[Customer]:
	var customers: Array[Customer] = []
	for child in root.get_children():
		if child is Customer:
			customers.append(child as Customer)
		customers.append_array(_collect_customers(child))
	return customers

func _build_snapshot_from_runtime(registry: PlaceableRuntimeRegistry) -> DaySnapshot:
	var snapshot: DaySnapshot = DaySnapshot.new()
	snapshot.save_version = SaveConstants.SAVE_VERSION
	snapshot.day_index = DayManager.current_day if DayManager != null else 1
	snapshot.money = EconomyManager.current_money if EconomyManager != null else 0
	snapshot.timestamp_iso = Time.get_datetime_string_from_system(true, true)
	for placeable in registry.get_registered_placeables():
		var record: PlaceableRecord = _build_placeable_record(placeable, registry)
		if record != null:
			snapshot.placeable_records.append(record)
	for day_plan in _current_day_plans:
		snapshot.customer_day_plans.append(day_plan)
	return snapshot

func _build_placeable_record(placeable: Node2D, registry: PlaceableRuntimeRegistry) -> PlaceableRecord:
	if placeable == null:
		return null
	var record: PlaceableRecord = PlaceableRecord.new()
	record.placeable_id = String(placeable.get("placeable_id"))
	record.type_key = String(placeable.call("get_placeable_type_key"))
	record.resource_id = String(placeable.call("get_placeable_resource_id"))
	var cell: Vector2i = registry.world_to_map(placeable.global_position)
	record.grid_x = cell.x
	record.grid_y = cell.y
	record.rotation_step = int(placeable.call("get_placeable_rotation_step"))
	if placeable is Chair:
		var chair: Chair = placeable as Chair
		if chair.registered_table != null:
			record.linked_placeable_id = chair.registered_table.placeable_id
	return record

func _instantiate_placeable_from_record(record: PlaceableRecord) -> Node2D:
	var scene: PackedScene = null
	if record.type_key == SaveConstants.TYPE_TABLE:
		scene = TABLE_SCENE
	elif record.type_key == SaveConstants.TYPE_CHAIR:
		scene = CHAIR_SCENE
	if scene == null:
		return null

	var placeable: Node2D = scene.instantiate() as Node2D
	if placeable == null:
		return null
	if placeable.has_method("set_placeable_id"):
		placeable.call("set_placeable_id", record.placeable_id)
	if placeable.has_method("set_placeable_resource_id") and not placeable.call("set_placeable_resource_id", record.resource_id):
		placeable.queue_free()
		return null
	return placeable

func _snapshot_to_dictionary(snapshot: DaySnapshot) -> Dictionary:
	var payload: Dictionary = {
		"save_version": snapshot.save_version,
		"day_index": snapshot.day_index,
		"money": snapshot.money,
		"timestamp_iso": snapshot.timestamp_iso,
		"placeable_records": [],
		"customer_day_plans": [],
	}
	for record in snapshot.placeable_records:
		payload["placeable_records"].append(_placeable_record_to_dictionary(record))
	for day_plan in snapshot.customer_day_plans:
		payload["customer_day_plans"].append(_customer_plan_to_dictionary(day_plan))
	return payload

func _dictionary_to_snapshot(payload: Dictionary) -> DaySnapshot:
	var snapshot: DaySnapshot = DaySnapshot.new()
	snapshot.save_version = int(payload.get("save_version", 0))
	snapshot.day_index = int(payload.get("day_index", 1))
	snapshot.money = int(payload.get("money", 0))
	snapshot.timestamp_iso = String(payload.get("timestamp_iso", ""))
	for raw_record in payload.get("placeable_records", []):
		if typeof(raw_record) == TYPE_DICTIONARY:
			snapshot.placeable_records.append(_dictionary_to_placeable_record(raw_record as Dictionary))
	for raw_plan in payload.get("customer_day_plans", []):
		if typeof(raw_plan) == TYPE_DICTIONARY:
			snapshot.customer_day_plans.append(_dictionary_to_customer_plan(raw_plan as Dictionary))
	return snapshot

func _placeable_record_to_dictionary(record: PlaceableRecord) -> Dictionary:
	return {
		"placeable_id": record.placeable_id,
		"type_key": record.type_key,
		"resource_id": record.resource_id,
		"grid_x": record.grid_x,
		"grid_y": record.grid_y,
		"rotation_step": record.rotation_step,
		"linked_placeable_id": record.linked_placeable_id,
	}

func _dictionary_to_placeable_record(payload: Dictionary) -> PlaceableRecord:
	var record: PlaceableRecord = PlaceableRecord.new()
	record.placeable_id = String(payload.get("placeable_id", ""))
	record.type_key = String(payload.get("type_key", ""))
	record.resource_id = String(payload.get("resource_id", ""))
	record.grid_x = int(payload.get("grid_x", 0))
	record.grid_y = int(payload.get("grid_y", 0))
	record.rotation_step = int(payload.get("rotation_step", 0))
	record.linked_placeable_id = String(payload.get("linked_placeable_id", ""))
	return record

func _customer_plan_to_dictionary(day_plan: CustomerDayPlan) -> Dictionary:
	return {
		"customer_plan_id": day_plan.customer_plan_id,
		"arrival_time_seconds": day_plan.arrival_time_seconds,
		"order_pool": day_plan.order_pool,
		"patience_seconds": day_plan.patience_seconds,
		"preferred_table_id": day_plan.preferred_table_id,
		"status": day_plan.status,
		"attributes": day_plan.attributes,
	}

func _dictionary_to_customer_plan(payload: Dictionary) -> CustomerDayPlan:
	var day_plan: CustomerDayPlan = CustomerDayPlan.new()
	day_plan.customer_plan_id = String(payload.get("customer_plan_id", ""))
	day_plan.arrival_time_seconds = float(payload.get("arrival_time_seconds", 0.0))
	var order_pool: Array[String] = []
	for value in payload.get("order_pool", []):
		order_pool.append(String(value))
	day_plan.order_pool = order_pool
	day_plan.patience_seconds = float(payload.get("patience_seconds", 60.0))
	day_plan.preferred_table_id = String(payload.get("preferred_table_id", ""))
	day_plan.status = String(payload.get("status", SaveConstants.STATUS_PENDING))
	day_plan.attributes = payload.get("attributes", {}) as Dictionary
	return day_plan

func _find_registry() -> PlaceableRuntimeRegistry:
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return null
	return _find_registry_in_tree(current_scene)

func _find_registry_in_tree(root: Node) -> PlaceableRuntimeRegistry:
	if root is PlaceableRuntimeRegistry:
		return root as PlaceableRuntimeRegistry
	for child in root.get_children():
		var found: PlaceableRuntimeRegistry = _find_registry_in_tree(child)
		if found != null:
			return found
	return null
