extends SubViewportContainer

func _ready() -> void:
	SignalManager.sub_pixel_offset_updated.connect(_on_offset_updated)

func _on_offset_updated(offset: Vector2) -> void:
	material.set_shader_parameter("cam_offset", offset)
