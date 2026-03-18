extends Resource
class_name DaySnapshot

## Save snapshot schema for a single-slot save system
## Represents the "latest completed/generated day boundary in pre-open state"
## 
## LOAD TARGET SEMANTICS (IMPORTANT):
## - This represents the state AFTER a day has completed or been generated
## - NOT mid-day runtime state - only pre-open boundary data
## - When loaded: DayManager.is_day_active should be false
## - Placeables are rebuilt from records, not deserialized from live instances
## - Customer plans exist as data but NO live customer nodes are spawned yet
## - Player must manually start the day to begin gameplay

@export var save_version: int = 1              ## Schema version for migration
@export var day_index: int = 1                 ## Current day number
@export var money: int = 0                     ## Player total money
@export var placeable_records: Array[PlaceableRecord] = []      ## Array of PlaceableRecord (furniture layout)
@export var customer_day_plans: Array[CustomerDayPlan] = []     ## Array of CustomerDayPlan (generated plan)
@export var timestamp_iso: String = ""         ## Save time (ISO 8601 format)
