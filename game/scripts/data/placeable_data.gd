extends Resource
class_name PlaceableData

## Generic placeable data contract for runtime placement candidates
## This defines the configuration data for any placeable object (table, chair, future decor)

@export var placeable_id: String = ""          ## Unique stable identifier
@export var type_key: String = ""              ## "table", "chair", "decor", etc.
@export var resource_path: String = ""         ## Path to TableData/ChairData resource
@export var grid_position: Vector2i = Vector2i.ZERO  ## Grid cell coordinates
@export var rotation_step: int = 0             ## 0=0°, 1=90°, 2=180°, 3=270°
@export var metadata: Dictionary = {}          ## Type-specific extra data
