extends StaticBody2D
class_name Table

signal order_registered(customer: Node, food_id: String)
signal food_received(food: FoodData)
signal order_served(customer: Node, food: FoodData)
signal interaction_processed(result: Dictionary)

@export var data: TableData
@export var show_debug_seats: bool = true

# Runtime table-centric data.
var current_customers: Array[Node] = []
var expected_orders: Array[OrderData] = []
var foods_on_table: Array[FoodData] = []
var slot_sprites: Array[Sprite2D] = []

@onready var sprite: Sprite2D = $TableSprite
@onready var hitbox: CollisionShape2D = $Hitbox
@onready var interactbox: CollisionShape2D = $InteractableComponent/Interactbox
@onready var slots_container: Node2D = $FoodSlots

# Seat records are generated from nearby chairs during setup.
var available_seats: Array[Dictionary] = []
var connected_chairs: Array[Chair] = []

func _ready() -> void:
	z_index = 0
	z_as_relative = false
	if sprite:
		sprite.show_behind_parent = true

	if data:
		_initialize_from_data()

func _initialize_from_data() -> void:
	sprite.texture = data.texture
	sprite.offset = data.sprite_offset

	var h_shape: RectangleShape2D = RectangleShape2D.new()
	h_shape.size = data.hitbox_size
	hitbox.shape = h_shape
	hitbox.position = data.hitbox_offset

	var i_shape: RectangleShape2D = RectangleShape2D.new()
	i_shape.size = data.interactbox_size
	interactbox.shape = i_shape

	foods_on_table.resize(data.slot_positions.size())
	foods_on_table.fill(null)
	for slot_pos in data.slot_positions:
		var new_slot_sprite: Sprite2D = Sprite2D.new()
		new_slot_sprite.offset = slot_pos
		new_slot_sprite.position = Vector2.ZERO
		slots_container.add_child(new_slot_sprite)
		slot_sprites.append(new_slot_sprite)

func register_new_seats(chair: Chair, seat_info_list: Array[Dictionary]) -> void:
	if connected_chairs.has(chair):
		return

	connected_chairs.append(chair)
	for seat_info in seat_info_list:
		available_seats.append(_build_seat_record(seat_info))
	queue_redraw()

func reserve_seat(actor: Node) -> bool:
	if actor == null:
		return false

	for chair in connected_chairs:
		if chair.is_occupied_by(actor):
			return true

	for chair in connected_chairs:
		if chair.reserve(actor):
			queue_redraw()
			return true

	return false

func release_seat(actor: Node) -> bool:
	for chair in connected_chairs:
		if chair.release(actor):
			queue_redraw()
			return true
	return false

func get_free_seat_count() -> int:
	var free_count: int = 0
	for chair in connected_chairs:
		if chair.is_available():
			free_count += 1
	return free_count

func add_customer(customer: Node) -> bool:
	if customer == null:
		return false
	if current_customers.has(customer):
		return true
	current_customers.append(customer)
	return true

func remove_customer(customer: Node) -> bool:
	if customer == null:
		return false
	var idx: int = current_customers.find(customer)
	if idx < 0:
		return false
	current_customers.remove_at(idx)
	return true

func register_order(order: OrderData) -> bool:
	if order == null or order.customer == null or order.food == null:
		return false

	add_customer(order.customer)
	expected_orders.append(order)
	order_registered.emit(order.customer, order.food.id)
	return true

func receive_food(food_item: FoodData) -> bool:
	return try_receive_food(food_item).get("ok", false)

func try_receive_food(food_item: FoodData) -> Dictionary:
	var check: Dictionary = _check_food_receive(food_item)
	if not check.get("ok", false):
		return check

	var order_index: int = check.get("order_index", -1)
	var free_slot_index: int = check.get("slot_index", -1)
	foods_on_table[free_slot_index] = food_item
	slot_sprites[free_slot_index].texture = food_item.texture

	var served_order: OrderData = expected_orders[order_index]
	expected_orders.remove_at(order_index)

	food_received.emit(food_item)
	order_served.emit(served_order.customer, food_item)

	return {
		"ok": true,
		"reason": "served",
		"order_index": order_index,
		"slot_index": free_slot_index,
		"customer": served_order.customer,
		"food_id": food_item.id,
	}

