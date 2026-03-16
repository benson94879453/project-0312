extends Node2D
class_name CustomerVisualComponent

@export var sprite: Sprite2D
@export var movement_component: CustomerMovementComponent

@export var float_speed: float = 4.0
@export var float_amp_y: float = 6.0
@export var float_amp_x: float = 3.0

var _time_passed: float = 0.0
var _base_offset: Vector2 = Vector2.ZERO

func configure(p_sprite: Sprite2D, p_movement_component: CustomerMovementComponent) -> void:
	sprite = p_sprite
	movement_component = p_movement_component
	if sprite != null:
		_base_offset = sprite.offset

func _ready() -> void:
	if sprite != null:
		_base_offset = sprite.offset

func _process(delta: float) -> void:
	if sprite == null:
		return

	_time_passed += delta
	var float_y: float = sin(_time_passed * float_speed) * float_amp_y
	var float_x: float = cos(_time_passed * float_speed * 0.5) * float_amp_x
	sprite.offset = _base_offset + Vector2(float_x, float_y)

	if movement_component != null and movement_component.move_direction.x != 0.0:
		sprite.flip_h = movement_component.move_direction.x < 0.0
