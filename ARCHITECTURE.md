# Architecture Overview

## Purpose

This document describes the current runtime architecture of `project-0312` as implemented in the Godot project today. It focuses on the actual scene entry path, autoload services, gameplay flow, UI control chain, and module boundaries.

The project is structured around a small set of global services plus scene-local actors and components:

- `Main` owns rendering presentation through a `SubViewportContainer` wrapper.
- `TestScene` is the current gameplay scene where world objects, player, customers, and UI are instantiated.
- Autoload singletons provide event routing, item lookup, economy state, and day-cycle control.
- Scene actors (`Player`, `Customer`, `Table`, `Chair`) delegate behavior into focused component scripts where appropriate.

## Runtime Entry Path

### Main scene

The configured entry point is `res://game/playground/main.tscn`, declared in `project.godot`.

Runtime chain:

```text
project.godot
  -> game/playground/main.tscn
	  -> SubViewportContainer
		  -> SubViewport
			  -> game/playground/test.tscn
```

Key roles:

- `game/playground/main.tscn`
  - Presentation shell for the playable scene.
  - Applies the sub-pixel shader material to the viewport container.
  - Instances `TestScene` into a `SubViewport`.
- `game/playground/test.tscn`
  - Current gameplay composition root.
  - Owns the world layout, navigation region, player, customers, leave point, test tools, and `UIManager`.

## Global Services (Autoload)

The following services are configured in `project.godot`:

| Autoload | Responsibility | Notes |
|---|---|---|
| `SignalManager` | Global event bus | Declares cross-system signals only; no game logic. |
| `ItemDatabase` | Item lookup | Used by gameplay actors to resolve `FoodData`. |
| `EconomyManager` | Money and daily statistics SSOT | Tracks current money and per-day aggregates. |
| `DayManager` | Day-cycle runtime control | Starts/ends days and emits formatted time updates. |

### Signal contract

`SignalManager` is the shared integration surface between otherwise separate systems.

Important signals:

- `sub_pixel_offset_updated(offset: Vector2)`
- `customer_paid(base_amount: int, tips: int)`
- `customer_lost()`
- `money_updated(current_money: int, daily_earnings: int)`
- `time_ticked(formatted_time: String)`
- `day_started(day_count: int)`
- `day_ended()`

Boundary rule:

- Services and UI may subscribe to global signals.
- Feature logic should emit domain events rather than directly mutating unrelated systems.
- `SignalManager` remains declarative and does not coordinate behavior itself.

## Scene Composition

### `game/playground/test.tscn`

Current top-level scene contents:

- `Camera2D`
  - Uses `game/scripts/systems/subpixel_camera.gd`.
  - Tracks the player and emits sub-pixel offsets.
- `NavigationRegion2D`
  - Contains floor, walls, and placed world objects.
- `NavigationRegion2D/Object/Table`
  - Primary table actor.
- `NavigationRegion2D/Object/Chair*`
  - Seat providers that self-register to the table.
- `Player`
  - Main controllable character.
- `Customer`, `Customer2`
  - Autonomous actors that target the table and leave through `LeavePosition`.
- `LeavePosition`
  - Exit target for leaving customers.
- `TestTools`
  - Debug/test helper scene.
- `UIManager`
  - Root UI controller for HUD and end-of-day flow.

This means `test.tscn` is currently both the gameplay scene and the composition root for active runtime actors.

## Rendering and Camera Layer

Sub-pixel presentation is split across three parts:

| Part | File | Responsibility |
|---|---|---|
| Camera tracking | `game/scripts/systems/subpixel_camera.gd` | Smoothly follows the target and computes sub-pixel offset. |
| Event bridge | `SignalManager.sub_pixel_offset_updated` | Broadcasts the current offset. |
| Shader application | `game/scripts/systems/sub_viewport_container.gd` | Writes `cam_offset` into the viewport material. |

Flow:

