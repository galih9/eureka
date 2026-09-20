class_name FormationGridVisual
extends Node2D

## Renders stylish horizontal perspective floor cells and manages interactive tile selection for Move command.
## Must live in the world (Node2D) scene so the camera transform is applied correctly.
## The grid is hidden by default and only shown when a Move action is active to select a destination cell.

signal slot_clicked(slot_index: int)
signal move_canceled()

## Reference to the Camera2D so mouse clicks can be converted from screen→world space.
var camera: Camera2D = null

var formation_system: FormationSystem = null
var is_move_targeting: bool = false
var valid_slot_indices: Array[int] = []
var selected_valid_idx: int = 0
var hovered_slot: int = -1

# Floor cell dimensions (horizontal perspective ellipse)
const RX: float = 34.0
const RY: float = 12.0

var pulse_time: float = 0.0

func _ready() -> void:
	z_index = 0 # Rendered in world space alongside characters
	visible = false # Hidden by default; only displayed during Move command selection

func _process(delta: float) -> void:
	if is_move_targeting and visible:
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
	pulse_time = 0.0
	queue_redraw()

func cancel_move_selection() -> void:
	is_move_targeting = false
	valid_slot_indices.clear()
	visible = false
	queue_redraw()

func get_current_selected_slot() -> int:
	if valid_slot_indices.is_empty():
		return -1
	return valid_slot_indices[selected_valid_idx]

func _unhandled_input(event: InputEvent) -> void:
	if not is_move_targeting or not visible or valid_slot_indices.is_empty():
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
	elif event is InputEventMouseMotion:
		var world_pos = _get_world_mouse_position(event.position)
		var slot = _find_slot_at_world_pos(world_pos)
		if slot in valid_slot_indices:
			var idx = valid_slot_indices.find(slot)
			if idx != -1 and idx != selected_valid_idx:
				selected_valid_idx = idx
				queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world_pos = _get_world_mouse_position(event.position)
		var clicked_slot = _find_slot_at_world_pos(world_pos)
		if clicked_slot in valid_slot_indices:
			slot_clicked.emit(clicked_slot)
			get_viewport().set_input_as_handled()

func _get_world_mouse_position(screen_pos: Vector2) -> Vector2:
	if is_inside_tree():
		return get_global_mouse_position()
	if camera != null:
		return camera.get_screen_center_position() \
			+ (screen_pos - get_viewport().get_visible_rect().size * 0.5) / camera.zoom
	return screen_pos

func _find_slot_at_world_pos(world_pos: Vector2) -> int:
	if formation_system == null:
		return -1
	for idx in valid_slot_indices:
		var slot_pos = formation_system.get_slot_position(0, idx)
		var dx = world_pos.x - slot_pos.x
		var dy = world_pos.y - slot_pos.y
		# Ellipse metric: (dx/RX)^2 + (dy/RY)^2 <= 1.4
		if (dx * dx) / (RX * RX) + (dy * dy) / (RY * RY) <= 1.4:
			return idx
	return -1

func _draw() -> void:
	# ONLY draw when actively selecting a move destination!
	if not is_move_targeting or not visible or formation_system == null:
		return
		
	# Draw only the valid destination slots for the moving character
	for i in range(valid_slot_indices.size()):
		var slot_idx = valid_slot_indices[i]
		var pos = formation_system.get_slot_position(0, slot_idx)
		var is_focused = (i == selected_valid_idx)
		_draw_tile(pos, slot_idx, is_focused)

func _get_ellipse_points(center: Vector2, rx: float, ry: float, segments: int = 24) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(segments):
		var angle = float(i) / float(segments) * TAU
		pts.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	return pts

func _draw_tile(pos: Vector2, slot_idx: int, is_focused: bool) -> void:
	var pts = _get_ellipse_points(pos, RX, RY, 24)
	
	if is_focused:
		# Bright pulsing gold cursor with floating indicator arrow
		var alpha = 0.8 + 0.2 * sin(pulse_time * 2.0)
		draw_colored_polygon(pts, Color(1.0, 0.85, 0.2, 0.42 * alpha))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1.0, 0.95, 0.4, alpha), 2.5)
		
		# Inner tactical accent ring
		var inner_pts = _get_ellipse_points(pos, RX * 0.65, RY * 0.65, 20)
		draw_polyline(inner_pts + PackedVector2Array([inner_pts[0]]), Color(1.0, 1.0, 0.6, 0.7 * alpha), 1.5)
		
		# Downward pointing arrow indicator hovering above the cell
		var bounce = sin(pulse_time * 3.0) * 3.0
		var arrow_tip = pos + Vector2(0, -RY - 10 + bounce)
		var arrow_pts = PackedVector2Array([
			arrow_tip,
			arrow_tip + Vector2(-6, -10),
			arrow_tip + Vector2(6, -10)
		])
		draw_colored_polygon(arrow_pts, Color(1.0, 0.9, 0.2, 0.95))
		draw_polyline(arrow_pts + PackedVector2Array([arrow_pts[0]]), Color(1.0, 1.0, 0.6, 1.0), 1.5)
	else:
		# Glowing cyan/emerald destination cell (perspective floor disc)
		var alpha = 0.45 + 0.2 * sin(pulse_time + float(slot_idx) * 0.4)
		draw_colored_polygon(pts, Color(0.15, 0.85, 0.65, 0.28 * alpha))
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.25, 1.0, 0.75, 0.8 * alpha), 2.0)
		
		# Subtle inner accent
		var inner_pts = _get_ellipse_points(pos, RX * 0.55, RY * 0.55, 16)
		draw_polyline(inner_pts + PackedVector2Array([inner_pts[0]]), Color(0.35, 1.0, 0.8, 0.35 * alpha), 1.0)
