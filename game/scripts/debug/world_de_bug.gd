extends Node2D

@export var test_action: StringName = &"test_add_coffee"
@export var food_item_id: String = "coffee"
@export var customer_scene: PackedScene = preload("res://game/playground/customer.tscn")

var _target_node: Node = null
var _table: Table = null
var _tracked_customer: Node2D = null
var _leave_target: Node2D = null
var _spawn_parent: Node = null

func setup(target_node: Node, table: Table, tracked_customer: Node, leave_target: Node2D, spawn_parent: Node) -> void:
	_target_node = target_node
	_table = table
	_tracked_customer = tracked_customer as Node2D
	_leave_target = leave_target
	_spawn_parent = spawn_parent

func _ready() -> void:
	if not InputMap.has_action(test_action):
		push_warning("[WorldDeBug] 找不到 InputMap 動作：%s" % String(test_action))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(test_action):
		_grant_food_to_target()

func _grant_food_to_target() -> void:
	if _target_node == null:
		push_warning("[WorldDeBug] 無法發送物品：目標節點為空")
		return

	var food: FoodData = ItemDatabase.get_item(food_item_id)
	if food == null:
		push_warning("[WorldDeBug] 無法發送物品：找不到 '%s'" % food_item_id)
		return

	if _target_node.has_method("set_held_food"):
		_target_node.call("set_held_food", food)
		print("[WorldDeBug] 已透過 set_held_food() 將 %s 發送給 %s" % [food_item_id, _target_node.name])
		return

	if _has_property(_target_node, "held_food"):
		_target_node.set("held_food", food)
		print("[WorldDeBug] 已透過 held_food 屬性將 %s 發送給 %s" % [food_item_id, _target_node.name])
		return

	push_warning("[WorldDeBug] 目標 %s 不支援 set_held_food() 或 held_food" % _target_node.name)

func spawn_customer() -> Dictionary:
	if customer_scene == null:
		return {"ok": false, "message": "無法生成顧客：Customer 場景未設定"}
	if _table == null:
		return {"ok": false, "message": "無法生成顧客：桌子節點為空"}
	if _spawn_parent == null:
		return {"ok": false, "message": "無法生成顧客：找不到生成父節點"}
	if _leave_target == null:
		return {"ok": false, "message": "無法生成顧客：離場節點為空"}
	if _table.get_free_seat_count() <= 0:
		return {"ok": false, "message": "無法生成顧客：目前沒有空位"}

	var instance: Node = customer_scene.instantiate()
	var customer: Customer = instance as Customer
	if customer == null:
		if instance != null:
			instance.queue_free()
		return {"ok": false, "message": "無法生成顧客：場景不是 Customer"}

	customer.auto_start_on_ready = false
	_spawn_parent.add_child(customer)
	customer.global_position = _get_spawn_position()
	customer.target_table_path = customer.get_path_to(_table)
	customer.leave_target_path = customer.get_path_to(_leave_target)

	if not customer.start_lifecycle(_table):
		customer.queue_free()
		return {"ok": false, "message": "無法生成顧客：初始化生命週期失敗"}

	_tracked_customer = customer
	return {
		"ok": true,
		"message": "已生成新顧客：%s" % customer.name,
		"customer": customer,
	}

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