```text
Player moves
  -> SubpixelCamera updates actual camera position
	  -> emits sub_pixel_offset_updated
		  -> SubViewportContainer writes shader parameter
			  -> viewport output stays pixel-snapped while preserving smooth motion
```

## Gameplay Domains

### Player domain

Files:

- `game/scripts/actors/player.gd`
- `game/scripts/components/player_movement_component.gd`
- `game/scripts/components/player_state_machine.gd`
- `game/scripts/components/player_interact.gd`
- `game/scripts/components/player_held_item.gd`

Responsibilities are split as follows:

- `Player`
  - Owns runtime state such as `facing_direction` and `held_food`.
  - Applies the velocity returned by the movement component.
  - Updates animation/state intent through `PlayerStateMachine`.
- `MovementComponent`
  - Reads input actions.
  - Computes current velocity from walk/run settings.
  - Exposes `input_vector`, `is_running`, and `current_velocity`.
- `PlayerStateMachine`
  - Classifies movement into `IDLE`, `WALK`, or `RUN`.
  - Does not own physics or input.
- `InteractionComponent`
  - Scans overlapping bodies/areas when the interact action is pressed.
  - Emits `interaction_requested(target, interactor)`.
  - Invokes `interact(interactor)` on targets that implement it.
- `PlayerHeldItem`
  - Mirrors the currently held `FoodData` visually.

Boundary summary:

- Input and velocity calculation belong to the movement component.
- Physical movement belongs to `Player`.
- State classification belongs to `PlayerStateMachine`.
- World interaction routing belongs to `InteractionComponent`.

### Customer / table / chair domain

Files:

- `game/scripts/actors/customer.gd`
- `game/scripts/components/customer_state_machine.gd`
- `game/scripts/components/customer_movement_component.gd`
- `game/scripts/components/customer_visual_component.gd`
- `game/scripts/actors/table.gd`
- `game/scripts/actors/chair.gd`

This domain models the restaurant service loop.

#### Chair

`Chair` is a seat provider, not a gameplay orchestrator.

- Reads seat slot data from `ChairData`.
- Detects a nearby `Table` after physics frames are ready.
- Registers seat world positions and facing directions into the table.
- Owns seat reservation state (`available` / `occupied`).

#### Table

`Table` is the local coordination hub for seating and order fulfillment.

- Collects seat records from connected chairs.
- Reserves/releases seats for actors.
- Registers customer orders.
- Accepts served food from an interacting actor.
- Emits `order_registered`, `food_received`, `order_served`, and `interaction_processed`.

`Table` intentionally knows nothing about global economy or day-cycle systems.

#### Customer

`Customer` is the scene actor that owns the lifecycle and delegates specialized work to components.

- Holds references to table assignment, order, facing direction, and child components.
- Moves via `CustomerMovementComponent`.
- Delegates lifecycle transitions to `CustomerStateMachine`.
- Delegates sprite bob/flip behavior to `CustomerVisualComponent`.
- Updates `UI_Anchor/PatienceBar` based on state-machine patience values.

#### CustomerStateMachine

`CustomerStateMachine` owns the lifecycle state transitions:

- `IDLE`
- `MOVING_TO_SEAT`
- `WAITING_FOOD`
- `EATING`
- `LEAVING`

It is responsible for:

- Starting a seating attempt through the table.
- Entering waiting/eating/leaving states.
- Decrementing patience during `WAITING_FOOD`.
- Emitting `customer_lost` when patience is depleted.
- Calculating tips when food is accepted.
- Emitting `customer_paid` after eating completes.

Boundary summary:

- `Chair` owns seat slot definition and occupancy state.
- `Table` owns seat registry, order matching, and served-food routing.
- `Customer` owns actor-level runtime context and delegates behavior.
- `CustomerStateMachine` owns lifecycle transitions and economic outcome signals.

## Economy and Day Cycle

### EconomyManager

`EconomyManager` is the single source of truth for money and daily aggregates.

It owns:

- `current_money`
- `total_earnings_today`
- `customers_served_today`
- `customers_lost_today`

It reacts to:

