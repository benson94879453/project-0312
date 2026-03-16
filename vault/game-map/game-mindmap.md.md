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

### Scripts
#### Actors
##### game/scripts/actors/player.gd
##### game/scripts/actors/table.gd
##### game/scripts/actors/chair.gd
#### Components
##### game/scripts/components/movement_component.gd
##### game/scripts/components/state_machine.gd
##### game/scripts/components/visual_component.gd
##### game/scripts/components/interact.gd
#### Systems
##### game/scripts/systems/subpixel_camera.gd
##### game/scripts/systems/sub_viewport_container.gd
##### game/scripts/systems/signal_manager.gd
##### game/scripts/systems/item_database.gd
#### Resource Scripts
##### game/scripts/resources/food_data.gd
##### game/scripts/resources/table_data.gd
##### game/scripts/resources/chair_data.gd
##### game/scripts/resources/seat_slot_data.gd

### Data Assets
#### game/data/foods
##### food_coffee.tres
#### game/data/tables
##### wooden_table_a.tres
#### game/data/chairs
##### low_sofa_a.tres

### Runtime Flow
#### Player Movement
##### Input actions ui_left ui_right ui_up ui_down run
##### MovementComponent computes velocity
##### Player applies move_and_slide in physics
##### StateMachine updates IDLE WALK RUN
#### Interaction
##### Player InteractionComponent listens interact action
##### request_interaction scans overlapping bodies and areas
##### Target interact(actor) method is called when present
##### Table implements interact(actor) basic debug behavior
#### Subpixel Rendering
##### Camera follows target_path NodePath
##### Camera emits offset via SignalManager
##### SubViewportContainer applies cam_offset to shader
#### Table And Chair
##### Chair detects nearby Table
##### Chair registers seat info to Table
##### Table stores connected chairs and available seats

### Status
#### Completed
##### chair.gd moved to scripts actors
##### scripts split into actors components systems resources
##### scene tmp files removed
##### gitignore ignores tscn tmp files
##### item database has validation and warnings
##### interact input action added to project settings
##### explicit types added to avoid Variant inference
#### Remaining Technical Debt
##### target_path fallback logic in camera can be removed later
##### formal IInteractable interface still not defined
##### add smoke tests for interaction and data loading

### Roadmap
#### NPC and seat reservation
#### Order and serving loop
#### Economy and day summary
#### SaveLoad
