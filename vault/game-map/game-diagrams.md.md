# Game System Diagrams

This file contains all Mermaid diagrams for the game architecture.

---

## 1. System Architecture Overview

```mermaid
flowchart TB
    subgraph SceneLayer[Scene Layer]
        main[main.tscn<br/>SubViewport & Shader]
        test[test.tscn<br/>Test Map]
        player_scn[player.tscn]
        table_scn[table.tscn]
        chair_scn[chair.tscn]
        customer_scn[customer.tscn]
    end

    subgraph LogicLayer[Logic Layer]
        subgraph Actors[Actors]
            player_gd[player.gd]
            table_gd[table.gd]
            chair_gd[chair.gd]
            customer_gd[customer.gd]
        end

        subgraph Components[Components]
            movement[movement_component.gd]
            state_machine[player_state_machine.gd]
            visual[visual_component.gd]
            interact[interact.gd]
            held_item[player_held_item.gd]
            customer_sm[customer_state_machine.gd]
            customer_move[customer_movement_component.gd]
            customer_vis[customer_visual_component.gd]
        end

        subgraph Systems[Systems]
            signal_mgr[signal_manager.gd]
            item_db[item_database.gd]
            camera[subpixel_camera.gd]
            viewport[sub_viewport_container.gd]
            debug_hud[service_debug_hud.gd]
        end

        subgraph Resources[Resources]
            food_data[food_data.gd]
            table_data[table_data.gd]
            chair_data[chair_data.gd]
            seat_slot[seat_slot_data.gd]
            order_data[order_data.gd]
        end
    end

    subgraph DataLayer[Data Layer]
        foods[game/data/foods/*.tres]
        tables[game/data/tables/*.tres]
        chairs[game/data/chairs/*.tres]
    end

    subgraph GlobalLayer[Global Layer Autoload]
        autoload1[SignalManager]
        autoload2[ItemDatabase]
    end
```

---

## 2. Player Movement Sequence

```mermaid
sequenceDiagram
    participant Input as Input
    participant MC as MovementComponent
    participant Player as Player
    participant SM as PlayerStateMachine
    participant VC as VisualComponent

    Input->>MC: ui_left/right/up/down + run
    MC->>MC: _read_input()
    MC->>Player: get_velocity(delta)
    Player->>Player: move_and_slide()
    Player->>SM: update_state()
    SM->>VC: Update visual state
```

---

## 3. Serving Flow (Player -> Table -> Customer)

```mermaid
sequenceDiagram
    participant Player as Player
    participant IC as InteractionComponent
    participant Table as Table
    participant Customer as Customer
    participant CSM as CustomerStateMachine

    Player->>IC: Press E (interact)
    IC->>IC: request_interaction(player)
    IC->>Table: interact(player)
    Table->>Player: get_held_food()
    Table->>Table: try_receive_food(food)
    Table->>Table: _find_matching_order_index()
    Table->>Customer: order_served.emit()
    Customer->>CSM: try_accept_served_food()
    CSM->>CSM: Transition to EATING
    Player->>Player: try_consume_held_food()
```

---

## 4. Customer State Machine

```mermaid
stateDiagram-v2
    [*] --> IDLE: Spawn
    IDLE --> SEEKING_SEAT: start_lifecycle()
    SEEKING_SEAT --> MOVING_TO_SEAT: set_seat_target()
    MOVING_TO_SEAT --> ORDERING: on_reached_seat()
    ORDERING --> WAITING_FOOD: _create_and_submit_order()
    WAITING_FOOD --> EATING: try_accept_served_food()
    EATING --> LEAVING: tick() timer finished
    LEAVING --> [*]: _finish_leaving()
```

### State Descriptions

| State | Description |
|-------|-------------|
| IDLE | Initial state before lifecycle starts |
| SEEKING_SEAT | Looking for available table/chair |
| MOVING_TO_SEAT | Walking to reserved seat position |
| ORDERING | At table, creating order |
| WAITING_FOOD | Order submitted, waiting for food |
| EATING | Food received, eating timer running |
| LEAVING | Finished eating, walking to exit |

---

## 5. Chair-Table-Customer Seat System