- `SignalManager.customer_paid`
- `SignalManager.customer_lost`

It exposes:

- `reset_daily_stats()`
- `get_daily_stats()`
- `add_money(amount)`
- `try_spend_money(amount)`

### DayManager

`DayManager` owns the business-day timeline.

It owns:

- `current_day`
- `time_elapsed`
- `is_day_active`
- `day_duration_seconds`
- `day_start_hour`
- `day_end_hour`
- `auto_start_first_day`

It is responsible for:

- Auto-starting the first day during `_ready()` when enabled.
- Resetting daily economy stats at day start.
- Emitting `day_started` and the initial time label value.
- Emitting `time_ticked` while the day is active.
- Ending the day when duration is reached.
- Advancing the day counter before starting the next day.

Runtime chain:

```text
DayManager.start_day()
  -> EconomyManager.reset_daily_stats()
  -> SignalManager.day_started(day_count)
  -> SignalManager.time_ticked(formatted_time)

DayManager._process(delta)
  -> update time_elapsed
  -> SignalManager.time_ticked(formatted_time)
  -> if duration reached: end_day()

DayManager.end_day()
  -> SignalManager.day_ended()
```

## UI Architecture

Files:

- `game/playground/ui/ui_manager.tscn`
- `game/playground/ui/end_of_day_panel.tscn`
- `game/scripts/systems/ui_manager.gd`
- `game/scripts/systems/hud_layer.gd`
- `game/scripts/systems/end_of_day_panel.gd`

### Structure

```text
UIManager (CanvasLayer)
  -> HUD_Layer
	  -> MarginContainer
		  -> HBoxContainer
			  -> MoneyLabel
			  -> TimeLabel
  -> Menu_Layer
	  -> EndOfDayPanel
```

### Control model

`UIManager` is the root UI coordinator.

- On `day_started`
  - Shows `HUD_Layer`.
  - Hides `EndOfDayPanel`.
- On `day_ended`
  - Hides `HUD_Layer`.
  - Calls `end_of_day_panel.show_panel()`.

`HUD_Layer` is passive display UI.

- Subscribes to `money_updated`.
- Subscribes to `time_ticked`.
- Updates labels only.

`EndOfDayPanel` is a local modal-like UI component.

- Pulls daily statistics from `EconomyManager` when shown.
- Pauses the tree in `show_panel()`.
- On next-day button press:
  - hides itself,
  - unpauses the tree,
  - calls `DayManager.advance_to_next_day()`,
  - calls `DayManager.start_day()`.

Boundary summary:

- `UIManager` decides when the panel is shown.
- `EndOfDayPanel` decides how the panel displays and how the local next-day interaction behaves.
- `HUD_Layer` only renders current values and does not drive gameplay state.

## End-to-End Runtime Flows

### 1. Startup flow

```text
Main scene loads
  -> TestScene instances gameplay world + UIManager
  -> Autoloads already available
  -> DayManager._ready()
	  -> auto_start_first_day
	  -> start_day()
		  -> reset daily stats
		  -> emit day_started + initial time_ticked
  -> UIManager shows HUD for active day
```

### 2. Serving flow

```text
Player interacts with Table while holding food
  -> InteractionComponent calls Table.interact(player)
  -> Table.try_receive_food(food)
  -> Table emits order_served(customer, food)
  -> Customer forwards to CustomerStateMachine.try_accept_served_food(food)
  -> state enters EATING
  -> patience is frozen and tips multiplier is captured
```

### 3. Payment flow

```text
Customer finishes eating
  -> CustomerStateMachine._process_payment()
  -> SignalManager.customer_paid(base_amount, tips)
  -> EconomyManager updates money + daily served stats
  -> SignalManager.money_updated(current_money, daily_earnings)
  -> HUD_Layer updates money label
```

### 4. Lost-customer flow

```text
Customer waits too long
  -> CustomerStateMachine._update_patience(delta)
  -> patience reaches zero
  -> SignalManager.customer_lost()
  -> EconomyManager increments daily lost count
  -> Customer transitions to LEAVING
```

