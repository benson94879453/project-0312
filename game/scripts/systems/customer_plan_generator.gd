extends Node
class_name CustomerPlanGenerator

const DEFAULT_ORDER_POOL: Array[String] = ["coffee"]
const MIN_ARRIVAL_SPACING_SEC: float = 3.0

@export var base_customer_count: int = 8
@export var arrival_window_start_sec: float = 5.0
@export var arrival_window_end_sec: float = 150.0
@export var order_pool: Array[String] = DEFAULT_ORDER_POOL.duplicate()
@export var min_patience_sec: float = 45.0
@export var max_patience_sec: float = 90.0

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = _generate_seed_from_day(DayManager.current_day if DayManager != null else 1)

func generate_day_plans(day_index: int, registry: PlaceableRuntimeRegistry) -> Array[CustomerDayPlan]:
	_rng.seed = _generate_seed_from_day(day_index)

	if SaveManager != null:
		var existing_plans: Array[CustomerDayPlan] = SaveManager.get_current_day_plans()
		if _plans_match_day(existing_plans, day_index):
			print("[CustomerPlanGenerator] Reusing %d existing plans for day %d" % [existing_plans.size(), day_index])
			return existing_plans
		SaveManager.clear_day_plans()

	var seating_capacity: int = _calculate_seating_capacity(registry)
	var target_count: int = _determine_target_customer_count(seating_capacity)
	var plans: Array[CustomerDayPlan] = _generate_plans(day_index, target_count, registry)

	print("[CustomerPlanGenerator] Generated %d plans for day %d (capacity: %d)" % [plans.size(), day_index, seating_capacity])

	if SaveManager != null:
		SaveManager.set_current_day_plans(plans)

	return plans

func force_regenerate_plans(day_index: int, registry: PlaceableRuntimeRegistry) -> Array[CustomerDayPlan]:
	if SaveManager != null:
		SaveManager.clear_day_plans()
	_rng.seed = _generate_seed_from_day(day_index)
	return generate_day_plans(day_index, registry)

func _calculate_seating_capacity(registry: PlaceableRuntimeRegistry) -> int:
	if registry == null:
		return 0

	var total_seats: int = 0
	for placeable in registry.get_registered_placeables():
		if placeable is Table:
			var table: Table = placeable as Table
			total_seats += table.connected_chairs.size()
	return total_seats

func _determine_target_customer_count(seating_capacity: int) -> int:
	if seating_capacity <= 0:
		return 0
	if base_customer_count <= seating_capacity:
		return base_customer_count

	var max_with_turnover: int = maxi(int(ceil(float(seating_capacity) * 1.5)), seating_capacity)
	return mini(base_customer_count, max_with_turnover)

func _generate_plans(day_index: int, count: int, registry: PlaceableRuntimeRegistry) -> Array[CustomerDayPlan]:
	var plans: Array[CustomerDayPlan] = []
	var arrival_times: Array[float] = _distribute_arrival_times(count)
	var table_ids: Array[String] = _collect_table_ids(registry)

	for i in range(count):
		var plan: CustomerDayPlan = CustomerDayPlan.new()
		plan.customer_plan_id = _generate_plan_id(day_index, i)
		plan.arrival_time_seconds = arrival_times[i]
		plan.order_pool = order_pool.duplicate()
		plan.patience_seconds = _generate_patience()
		plan.preferred_table_id = table_ids[i % table_ids.size()] if not table_ids.is_empty() else ""
		plan.status = SaveConstants.STATUS_PENDING
		plan.attributes = _generate_attributes()
		plan.attributes["day_index"] = day_index
		plans.append(plan)

	return plans

func _distribute_arrival_times(count: int) -> Array[float]:
	var times: Array[float] = []
	if count <= 0:
		return times

	var available_window: float = maxf(arrival_window_end_sec - arrival_window_start_sec, MIN_ARRIVAL_SPACING_SEC)
	var spacing: float = maxf(available_window / maxi(count, 1), MIN_ARRIVAL_SPACING_SEC)

	for i in range(count):
		var base_time: float = arrival_window_start_sec + (i * spacing)
		var variance: float = _rng.randf_range(0.0, minf(2.0, spacing * 0.5))
		times.append(minf(base_time + variance, arrival_window_end_sec))

	return times

func _generate_seed_from_day(day_index: int) -> int:
	return max(day_index, 1) * 12345

func _generate_plan_id(day_index: int, index: int) -> String:
	return "customer_%s_%03d" % [str(max(day_index, 1)), index]

func _generate_patience() -> float:
	return _rng.randf_range(min_patience_sec, max_patience_sec)

func _generate_attributes() -> Dictionary:
	var attrs: Dictionary = {}
	if _rng.randf() < 0.1:
		attrs["vip"] = true
		attrs["tip_multiplier"] = 1.5
	if _rng.randf() < 0.15:
		attrs["rushed"] = true
	return attrs

func _plans_match_day(existing_plans: Array[CustomerDayPlan], day_index: int) -> bool:
	if existing_plans.is_empty():
		return false
	for plan in existing_plans:
		if int(plan.attributes.get("day_index", -1)) != day_index:
			return false
	return true

func _collect_table_ids(registry: PlaceableRuntimeRegistry) -> Array[String]:
	var table_ids: Array[String] = []
	if registry == null:
		return table_ids
	for placeable in registry.get_registered_placeables():
		if placeable is Table:
			table_ids.append(String(placeable.get("placeable_id")))
	return table_ids
