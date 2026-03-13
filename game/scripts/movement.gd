extends Node

class_name MovementComponent

@export var body: CharacterBody2D
@export var walk_speed := 200.0
@export var run_speed := 320.0
@export var move_left_action: StringName = &"ui_left"
@export var move_right_action: StringName = &"ui_right"
@export var move_up_action: StringName = &"ui_up"
@export var move_down_action: StringName = &"ui_down"
@export var run_action: StringName = &"run"

var input_vector := Vector2.ZERO
var is_running := false

func physics_update() -> void:
	input_vector = Input.get_vector(
		move_left_action,
		move_right_action,
		move_up_action,
		move_down_action
	)

	is_running = InputMap.has_action(run_action) and Input.is_action_pressed(run_action)
	var speed := run_speed if is_running else walk_speed
	body.velocity = input_vector * speed
	body.move_and_slide()
