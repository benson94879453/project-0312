extends Sprite2D

@export var player_path: NodePath = NodePath("..")
@export var hold_offset: Vector2 = Vector2(16, -16)
@export var hide_when_empty: bool = true
@export var flip_with_facing: bool = true

var _player: Node = null
var _cached_food: FoodData = null

func _ready() -> void:
	_player = get_node_or_null(player_path)
	centered = true
	_update_visual()

func _process(_delta: float) -> void:
	_update_visual()
	_update_hold_position()

func _update_visual() -> void:
	if _player == null or not _player.has_method("get_held_food"):
		if hide_when_empty:
			visible = false
		return

	var held_food: FoodData = _player.call("get_held_food") as FoodData
	if held_food == _cached_food:
		return

	_cached_food = held_food
	if _cached_food == null or _cached_food.texture == null:
		texture = null
		if hide_when_empty:
			visible = false
		return

	texture = _cached_food.texture
	visible = true

func _update_hold_position() -> void:
	if _player == null:
		position = hold_offset
		return

	var facing: Vector2 = _player.get("facing_direction")
	var x_sign: float = -1.0 if facing.x < 0.0 else 1.0

	if flip_with_facing:
		flip_h = x_sign < 0.0

	position = Vector2(absf(hold_offset.x) * x_sign, hold_offset.y)
