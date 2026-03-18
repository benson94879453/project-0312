extends Node
class_name EditModeController

signal edit_mode_entered
signal edit_mode_exited
signal placeable_selected(placeable: Node2D)
signal placeable_deselected
signal validation_changed(is_valid: bool, reason: String)

const MODE_NONE: StringName = &"none"
const MODE_PLACING_NEW: StringName = &"placing_new"
const MODE_MOVING_EXISTING: StringName = &"moving_existing"

@export var registry_path: NodePath
@export var floor_layer_path: NodePath
@export var object_container_path: NodePath
@export var ui_manager_path: NodePath

@export var table_scene: PackedScene
@export var chair_scene: PackedScene

var _registry: PlaceableRuntimeRegistry = null
var _floor_layer: TileMapLayer = null
var _object_container: Node = null
var _ui_manager: UIManager = null

var _is_in_edit_mode: bool = false
var _current_mode: StringName = MODE_NONE
var _current_preview: PlacementPreview = null
var _selected_placeable: Node2D = null
var _pending_placeable_type: String = ""  # "table" or "chair"
var _pending_resource_id: String = ""  # Resource ID for data lookup
var _rotation_step: int = 0

var _temp_placeable: Node2D = null
var _original_position: Vector2 = Vector2.ZERO
var _original_rotation_step: int = 0

func _ready() -> void:
	_resolve_references()

func _resolve_references() -> void:
	_registry = get_node_or_null(registry_path) as PlaceableRuntimeRegistry
	_floor_layer = get_node_or_null(floor_layer_path) as TileMapLayer
	_object_container = get_node_or_null(object_container_path)
	_ui_manager = get_node_or_null(ui_manager_path) as UIManager

func can_enter_edit_mode() -> bool:
	return not DayManager.is_day_active

func enter_edit_mode() -> bool:
	if _is_in_edit_mode:
		return true
	
	if not can_enter_edit_mode():
		push_warning("[EditModeController] Cannot enter edit mode while day is active")
		return false
	
	if _registry == null:
		push_error("[EditModeController] Registry not available")
		return false
	
	_is_in_edit_mode = true
	_current_mode = MODE_NONE
	_rotation_step = 0
	
	print("[EditModeController] Entered edit mode")
	edit_mode_entered.emit()
	return true

func exit_edit_mode() -> void:
	if not _is_in_edit_mode:
		return
	
	_cancel_current_operation()
	_is_in_edit_mode = false
	_current_mode = MODE_NONE
	_selected_placeable = null
	
	print("[EditModeController] Exited edit mode")
	edit_mode_exited.emit()

func is_in_edit_mode() -> bool:
	return _is_in_edit_mode

func get_current_mode() -> StringName:
	return _current_mode

func get_selected_placeable() -> Node2D:
	return _selected_placeable

# Start placing a new placeable
func start_placing_new(placeable_type: String, resource_id: String = "") -> bool:
	if not _is_in_edit_mode:
		return false
	
	_cancel_current_operation()
	
	_pending_placeable_type = placeable_type
	_pending_resource_id = resource_id
	_current_mode = MODE_PLACING_NEW
	_rotation_step = 0
	
	_create_preview()
	return true

# Start moving an existing placeable
func start_moving_existing(placeable: Node2D) -> bool:
	if not _is_in_edit_mode or placeable == null:
		return false
	
	_cancel_current_operation()
	
	_selected_placeable = placeable
	_original_position = placeable.global_position
	_original_rotation_step = _get_placeable_rotation_step(placeable)
	_current_mode = MODE_MOVING_EXISTING
	_rotation_step = _original_rotation_step
	
	_create_preview_for_existing(placeable)
	placeable_selected.emit(placeable)
	return true

# Select an existing placeable (for deletion or moving)
func select_placeable_at(mouse_position: Vector2) -> Node2D:
	if not _is_in_edit_mode:
		return null
	
	if _current_mode != MODE_NONE:
		return null
	
	var cell: Vector2i = _floor_layer.local_to_map(_floor_layer.to_local(mouse_position))
	
	# Find placeable at this cell
	var placeables: Array[Node2D] = _registry.get_registered_placeables()
	for placeable in placeables:
		var cells: Array[Vector2i] = _get_placeable_cells(placeable, placeable.global_position)
		if cell in cells:
			_selected_placeable = placeable
			placeable_selected.emit(placeable)
			return placeable
	
	_selected_placeable = null
	placeable_deselected.emit()
	return null

