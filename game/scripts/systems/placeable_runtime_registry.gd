extends Node
class_name PlaceableRuntimeRegistry

signal registry_rebuilt

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.UP,
	Vector2i.DOWN,
]

const REASON_OK: String = "ok"
const REASON_MISSING_ANCHORS: String = "missing_scene_anchors"
const REASON_OUT_OF_FLOOR_BOUNDS: String = "out_of_floor_bounds"
const REASON_OCCUPIED: String = "occupied_cells"
const REASON_BLOCKED_ROUTE: String = "blocked_required_route"
const REASON_NO_SEAT_ROUTE: String = "no_reachable_seat"

@export var navigation_region_path: NodePath
@export var floor_path: NodePath
@export var wall_path: NodePath
@export var object_container_path: NodePath
@export var entry_anchor_path: NodePath
@export var leave_anchor_path: NodePath

var _navigation_region: NavigationRegion2D = null
var _floor_layer: TileMapLayer = null
var _wall_layer: TileMapLayer = null
var _object_container: Node = null
var _entry_anchor: Node2D = null
var _leave_anchor: Node2D = null

var _placeables_by_id: Dictionary = {}
var _occupied_cells: Dictionary = {}
var _floor_cells: Dictionary = {}
var _wall_cells: Dictionary = {}
var _id_counter: int = 0
var _refresh_queued: bool = false

func _ready() -> void:
	_resolve_scene_anchors()
	_connect_container_signals()
	call_deferred("rebuild_registry")

func get_placeable(placeable_id: String) -> Node2D:
	return _placeables_by_id.get(placeable_id, null) as Node2D

func has_placeable(placeable_id: String) -> bool:
	return _placeables_by_id.has(placeable_id)

func get_registered_placeables() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for placeable in _placeables_by_id.values():
		var node: Node2D = placeable as Node2D
		if node != null:
			result.append(node)
	return result

func get_floor_layer() -> TileMapLayer:
	return _floor_layer

func get_object_container() -> Node:
	return _object_container

func get_entry_anchor() -> Node2D:
	return _entry_anchor

func get_leave_anchor() -> Node2D:
	return _leave_anchor

func world_to_map(world_position: Vector2) -> Vector2i:
	if _floor_layer == null:
		return Vector2i.ZERO
	return _world_to_map(world_position)

func map_to_world(cell: Vector2i) -> Vector2:
	if _floor_layer == null:
		return Vector2.ZERO
	return _floor_layer.to_global(_floor_layer.map_to_local(cell))

func rebuild_registry() -> void:
	_refresh_queued = false
	_resolve_scene_anchors()
	if not _has_required_anchors():
		push_warning("[PlaceableRuntimeRegistry] Missing scene anchors; registry rebuild skipped")
		return

	_cache_floor_and_wall_cells()
	_placeables_by_id.clear()
	_occupied_cells.clear()

	var tables: Array[Table] = []
	var chairs: Array[Chair] = []
	for child in _object_container.get_children():
		if child is Table:
			var table: Table = child as Table
			_ensure_placeable_id(table)
			_placeables_by_id[table.placeable_id] = table
			tables.append(table)
			_register_occupied_cells(table)
		elif child is Chair:
			var chair: Chair = child as Chair
			_ensure_placeable_id(chair)
			_placeables_by_id[chair.placeable_id] = chair
			chairs.append(chair)
			_register_occupied_cells(chair)

	_rebind_all_chairs(tables, chairs)
	registry_rebuilt.emit()

func request_registry_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("rebuild_registry")

func validate_placeable_candidate(placeable: Node2D, target_position: Vector2, rotation_step: int, ignore_placeable_id: String = "") -> Dictionary:
	if placeable == null or not _has_required_anchors():
		return _build_validation_result(false, REASON_MISSING_ANCHORS)

	var candidate_cells: Array[Vector2i] = _get_placeable_cells(placeable, target_position, rotation_step)
	for cell in candidate_cells:
		if not _floor_cells.has(cell) or _wall_cells.has(cell):
			return _build_validation_result(false, REASON_OUT_OF_FLOOR_BOUNDS, {"cell": cell})
		var occupant_id: String = String(_occupied_cells.get(cell, ""))
		if occupant_id != "" and occupant_id != ignore_placeable_id:
			return _build_validation_result(false, REASON_OCCUPIED, {"cell": cell, "occupant_id": occupant_id})

	var route_result: Dictionary = _validate_required_route(ignore_placeable_id, placeable, target_position, rotation_step, candidate_cells)
	if not route_result.get("ok", false):
		return route_result

	return _build_validation_result(true, REASON_OK, {"cells": candidate_cells})

func commit_placeable_state(placeable: Node2D, target_position: Vector2, rotation_step: int, ignore_placeable_id: String = "") -> Dictionary:
	var validation: Dictionary = validate_placeable_candidate(placeable, target_position, rotation_step, ignore_placeable_id)
	if not validation.get("ok", false):
		return validation

	if _object_container != null and placeable.get_parent() != _object_container:
		_object_container.add_child(placeable)
	if placeable is Table:
		(placeable as Table).set_placeable_rotation_step(rotation_step)
	elif placeable is Chair:
		(placeable as Chair).set_placeable_rotation_step(rotation_step)
	placeable.global_position = target_position
	rebuild_registry()
	return validation

