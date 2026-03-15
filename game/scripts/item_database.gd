extends Node

# 儲存所有餐點的字典
var _database: Dictionary = {}

# 設定你要掃描的資料夾路徑 (資料夾必須存在)
const FOODS_DIR = "res://game/data/foods/"

func _ready() -> void:
	# 遊戲一啟動就自動掃描
	_scan_and_load_items(FOODS_DIR)

# --- 核心：自動掃描邏輯 ---
func _scan_and_load_items(path: String) -> void:
	var dir = DirAccess.open(path)
	
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			# 確保它不是資料夾，且是檔案
			if not dir.current_is_dir():				
				# 處理匯出後的 .remap 副檔名(預留,無意義)
				var clean_file_name = file_name.trim_suffix(".remap")
				# 確保只讀取 .tres 資源檔
				if clean_file_name.ends_with(".tres"):
					var full_path = path + clean_file_name					
					# 動態載入資源,不能用preload
					var item_data = load(full_path) as FoodData
					_register_item(item_data)
					
			# 讀取下一個檔案
			file_name = dir.get_next()
			
		print("資料庫初始化完成，共載入 ", _database.size(), " 筆餐點資料。")
	else:
		push_error("無法開啟餐點資料夾，請檢查路徑是否存在: ", path)

# 註冊與獲取邏輯 (與之前相同) 
func _register_item(item: FoodData) -> void:
	if item != null and item.id != "":
		_database[item.id] = item
		print("  - 成功註冊: ", item.id)

func get_item(id: String) -> FoodData:
	if _database.has(id):
		return _database[id]
	push_warning("資料庫找不到物品 ID: ", id)
	return null