func delete_selected_placeable() -> bool:
	if not _is_in_edit_mode or _selected_placeable == null:
		return false
	
	var placeable_id: String = _selected_placeable.get("placeable_id") if _selected_placeable.has_method("get_placeable_type_key") else ""
	if placeable_id.is_empty():
		return false
	
	_registry.remove_placeable(placeable_id)
	_selected_placeable = null
	placeable_deselected.emit()
	return true

func rotate_preview() -> void:
	_rotation_step = (_rotation_step + 1) % 4
	if _current_preview != null:
		_current_preview.set_rotation_step(_rotation_step)
		_update_validation()

func confirm_placement() -> bool:
	if not _is_in_edit_mode or _current_preview == null:
		return false
	
	var mouse_pos: Vector2 = _current_preview.global_position
	
	if _current_mode == MODE_PLACING_NEW:
		return _confirm_new_placement(mouse_pos)
	elif _current_mode == MODE_MOVING_EXISTING:
		return _confirm_move_placement(mouse_pos)
	
	return false

func cancel_operation() -> void:
	_cancel_current_operation()

func _cancel_current_operation() -> void:
	if _current_preview != null:
		_current_preview.queue_free()
		_current_preview = null
	
	if _current_mode == MODE_MOVING_EXISTING and _selected_placeable != null:
		# Restore original position
		_selected_placeable.global_position = _original_position
		_set_placeable_rotation_step(_selected_placeable, _original_rotation_step)
	
	_current_mode = MODE_NONE
	_pending_placeable_type = ""
	_pending_resource_id = ""
	_rotation_step = 0
	
	if _temp_placeable != null:
		_temp_placeable.queue_free()
		_temp_placeable = null

func _confirm_new_placement(target_position: Vector2) -> bool:
	if _temp_placeable == null:
		return false
	
	var validation: Dictionary = _registry.validate_placeable_candidate(_temp_placeable, target_position, _rotation_step)
	if not validation.get("ok", false):
		print("[EditModeController] Cannot place: %s" % validation.get("reason", "unknown"))
		return false
	
	var result: Dictionary = _registry.commit_placeable_state(_temp_placeable, target_position, _rotation_step)
	if not result.get("ok", false):
		return false
	
	# Clean up preview
	if _current_preview != null:
		_current_preview.queue_free()
		_current_preview = null
	
	_temp_placeable = null
	_current_mode = MODE_NONE
	_pending_placeable_type = ""
	_pending_resource_id = ""
	_rotation_step = 0
	
	return true

func _confirm_move_placement(target_position: Vector2) -> bool:
	if _selected_placeable == null:
		return false
	
	var ignore_id: String = _selected_placeable.get("placeable_id") if _selected_placeable.has_method("get_placeable_type_key") else ""
	var validation: Dictionary = _registry.validate_placeable_candidate(_selected_placeable, target_position, _rotation_step, ignore_id)
	if not validation.get("ok", false):
		print("[EditModeController] Cannot move: %s" % validation.get("reason", "unknown"))
		return false
	
	var result: Dictionary = _registry.commit_placeable_state(_selected_placeable, target_position, _rotation_step, ignore_id)
	if not result.get("ok", false):
		return false
	
	# Clean up preview
	if _current_preview != null:
		_current_preview.queue_free()
		_current_preview = null
	
	_selected_placeable = null
	_current_mode = MODE_NONE
	_rotation_step = 0
	
	return true

func _create_preview() -> void:
	# Create temporary placeable for preview
	_temp_placeable = _create_temp_placeable(_pending_placeable_type, _pending_resource_id)
	if _temp_placeable == null:
		return
	
	_current_preview = PlacementPreview.new()
	_current_preview.setup(_temp_placeable, _floor_layer)
	_current_preview.set_rotation_step(_rotation_step)
	add_child(_current_preview)

func _create_preview_for_existing(placeable: Node2D) -> void:
	_current_preview = PlacementPreview.new()
	_current_preview.setup(placeable, _floor_layer)
	_current_preview.set_rotation_step(_rotation_step)
	add_child(_current_preview)
	
	# Hide the original placeable while moving
	placeable.visible = false

func _create_temp_placeable(placeable_type: String, resource_id: String) -> Node2D:
	var scene: PackedScene = null
	if placeable_type == "table":
		scene = table_scene
	elif placeable_type == "chair":
		scene = chair_scene
	
	if scene == null:
		push_error("[EditModeController] Unknown placeable type: %s" % placeable_type)
		return null
	
	var instance: Node2D = scene.instantiate() as Node2D
	if instance == null:
		return null
	
	# Set resource data if specified
	if not resource_id.is_empty() and instance.has_method("set_placeable_resource_id"):
		instance.call("set_placeable_resource_id", resource_id)
	
	return instance

