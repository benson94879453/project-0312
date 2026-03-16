# Godot 4 2D 碰撞系統避坑筆記

## 核心觀念

### 1. 大腦 vs 模具
- 大腦：`CharacterBody2D`、`StaticBody2D`、`Area2D`
- 模具：`CollisionShape2D`
- `Layer/Mask` 永遠設在大腦，不在 Shape。

### 2. Layer vs Mask
- `Layer`：我是誰（名牌）
- `Mask`：我在意誰（雷達）

### 3. Area2D 與實體碰撞
- `Area2D` 是感測器，通常只要開 `Mask` 找目標。
- 實體阻擋（玩家撞桌子）要確保移動方 mask 看得到阻擋方 layer。

## 專案對應（project-0312）

### Layer 命名
- Layer 1：Player
- Layer 2：Table
- Layer 3：Chair

### 三個物件設定
- Player (`CharacterBody2D`)
  - Layer: Player
  - Mask: Table（必要），Pickup（若有）
- Table (`StaticBody2D`)
  - Layer: Table
  - Mask: 通常不需要主動掃描
- TableDetector (`Area2D` on Chair)
  - Mask: Table
  - 功能：開局註冊座位，不參與阻擋

## 快速排錯清單
- 撞不到：
  - Player 是否在 `_physics_process` 呼叫 `move_and_slide()`
  - Player mask 是否包含 Table
  - Table 是否有 CollisionShape2D 且未 disabled
- Area2D 沒反應：
  - 用 `body_entered` 還是 `area_entered` 是否正確
  - Area2D mask 是否包含目標 layer
  - 是否真的有重疊

## 效能小提醒
- Mask 不要全開。
- 一次性偵測（例如 Chair 找 Table）完成後可關 `monitoring`。
- 感測範圍別畫太大，會增加碰撞配對成本。
