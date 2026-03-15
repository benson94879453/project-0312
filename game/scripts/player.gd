extends CharacterBody2D

@export var movement_component: MovementComponent
@export var state_machine: PlayerStateMachine

var facing_direction := Vector2.DOWN

func _physics_process(delta: float) -> void:
	var _velocity: Vector2 = movement_component.get_velocity(delta)
	velocity = _velocity
	#移動
	move_and_slide()
	#面朝向更新
	_update_facing_direction()
	#狀態機更新
	state_machine.update_state()

#面朝向更新
func _update_facing_direction() -> void:
	if movement_component.input_vector != Vector2.ZERO:
		facing_direction = movement_component.input_vector
