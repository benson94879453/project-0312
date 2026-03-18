# UIManager 架构说明

## 概述

UIManager 是游戏的单一界面控制中枢，负责管理所有 UI 层级的显示、更新与交互。采用分层架构设计，将 HUD（实时显示）与 Menu（弹窗面板）分离，确保关注点清晰。

- **UIManager** (CanvasLayer)：根节点，统筹管理所有 UI 层级
- **HUD_Layer**：游戏进行中的实时信息显示（金钱、时间）
- **Menu_Layer**：游戏暂停时的面板（每日结算、主菜单等）

---

## 场景节点结构

```
UIManager (CanvasLayer)
├── HUD_Layer (Control)  ➔ Layout: Full Rect (全螢幕大小)
│   └── MarginContainer (MarginContainer) ➔ Layout: Top Wide (靠上對齊並設定邊距)
│       └── HBoxContainer (HBoxContainer)
│           ├── MoneyIcon (TextureRect) ➔ (可選) 放個金幣圖示
│           ├── MoneyLabel (Label) ➔ 預設文字: "$ 0"
│           ├── Spacer (Control) ➔ Size Flags -> Horizontal 勾選 Expand (用來把時間推到最右邊)
│           └── TimeLabel (Label) ➔ 預設文字: "09:00 AM"
│
├── Menu_Layer (Control) ➔ Layout: Full Rect, Mouse Filter: Ignore (避免擋住遊戲點擊)
│   └── EndOfDayPanel (PanelContainer) ➔ Layout: Center (置中), 預設 Visible: false
│       └── MarginContainer (MarginContainer) ➔ 設定一些內邊距 (Theme Overrides -> Constants)
│           └── VBoxContainer (VBoxContainer) ➔ 排列內部元素
│               ├── TitleLabel (Label) ➔ 預設文字: "營業結束" (可調大字體)
│               ├── HSeparator (HSeparator) ➔ 視覺分隔線
│               ├── StatsGrid (GridContainer) ➔ Columns: 2 (做成兩欄式的對齊表)
│               │   ├── IncomeTitle (Label) ➔ "今日收入:"
│               │   ├── IncomeValue (Label) ➔ "$0"
│               │   ├── ServedTitle (Label) ➔ "服務客數:"
│               │   ├── ServedValue (Label) ➔ "0"
│               │   ├── LostTitle (Label) ➔ "流失客數:"
│               │   └── LostValue (Label) ➔ "0"
│               ├── HSeparator (HSeparator)
│               └── NextDayButton (Button) ➔ 預設文字: "開始下一天"
```

---

## UIManager (根控制器)

**目标路径**：`game/playground/ui/ui_manager.tscn` (CanvasLayer)

**挂载脚本**：`game/scripts/systems/ui_manager.gd`

### 职责
1. 初始化时建立 HUD_Layer 与 Menu_Layer 的引用
2. 协调各层级之间的显示/隐藏关系
3. 接收 SignalManager 的全局信号并分派给对应子层

### 关键属性

| 属性 | 型别 | 说明 |
|------|------|------|
| `hud_layer` | HUDLayer | HUD 控制层实例引用 |
| `menu_layer` | MenuLayer | 菜单层实例引用 |
| `end_of_day_panel` | EndOfDayPanel | 每日结算面板实例引用 |

### 函数详细说明

#### `_ready() -> void`
- 初始化：获取 HUD_Layer、Menu_Layer 子节点引用
- 主动隐藏 `EndOfDayPanel`，确保开局不会显示结算面板
- 建立与 SignalManager 的连接：
  - `day_ended -> _on_day_ended()`
  - `day_started -> _on_day_started()`

#### `_on_day_ended() -> void`
- 接收每日结束信号
- 调用 `hud_layer.hide()` 隐藏 HUD
- 调用 `end_of_day_panel.show_panel()` 显示结算面板

#### `_on_day_started(day_count: int) -> void`
- 接收新一天开始信号
- 调用 `hud_layer.show()` 显示 HUD
- 调用 `end_of_day_panel.hide()` 确保结算面板关闭

---

## HUD_Layer (平视显示器层)

**节点路径**：`UIManager/HUD_Layer` (Control)

**挂载脚本**：`game/scripts/systems/hud_layer.gd`

### 职责
1. 实时显示当前金钱与今日收入
2. 实时显示游戏内时间
3. 通过 SignalManager 接收数据更新

### 关键属性

| 属性 | 型别 | 说明 |
|------|------|------|
| `money_label` | Label | 金钱显示标签 |
| `time_label` | Label | 时间显示标签 |

### 函数详细说明

#### `_ready() -> void`
- 获取 `MoneyLabel`、`TimeLabel` 节点引用
- 建立 SignalManager 连接：
  - `money_updated -> _on_money_updated(current_money, daily_earnings)`
  - `time_ticked -> _on_time_ticked(formatted_time)`
