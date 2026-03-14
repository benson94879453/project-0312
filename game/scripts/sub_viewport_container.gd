extends SubViewportContainer

func _ready() -> void:
	# 訂閱信號
	SignalManager.sub_pixel_offset_updated.connect(_on_offset_updated)

func _on_offset_updated(offset: Vector2) -> void:
	# 接收到資料後，修改自己身上的 Shader 參數
	material.set_shader_parameter("cam_offset", offset)
