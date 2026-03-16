extends Resource
class_name TableData

@export_category("基本資訊")
@export var table_id: String = "table_basic"
@export var texture: Texture2D
# 新增這行：決定圖片要往上偏移多少像素
@export var sprite_offset: Vector2 = Vector2(0, -16)

@export_category("物理與互動 (長方形寬高)")
@export var hitbox_size: Vector2 = Vector2(32, 16)       # 擋路的實體大小 (通常只包住桌腳)
# Hitbox 預設也需要稍微往上一點，才不會讓桌腳踩在原點正中央
@export var hitbox_offset: Vector2 = Vector2(0, -8)
@export var interactbox_size: Vector2 = Vector2(48, 48)  # 觸發互動的範圍大小

@export_category("餐點槽位配置")
# 陣列長度 = 可放幾份餐點。 Vector2 = 每一份餐點相對於桌子中心的座標
@export var slot_positions: Array[Vector2] = [
	Vector2(-10, -5), # 左上
	Vector2(10, -5),  # 右上
	Vector2(-10, 5),  # 左下
	Vector2(10, 5)    # 右下
]