# Basic interaction hook called by InteractionComponent.
func interact(actor: Node) -> void:
	var actor_name: String = String(actor.name) if actor != null else "Unknown"

	if actor != null and actor.has_method("get_held_food") and actor.has_method("try_consume_held_food"):
		var held_food: FoodData = actor.call("get_held_food") as FoodData
		if held_food != null:
			var receive_result: Dictionary = try_receive_food(held_food)
			var served_ok: bool = receive_result.get("ok", false)
			if served_ok:
				actor.call("try_consume_held_food")
				interaction_processed.emit({
					"actor": actor_name,
					"success": true,
					"reason": "served",
					"food_id": held_food.id,
					"pending_orders": expected_orders.size(),
					"foods_on_table": _debug_food_ids_on_table(),
				})
				print("[Table] %s served %s" % [actor_name, held_food.id])
				return
			var fail_reason: String = String(receive_result.get("reason", "serve_failed"))
			interaction_processed.emit({
				"actor": actor_name,
				"success": false,
				"reason": fail_reason,
				"food_id": held_food.id,
				"pending_orders": expected_orders.size(),
				"foods_on_table": _debug_food_ids_on_table(),
			})
			print("[Table] %s tried serving %s but failed (%s)" % [actor_name, held_food.id, fail_reason])
			return

		interaction_processed.emit({
			"actor": actor_name,
			"success": false,
			"reason": "no_food_in_hand",
			"food_id": "",
			"pending_orders": expected_orders.size(),
			"foods_on_table": _debug_food_ids_on_table(),
		})
		print("[Table] %s interacted without food in hand" % actor_name)
		return

	var was_released: bool = release_seat(actor)
	var was_reserved: bool = false
	if not was_released:
		was_reserved = reserve_seat(actor)

	var result: String = "no_free_seat"
	if was_released:
		result = "released"
	elif was_reserved:
		result = "reserved"

	print("[Table] Interacted by %s | result=%s | seats=%d/%d | pending_orders=%d" % [
		actor_name,
		result,
		get_free_seat_count(),
		available_seats.size(),
		expected_orders.size()
	])
	interaction_processed.emit({
		"actor": actor_name,
		"success": was_released or was_reserved,
		"reason": result,
		"food_id": "",
		"pending_orders": expected_orders.size(),
		"foods_on_table": _debug_food_ids_on_table(),
	})

func _draw() -> void:
	if not show_debug_seats or available_seats.is_empty():
		return

	for seat in available_seats:
		if not seat.has("position") or not seat.has("direction"):
			continue
		var seat_position: Vector2 = seat["position"] as Vector2
		var seat_direction: Vector2 = seat["direction"] as Vector2
		var local_pos: Vector2 = to_local(seat_position)
		var chair: Chair = seat.get("chair", null) as Chair
		var is_occupied: bool = chair != null and not chair.is_available()
		var seat_color: Color = Color(1, 0.35, 0.2, 0.85) if is_occupied else Color(0, 1, 0, 0.7)
		draw_circle(local_pos, 4.0, seat_color)
		draw_line(local_pos, local_pos + (seat_direction * 15.0), Color(1, 0.2, 0.2, 0.9), 2.0)

func _build_seat_record(seat_info: Dictionary) -> Dictionary:
	var record: Dictionary = {}
	if seat_info.has("chair"):
		record["chair"] = seat_info["chair"]
	if seat_info.has("position"):
		record["position"] = seat_info["position"]
	if seat_info.has("direction"):
		record["direction"] = seat_info["direction"]
	return record

func _find_matching_order_index(food_item: FoodData) -> int:
	for i in range(expected_orders.size()):
		var order: OrderData = expected_orders[i]
		if order.matches_food(food_item):
			return i
	return -1

func _find_free_food_slot_index() -> int:
	for i in range(foods_on_table.size()):
		if foods_on_table[i] == null:
			return i
	return -1

func _check_food_receive(food_item: FoodData) -> Dictionary:
	if food_item == null:
		return {"ok": false, "reason": "null_food"}

	var order_index: int = _find_matching_order_index(food_item)
	if order_index < 0:
		return {"ok": false, "reason": "no_matching_order"}

	var free_slot_index: int = _find_free_food_slot_index()
	if free_slot_index < 0:
		return {"ok": false, "reason": "table_full"}

	return {
		"ok": true,
		"reason": "ok",
		"order_index": order_index,
		"slot_index": free_slot_index,
	}

func _debug_food_ids_on_table() -> Array[String]:
	var result: Array[String] = []
	for item in foods_on_table:
		var food: FoodData = item as FoodData
		result.append(food.id if food != null else "-")
	return result