func _get_placeable_rotation_step(placeable: Node2D) -> int:
	if placeable.has_method("get_placeable_rotation_step"):
		return placeable.call("get_placeable_rotation_step") as int
	return 0

func _set_placeable_rotation_step(placeable: Node2D, step: int) -> void:
	if placeable.has_method("set_placeable_rotation_step"):
		placeable.call("set_placeable_rotation_step", step)

func _get_placeable_cells(placeable: Node2D, position: Vector2) -> Array[Vector2i]:
	if placeable.has_method("get_placeable_footprint_cells"):
		var cells: Array = placeable.call("get_placeable_footprint_cells")
		var result: Array[Vector2i] = []
		var origin: Vector2i = _floor_layer.local_to_map(_floor_layer.to_local(position))
		var rotation_step: int = _get_placeable_rotation_step(placeable)
		
		for cell in cells:
			var rotated: Vector2i = _rotate_cell(cell as Vector2i, rotation_step)
			result.append(origin + rotated)
		return result
	return [Vector2i.ZERO]

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

func update_preview_position(mouse_position: Vector2) -> void:
	if _current_preview == null:
		return
	
	# Snap to grid
	var local_pos: Vector2 = _floor_layer.to_local(mouse_position)
	var cell: Vector2i = _floor_layer.local_to_map(local_pos)
	var snapped_pos: Vector2 = _floor_layer.to_global(_floor_layer.map_to_local(cell))
	
	_current_preview.global_position = snapped_pos
	_update_validation()

func _update_validation() -> void:
	if _current_preview == null or _registry == null:
		return
	
	var target_position: Vector2 = _current_preview.global_position
	var ignore_id: String = ""
	var placeable: Node2D = _temp_placeable if _current_mode == MODE_PLACING_NEW else _selected_placeable
	
	if _current_mode == MODE_MOVING_EXISTING and _selected_placeable != null:
		ignore_id = _selected_placeable.get("placeable_id") if _selected_placeable.has_method("get_placeable_type_key") else ""
	
	var validation: Dictionary = _registry.validate_placeable_candidate(placeable, target_position, _rotation_step, ignore_id)
	var is_valid: bool = validation.get("ok", false)
	var reason: String = validation.get("reason", "unknown")
	
	_current_preview.set_valid(is_valid)
	validation_changed.emit(is_valid, _get_validation_message(reason))

func _get_validation_message(reason: String) -> String:
	match reason:
		PlaceableRuntimeRegistry.REASON_OK:
			return "Valid placement"
		PlaceableRuntimeRegistry.REASON_MISSING_ANCHORS:
			return "Missing required scene anchors"
		PlaceableRuntimeRegistry.REASON_OUT_OF_FLOOR_BOUNDS:
			return "Outside floor bounds"
		PlaceableRuntimeRegistry.REASON_OCCUPIED:
			return "Cell already occupied"
		PlaceableRuntimeRegistry.REASON_BLOCKED_ROUTE:
			return "Would block required route"
		PlaceableRuntimeRegistry.REASON_NO_SEAT_ROUTE:
			return "No reachable seat from entry"
		_:
			return "Invalid placement: %s" % reason

func _process(_delta: float) -> void:
	if not _is_in_edit_mode:
		return
	
	# Update preview position to follow mouse
	if _current_preview != null:
		update_preview_position(get_viewport().get_mouse_position())

func _unhandled_input(event: InputEvent) -> void:
	if not _is_in_edit_mode:
		return
	
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if _current_mode == MODE_NONE:
				# Try to select existing placeable
				select_placeable_at(mouse_event.global_position)
	elif event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		
		if key_event.pressed:
			match key_event.keycode:
				KEY_ENTER, KEY_KP_ENTER:
					if _current_mode != MODE_NONE:
						confirm_placement()
				KEY_R:
					rotate_preview()
				KEY_ESCAPE:
					if _current_mode != MODE_NONE:
						cancel_operation()
					else:
						exit_edit_mode()
				KEY_DELETE, KEY_BACKSPACE:
					if _selected_placeable != null and _current_mode == MODE_NONE:
						delete_selected_placeable()

func get_pending_placeable_type() -> String:
	return _pending_placeable_type

func get_rotation_step() -> int:
	return _rotation_step
