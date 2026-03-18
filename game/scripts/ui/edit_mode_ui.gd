extends Control
class_name EditModeUI

signal table_selected
signal chair_selected
signal move_pressed
signal rotate_pressed
signal confirm_pressed
signal cancel_pressed
signal delete_pressed
signal exit_edit_mode_pressed

@onready var toolbar_panel: PanelContainer = $ToolbarPanel
@onready var status_label: Label = $StatusLabel
@onready var table_button: Button = $ToolbarPanel/MarginContainer/VBoxContainer/PlacementRow/TableButton
@onready var chair_button: Button = $ToolbarPanel/MarginContainer/VBoxContainer/PlacementRow/ChairButton
@onready var move_button: Button = $ToolbarPanel/MarginContainer/VBoxContainer/ActionRow/MoveButton
@onready var rotate_button: Button = $ToolbarPanel/MarginContainer/VBoxContainer/ActionRow/RotateButton
@onready var confirm_button: Button = $ToolbarPanel/MarginContainer/VBoxContainer/ActionRow/ConfirmButton
@onready var cancel_button: Button = $ToolbarPanel/MarginContainer/VBoxContainer/ActionRow/CancelButton
@onready var delete_button: Button = $ToolbarPanel/MarginContainer/VBoxContainer/ActionRow/DeleteButton
@onready var exit_button: Button = $ToolbarPanel/MarginContainer/VBoxContainer/ExitRow/ExitButton

var _edit_mode_controller: EditModeController = null

func setup(controller: EditModeController) -> void:
	_edit_mode_controller = controller
	
	if _edit_mode_controller != null:
		_edit_mode_controller.edit_mode_entered.connect(_on_edit_mode_entered)
		_edit_mode_controller.edit_mode_exited.connect(_on_edit_mode_exited)
		_edit_mode_controller.placeable_selected.connect(_on_placeable_selected)
		_edit_mode_controller.placeable_deselected.connect(_on_placeable_deselected)
		_edit_mode_controller.validation_changed.connect(_on_validation_changed)
	
	_connect_button_signals()
	hide()

func _connect_button_signals() -> void:
	if table_button:
		table_button.pressed.connect(_on_table_button_pressed)
	if chair_button:
		chair_button.pressed.connect(_on_chair_button_pressed)
	if move_button:
		move_button.pressed.connect(_on_move_button_pressed)
	if rotate_button:
		rotate_button.pressed.connect(_on_rotate_button_pressed)
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_button_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_button_pressed)
	if delete_button:
		delete_button.pressed.connect(_on_delete_button_pressed)
	if exit_button:
		exit_button.pressed.connect(_on_exit_button_pressed)

func _on_edit_mode_entered() -> void:
	show()
	_update_ui_state()

func _on_edit_mode_exited() -> void:
	hide()

func _on_placeable_selected(_placeable: Node2D) -> void:
	_update_ui_state()

func _on_placeable_deselected() -> void:
	_update_ui_state()

func _on_validation_changed(is_valid: bool, reason: String) -> void:
	if status_label:
		status_label.text = reason
		status_label.modulate = Color(0.0, 1.0, 0.0) if is_valid else Color(1.0, 0.0, 0.0)
	
	if confirm_button:
		confirm_button.disabled = not is_valid

func _update_ui_state() -> void:
	if _edit_mode_controller == null:
		return
	
	var mode: StringName = _edit_mode_controller.get_current_mode()
	var has_selection: bool = _edit_mode_controller.get_selected_placeable() != null
	var is_placing: bool = mode == EditModeController.MODE_PLACING_NEW or mode == EditModeController.MODE_MOVING_EXISTING
	
	# Enable/disable buttons based on state
	if table_button:
		table_button.disabled = is_placing
	if chair_button:
		chair_button.disabled = is_placing
	if move_button:
		move_button.disabled = not has_selection or is_placing
	if rotate_button:
		rotate_button.disabled = not is_placing
	if confirm_button:
		confirm_button.disabled = not is_placing
	if cancel_button:
		cancel_button.disabled = not is_placing
	if delete_button:
		delete_button.disabled = not has_selection or is_placing
	
	# Update status text
	if status_label:
		if is_placing:
			status_label.text = "Position and rotate, then confirm or cancel"
		elif has_selection:
			status_label.text = "Selected: %s" % _edit_mode_controller.get_selected_placeable().name
		else:
			status_label.text = "Click furniture to select, or choose a type to place new"

func _on_table_button_pressed() -> void:
	table_selected.emit()

func _on_chair_button_pressed() -> void:
	chair_selected.emit()

func _on_move_button_pressed() -> void:
	move_pressed.emit()

func _on_rotate_button_pressed() -> void:
	rotate_pressed.emit()

func _on_confirm_button_pressed() -> void:
	confirm_pressed.emit()

func _on_cancel_button_pressed() -> void:
	cancel_pressed.emit()

func _on_delete_button_pressed() -> void:
	delete_pressed.emit()

func _on_exit_button_pressed() -> void:
	exit_edit_mode_pressed.emit()

func show_message(message: String, is_error: bool = false) -> void:
	if status_label:
		status_label.text = message
		status_label.modulate = Color(1.0, 0.0, 0.0) if is_error else Color(1.0, 1.0, 1.0)
