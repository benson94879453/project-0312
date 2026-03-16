extends Resource
class_name ChairData

@export_category("Information")
@export var chair_id: String = "chair_basic"
@export var texture: Texture2D
@export var sprite_offset: Vector2 = Vector2(0, -8) 

@export_category("PositionSetting")
@export var hitbox_size: Vector2 = Vector2(16, 16)

@export_category("SeatData")

# 這張椅子的位子資料表，seat_slot_position是相對於椅子中心的座標
@export var seats: Array[SeatSlotData] = []
