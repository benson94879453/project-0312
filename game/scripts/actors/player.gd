extends CharacterBody2D

@export var movement_component: MovementComponent
@export var state_machine: PlayerStateMachine
@export var debug_start_food_id: String = "coffee"

var facing_direction: Vector2 = Vector2.DOWN
var held_food: FoodData = null

func _ready() -> void:
	if debug_start_food_id.is_empty():
		return
	held_food = ItemDatabase.get_item(debug_start_food_id)

func _physics_process(delta: float) -> void:
	var next_velocity: Vector2 = movement_component.get_velocity(delta)
	velocity = next_velocity
	move_and_slide()
	_update_facing_direction()
	state_machine.update_state()

func _update_facing_direction() -> void:
	if movement_component.input_vector != Vector2.ZERO:
		facing_direction = movement_component.input_vector

func get_held_food() -> FoodData:
	return held_food

func try_consume_held_food() -> FoodData:
	var consumed: FoodData = held_food
	held_food = null
	return consumed

func set_held_food(food: FoodData) -> void:
	held_food = food
