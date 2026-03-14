extends Camera2D

var actual_cam_pos: Vector2


func _process(delta: float) -> void:
	
	actual_cam_pos = actual_cam_pos.lerp(%Player.global_position, delta * 3)
	
	var cam_subpixel_offset = actual_cam_pos.round() - actual_cam_pos
	
	#send to shader
	SignalManager.sub_pixel_offset_updated.emit(cam_subpixel_offset)
	
	#set camera position
	global_position = actual_cam_pos.round() 
