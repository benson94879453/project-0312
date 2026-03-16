extends Node

var _database: Dictionary = {}
const FOODS_DIR: String = "res://game/data/foods/"

func _ready() -> void:
	_scan_and_load_items(FOODS_DIR)

func _scan_and_load_items(path: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		push_error("[ItemDatabase] Failed to open dir: %s" % path)
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var clean_file_name: String = file_name.trim_suffix(".remap")
			if clean_file_name.ends_with(".tres"):
				var full_path: String = path.path_join(clean_file_name)
				var item_data: FoodData = load(full_path) as FoodData
				_register_item(item_data, full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("[ItemDatabase] Loaded %d item(s)." % _database.size())

func _register_item(item: FoodData, source_path: String) -> void:
	if item == null:
		push_warning("[ItemDatabase] Skip invalid resource: %s" % source_path)
		return
	if item.id.is_empty():
		push_warning("[ItemDatabase] Skip item without id: %s" % source_path)
		return
	if _database.has(item.id):
		push_warning("[ItemDatabase] Duplicate id '%s' from %s" % [item.id, source_path])
		return

	_database[item.id] = item
	print("[ItemDatabase] Registered: %s" % item.id)

func get_item(id: String) -> FoodData:
	if _database.has(id):
		return _database[id]
	push_warning("[ItemDatabase] Missing item id: %s" % id)
	return null
