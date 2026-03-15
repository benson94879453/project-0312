extends StaticBody2D
class_name Chair

@export var data: ChairData
@export var facing_direction: Vector2 = Vector2.DOWN

@onready var sprite: Sprite2D = $ChairSprite
@onready var hitbox: CollisionShape2D = $Hitbox
@onready var table_detector: Area2D = $TableDetector


var registered_table: Node2D = null # 記錄自己屬於哪張桌子

func _ready() -> void:
	if data:
		_initialize_from_data()
	
	# 啟動動態註冊流程
	_attempt_register_to_table()

func _initialize_from_data() -> void:
	sprite.texture = data.texture
	sprite.offset = data.sprite_offset
	
	var h_shape = RectangleShape2D.new()
	h_shape.size = data.hitbox_size
	hitbox.shape = h_shape

func _attempt_register_to_table() -> void:
	# 連等兩個物理幀，保證 CollisionTree 絕對建立完畢(AI建議的,我不確定正確性)
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	# 取得雷達範圍內碰到的所有物理實體
	var overlapping_bodies = table_detector.get_overlapping_bodies()
	
	for body in overlapping_bodies:
		# 檢查碰到的東西是不是桌子
		if body is Table:
			_bind_to_table(body)
			return # 找到一張桌子就夠了，結束尋找

func _bind_to_table(table: Table) -> void:
	registered_table = table
	
	# 核心升級：將單純的座標陣列，改成「包含座標與方向的字典陣列」
	var seat_info_list: Array[Dictionary] = []
	
	# slot 現在的型別是我們自訂的 SeatSlotData
	for slot in data.seats:
		var info = {
			# 型別安全：Vector2 + Vector2
			"position": global_position + slot.seat_slot_position,
			# 每個座位可以擁有自己的獨立朝向！
			"direction": slot.seat_slot_direction 
		}
		seat_info_list.append(info)
	
	table.register_new_seats(self, seat_info_list)
	print("椅子註冊成功！座位數: ", seat_info_list.size(), "，整體朝向: ", facing_direction)
