extends Node2D

@export var target_node: Node2D
@export var test_action: StringName = &"test_add_coffee"
@export var food_item_id: String = "coffee"

func _ready() -> void:
	if not InputMap.has_action(test_action):
		push_warning("[TestTools] Missing InputMap action: %s" % String(test_action))
	if target_node == null:
		push_warning("[TestTools] target_node is not assigned")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(test_action):
		_grant_coffee_to_target()

func _grant_coffee_to_target() -> void:
	if target_node == null:
		push_warning("[TestTools] Cannot grant coffee: target_node is null")
		return

	var coffee: FoodData = ItemDatabase.get_item(food_item_id)
	if coffee == null:
		push_warning("[TestTools] Cannot grant coffee: item '%s' not found" % food_item_id)
		return

	if target_node.has_method("set_held_food"):
		target_node.call("set_held_food", coffee)
		print("[TestTools] Granted %s to %s via set_held_food()" % [food_item_id, target_node.name])
		return

	if _has_property(target_node, "held_food"):
		target_node.set("held_food", coffee)
		print("[TestTools] Granted %s to %s via held_food property" % [food_item_id, target_node.name])
		return

	push_warning("[TestTools] Target %s does not support set_held_food() or held_food" % target_node.name)

func _has_property(node: Object, property_name: String) -> bool:
	for entry in node.get_property_list():
		if String(entry.get("name", "")) == property_name:
			return true
	return false