func restore_placeable_state(placeable: Node2D, target_position: Vector2, rotation_step: int) -> Dictionary:
	if placeable == null or _object_container == null:
		return _build_validation_result(false, REASON_MISSING_ANCHORS)

	if placeable.get_parent() != _object_container:
		_object_container.add_child(placeable)
	if placeable is Table:
		(placeable as Table).set_placeable_rotation_step(rotation_step)
	elif placeable is Chair:
		(placeable as Chair).set_placeable_rotation_step(rotation_step)
	placeable.global_position = target_position
	return _build_validation_result(true, REASON_OK)

func remove_placeable(placeable_id: String) -> void:
	var placeable: Node2D = get_placeable(placeable_id)
	if placeable == null:
		print("[PlaceableRuntimeRegistry] Delete lookup failed. id=%s registered_ids=%s" % [placeable_id, _placeables_by_id.keys()])
		return
	print("[PlaceableRuntimeRegistry] Removing placeable id=%s node=%s" % [placeable_id, placeable])
	if placeable is Chair:
		(placeable as Chair).unbind_from_table()
	var parent: Node = placeable.get_parent()
	if parent != null:
		parent.remove_child(placeable)
	placeable.free()
	rebuild_registry()

func _resolve_scene_anchors() -> void:
	_navigation_region = get_node_or_null(navigation_region_path) as NavigationRegion2D
	_floor_layer = get_node_or_null(floor_path) as TileMapLayer
	_wall_layer = get_node_or_null(wall_path) as TileMapLayer
	_object_container = get_node_or_null(object_container_path)
	_entry_anchor = get_node_or_null(entry_anchor_path) as Node2D
	_leave_anchor = get_node_or_null(leave_anchor_path) as Node2D

func _has_required_anchors() -> bool:
	return _navigation_region != null and _floor_layer != null and _object_container != null and _entry_anchor != null and _leave_anchor != null

func _connect_container_signals() -> void:
	if _object_container == null:
		return
	if not _object_container.child_entered_tree.is_connected(_on_object_container_child_changed):
		_object_container.child_entered_tree.connect(_on_object_container_child_changed)
	if not _object_container.child_exiting_tree.is_connected(_on_object_container_child_changed):
		_object_container.child_exiting_tree.connect(_on_object_container_child_changed)

func _on_object_container_child_changed(_node: Node) -> void:
	request_registry_refresh()

func _cache_floor_and_wall_cells() -> void:
	_floor_cells.clear()
	_wall_cells.clear()
	if _floor_layer != null:
		for cell in _floor_layer.get_used_cells():
			_floor_cells[cell] = true
	if _wall_layer != null:
		for cell in _wall_layer.get_used_cells():
			_wall_cells[cell] = true

func _register_occupied_cells(placeable: Node2D) -> void:
	var placeable_id: String = _extract_placeable_id(placeable)
	for cell in _get_placeable_cells(placeable, placeable.global_position, _extract_rotation_step(placeable)):
		_occupied_cells[cell] = placeable_id

func _get_placeable_cells(placeable: Node2D, target_position: Vector2, rotation_step: int) -> Array[Vector2i]:
	var origin_cell: Vector2i = _world_to_map(target_position)
	var cells: Array[Vector2i] = []
	for footprint_cell in _extract_footprint_cells(placeable):
		var rotated_cell: Vector2i = _rotate_cell(footprint_cell, rotation_step)
		var final_cell: Vector2i = origin_cell + rotated_cell
		if not cells.has(final_cell):
			cells.append(final_cell)
	return cells

func _rebind_all_chairs(tables: Array[Table], chairs: Array[Chair]) -> void:
	for table in tables:
		table.clear_registered_seats()
	for chair in chairs:
		chair.clear_registered_table_reference()
	for chair in chairs:
		var target_table: Table = _find_best_table_for_chair(chair, tables)
		if target_table != null:
			chair.bind_to_table(target_table)

func _find_best_table_for_chair(chair: Chair, tables: Array[Table]) -> Table:
	var best_table: Table = null
	var best_distance: float = INF
	var bind_radius: float = chair.get_table_bind_radius()
	for table in tables:
		var distance: float = chair.global_position.distance_to(table.global_position)
		if distance > bind_radius:
			continue
		if distance < best_distance:
			best_distance = distance
			best_table = table
	return best_table

