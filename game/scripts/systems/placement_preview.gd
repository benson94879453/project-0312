extends Node2D
class_name PlacementPreview

const VALID_COLOR: Color = Color(0.0, 1.0, 0.0, 0.5)
const INVALID_COLOR: Color = Color(1.0, 0.0, 0.0, 0.5)
const GHOST_ALPHA: float = 0.6

var _source_placeable: Node2D = null
var _preview_sprite: Sprite2D = null
var _floor_layer: TileMapLayer = null
var _rotation_step: int = 0
var _is_valid: bool = true
var _footprint_indicator: Node2D = null

func setup(source_placeable: Node2D, floor_layer: TileMapLayer) -> void:
	_source_placeable = source_placeable
	_floor_layer = floor_layer
	
	_create_preview_visuals()
	_create_footprint_indicator()
	_update_visuals()

func _create_preview_visuals() -> void:
	if _source_placeable == null:
		return
	
	# Find the sprite in the source placeable
	var source_sprite: Sprite2D = _find_sprite_in_node(_source_placeable)
	if source_sprite == null:
		return
	
	_preview_sprite = Sprite2D.new()
	_preview_sprite.texture = source_sprite.texture
	_preview_sprite.offset = source_sprite.offset
	_preview_sprite.scale = source_sprite.scale
	_preview_sprite.flip_h = source_sprite.flip_h
	_preview_sprite.flip_v = source_sprite.flip_v
	_preview_sprite.z_index = 100  # Render on top
	add_child(_preview_sprite)

func _find_sprite_in_node(node: Node) -> Sprite2D:
	# Look for a Sprite2D child
	for child in node.get_children():
		if child is Sprite2D:
			return child as Sprite2D
		var found: Sprite2D = _find_sprite_in_node(child)
		if found != null:
			return found
	return null

func _create_footprint_indicator() -> void:
	_footprint_indicator = Node2D.new()
	_footprint_indicator.z_index = 99  # Below the sprite but above most things
	add_child(_footprint_indicator)
	_update_footprint_visual()

func _update_footprint_visual() -> void:
	if _footprint_indicator == null or _floor_layer == null:
		return
	
	# Clear existing
	for child in _footprint_indicator.get_children():
		child.queue_free()
	
	var footprint_cells: Array[Vector2i] = _get_footprint_cells()
	var indicator_color: Color = VALID_COLOR if _is_valid else INVALID_COLOR
	
	for cell in footprint_cells:
		var indicator: Polygon2D = Polygon2D.new()
		var cell_size: Vector2 = Vector2(_floor_layer.tile_set.tile_size)
		var half_size: Vector2 = cell_size / 2.0
		
		# Create a diamond shape for the cell
		indicator.polygon = PackedVector2Array([
			Vector2(0, -half_size.y),
			Vector2(half_size.x, 0),
			Vector2(0, half_size.y),
			Vector2(-half_size.x, 0)
		])
		
		# Position relative to parent
		var local_cell_pos: Vector2 = _get_local_cell_position(cell)
		indicator.position = local_cell_pos
		indicator.color = indicator_color
		_footprint_indicator.add_child(indicator)

func _get_footprint_cells() -> Array[Vector2i]:
	if _source_placeable == null:
		return [Vector2i.ZERO]
	
	var cells: Array[Vector2i] = []
	if _source_placeable.has_method("get_placeable_footprint_cells"):
		var raw_cells: Array = _source_placeable.call("get_placeable_footprint_cells")
		for cell in raw_cells:
			cells.append(cell as Vector2i)
	else:
		cells = [Vector2i.ZERO]
	
	# Rotate cells based on rotation step
	var rotated_cells: Array[Vector2i] = []
	for cell in cells:
		rotated_cells.append(_rotate_cell(cell, _rotation_step))
	
	return rotated_cells

func _rotate_cell(cell: Vector2i, rotation_step: int) -> Vector2i:
	match posmod(rotation_step, 4):
		1:
			return Vector2i(-cell.y, cell.x)
		2:
			return Vector2i(-cell.x, -cell.y)
		3:
			return Vector2i(cell.y, -cell.x)
		_:
			return cell

func _get_local_cell_position(cell: Vector2i) -> Vector2:
	if _floor_layer == null:
		return Vector2.ZERO
	
	var cell_size: Vector2 = Vector2(_floor_layer.tile_set.tile_size)
	return Vector2(cell.x * cell_size.x, cell.y * cell_size.y)

func set_rotation_step(step: int) -> void:
	_rotation_step = step
	_update_visuals()
	_update_footprint_visual()

func set_valid(valid: bool) -> void:
	if _is_valid == valid:
		return
	_is_valid = valid
	_update_visuals()
	_update_footprint_visual()

func _update_visuals() -> void:
	if _preview_sprite == null:
		return
	
	# Apply rotation
	_preview_sprite.rotation = deg_to_rad(_rotation_step * 90)
	
	# Apply ghost effect
	var preview_modulate: Color = Color(1.0, 1.0, 1.0, GHOST_ALPHA)
	if not _is_valid:
		preview_modulate = Color(1.0, 0.5, 0.5, GHOST_ALPHA)
	
	_preview_sprite.modulate = preview_modulate

func is_valid() -> bool:
	return _is_valid

func get_rotation_step() -> int:
	return _rotation_step

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Restore visibility of source placeable if it was hidden
		if _source_placeable != null:
			_source_placeable.visible = true