- 初始化默认文字：`$ 0`、`09:00 AM`

#### `_on_money_updated(current_money: int, daily_earnings: int) -> void`
- 更新 `money_label.text = "$%d" % current_money`

#### `_on_time_ticked(formatted_time: String) -> void`
- 更新 `time_label.text = formatted_time`

---

## EndOfDayPanel (每日结算面板)

**节点路径**：`UIManager/Menu_Layer/EndOfDayPanel` (PanelContainer)

**挂载脚本**：`game/scripts/systems/end_of_day_panel.gd`

### 职责
1. 在每日结束时显示统计信息
2. 暂停游戏循环 (`get_tree().paused`)
3. 提供「开始下一天」按钮恢复游戏

### 关键属性

| 属性 | 型别 | 说明 |
|------|------|------|
| `income_value_label` | Label | 今日收入数值 |
| `served_value_label` | Label | 服务客数数值 |
| `lost_value_label` | Label | 流失客数数值 |
| `next_day_button` | Button | 开始下一天按钮 |

### 函数详细说明

#### `_ready() -> void`
- 获取各数值标签与按钮引用
- 连接 `next_day_button.pressed -> _on_next_day_pressed()`
- 默认 `visible = false`（隐藏）
- 不再自行监听 `day_ended`，由 `UIManager` 统一协调显示时机

#### `show_panel() -> void`
- 从 EconomyManager 获取统计数据：
  - `total_earnings_today`
  - `customers_served_today`
  - `customers_lost_today`
- 更新各数值标签
- 设置 `visible = true`
- 暂停游戏：`get_tree().paused = true`

#### `_on_next_day_pressed() -> void`
- 设置 `visible = false`
- 恢复游戏：`get_tree().paused = false`
- 调用 `DayManager.advance_to_next_day()` 后，再调用 `DayManager.start_day()` 开始新一天

---

## 信号契约 (SignalManager)

UIManager 依赖以下全局信号进行数据更新：

| 信号 | 发送者 | 参数 | 说明 |
|------|--------|------|------|
| `money_updated` | EconomyManager | `(current_money: int, daily_earnings: int)` | 金钱变化时更新 HUD |
| `time_ticked` | DayManager | `(formatted_time: String)` | 每秒更新游戏时间 |
| `day_started` | DayManager | `(day_count: int)` | 新一天开始，显示 HUD |
| `day_ended` | DayManager | `()` | 一天结束，显示结算面板 |

---

## 协作流程图

```
DayManager._process(delta)
	└── 累積 time_elapsed
			└── 格式化時間字串
					└── SignalManager.time_ticked.emit("12:30 PM")
							└── HUD_Layer._on_time_ticked()
									└── time_label.text = "12:30 PM"

Customer (EATING 結束準備 LEAVING)
	└── SignalManager.customer_paid.emit(price, tips)
			└── EconomyManager._on_customer_paid()
					└── current_money += price + tips
							└── SignalManager.money_updated.emit(new_money, earnings)
									└── HUD_Layer._on_money_updated()
											└── money_label.text = "$150"

Customer (耐心歸零)
	└── SignalManager.customer_lost.emit()
			└── EconomyManager._on_customer_lost()
					└── customers_lost_today += 1

DayManager (時間到達)
	└── end_day()
			└── SignalManager.day_ended.emit()
					└── UIManager._on_day_ended()
							├── hud_layer.hide()
							└── end_of_day_panel.show_panel()
									├── 從 EconomyManager 抓取統計
									├── 更新 StatsGrid 各數值
									├── visible = true
									└── get_tree().paused = true

玩家點擊 "開始下一天"
	└── EndOfDayPanel._on_next_day_pressed()
			├── visible = false
			├── get_tree().paused = false
			├── DayManager.advance_to_next_day()
			└── DayManager.start_day()
					└── SignalManager.day_started.emit(day_count)
							└── UIManager._on_day_started()
									├── hud_layer.show()
									└── end_of_day_panel.hide()
```

---

## 数据流向

| 数据 | 来源 | 流向 | 用途 |
|------|------|------|------|
| current_money | EconomyManager | SignalManager → HUD_Layer | 实时显示总金钱 |
| formatted_time | DayManager | SignalManager → HUD_Layer | 实时显示游戏内时间 |
| daily_earnings | EconomyManager | EndOfDayPanel 查询 | 结算面板显示今日收入 |
| customers_served | EconomyManager | EndOfDayPanel 查询 | 结算面板显示服务统计 |
| customers_lost | EconomyManager | EndOfDayPanel 查询 | 结算面板显示流失统计 |

---

## 系统依赖关系

