# Debug Tools And OpenCode Update

## This round's completed work

### Gameplay fix: cancel order when patience depletes

- File: `game/scripts/actors/table.gd`
  - Added `cancel_order_for_customer(customer)` to remove that customer's pending order from `expected_orders`.
- File: `game/scripts/components/customer_state_machine.gd`
  - When entering `LEAVING` with `failure_reason == "patience_depleted"`, the system now:
    - cancels the pending table order,
    - clears `current_order` on the state machine,
    - clears `customer.current_order` on the actor.

Result:
- A customer leaving because patience reached zero no longer leaves a stale pending order on the table.

---

### Rebuilt debug tool scene

New structure:

- Scene: `game/playground/de_bug_tools.tscn`
- Scripts:
  - `game/scripts/debug/de_bug_tools.gd`
  - `game/scripts/debug/world_de_bug.gd`
  - `game/scripts/debug/message_hud.gd`

Current responsibility split:

- `DeBugTools` (`Node2D`)
  - coordinator
  - resolves scene references
  - forwards HUD actions to world-side debug actions
- `WorldDeBug` (`Node2D`)
  - world-side debug actions
  - test item grant
  - runtime customer spawn
  - debug time multiplier control
- `MessageHUD` (`CanvasLayer`)
  - on-screen snapshot and log panel
  - debug controls UI
  - localized output text

Scene tree includes:

- `DeBugTools`
  - `WorldDeBug`
  - `MessageHUD`
    - `DeBugPanel`
      - `Margin`
        - `Content`
          - `ControlsRow`
          - `SnapshotLabel`
          - `TableLabel`
          - `LogOutLabel`

---

### Current debug features

#### 1. Give test food

- UI entry: `拿 Coffee`
- Now mouse-button only
- Flow:
  - `MessageHUD` emits `coffee_requested`
  - `DeBugTools` forwards to `WorldDeBug.grant_food_to_target()`
  - `WorldDeBug` gives `coffee` to the current player target

#### 2. Spawn customer

- UI entry: `生成顧客`
- Flow:
  - `MessageHUD` emits `spawn_customer_requested`
  - `DeBugTools` forwards to `WorldDeBug.spawn_customer()`
  - `WorldDeBug` delegates to `CustomerSpawnExecutor.spawn_next_pending_customer()`
  - actual customer creation uses the same production spawn path as normal day-plan execution
- Result:
  - no longer depends on a scene-authored static table node for spawn logic
  - reuses existing day plan / table selection / lifecycle rules

#### 3. Accelerate day time

- UI entry: time multiplier selector
- Current options:
  - `1x`
  - `2x`
  - `4x`
  - `8x`
- File: `game/scripts/systems/day_manager.gd`
  - added `debug_day_speed_multiplier`
  - `time_elapsed` now uses `delta * debug_day_speed_multiplier`
  - added:
    - `set_debug_day_speed_multiplier(multiplier)`
    - `get_debug_day_speed_multiplier()`

Important behavior:
- This only accelerates day progression.
- It does not globally speed up player movement or the entire engine timescale.

#### 4. Start day manually

- UI entry: `開始營業`
- Reason:
  - after the pre-open / next-day pipeline split, time no longer advances until `DayManager.start_day()` is explicitly called
- Flow:
  - `MessageHUD` emits `start_day_requested`
  - `DeBugTools` calls `DayManager.start_day()` when not already active / transitioning

---

### Input model update

- Debug panel keyboard triggers have been removed
- `world_de_bug.gd` no longer uses `_unhandled_input()` for `test_add_coffee`
- Current debug interactions are intended to be mouse-button-only via UI buttons
- Player movement / interaction hotkeys still exist in normal gameplay scripts and were not changed as part of this debug-panel cleanup

---

### Debug HUD localization

Files updated:

- `game/scripts/debug/world_de_bug.gd`
- `game/scripts/debug/message_hud.gd`
- `game/playground/de_bug_tools.tscn`

What changed:

- user-facing warnings changed to Chinese
- HUD status text changed to Chinese
- event logs changed to Chinese
- default label text changed to Chinese

---

## OpenCode / oh-my-opencode maintenance

### Plugin version

- Local plugin cache updated to `oh-my-opencode 3.12.1`
- Verified with local version check: current = latest = `3.12.1`

Relevant file:

- `C:/Users/user/.cache/opencode/package.json`

### Local config fix

File:

- `C:/Users/user/.config/opencode/oh-my-opencode.json`

Fix applied:

- replaced invalid provider references from `kimi/k2.5`
- new valid model id used: `moonshotai/kimi-k2.5`

Reason:

- local `models.json` cache did not contain provider `kimi`
- local cache did contain `moonshotai/kimi-k2.5`

### Installed helper tools

- `gh` installed
- `comment-checker` installed and shimmed into PATH
- LSP-related tools installed:
  - `typescript-language-server`
  - `typescript`
  - `pyright`

---

## Current status check

`oh-my-opencode doctor` is now reduced to one remaining item:

- `GitHub CLI not authenticated`

Meaning:

- `gh` is installed
- only `gh auth login` is still pending
- this was intentionally not auto-completed because it requires user GitHub account interaction

---

## Recommended manual verification

### In Godot

1. Open `test.tscn`
2. Verify `DeBugTools` panel appears
3. Click `開始營業` and confirm time starts ticking
4. Click `拿 Coffee` and confirm the player receives coffee
5. Click `生成顧客`
6. Confirm the new customer is spawned through the normal day-plan executor path
7. Switch time multiplier to `2x/4x/8x`
8. Confirm day progress speeds up while player control remains normal
9. Force a patience-depleted leave case and confirm the pending order is removed

### In terminal

Run when needed:

```bash
gh auth login
```

After that, re-check health:

```bash
npx --yes oh-my-opencode doctor
```

---

## Notes for next session

- The current debug HUD tracks the latest spawned customer instead of a multi-customer list.
- If future debugging needs grow, likely next additions are:
  - clear all customers
  - end day immediately
  - force specific customer state transitions