func _validate_required_route(ignore_placeable_id: String, preview_placeable: Node2D, preview_position: Vector2, preview_rotation_step: int, candidate_cells: Array[Vector2i]) -> Dictionary:
	var blocked_cells: Dictionary = {}
	for placeable_id in _placeables_by_id.keys():
		if placeable_id == ignore_placeable_id:
			continue
		var placeable: Node2D = _placeables_by_id[placeable_id] as Node2D
		if placeable == null:
			continue
		if placeable is Chair:
			continue
		for cell in _get_placeable_cells(placeable, placeable.global_position, _extract_rotation_step(placeable)):
			blocked_cells[cell] = true
	if not (preview_placeable is Chair):
		for cell in candidate_cells:
			blocked_cells[cell] = true

	var entry_cell: Vector2i = _world_to_map(_entry_anchor.global_position)
	var leave_cell: Vector2i = _world_to_map(_leave_anchor.global_position)
	var reachable: Dictionary = _collect_reachable_cells(entry_cell, blocked_cells)
	if not reachable.has(leave_cell):
		return _build_validation_result(false, REASON_BLOCKED_ROUTE, {"entry_cell": entry_cell, "leave_cell": leave_cell})

	var seat_cells: Array[Vector2i] = _collect_preview_seat_cells(ignore_placeable_id, preview_placeable, preview_position, preview_rotation_step)
	for seat_cell in seat_cells:
		if reachable.has(seat_cell):
			return _build_validation_result(true, REASON_OK, {"entry_cell": entry_cell, "leave_cell": leave_cell, "seat_cell": seat_cell})

	return _build_validation_result(false, REASON_NO_SEAT_ROUTE, {"entry_cell": entry_cell, "leave_cell": leave_cell})

func _collect_preview_seat_cells(ignore_placeable_id: String, preview_placeable: Node2D, preview_position: Vector2, preview_rotation_step: int) -> Array[Vector2i]:
	var seat_cells: Array[Vector2i] = []
	for placeable_id in _placeables_by_id.keys():
		if placeable_id == ignore_placeable_id:
			continue
		var chair: Chair = _placeables_by_id[placeable_id] as Chair
		if chair == null:
			continue
		for seat_cell in chair.get_seat_cells_for_transform(_floor_layer, chair.global_position, chair.get_placeable_rotation_step()):
			if not seat_cells.has(seat_cell):
				seat_cells.append(seat_cell)
	if preview_placeable is Chair:
		for seat_cell in (preview_placeable as Chair).get_seat_cells_for_transform(_floor_layer, preview_position, preview_rotation_step):
			if not seat_cells.has(seat_cell):
				seat_cells.append(seat_cell)
	return seat_cells

func _collect_reachable_cells(start_cell: Vector2i, blocked_cells: Dictionary) -> Dictionary:
	var reachable: Dictionary = {}
	if not _is_walkable_cell(start_cell, blocked_cells):
		return reachable

	var queue: Array[Vector2i] = [start_cell]
	reachable[start_cell] = true
	var index: int = 0
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		for direction in CARDINAL_DIRECTIONS:
			var next: Vector2i = current + direction
			if reachable.has(next):
				continue
			if not _is_walkable_cell(next, blocked_cells):
				continue
			reachable[next] = true
			queue.append(next)
	return reachable

func _is_walkable_cell(cell: Vector2i, blocked_cells: Dictionary) -> bool:
	return _floor_cells.has(cell) and not _wall_cells.has(cell) and not blocked_cells.has(cell)

func _world_to_map(world_position: Vector2) -> Vector2i:
	return _floor_layer.local_to_map(_floor_layer.to_local(world_position))

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

func _ensure_placeable_id(placeable: Node2D) -> void:
	var placeable_id: String = _extract_placeable_id(placeable)
	if not placeable_id.is_empty():
		return
	placeable.call("set_placeable_id", _generate_placeable_id(placeable))

func _generate_placeable_id(placeable: Node2D) -> String:
	_id_counter += 1
	var type_key: String = _extract_type_key(placeable)
	var resource_id: String = _extract_resource_id(placeable)
	var node_name: String = String(placeable.name).to_snake_case()
	if resource_id.is_empty():
		resource_id = "resource"
	return "%s_%s_%s_%d" % [type_key, resource_id, node_name, _id_counter]

func _extract_placeable_id(placeable: Node2D) -> String:
	return String(placeable.get("placeable_id"))

func _extract_type_key(placeable: Node2D) -> String:
	return String(placeable.call("get_placeable_type_key"))

func _extract_resource_id(placeable: Node2D) -> String:
	return String(placeable.call("get_placeable_resource_id"))

func _extract_rotation_step(placeable: Node2D) -> int:
	return int(placeable.call("get_placeable_rotation_step"))

func _extract_footprint_cells(placeable: Node2D) -> Array[Vector2i]:
	var raw_footprint: Array = placeable.call("get_placeable_footprint_cells")
	var footprint_cells: Array[Vector2i] = []
	for cell in raw_footprint:
		footprint_cells.append(cell as Vector2i)
	if footprint_cells.is_empty():
		return [Vector2i.ZERO]
	return footprint_cells

func _build_validation_result(ok: bool, reason: String, extra: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"ok": ok, "reason": reason}
	for key in extra.keys():
		result[key] = extra[key]
	return result
