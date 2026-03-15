extends Node

class_name MovementComponent

@export var walk_speed := 200.0
@export var run_speed := 320.0
@export var acceleration := 1200.0  # 起步推力
@export var friction := 400.0       # 摩擦力（越低滑越遠）

@export var move_left_action: StringName = "ui_left"
@export var move_right_action: StringName = "ui_right"
@export var move_up_action: StringName = "ui_up"
@export var move_down_action: StringName = "ui_down"
@export var run_action: StringName = "run"

var input_vector := Vector2.ZERO
var is_running := false
var current_velocity := Vector2.ZERO  # 記錄當前真實速度

func _read_input() -> void:
	input_vector = Input.get_vector(
		move_left_action, move_right_action, move_up_action, move_down_action
	)
	is_running = InputMap.has_action(run_action) and Input.is_action_pressed(run_action)

func get_velocity(delta: float) -> Vector2:
	_read_input()
	var target_speed := run_speed if is_running else walk_speed

	if input_vector != Vector2.ZERO:
		# 加速：朝目標速度推進
		current_velocity = current_velocity.move_toward(input_vector * target_speed, acceleration * delta)
	else:
		# 煞車滑行：朝零速度靠近
		current_velocity = current_velocity.move_toward(Vector2.ZERO, friction * delta)

	return current_velocity