```mermaid
sequenceDiagram
    participant Chair as Chair
    participant Table as Table
    participant Customer as Customer

    Note over Chair,Table: Setup Phase
    Chair->>Chair: _ready() wait physics frames
    Chair->>Chair: TableDetector scan
    Chair->>Table: _bind_to_table()
    Chair->>Table: register_new_seats(seat_info_list)

    Note over Customer,Table: Reservation Phase
    Customer->>Table: start_lifecycle(target_table)
    Table->>Chair: reserve_seat(actor)
    Chair->>Chair: reserve(actor) mark occupied
    Customer->>Customer: Move to seat position

    Note over Customer,Table: Order Phase
    Customer->>Table: register_order(order)

    Note over Customer,Chair: Leaving Phase
    Customer->>Customer: begin_leaving()
    Table->>Chair: release_seat(actor)
    Chair->>Chair: release(actor) mark available
```

---

## 6. Table Order & Food Management

```mermaid
flowchart LR
    subgraph TableSystem[Table System]
        T[Table]
        ES["expected_orders<br/>Array[OrderData]"]
        FT[foods_on_table<br/>Array(FoodData)]
        CS[current_customers<br/>Array(Node)]
        AS[available_seats<br/>Array(Dictionary)]
        CC[connected_chairs<br/>Array(Chair)]
    end

    subgraph OrderFlow[Order Flow]
        C1[Customer]
        O[OrderData]
        F[FoodData]
    end

    C1 -->|register_order| T
    T -->|add| ES
    T -->|add| CS

    P[Player] -->|interact + held_food| T
    T -->|try_receive_food| FT
    T -->|remove from| ES
    T -->|order_served| C1
```

---

## 7. Subpixel Rendering Pipeline

```mermaid
sequenceDiagram
    participant Camera as SubpixelCamera
    participant Signal as SignalManager
    participant Viewport as SubViewportContainer
    participant Shader as Shader

    Camera->>Camera: _physics_process()
    Camera->>Camera: lerp smooth follow
    Camera->>Signal: sub_pixel_offset_updated.emit(offset)
    Signal->>Viewport: _on_offset_updated()
    Viewport->>Shader: material.set_shader_parameter(cam_offset)
```

---

## 8. Core Systems Interaction

```mermaid
flowchart TB
    subgraph PlayerSystem[Player System]
        P[Player]
        PM[MovementComponent]
        PS[StateMachine]
        PI[InteractionComponent]
        PH[HeldItem]
    end

    subgraph CustomerSystem[Customer System]
        C[Customer]
        CS[CustomerStateMachine]
        CM[CustomerMovementComponent]
        CV[CustomerVisualComponent]
    end

    subgraph FurnitureSystem[Furniture System]
        T[Table]
        CH[Chair]
    end

    subgraph DataSystem[Data System]
        ID[ItemDatabase]
        FD[FoodData]
        OD[OrderData]
    end

    subgraph Global[Global]
        SM[SignalManager]
        DH[ServiceDebugHud]
    end

    P --> PM
    P --> PS
    P --> PI
    P --> PH

    C --> CS
    C --> CM
    C --> CV

    CH --> T
    C --> T
    P --> T

    T -.-> OD
    C -.-> OD
    ID -.-> FD

    SM -.-> DH
    T -.-> SM
    CS -.-> SM
```

---

## 9. Complete Service Loop Flow

```mermaid
flowchart TB
    subgraph Spawn[1. Customer Spawn]
        S1[Customer spawns]
        S2[Call start_lifecycle table]
    end

    subgraph Seat[2. Seating]
        SE1[Table.reserve_seat]
        SE2[Chair.reserve]
        SE3[Move to seat]
    end

    subgraph Order[3. Ordering]
        O1[Reached seat]
        O2[Create OrderData]
        O3[Table.register_order]
        O4[State WAITING_FOOD]
    end

    subgraph Serve[4. Serving]
        SV1[Player holds food]
        SV2[Interact with Table]
        SV3[Table.try_receive_food]
        SV4[Match order check]
        SV5[Place on slot]
        SV6[Emit order_served]
    end

    subgraph Eat[5. Eating & Leaving]
        E1[Customer receives food]
        E2[State EATING]
        E3[Timer countdown]
        E4[State LEAVING]
        E5[Move to exit]
        E6[Release seat]
    end

    S1 --> S2
    S2 --> SE1
    SE1 --> SE2
    SE2 --> SE3
    SE3 --> O1
    O1 --> O2
    O2 --> O3
    O3 --> O4
    O4 -.->|waiting| SV1
    SV1 --> SV2
    SV2 --> SV3
    SV3 --> SV4
    SV4 --> SV5
    SV5 --> SV6
    SV6 --> E1
    E1 --> E2
    E2 --> E3
    E3 --> E4
    E4 --> E5
    E5 --> E6
```
