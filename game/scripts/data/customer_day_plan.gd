extends Resource
class_name CustomerDayPlan

## Per-customer day plan record
## Generated at day start, persisted in save, consumed by runtime spawner
## NOTE: This is plan data, not live runtime state

@export var customer_plan_id: String = ""      ## Unique ID for this customer instance
@export var arrival_time_seconds: float = 0.0  ## When to spawn (relative to day start)
@export var order_pool: Array[String] = []     ## Possible orders (random selection at spawn)
@export var patience_seconds: float = 60.0     ## How long they'll wait before leaving
@export var preferred_table_id: String = ""    ## Optional: specific table request (stable ID)
@export var status: String = "pending"         ## pending/active/completed/lost
@export var attributes: Dictionary = {}        ## Extra traits (vip, rushed, etc.)
