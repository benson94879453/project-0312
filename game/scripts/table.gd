extends StaticBody2D
class_name Table

# 接收設計師配好的資料 (也可以從 Manager 讀取)
@export var data: TableData 
#是否在遊戲畫面中顯示座位除錯點
@export var show_debug_seats: bool = true
# 臨時數據：裝真正的餐點資料
var foods_on_table: Array[FoodData] = []
var slot_sprites: Array[Sprite2D] = []

@onready var sprite: Sprite2D = $TableSprite
@onready var hitbox: CollisionShape2D = $Hitbox
@onready var interactbox: CollisionShape2D = $InteractableComponent/Interactbox
@onready var slots_container: Node2D = $FoodSlots

func _ready() -> void:
	if data:
		_initialize_from_data()

func _initialize_from_data() -> void:
	# 1. 設定圖片
	sprite.texture = data.texture
	sprite.offset = data.sprite_offset #偏移量
	# 2. 動態生成物理與互動範圍 (使用 RectangleShape2D)
	var h_shape = RectangleShape2D.new()
	h_shape.size = data.hitbox_size
	hitbox.shape = h_shape
	# 設定物理碰撞體的位置
	hitbox.position = data.hitbox_offset
	
	var i_shape = RectangleShape2D.new()
	i_shape.size = data.interactbox_size
	interactbox.shape = i_shape
	
	# 3. 動態生成餐點槽位
	foods_on_table.resize(data.slot_positions.size())
	foods_on_table.fill(null) # 初始化為空
	
	for i in range(data.slot_positions.size()):
		var new_slot_sprite = Sprite2D.new()
		new_slot_sprite.offset = data.slot_positions[i]
		new_slot_sprite.position = Vector2.ZERO
		# 如果需要，這裡也可以設定槽位在 Y-Sort 的微調
		slots_container.add_child(new_slot_sprite)
		slot_sprites.append(new_slot_sprite)

#chair
# 儲存這張桌子目前擁有的小弟 (椅子) 與可用的座位絕對座標
var available_seats: Array[Dictionary] = [] # position + direction
var connected_chairs: Array[Chair] = []

func register_new_seats(chair: Chair, seat_info_list: Array[Dictionary]) -> void:
	if not connected_chairs.has(chair):
		connected_chairs.append(chair)
		
		# 把椅子送來的字典陣列，全部倒進桌子的可用清單裡
		available_seats.append_array(seat_info_list)

# 除錯工具：把資料畫在螢幕上
func _draw() -> void:
	if not show_debug_seats or available_seats.is_empty():
		return
		
	for seat in available_seats:
		# 畫布 API 只能畫「相對於桌子本身」的本地座標，所以要轉回來
		var local_pos = to_local(seat["position"])
		var dir = seat["direction"]
		
		# 畫一個半透明的綠色圓圈 (半徑 4) 代表座位點
		draw_circle(local_pos, 4.0, Color(0, 1, 0, 0.5))
		# 畫一條紅線代表椅子的朝向 (長度 10)
		draw_line(local_pos, local_pos + (dir * 10.0), Color(1, 0, 0, 0.8), 2.0)
