extends Node

class_name PlayerStateMachine

@export var movement_component: MovementComponent

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
