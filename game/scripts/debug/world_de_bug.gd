extends Node2D

@export var food_item_id: String = "coffee"
@export var customer_scene: PackedScene = preload("res://game/playground/customer.tscn")

var _target_node: Node = null
var _table: Table = null
var _tracked_customer: Node2D = null
var _leave_target: Node2D = null
var _spawn_parent: Node = null
var _spawn_executor: CustomerSpawnExecutor = null

func setup(target_node: Node, table: Table, tracked_customer: Node, leave_target: Node2D, spawn_parent: Node, spawn_executor: CustomerSpawnExecutor = null) -> void:
	_target_node = target_node
	_table = table
	_tracked_customer = tracked_customer as Node2D
	_leave_target = leave_target
	_spawn_parent = spawn_parent
	_spawn_executor = spawn_executor

func grant_food_to_target() -> Dictionary:
	if _target_node == null:
		push_warning("[WorldDeBug] 無法發送物品：目標節點為空")
		return {"ok": false, "message": "無法給予 coffee：目標節點為空"}

	var food: FoodData = ItemDatabase.get_item(food_item_id)
	if food == null:
		push_warning("[WorldDeBug] 無法發送物品：找不到 '%s'" % food_item_id)
		return {"ok": false, "message": "無法給予 coffee：找不到資源 %s" % food_item_id}

	if _target_node.has_method("set_held_food"):
		_target_node.call("set_held_food", food)
		print("[WorldDeBug] 已透過 set_held_food() 將 %s 發送給 %s" % [food_item_id, _target_node.name])
		return {"ok": true, "message": "已給玩家一杯 coffee"}

	if _has_property(_target_node, "held_food"):
		_target_node.set("held_food", food)
		print("[WorldDeBug] 已透過 held_food 屬性將 %s 發送給 %s" % [food_item_id, _target_node.name])
		return {"ok": true, "message": "已給玩家一杯 coffee"}

	push_warning("[WorldDeBug] 目標 %s 不支援 set_held_food() 或 held_food" % _target_node.name)
	return {"ok": false, "message": "目標不支援持有 food"}

func spawn_customer() -> Dictionary:
	if _spawn_executor == null:
		return {"ok": false, "message": "無法生成顧客：CustomerSpawnExecutor 不可用"}

	var result: Dictionary = _spawn_executor.spawn_next_pending_customer()
	if result.get("ok", false):
		_tracked_customer = result.get("customer", null) as Node2D
		if _tracked_customer != null:
			return {
				"ok": true,
				"message": "已依既有顧客計畫生成：%s" % _tracked_customer.name,
				"customer": _tracked_customer,
			}
	return result

func set_day_speed_multiplier(multiplier: float) -> Dictionary:
	if DayManager == null or not DayManager.has_method("set_debug_day_speed_multiplier"):
		return {"ok": false, "message": "無法設定時間倍率：DayManager 不可用", "multiplier": 1.0}

	DayManager.set_debug_day_speed_multiplier(multiplier)
	var applied_multiplier: float = DayManager.get_debug_day_speed_multiplier() if DayManager.has_method("get_debug_day_speed_multiplier") else multiplier
	return {
		"ok": true,
		"message": "已將營業時間倍率設為 %.1fx" % applied_multiplier,
		"multiplier": applied_multiplier,
	}

func _get_spawn_position() -> Vector2:
	if _tracked_customer != null and is_instance_valid(_tracked_customer):
		return _tracked_customer.global_position
	if _target_node is Node2D:
		return (_target_node as Node2D).global_position + Vector2(24.0, 0.0)
	if _leave_target != null:
		return _leave_target.global_position
	return global_position

func _has_property(node: Object, property_name: String) -> bool:
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return true
	return false