### 5. Day-end flow

```text
Day duration reached
  -> DayManager.end_day()
  -> SignalManager.day_ended()
  -> UIManager hides HUD and shows EndOfDayPanel
  -> EndOfDayPanel reads EconomyManager daily stats
  -> tree is paused
```

### 6. Next-day flow

```text
Player presses "開始下一天"
  -> EndOfDayPanel unpauses tree and hides itself
  -> DayManager.advance_to_next_day()
  -> DayManager.start_day()
  -> EconomyManager daily stats reset
  -> UIManager receives day_started and restores HUD
```

## Responsibility Boundaries

The current architecture is strongest when each layer stays inside these boundaries:

- Autoload services
  - Own shared state or shared contracts.
  - Do not depend on scene-local node paths.
- UI
  - Reacts to global state and emits intentional user actions.
  - Does not own economy calculations or customer behavior.
- Actors
  - Own scene-local runtime state.
  - Delegate reusable concerns into components.
- Components
  - Focus on one concern: movement, state classification, interaction, visual presentation.
- World objects
  - `Table` and `Chair` coordinate local seating/order behavior without reaching into global services.

Current notable design choices:

- `CustomerStateMachine` is allowed to emit economic outcome signals because payment/loss is a direct result of customer lifecycle completion.
- `EndOfDayPanel` is allowed to call `DayManager` because starting the next day is a direct consequence of the panel's primary interaction.
- `UIManager` remains the coordinator for visibility transitions so panel-display responsibility is not duplicated across multiple UI scripts.

## File Map

### Entry and composition

- `project.godot`
- `game/playground/main.tscn`
- `game/playground/test.tscn`

### Autoload systems

- `game/scripts/systems/signal_manager.gd`
- `game/scripts/systems/item_database.gd`
- `game/scripts/systems/economy_manager.gd`
- `game/scripts/systems/day_manager.gd`

### Rendering and camera

- `game/scripts/systems/subpixel_camera.gd`
- `game/scripts/systems/sub_viewport_container.gd`
- `game/shader/subpixel.gdshader`

### Player domain

- `game/scripts/actors/player.gd`
- `game/scripts/components/player_movement_component.gd`
- `game/scripts/components/player_state_machine.gd`
- `game/scripts/components/player_interact.gd`
- `game/scripts/components/player_held_item.gd`
- `game/scripts/components/player_visual_component.gd`

### Customer service domain

- `game/scripts/actors/customer.gd`
- `game/scripts/components/customer_state_machine.gd`
- `game/scripts/components/customer_movement_component.gd`
- `game/scripts/components/customer_visual_component.gd`
- `game/scripts/actors/table.gd`
- `game/scripts/actors/chair.gd`
- `game/scripts/resources/order_data.gd`
- `game/scripts/resources/food_data.gd`
- `game/scripts/resources/table_data.gd`
- `game/scripts/resources/chair_data.gd`
- `game/scripts/resources/seat_slot_data.gd`

### UI

- `game/playground/ui/ui_manager.tscn`
- `game/playground/ui/end_of_day_panel.tscn`
- `game/scripts/systems/ui_manager.gd`
- `game/scripts/systems/hud_layer.gd`
- `game/scripts/systems/end_of_day_panel.gd`

### Supporting docs

- `vault/current/task.md`
- `vault/current/UIManager.md`
- `vault/current/customer-chair-table-architecture.md`

## Current Status

As of the current implementation:

- The first day auto-starts.
- The HUD and end-of-day panel follow a single coordinated UI control path.
- Customer patience, payment, and lost-customer reporting are wired into economy tracking.
- `vault/current` documentation has been aligned with the active runtime structure.

This document should be updated whenever one of these changes occurs:

- the main scene or composition root changes,
- a new autoload service is added,
- UI control ownership changes,
- the customer/table/chair lifecycle changes,
- the project moves beyond `test.tscn` as the active gameplay scene.
