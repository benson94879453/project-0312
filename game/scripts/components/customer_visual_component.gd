extends Node2D
class_name CustomerVisualComponent

@export var sprite: Sprite2D
@export var movement_component: CustomerMovementComponent

@export var float_speed: float = 4.0
@export var float_amp_y: float = 6.0
@export var float_amp_x: float = 3.0
@export var bob_only_while_moving: bool = true
@export var return_to_base_speed: float = 14.0
@export var moving_deadzone_speed_sq: float = 1.0

var _time_passed: float = 0.0
var _base_offset: Vector2 = Vector2.ZERO
var _owner_customer: Customer = null

func configure(p_sprite: Sprite2D, p_movement_component: CustomerMovementComponent) -> void:
	sprite = p_sprite
	movement_component = p_movement_component
	if sprite != null:
		_base_offset = sprite.offset

func _ready() -> void:
	if sprite != null:
		_base_offset = sprite.offset
	_owner_customer = get_parent() as Customer

func _process(delta: float) -> void:
	if sprite == null:
		return

	var speed_sq: float = 0.0
	if movement_component != null:
		speed_sq = movement_component.current_velocity.length_squared()
	var is_moving: bool = speed_sq > moving_deadzone_speed_sq
	if not bob_only_while_moving or is_moving:
		_time_passed += delta
		var float_y: float = sin(_time_passed * float_speed) * float_amp_y
		var float_x: float = cos(_time_passed * float_speed * 0.5) * float_amp_x
		sprite.offset = _base_offset + Vector2(float_x, float_y)
	else:
		sprite.offset = sprite.offset.move_toward(_base_offset, return_to_base_speed * delta)

	if movement_component != null and movement_component.move_direction.x != 0.0:
		sprite.flip_h = movement_component.move_direction.x < 0.0
	elif _owner_customer != null and _owner_customer.facing_direction.x != 0.0:
		sprite.flip_h = _owner_customer.facing_direction.x < 0.0
