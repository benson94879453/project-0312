extends Resource
class_name PlaceableRecord

## Serialized placeable record for save/load
## Stores durable data needed to recreate a placeable instance after reload
## NOTE: Uses stable IDs only - no NodePaths or runtime references

@export var placeable_id: String = ""          ## Stable ID (persists across saves)
@export var type_key: String = ""              ## "table" or "chair"
@export var resource_id: String = ""           ## Resource identifier (table_id/chair_id from TableData/ChairData)
@export var grid_x: int = 0                    ## Grid X coordinate
@export var grid_y: int = 0                    ## Grid Y coordinate
@export var rotation_step: int = 0             ## Rotation (0-3 representing 0°, 90°, 180°, 270°)
@export var linked_placeable_id: String = ""   ## For chairs: linked table's stable ID (empty if unlinked)
