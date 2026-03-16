extends Camera2D

@export var target_path: NodePath
var target: Node2D

var actual_cam_pos: Vector2


func _ready() -> void:
	if target_path != NodePath():
		target = get_node_or_null(target_path) as Node2D
	if target == null and has_node(target_path):
		target = get_node(target_path) as Node2D
	if target != null:
		actual_cam_pos = target.global_position
	else:
		actual_cam_pos = global_position


func _physics_process(delta: float) -> void:
	if target == null:
		return

	actual_cam_pos = actual_cam_pos.lerp(target.global_position, delta * 3)

	var cam_subpixel_offset: Vector2 = actual_cam_pos.round() - actual_cam_pos
	SignalManager.sub_pixel_offset_updated.emit(cam_subpixel_offset)
	global_position = actual_cam_pos.round()
