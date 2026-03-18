extends StaticBody2D
class_name Chair

const STATE_AVAILABLE: StringName = &"available"
const STATE_OCCUPIED: StringName = &"occupied"

@export var data: ChairData
@export var facing_direction: Vector2 = Vector2.DOWN
@export var placeable_id: String = ""

@onready var sprite: Sprite2D = $ChairSprite
@onready var hitbox: CollisionShape2D = $Hitbox
@onready var table_detector: Area2D = $TableDetector

var registered_table: Table = null
var seat_state: StringName = STATE_AVAILABLE
var occupied_by: Node = null

func _ready() -> void:
	if data:
		_initialize_from_data()
	call_deferred("_attempt_register_to_table")

func _initialize_from_data() -> void:
	sprite.texture = data.texture
	sprite.offset = data.sprite_offset

	var h_shape: RectangleShape2D = RectangleShape2D.new()
	h_shape.size = data.hitbox_size
	hitbox.shape = h_shape

func _attempt_register_to_table() -> void:
	if registered_table != null:
		return

	# Wait for physics broadphase so Area2D overlap data is ready.
	await get_tree().physics_frame
	await get_tree().physics_frame

	var overlapping_bodies: Array[Node2D] = table_detector.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body is Table:
			bind_to_table(body as Table)
			return

func bind_to_table(table: Table) -> void:
	if registered_table == table:
		return
	if registered_table != null:
		var previous_table: Table = registered_table
		registered_table = null
		previous_table.unregister_chair(self)
	if table == null:
		return

	registered_table = table
	table.register_new_seats(self, build_seat_info_list())
	print("[Chair] Registered %d seat(s). facing=%s" % [data.seats.size() if data != null else 0, facing_direction])

func unbind_from_table() -> void:
	if registered_table == null:
		return
	var previous_table: Table = registered_table
	registered_table = null
	previous_table.unregister_chair(self)

func clear_registered_table_reference() -> void:
	registered_table = null

func build_seat_info_list() -> Array[Dictionary]:
	return build_seat_info_list_for_transform(global_position, get_placeable_rotation_step())

func build_seat_info_list_for_transform(target_position: Vector2, rotation_step: int) -> Array[Dictionary]:
	var seat_info_list: Array[Dictionary] = []
	if data == null:
		return seat_info_list

	for slot in data.seats:
		var rotated_position: Vector2 = _rotate_vector_by_step(slot.seat_slot_position, rotation_step)
		var rotated_direction: Vector2 = _rotate_vector_by_step(slot.seat_slot_direction, rotation_step)
		var info: Dictionary = {
			"chair": self,
			"position": target_position + rotated_position,
			"direction": rotated_direction
		}
		seat_info_list.append(info)
	return seat_info_list

func get_seat_cells_for_transform(floor_layer: TileMapLayer, target_position: Vector2, rotation_step: int) -> Array[Vector2i]:
	var seat_cells: Array[Vector2i] = []
	if floor_layer == null:
		return seat_cells

	for seat_info in build_seat_info_list_for_transform(target_position, rotation_step):
		var seat_position: Vector2 = seat_info.get("position", target_position)
		var seat_cell: Vector2i = floor_layer.local_to_map(floor_layer.to_local(seat_position))
		if not seat_cells.has(seat_cell):
			seat_cells.append(seat_cell)
	return seat_cells

func set_placeable_id(new_placeable_id: String) -> void:
	placeable_id = new_placeable_id

func get_placeable_type_key() -> String:
	return SaveConstants.TYPE_CHAIR

func get_placeable_resource_id() -> String:
	if data == null:
		return ""
	return data.chair_id

func set_placeable_resource_id(resource_id: String) -> bool:
	if resource_id.is_empty():
		return false
	var resource: ChairData = _load_chair_data(resource_id)
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

func get_table_bind_radius() -> float:
	var detector_shape: CollisionShape2D = get_node_or_null("TableDetector/DetectorShape") as CollisionShape2D
	if detector_shape == null:
		return 64.0
	var circle_shape: CircleShape2D = detector_shape.shape as CircleShape2D
	if circle_shape == null:
		return 64.0
	return circle_shape.radius

func _load_chair_data(resource_id: String) -> ChairData:
	var directory: DirAccess = DirAccess.open("res://game/data/chairs")
	if directory == null:
		return null

	directory.list_dir_begin()
	var file_name: String = directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".tres"):
			var resource_path: String = "res://game/data/chairs/%s" % file_name
			var candidate: ChairData = load(resource_path) as ChairData
			if candidate != null and candidate.chair_id == resource_id:
				directory.list_dir_end()
				return candidate
		file_name = directory.get_next()
	directory.list_dir_end()
	return null

func _rotate_vector_by_step(value: Vector2, rotation_step: int) -> Vector2:
	match posmod(rotation_step, 4):
		1:
			return Vector2(-value.y, value.x)
		2:
			return -value
		3:
			return Vector2(value.y, -value.x)
		_:
			return value

func is_available() -> bool:
	return seat_state == STATE_AVAILABLE

func is_occupied_by(actor: Node) -> bool:
	if actor == null:
		return false
	return occupied_by == actor

func reserve(actor: Node) -> bool:
	if actor == null:
		return false
	if is_occupied_by(actor):
		return true
	if not is_available():
		return false

	seat_state = STATE_OCCUPIED
	occupied_by = actor
	return true

func release(actor: Node) -> bool:
	if not is_occupied_by(actor):
		return false

	seat_state = STATE_AVAILABLE
	occupied_by = null
	return true