```
Task 1 (SignalManager)
	↓ (被依赖)
Task 2 (EconomyManager) ←→ Task 3 (DayManager) ←→ Task 4 (CustomerPatience)
	↓                           ↓                        ↓
	└───────────────────────────┴────────────────────────┘
							 ↓
					  Task 5 (UIManager/HUD)
							 ↓
					  Task 6 (EndOfDayPanel)
```

**当前完成状态**: Task 1-6 ✅ 已完成，并补齐首日自动启动与结算面板协调流程

---

## 实现检查清单

### Task 1: SignalManager 扩展 ✅
- [x] 新增 `customer_paid(base_amount, tips)` 信号
- [x] 新增 `customer_lost()` 信号
- [x] 新增 `money_updated(current_money, daily_earnings)` 信号
- [x] 新增 `time_ticked(formatted_time)` 信号
- [x] 新增 `day_started(day_count)` 信号
- [x] 新增 `day_ended()` 信号

### Task 2: EconomyManager (SSOT) ✅
- [x] 定义内部变量：`current_money`, `total_earnings_today`, `customers_served_today`, `customers_lost_today`
- [x] 连接 `customer_paid` 与 `customer_lost` 信号
- [x] 实现 `_on_customer_paid()`：更新金钱、增加服务计数、发射 `money_updated`
- [x] 实现 `_on_customer_lost()`：增加流失计数
- [x] 实现 `reset_daily_stats()`：重置每日统计
- [x] 实现 `get_daily_stats()`：提供统计查询接口

### Task 3: DayManager (营业时间管理) ✅
- [x] 定义变量：`day_duration_seconds`, `time_elapsed`, `current_day`, `is_day_active`
- [x] 实现 `start_day()`：重置时间、重置经济统计、发射 `day_started`
- [x] 实现 `auto_start_first_day`：初始化后自动开始第一天
- [x] 实现 `_process(delta)`：累积时间、格式化并发射 `time_ticked`、检查结束
- [x] 实现 `end_day()`：发射 `day_ended`
- [x] 实现 `advance_to_next_day()`：增加天数计数

### Task 4: 顾客耐心与小费机制 ✅
- [x] 在 `CustomerStateMachine` 新增 `max_patience_sec` 与 `current_patience`
- [x] 在 `tick(delta)` 中实现耐心衰减（仅在 WAITING_FOOD 状态）
- [x] 实现耐心归零处理：发射 `customer_lost`、切换到 LEAVING
- [x] 在 `EATING` 状态时冻结耐心并计算小费乘数
- [x] 在 EATING 结束时计算小费并发射 `customer_paid`

### Task 5: UIManager 与 HUD Layer ✅
- [x] 建立 `game/playground/ui/ui_manager.tscn` (CanvasLayer)
- [x] 建立子节点 `HUD_Layer` (Control, Full Rect)
- [x] 建立 `MoneyLabel` (Label) 与 `TimeLabel` (Label)
- [x] 编写 `game/scripts/systems/hud_layer.gd` 脚本
- [x] 连接 `money_updated` 信号更新金钱
- [x] 连接 `time_ticked` 信号更新时间
- [x] 在 `test.tscn` 中加入 `UIManager` 節點
- [x] 移除旧的 `ServiceDebugHud` 节点

### Task 6: 每日结算画面 ✅
- [x] 建立 `Menu_Layer` (Control, Full Rect, Mouse Filter: Ignore)
- [x] 建立 `EndOfDayPanel` (PanelContainer, Center, 默认隐藏)
- [x] 建立 `StatsGrid` (GridContainer, Columns: 2)
- [x] 建立标题、数值标签、分隔线
- [x] 建立 `NextDayButton` (Button)
- [x] 编写 `end_of_day_panel.gd` 脚本
- [x] 由 `UIManager` 在 `day_ended` 时调用 `show_panel()`，由面板内部暂停游戏
- [x] 实现「开始下一天」按钮逻辑

---

## 更新记录

| 日期 | 版本 | 变更内容 |
|------|------|----------|
| 2026-03-17 | 初始 | 建立文档，规划 Task 5-6 架构 |
| 2026-03-17 | v1.1 | **Task 1-4 完成**：更新实现检查清单，标记已完成的基础系统 |
| 2026-03-18 | v1.2 | **Task 5 完成**：建立 UIManager 与 HUD Layer 場景與腳本，整合到 test.tscn |
| 2026-03-18 | v1.3 | **Task 6 完成**：建立 EndOfDayPanel 場景與腳本，加入 Menu_Layer，整合到 UIManager |
| 2026-03-18 | v1.4 | **流程补齐**：首日自动启动、UIManager 接管结算面板显示、移除旧调试 HUD |

---

*文件建立时间：2026-03-17*
*最新更新：Task 1-6 与启动/结算流程已对齐当前实现*
*待完成任务：无（若后续扩展主菜单或更多菜单层，再另开任务）*
