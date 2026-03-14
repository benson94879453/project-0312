專案架構總覽

元件與責任

- `MovementComponent` (game/scripts/movement.gd)
  - 負責讀取輸入、計算移動向量與速度。
  - 提供 `get_velocity()`、並保留 `input_vector`、`is_running` 屬性供外部查詢。
  - 不直接改變 `CharacterBody2D`，改由擁有者（例如 `Player`）應用 velocity。

- `Player` (game/scripts/player.gd)
  - 擁有 `MovementComponent` 與 `PlayerStateMachine` 的參考。
  - 以 `export NodePath` 注入依賴（在 Editor 指定），每幀呼叫 `movement_component.get_velocity()` 並套用到自身 `velocity`。
  - 更新面向方向並驅動 state machine。

- `PlayerStateMachine` (game/scripts/state_machine.gd)
  - 以 `export NodePath` 注入 `MovementComponent`，根據 `input_vector` 與 `is_running` 決定 `IDLE/WALK/RUN`。

- `SignalManager` (autoload)
  - 系統級事件匯流排，適合放 singleton（如 sub-pixel offset signal）。

- `InteractionComponent` (game/scripts/interact.gd)
  - 擴充自 `Area2D`，作為互動觸發點；應明確宣告互動介面（例如 `interact()` 或發出信號）。

相依注入原則

- 實體級元件（Movement、StateMachine、Interaction）應由場景注入，使用 `export NodePath` 或 `onready` 指向具體節點，這樣：
  - 編輯器能看見依賴並快速配置。
  - 測試時容易替換 mock 節點。
  - 多實例場景不會互相干擾。

- 系統級資源（SignalManager、GameSettings）可使用 Autoload/singleton。

設定教學（如何在 Editor 接線）

1. 在 `Player` 節點上：
   - 設定 `movement_path` 指向子節點 `MovementComponent`（或場景中的相對節點）。
   - 設定 `state_machine_path` 指向 `PlayerStateMachine` 節點。

2. 在 `PlayerStateMachine` 節點上：
   - 設定 `movement_path` 指向相同的 `MovementComponent` 節點。

重構建議摘要

- 將 `MovementComponent` 改為回傳 velocity（已實作）。
- 以 `export NodePath` 注入相依：已將 `Player` 與 `PlayerStateMachine` 更新為 `NodePath` 注入樣式。
- 定義 `InteractionComponent` 的介面（`interact()` 或 signal）。
- 保留 `SignalManager` 作為 Autoload 用於跨系統事件。

關係圖（Mermaid）

```mermaid
flowchart LR
    Player[Player]
    Movement[MovementComponent]
    State[PlayerStateMachine]
    Signal[SignalManager (autoload)]
    Camera[SubpixelCamera]
    Viewport[SubViewportContainer]

    Player -->|uses| Movement
    Player -->|uses| State
    Camera -->|emit offset| Signal
    Signal -->|notify| Viewport
    Viewport -->|set shader| Shader
```

下一步建議

- 定義 `InteractionComponent` 的事件契約（我可以代寫範例）。
- 若要更嚴格：把 `MovementComponent` 的輸入抽成介面，並補上單元測試。

如果要我繼續，我可以：

- 1) 將 `InteractionComponent` 加上 `interact()` 與信號範例。
- 2) 將 `subpixel_camera.gd` 與其他使用 `%Player` 的地方改為明確注入。

請告訴我想先做哪一步。