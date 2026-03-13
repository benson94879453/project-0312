extends Node

class_name PlayerStateMachine

@onready var movement_component: MovementComponent = %MovementComponent

enum MoveState {
	IDLE,
	WALK,
	RUN
}

var state: MoveState = MoveState.IDLE

func update_state() -> void:
	if movement_component.input_vector == Vector2.ZERO:
		state = MoveState.IDLE
		return

	state = MoveState.RUN if movement_component.is_running else MoveState.WALK

func get_animation_prefix() -> String:
	match state:
		MoveState.IDLE:
			return "idle"
		MoveState.RUN:
			return "run"
		_:
			return "walk"
