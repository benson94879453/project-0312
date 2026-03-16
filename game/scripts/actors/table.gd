extends StaticBody2D
class_name Table

@export var data: TableData
@export var show_debug_seats: bool = true

# Slot-aligned food data for future serving gameplay.
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
	z_index = 10
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

# Basic interaction hook called by InteractionComponent.
func interact(actor: Node) -> void:
	var actor_name: String = String(actor.name) if actor != null else "Unknown"
	var was_released: bool = release_seat(actor)
	var was_reserved: bool = false
	if not was_released:
		was_reserved = reserve_seat(actor)

	var result: String = "no_free_seat"
	if was_released:
		result = "released"
	elif was_reserved:
		result = "reserved"

	print("[Table] Interacted by %s | result=%s | seats=%d/%d | free_food_slots=%d" % [
		actor_name,
		result,
		get_free_seat_count(),
		available_seats.size(),
		_get_free_food_slot_count()
	])

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

func _get_free_food_slot_count() -> int:
	var free_food_slots: int = 0
	for food in foods_on_table:
		if food == null:
			free_food_slots += 1
	return free_food_slots
