extends CharacterBody2D

@onready var movement_component: MovementComponent = %MovementComponent
@onready var state_machine: PlayerStateMachine = %StateMachine
@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite2D

var facing_direction := Vector2.DOWN

func _physics_process(_delta: float) -> void:
	movement_component.physics_update()
	_update_facing_direction()
	state_machine.update_state()
	_update_animation()

func _update_facing_direction() -> void:
	if movement_component.input_vector != Vector2.ZERO:
		facing_direction = movement_component.input_vector

func _update_animation() -> void:
	var direction := _get_direction_name()
	var prefix := state_machine.get_animation_prefix()
	var animation_name := StringName("%s_%s" % [prefix, direction])
	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)

func _get_direction_name() -> String:
	if absf(facing_direction.x) > absf(facing_direction.y):
		return "right" if facing_direction.x > 0.0 else "left"
	return "down" if facing_direction.y > 0.0 else "up"
