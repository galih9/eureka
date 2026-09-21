class_name FormationGridVisual
extends Node3D

## Semi-3D Tactical Formation Grid Visualizer for Move command slot selection.
## Renders stylish glowing 3D floor tiles and a hovering indicator over valid destination cells.

signal slot_clicked(slot_index: int)
signal move_canceled()

@export var camera: Camera3D = null

var formation_system: FormationSystem = null
var is_move_targeting: bool = false
var valid_slot_indices: Array[int] = []
var selected_valid_idx: int = 0
var hovered_slot: int = -1

var pulse_time: float = 0.0
var tile_nodes: Dictionary = {} # slot_index -> MeshInstance3D
var cursor_arrow: MeshInstance3D = null

func _ready() -> void:
	visible = false
	_create_cursor_arrow()

func _create_cursor_arrow() -> void:
	if cursor_arrow != null:
		return
	cursor_arrow = MeshInstance3D.new()
	cursor_arrow.name = "MoveCursorArrow"
	
	var cone = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.22
	cone.height = 0.45
	
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.88, 0.2, 0.95)
	cone.material = mat
	
	cursor_arrow.mesh = cone
	cursor_arrow.rotation_degrees = Vector3(180, 0, 0) # Point downward
	cursor_arrow.visible = false
	add_child(cursor_arrow)

func _process(delta: float) -> void:
	if not is_move_targeting or not visible:
		return
		
	pulse_time += delta * 4.0
	_update_tile_visuals()

func start_move_selection(formation: FormationSystem, valid_slots: Array) -> void:
	formation_system = formation
	valid_slot_indices.clear()
	for s in valid_slots:
		valid_slot_indices.append(int(s))
	selected_valid_idx = 0
	is_move_targeting = true
	visible = true
	pulse_time = 0.0
	
	_rebuild_tiles()
	_update_tile_visuals()

func cancel_move_selection() -> void:
	is_move_targeting = false
	valid_slot_indices.clear()
	visible = false
	_clear_tiles()
	if cursor_arrow != null:
		cursor_arrow.visible = false

func get_current_selected_slot() -> int:
	if valid_slot_indices.is_empty():
		return -1
	return valid_slot_indices[selected_valid_idx]

func _clear_tiles() -> void:
	for slot_idx in tile_nodes.keys():
		var node = tile_nodes[slot_idx]
		if is_instance_valid(node):
			node.queue_free()
	tile_nodes.clear()

func _rebuild_tiles() -> void:
	_clear_tiles()
	if formation_system == null:
		return
		
	for slot_idx in valid_slot_indices:
		var slot_pos = formation_system.get_slot_position(0, slot_idx)
		
		var tile = MeshInstance3D.new()
		tile.name = "SlotTile_%d" % slot_idx
		
		var torus = TorusMesh.new()
		torus.inner_radius = 0.52
		torus.outer_radius = 0.65
		torus.rings = 32
		torus.ring_segments = 4
		
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.2, 0.85, 0.65, 0.7)
		torus.material = mat
		
		tile.mesh = torus
		tile.position = slot_pos + Vector3(0.0, 0.02, 0.0)
		add_child(tile)
		tile_nodes[slot_idx] = tile

func _update_tile_visuals() -> void:
	if valid_slot_indices.is_empty():
		return
		
	var active_slot = valid_slot_indices[selected_valid_idx]
	var alpha_pulse = 0.75 + 0.25 * sin(pulse_time * 2.5)
	
	for slot_idx in tile_nodes.keys():
		var tile = tile_nodes[slot_idx] as MeshInstance3D
		if tile == null or not is_instance_valid(tile):
			continue
			
		var mat = tile.mesh.material as StandardMaterial3D
		if slot_idx == active_slot:
			# Focused slot: bright pulsing gold
			if mat != null:
				mat.albedo_color = Color(1.0, 0.88, 0.2, 0.95 * alpha_pulse)
			tile.scale = Vector3(1.15, 1.0, 1.15)
		else:
			# Available slot: subtle emerald/cyan
			if mat != null:
				mat.albedo_color = Color(0.2, 0.85, 0.65, 0.55)
			tile.scale = Vector3.ONE
			
	# Update arrow cursor
	if cursor_arrow != null and formation_system != null:
		var slot_pos = formation_system.get_slot_position(0, active_slot)
		var bounce = sin(pulse_time * 3.0) * 0.10
		cursor_arrow.position = slot_pos + Vector3(0.0, 0.8 + bounce, 0.0)
		cursor_arrow.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not is_move_targeting or not visible or valid_slot_indices.is_empty():
		return
		
	# Keyboard / Gamepad Navigation
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and event.keycode == KEY_D):
		selected_valid_idx = (selected_valid_idx + 1) % valid_slot_indices.size()
		_update_tile_visuals()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and event.keycode == KEY_A):
		selected_valid_idx = (selected_valid_idx - 1 + valid_slot_indices.size()) % valid_slot_indices.size()
		_update_tile_visuals()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
		slot_clicked.emit(valid_slot_indices[selected_valid_idx])
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		cancel_move_selection()
		move_canceled.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var hovered = _find_slot_at_screen_pos(event.position)
		if hovered in valid_slot_indices:
			var idx = valid_slot_indices.find(hovered)
			if idx != -1 and idx != selected_valid_idx:
				selected_valid_idx = idx
				_update_tile_visuals()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_slot = _find_slot_at_screen_pos(event.position)
		if clicked_slot in valid_slot_indices:
			slot_clicked.emit(clicked_slot)
			get_viewport().set_input_as_handled()

func _find_slot_at_screen_pos(screen_pos: Vector2) -> int:
	if formation_system == null:
		return -1
		
	var active_cam = camera
	if active_cam == null and is_inside_tree():
		active_cam = get_viewport().get_camera_3d()
		
	if active_cam == null:
		return -1
		
	var closest_slot = -1
	var min_dist = 60.0 # Screen click radius threshold
	
	for slot_idx in valid_slot_indices:
		var slot_pos_3d = formation_system.get_slot_position(0, slot_idx)
		if active_cam.is_position_behind(slot_pos_3d):
			continue
		var unprojected = active_cam.unproject_position(slot_pos_3d)
		var dist = screen_pos.distance_to(unprojected)
		if dist < min_dist:
			min_dist = dist
			closest_slot = slot_idx
			
	return closest_slot
