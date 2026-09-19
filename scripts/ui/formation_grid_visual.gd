class_name FormationGridVisual
extends Node2D

## Renders stylish isometric slot diamonds and manages interactive tile selection for Move command.

signal slot_clicked(slot_index: int)
signal move_canceled()

var formation_system: FormationSystem = null
var is_move_targeting: bool = false
var valid_slot_indices: Array[int] = []
var selected_valid_idx: int = 0
var hovered_slot: int = -1

# Diamond half-dimensions for isometric visual
const DX: float = 24.0
const DY: float = 12.0

var pulse_time: float = 0.0

func _ready() -> void:
	z_index = -1 # Above floor base, below characters

func _process(delta: float) -> void:
	if is_move_targeting:
		pulse_time += delta * 4.0
		queue_redraw()

func start_move_selection(formation: FormationSystem, valid_slots: Array) -> void:
	formation_system = formation
	valid_slot_indices.clear()
	for s in valid_slots:
		valid_slot_indices.append(int(s))
	selected_valid_idx = 0
	is_move_targeting = true
	visible = true
	queue_redraw()

func cancel_move_selection() -> void:
	is_move_targeting = false
	valid_slot_indices.clear()
	queue_redraw()

func get_current_selected_slot() -> int:
	if valid_slot_indices.is_empty():
		return -1
	return valid_slot_indices[selected_valid_idx]

func _unhandled_input(event: InputEvent) -> void:
	if not is_move_targeting or valid_slot_indices.is_empty():
		return
		
	# Keyboard / Gamepad Navigation
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and event.keycode == KEY_D):
		selected_valid_idx = (selected_valid_idx + 1) % valid_slot_indices.size()
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and event.keycode == KEY_A):
		selected_valid_idx = (selected_valid_idx - 1 + valid_slot_indices.size()) % valid_slot_indices.size()
		queue_redraw()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
		slot_clicked.emit(valid_slot_indices[selected_valid_idx])
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		cancel_move_selection()
		move_canceled.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_slot = _find_slot_at_pos(event.position)
		if clicked_slot in valid_slot_indices:
			slot_clicked.emit(clicked_slot)
			get_viewport().set_input_as_handled()

func _find_slot_at_pos(mouse_pos: Vector2) -> int:
	if formation_system == null:
		return -1
	for idx in valid_slot_indices:
		var slot_pos = formation_system.get_slot_position(0, idx)
		if mouse_pos.distance_to(slot_pos) <= DX * 1.5:
			return idx
	return -1

func _draw() -> void:
	if formation_system == null:
		return
		
	# 1. Draw Player Slots (12)
	for i in range(FormationSystem.TOTAL_SLOTS):
		var pos = formation_system.get_slot_position(0, i)
		var is_valid_move = is_move_targeting and (i in valid_slot_indices)
		var is_focused = is_move_targeting and not valid_slot_indices.is_empty() and valid_slot_indices[selected_valid_idx] == i
		_draw_tile(pos, 0, i, is_valid_move, is_focused)
		
	# 2. Draw Enemy Slots (12)
	for i in range(FormationSystem.TOTAL_SLOTS):
		var pos = formation_system.get_slot_position(1, i)
		_draw_tile(pos, 1, i, false, false)

func _draw_tile(pos: Vector2, team: int, slot_idx: int, is_valid_move: bool, is_focused: bool) -> void:
	var pts = PackedVector2Array([
		pos + Vector2(0, -DY),
		pos + Vector2(DX, 0),
		pos + Vector2(0, DY),
		pos + Vector2(-DX, 0)
	])
	
	if is_focused:
		# Bright pulsing gold cursor
		var alpha = 0.8 + 0.2 * sin(pulse_time * 2.0)
		draw_colored_polygon(pts, Color(1.0, 0.85, 0.2, 0.5 * alpha))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1.0, 0.95, 0.4, alpha), 3.0)
	elif is_valid_move:
		# Glowing cyan/green for valid move destinations
		var alpha = 0.5 + 0.25 * sin(pulse_time)
		draw_colored_polygon(pts, Color(0.2, 0.9, 0.6, 0.35 * alpha))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.3, 1.0, 0.7, alpha), 2.0)
	else:
		# Subtle ambient grid tile
		var base_color = Color(0.2, 0.5, 0.9, 0.12) if team == 0 else Color(0.9, 0.3, 0.3, 0.10)
		var border_color = Color(0.25, 0.6, 1.0, 0.25) if team == 0 else Color(1.0, 0.35, 0.35, 0.20)
		draw_colored_polygon(pts, base_color)
		draw_polyline(pts + PackedVector2Array([pts[0]]), border_color, 1.0)
