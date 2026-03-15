extends Node2D

class_name VisualComponent

@export var sprite: Sprite2D
@export var movement_component: MovementComponent

# 漂浮參數
@export var float_speed := 4.0
@export var float_amp_y := 6.0   # 上下浮動幅度
@export var float_amp_x := 3.0   # 左右浮動幅度（8字型的關鍵）

var _time_passed := 0.0
var _base_offset := Vector2.ZERO

func _ready() -> void:
	if sprite:
		_base_offset = sprite.offset

func _process(delta: float) -> void:
	if not sprite or not movement_component:
		return

	_time_passed += delta

	# ── 1. 8字型魔法漂浮（Lissajous curve）──
	var float_y := sin(_time_passed * float_speed) * float_amp_y
	var float_x := cos(_time_passed * float_speed * 0.5) * float_amp_x
	sprite.offset = _base_offset + Vector2(float_x, float_y)

	# ── 2. 左右翻轉 ──
	if movement_component.input_vector.x != 0.0:
		sprite.flip_h = movement_component.input_vector.x < 0.0
