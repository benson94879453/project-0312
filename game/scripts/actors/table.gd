extends StaticBody2D
class_name Table

signal order_registered(customer: Node, food_id: String)
signal food_received(food: FoodData)
signal order_served(customer: Node, food: FoodData)
signal interaction_processed(result: Dictionary)

@export var data: TableData
@export var show_debug_seats: bool = true
@export var placeable_id: String = ""

# Runtime table-centric data.
var current_customers: Array[Node] = []
var expected_orders: Array[OrderData] = []
var foods_on_table: Array[FoodData] = []
var food_slot_customers: Array[Node] = []
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
	for slot_sprite in slot_sprites:
		if slot_sprite != null:
			slot_sprite.queue_free()
	slot_sprites.clear()
	foods_on_table.clear()
	food_slot_customers.clear()

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
	food_slot_customers.resize(data.slot_positions.size())
	food_slot_customers.fill(null)
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

func unregister_chair(chair: Chair) -> void:
	if chair == null:
		return

	connected_chairs.erase(chair)
	var filtered_seats: Array[Dictionary] = []
	for seat in available_seats:
		var seat_chair: Chair = seat.get("chair", null) as Chair
		if seat_chair != chair:
			filtered_seats.append(seat)
	available_seats = filtered_seats
	queue_redraw()

func clear_registered_seats() -> void:
	connected_chairs.clear()
	available_seats.clear()
	queue_redraw()

func set_placeable_id(new_placeable_id: String) -> void:
	placeable_id = new_placeable_id

func get_placeable_type_key() -> String:
	return SaveConstants.TYPE_TABLE

func get_placeable_resource_id() -> String:
	if data == null:
		return ""
	return data.table_id

func set_placeable_resource_id(resource_id: String) -> bool:
	if resource_id.is_empty():
		return false
	var resource: TableData = _load_table_data(resource_id)
	if resource == null:
		return false
	data = resource
	if is_node_ready():
		_initialize_from_data()
	return true

func get_placeable_rotation_step() -> int:
	var quarter_turns: int = int(round(rad_to_deg(rotation) / 90.0))
	return posmod(quarter_turns, 4)

func set_placeable_rotation_step(rotation_step: int) -> void:
	rotation = deg_to_rad(float(posmod(rotation_step, 4) * 90))

func get_placeable_footprint_cells() -> Array[Vector2i]:
	if data == null or data.footprint_cells.is_empty():
		return [Vector2i.ZERO]
	return data.footprint_cells.duplicate()

func _load_table_data(resource_id: String) -> TableData:
	var directory: DirAccess = DirAccess.open("res://game/data/tables")
	if directory == null:
		return null

	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".tres"):
			var resource_path: String = "res://game/data/tables/%s" % file_name
			var candidate: TableData = load(resource_path) as TableData
			if candidate != null and candidate.table_id == resource_id:
				directory.list_dir_end()
				return candidate
		file_name = directory.get_next()
	directory.list_dir_end()
	return null

func reserve_seat(actor: Node) -> bool:
	return reserve_seat_with_info(actor).get("ok", false)

func try_seat_customer(customer: Node) -> Dictionary:
	var seat: Dictionary = reserve_seat_with_info(customer)
	if not seat.get("ok", false):
		return {
			"success": false,
			"reason": String(seat.get("reason", "table_full")),
		}
	return {
		"success": true,
		"reason": "ok",
		"chair": seat.get("chair", null),
		"position": seat.get("position", global_position),
		"direction": seat.get("direction", Vector2.DOWN),
	}

func reserve_seat_with_info(actor: Node) -> Dictionary:
	if actor == null:
		return {"ok": false, "reason": "invalid_actor"}

	var existing_seat: Dictionary = get_reserved_seat_info(actor)
	if existing_seat.get("ok", false):
		return existing_seat

	for seat in available_seats:
		var chair: Chair = seat.get("chair", null) as Chair
		if chair != null and chair.reserve(actor):
			queue_redraw()
			return {
				"ok": true,
				"chair": chair,
				"position": seat.get("position", global_position),
				"direction": seat.get("direction", Vector2.ZERO),
			}

	return {"ok": false, "reason": "table_full"}

func get_reserved_seat_info(actor: Node) -> Dictionary:
	if actor == null:
		return {"ok": false}

	for seat in available_seats:
		var chair: Chair = seat.get("chair", null) as Chair
		if chair != null and chair.is_occupied_by(actor):
			return {
				"ok": true,
				"chair": chair,
				"position": seat.get("position", global_position),
				"direction": seat.get("direction", Vector2.ZERO),
			}
	return {"ok": false}

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

func cancel_order_for_customer(customer: Node) -> bool:
	if customer == null:
		return false

	for i in range(expected_orders.size() - 1, -1, -1):
		var order: OrderData = expected_orders[i]
		if order != null and order.customer == customer:
			expected_orders.remove_at(i)
			return true

	return false

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
	food_slot_customers[free_slot_index] = served_order.customer
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

func clear_food_for_customer(customer: Node) -> bool:
	if customer == null:
		return false
	for i in range(food_slot_customers.size()):
		if food_slot_customers[i] == customer:
			_clear_food_slot(i)
			return true
	return false

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

func _clear_food_slot(index: int) -> void:
	if index < 0 or index >= foods_on_table.size():
		return
	foods_on_table[index] = null
	if index < food_slot_customers.size():
		food_slot_customers[index] = null
	if index < slot_sprites.size() and slot_sprites[index] != null:
		slot_sprites[index].texture = null
