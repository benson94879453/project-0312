extends Area2D

class_name InteractionComponent

# Emitted whenever this component finds a target in range.
signal interaction_requested(target: Node, interactor: Node)

@export var enabled: bool = true
@export var interact_action: StringName = "interact"

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	# Guard against missing InputMap setup in early prototypes.
	if not InputMap.has_action(interact_action):
		return
	if event.is_action_pressed(interact_action):
		request_interaction(get_parent())

func request_interaction(interactor: Node) -> bool:
	if not enabled:
		return false

	var has_target: bool = false

	# Bodies are usually gameplay objects (StaticBody2D/CharacterBody2D).
	for body in get_overlapping_bodies():
		if body == interactor:
			continue
		has_target = true
		interaction_requested.emit(body, interactor)
		if body.has_method("interact"):
			body.call("interact", interactor)

	# Areas can also receive interaction if they implement `interact`.
	for area in get_overlapping_areas():
		if area == self or area == interactor:
			continue
		has_target = true
		interaction_requested.emit(area, interactor)
		if area.has_method("interact"):
			area.call("interact", interactor)

	return has_target
