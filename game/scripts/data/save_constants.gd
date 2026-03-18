extends RefCounted
class_name SaveConstants

## Save system constants and versioning
## Central location for all save-related constants to ensure consistency

# ============================================
# Versioning
# ============================================
const SAVE_VERSION: int = 1                    ## Current save schema version
const MIN_COMPATIBLE_VERSION: int = 1          ## Minimum loadable version (for migration)

# ============================================
# File Paths
# ============================================
const SAVE_FILE_PATH: String = "user://save_slot_1.json"  ## Single-slot save location

# ============================================
# Placeable Type Keys
# ============================================
const TYPE_TABLE: String = "table"
const TYPE_CHAIR: String = "chair"
const TYPE_DECOR: String = "decor"

# ============================================
# Customer Plan Status Values
# ============================================
const STATUS_PENDING: String = "pending"
const STATUS_ACTIVE: String = "active"
const STATUS_COMPLETED: String = "completed"
const STATUS_LOST: String = "lost"

# ============================================
# Rotation Steps (0-3 representing degrees/90)
# ============================================
const ROTATION_0: int = 0      ## 0 degrees
const ROTATION_90: int = 1     ## 90 degrees
const ROTATION_180: int = 2    ## 180 degrees
const ROTATION_270: int = 3    ## 270 degrees
