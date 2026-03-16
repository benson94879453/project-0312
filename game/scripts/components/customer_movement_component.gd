extends Node
class_name CustomerMovementComponent

@export var move_speed: float = 140.0
@export var acceleration: float = 900.0
@export var friction: float = 600.0
@export var stop_distance: float = 8.0

var current_velocity: Vector2 = Vector2.ZERO
var move_direction: Vector2 = Vector2.ZERO

var _has_target: bool = false
var _target_global: Vector2 = Vector2.ZERO
var _reached_target: bool = false
var _navigation_agent: NavigationAgent2D = null

func setup(navigation_agent: NavigationAgent2D = null) -> void:
	_navigation_agent = navigation_agent

func set_target(global_target: Vector2) -> void:
	_target_global = global_target
	_has_target = true
	_reached_target = false
	if _navigation_agent != null:
		_navigation_agent.target_position = global_target

func clear_target() -> void:
	_has_target = false
	_target_global = Vector2.ZERO

func has_target() -> bool:
	return _has_target

func consume_target_reached() -> bool:
	if not _reached_target:
		return false
	_reached_target = false
	return true

func get_velocity(current_global_position: Vector2, delta: float) -> Vector2:
	var desired_direction: Vector2 = Vector2.ZERO

	if _has_target:
		var remaining_to_target: Vector2 = _target_global - current_global_position
		var remaining_distance: float = remaining_to_target.length()
		if remaining_distance <= stop_distance:
			_has_target = false
			_reached_target = true
		else:
			var to_next: Vector2 = remaining_to_target
			if _navigation_agent != null and not _navigation_agent.is_navigation_finished():
				var next_path_position: Vector2 = _navigation_agent.get_next_path_position()
				to_next = next_path_position - current_global_position
			if to_next != Vector2.ZERO:
				desired_direction = to_next.normalized()

	if desired_direction != Vector2.ZERO:
		move_direction = desired_direction
		current_velocity = current_velocity.move_toward(desired_direction * move_speed, acceleration * delta)
	else:
		move_direction = Vector2.ZERO
		current_velocity = current_velocity.move_toward(Vector2.ZERO, friction * delta)

	return current_velocity
