extends CharacterBody2D

@export var movement_component: MovementComponent
@export var state_machine: PlayerStateMachine

var facing_direction: Vector2 = Vector2.DOWN

func _physics_process(delta: float) -> void:
	var next_velocity: Vector2 = movement_component.get_velocity(delta)
	velocity = next_velocity
	move_and_slide()
	_update_facing_direction()
	state_machine.update_state()

func _update_facing_direction() -> void:
	if movement_component.input_vector != Vector2.ZERO:
		facing_direction = movement_component.input_vector
