extends StaticBody2D
class_name Chair

const STATE_AVAILABLE: StringName = &"available"
const STATE_OCCUPIED: StringName = &"occupied"

@export var data: ChairData
@export var facing_direction: Vector2 = Vector2.DOWN

@onready var sprite: Sprite2D = $ChairSprite
@onready var hitbox: CollisionShape2D = $Hitbox
@onready var table_detector: Area2D = $TableDetector

var registered_table: Table = null
var seat_state: StringName = STATE_AVAILABLE
var occupied_by: Node = null

func _ready() -> void:
	if data:
		_initialize_from_data()
	_attempt_register_to_table()

func _initialize_from_data() -> void:
	sprite.texture = data.texture
	sprite.offset = data.sprite_offset

	var h_shape: RectangleShape2D = RectangleShape2D.new()
	h_shape.size = data.hitbox_size
	hitbox.shape = h_shape

func _attempt_register_to_table() -> void:
	# Wait for physics broadphase so Area2D overlap data is ready.
	await get_tree().physics_frame
	await get_tree().physics_frame

	var overlapping_bodies: Array[Node2D] = table_detector.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body is Table:
			_bind_to_table(body as Table)
			return

func _bind_to_table(table: Table) -> void:
	registered_table = table

	var seat_info_list: Array[Dictionary] = []
	for slot in data.seats:
		var info: Dictionary = {
			"chair": self,
			"position": global_position + slot.seat_slot_position,
			"direction": slot.seat_slot_direction
		}
		seat_info_list.append(info)

	table.register_new_seats(self, seat_info_list)
	print("[Chair] Registered %d seat(s). facing=%s" % [seat_info_list.size(), facing_direction])

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
