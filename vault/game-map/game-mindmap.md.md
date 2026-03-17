# project-0312 Game Mind Map

## Project
### Engine
#### Godot 4.6
### Main Scene
#### game/playground/main.tscn
### Autoload
#### SignalManager
#### ItemDatabase

## Game
### Scenes
#### game/playground/main.tscn
#### game/playground/test.tscn
#### game/playground/player.tscn
#### game/playground/table.tscn
#### game/playground/chair.tscn
#### game/playground/customer.tscn

### Scripts
#### Actors
##### game/scripts/actors/player.gd
##### game/scripts/actors/table.gd
##### game/scripts/actors/chair.gd
##### game/scripts/actors/customer.gd
#### Components
##### Player Components
###### game/scripts/components/player_movement_component.gd
###### game/scripts/components/player_state_machine.gd
###### game/scripts/components/player_visual_component.gd
###### game/scripts/components/player_interact.gd
###### game/scripts/components/player_held_item.gd
##### Customer Components
###### game/scripts/components/customer_state_machine.gd
###### game/scripts/components/customer_movement_component.gd
###### game/scripts/components/customer_visual_component.gd
#### Systems
##### game/scripts/systems/subpixel_camera.gd
##### game/scripts/systems/sub_viewport_container.gd
##### game/scripts/systems/signal_manager.gd
##### game/scripts/systems/item_database.gd
##### game/scripts/systems/service_debug_hud.gd
#### Resource Scripts
##### game/scripts/resources/food_data.gd
##### game/scripts/resources/table_data.gd
##### game/scripts/resources/chair_data.gd
##### game/scripts/resources/seat_slot_data.gd
##### game/scripts/resources/order_data.gd

### Data Assets
#### game/data/foods
##### food_coffee.tres
#### game/data/tables
##### wooden_table_a.tres
#### game/data/chairs
##### low_sofa_a.tres

## Runtime Flow
### Player Movement
#### Input actions ui_left ui_right ui_up ui_down run
#### MovementComponent computes velocity
#### Player applies move_and_slide in physics
#### StateMachine updates IDLE WALK RUN
#### VisualComponent floating animation + flip

### Player Interaction Serving
#### Player InteractionComponent listens interact action E
#### request_interaction scans overlapping bodies and areas
#### Target interact actor method is called
#### Table checks get_held_food from player
#### Table validates order match and free slot
#### Table emits order_served signal
#### Customer receives food and starts eating

### Customer Lifecycle
#### Spawn -> Seeking Seat -> Moving to Seat
#### Reached Seat -> Ordering -> Waiting Food
#### Order Served -> Eating timer
#### Eating Done -> Leaving -> Release Seat

### Table And Chair
#### Chair detects nearby Table physics frame delay
#### Chair registers seat info to Table
#### Table stores connected_chairs and available_seats
#### Customer reserves seat through Table
#### Seat state available -> occupied -> available

### Subpixel Rendering
#### Camera follows target_path NodePath
#### Camera emits offset via SignalManager
#### SubViewportContainer applies cam_offset to shader

## Status
### Completed
#### chair.gd moved to scripts/actors
#### scripts split into actors/components/systems/resources
#### scene tmp files removed
#### gitignore ignores tscn tmp files
#### item database has validation and warnings
#### interact input action added to project settings
#### explicit types added to avoid Variant inference
#### Customer system fully implemented
#### Table.reserve_seat / release_seat working
#### Order creation and submission flow
#### Food serving validation order match + slot check
#### Customer eating timer and leaving flow
#### ServiceDebugHud for monitoring state

### Remaining Technical Debt
#### target_path fallback logic in camera can be removed later
#### formal IInteractable interface still not defined using has_method
#### add smoke tests for interaction and data loading
#### unify VisualComponent for Player and Customer

## Roadmap
### Milestone 1 Foundation Completed
#### Directory restructuring
#### Basic interaction system
#### ItemDatabase with validation

### Milestone 2 Playable Core v1 Completed
#### Player movement and interaction
#### Table interact actor with seat info
#### Customer lifecycle Enter -> Sit -> Order -> Eat -> Leave

### Milestone 3 Seat System Production Completed
#### Seat state model available/occupied/occupied_by
#### Table.reserve_seat actor / release_seat actor
#### Duplicate reservation prevention

### Milestone 4 NPC Service Flow v1 Completed
#### NPC state machine
#### NPC find seat and sit
#### Serving changes state
#### Leaving releases seat

### Milestone 5 Economy Loop v1 Pending
#### Use FoodData.price for settlement
#### UI showing income and service status
#### Timed shift and settlement screen

### Milestone 6 Save Load Pending
#### Daily business data save
#### Player progress persistence
