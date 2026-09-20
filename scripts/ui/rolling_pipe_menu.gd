class_name RollingPipeMenu
extends Control

## 3D-perspective "Rolling Pipe" (Cylinder Drum / SMT V Arc) selection menu.
## Items roll along a vertical cylinder with smooth perspective scaling,
## foreshortening, cosine-based fade out, and horizontal spread/protrusion.
## Features an anchored middle [X] back button that stays fixed at the center row,
## and SMT V-inspired scroll indicator arrows.

signal item_activated(index: int, item_data: Dictionary)
signal item_changed(index: int, item_data: Dictionary)
signal back_pressed()

@export var radius: float = 100.0
@export var angle_step_deg: float = 24.0
@export var item_width: float = 215.0
@export var item_height: float = 28.0
@export var scroll_speed: float = 16.0
@export var arc_curve_x: float = 65.0

@export var show_back_button: bool = false:
	set(val):
		show_back_button = val
		if back_btn:
			back_btn.visible = val
			_update_layout()

@export var back_button_size: Vector2 = Vector2(28, 28)
@export var back_button_gap: float = 8.0

var items: Array[Dictionary] = []
var target_index: float = 0.0
var current_scroll: float = 0.0
var is_active: bool = false

# Internal nodes
var items_container: Control
var back_btn: Button
var button_pool: Array[Button] = []

# Mouse drag interaction
var is_dragging: bool = false
var drag_start_y: float = 0.0
var drag_start_scroll: float = 0.0

# Sound / visual styling cache
var style_normal: StyleBoxFlat
var style_active: StyleBoxFlat
var style_hover: StyleBoxFlat
var style_disabled: StyleBoxFlat
var style_back_normal: StyleBoxFlat
var style_back_hover: StyleBoxFlat
var style_back_pressed: StyleBoxFlat

func _init() -> void:
	_init_styles()

func _ready() -> void:
	custom_minimum_size = Vector2(item_width + arc_curve_x + back_button_size.x + back_button_gap + 20.0, radius * 2.2 + item_height)
	mouse_filter = MOUSE_FILTER_PASS
	clip_contents = false
	
	items_container = Control.new()
	items_container.name = "ItemsContainer"
	items_container.set_anchors_preset(PRESET_FULL_RECT)
	items_container.mouse_filter = MOUSE_FILTER_PASS
	add_child(items_container)
	
	_setup_back_button()
	set_process(true)

func _init_styles() -> void:
	var pill_radius = int(item_height / 2.0)
	
	# Normal button style (unfocused on arc, sleek dark glass capsule)
	style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.06, 0.09, 0.16, 0.85)
	style_normal.border_color = Color(0.28, 0.52, 0.80, 0.65)
	style_normal.border_width_left = 2
	style_normal.border_width_right = 2
	style_normal.border_width_top = 2
	style_normal.border_width_bottom = 2
	style_normal.corner_radius_top_left = pill_radius
	style_normal.corner_radius_top_right = pill_radius
	style_normal.corner_radius_bottom_right = pill_radius
	style_normal.corner_radius_bottom_left = pill_radius
	
	# Active / Center button style (glowing golden highlight)
	style_active = StyleBoxFlat.new()
	style_active.bg_color = Color(0.12, 0.17, 0.30, 0.96)
	style_active.border_color = Color(1.0, 0.84, 0.25, 1.0)
	style_active.border_width_left = 2
	style_active.border_width_right = 2
	style_active.border_width_top = 2
	style_active.border_width_bottom = 2
	style_active.corner_radius_top_left = pill_radius
	style_active.corner_radius_top_right = pill_radius
	style_active.corner_radius_bottom_right = pill_radius
	style_active.corner_radius_bottom_left = pill_radius
	style_active.shadow_color = Color(1.0, 0.82, 0.2, 0.40)
	style_active.shadow_size = 7
	
	# Hover style
	style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.15, 0.22, 0.35, 0.95)
	style_hover.border_color = Color(0.45, 0.78, 1.0, 0.95)
	style_hover.border_width_left = 2
	style_hover.border_width_right = 2
	style_hover.border_width_top = 2
	style_hover.border_width_bottom = 2
	style_hover.corner_radius_top_left = pill_radius
	style_hover.corner_radius_top_right = pill_radius
	style_hover.corner_radius_bottom_right = pill_radius
	style_hover.corner_radius_bottom_left = pill_radius
	
	# Disabled style
	style_disabled = StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.04, 0.05, 0.08, 0.70)
	style_disabled.border_color = Color(0.25, 0.3, 0.38, 0.35)
	style_disabled.border_width_left = 1
	style_disabled.border_width_right = 1
	style_disabled.border_width_top = 1
	style_disabled.border_width_bottom = 1
	style_disabled.corner_radius_top_left = pill_radius
	style_disabled.corner_radius_top_right = pill_radius
	style_disabled.corner_radius_bottom_right = pill_radius
	style_disabled.corner_radius_bottom_left = pill_radius

	# Back Button [X] Coral / Red style (matching sketch)
	style_back_normal = StyleBoxFlat.new()
	style_back_normal.bg_color = Color(0.88, 0.32, 0.38, 0.95)
	style_back_normal.border_color = Color(1.0, 0.68, 0.72, 0.95)
	style_back_normal.border_width_left = 2
	style_back_normal.border_width_right = 2
	style_back_normal.border_width_top = 2
	style_back_normal.border_width_bottom = 2
	style_back_normal.corner_radius_top_left = 7
	style_back_normal.corner_radius_top_right = 7
	style_back_normal.corner_radius_bottom_right = 7
	style_back_normal.corner_radius_bottom_left = 7
	
	style_back_hover = StyleBoxFlat.new()
	style_back_hover.bg_color = Color(0.96, 0.40, 0.46, 1.0)
	style_back_hover.border_color = Color(1.0, 0.85, 0.88, 1.0)
	style_back_hover.border_width_left = 2
	style_back_hover.border_width_right = 2
	style_back_hover.border_width_top = 2
	style_back_hover.border_width_bottom = 2
	style_back_hover.corner_radius_top_left = 7
	style_back_hover.corner_radius_top_right = 7
	style_back_hover.corner_radius_bottom_right = 7
	style_back_hover.corner_radius_bottom_left = 7
	style_back_hover.shadow_color = Color(0.95, 0.3, 0.4, 0.4)
	style_back_hover.shadow_size = 4
	
	style_back_pressed = StyleBoxFlat.new()
	style_back_pressed.bg_color = Color(0.65, 0.20, 0.25, 1.0)
	style_back_pressed.border_color = Color(0.85, 0.5, 0.55, 1.0)
	style_back_pressed.border_width_left = 2
	style_back_pressed.border_width_right = 2
	style_back_pressed.border_width_top = 2
	style_back_pressed.border_width_bottom = 2
	style_back_pressed.corner_radius_top_left = 7
	style_back_pressed.corner_radius_top_right = 7
	style_back_pressed.corner_radius_bottom_right = 7
	style_back_pressed.corner_radius_bottom_left = 7

func _setup_back_button() -> void:
	back_btn = Button.new()
	back_btn.name = "BtnMiddleBack"
	back_btn.text = "✕"
	back_btn.custom_minimum_size = back_button_size
	back_btn.size = back_button_size
	back_btn.pivot_offset = back_button_size / 2.0
	back_btn.focus_mode = FOCUS_NONE
	back_btn.mouse_filter = MOUSE_FILTER_STOP
	back_btn.visible = show_back_button
	
	back_btn.add_theme_stylebox_override("normal", style_back_normal)
	back_btn.add_theme_stylebox_override("hover", style_back_hover)
	back_btn.add_theme_stylebox_override("pressed", style_back_pressed)
	back_btn.add_theme_color_override("font_color", Color.WHITE)
	back_btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.95))
	back_btn.add_theme_font_size_override("font_size", 15)
	
	back_btn.pressed.connect(func():
		_play_back_punch_effect()
		back_pressed.emit()
	)
	
	add_child(back_btn)

func _play_back_punch_effect() -> void:
	var tw = create_tween()
	tw.tween_property(back_btn, "scale", Vector2(0.85, 0.85), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(back_btn, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Set the list of items to display.
## Each item dictionary can have:
## { "id": String/int, "text": String, "disabled": bool, "data": Variant }
func set_items(new_items: Array[Dictionary], initial_index: int = 0) -> void:
	items = new_items.duplicate(true)
	target_index = clampf(float(initial_index), 0.0, maxf(0.0, float(items.size() - 1)))
	current_scroll = target_index
	_rebuild_buttons()
	_update_layout()
	is_active = true

func set_selected_index(idx: int) -> void:
	if items.is_empty():
		return
	target_index = clampf(float(idx), 0.0, float(items.size() - 1))

func get_selected_index() -> int:
	return int(round(target_index))

func get_selected_item() -> Dictionary:
	var idx = get_selected_index()
	if idx >= 0 and idx < items.size():
		return items[idx]
	return {}

func _rebuild_buttons() -> void:
	if items_container == null:
		return
		
	# Ensure pool has enough buttons
	while button_pool.size() < items.size():
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(item_width, item_height)
		btn.size = Vector2(item_width, item_height)
		btn.pivot_offset = Vector2(0.0, item_height / 2.0)
		btn.clip_text = true
		btn.focus_mode = FOCUS_NONE
		btn.mouse_filter = MOUSE_FILTER_STOP
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		btn.add_theme_stylebox_override("normal", style_normal)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("disabled", style_disabled)
		btn.add_theme_font_size_override("font_size", 12)
		
		var b_idx = button_pool.size()
		btn.pressed.connect(func(): _on_button_clicked(b_idx))
		
		items_container.add_child(btn)
		button_pool.append(btn)
		
	# Configure buttons
	for i in range(button_pool.size()):
		var btn = button_pool[i]
		if i < items.size():
			btn.visible = true
			var item = items[i]
			btn.text = "  %s" % item.get("text", "")
			var dis = item.get("disabled", false)
			btn.disabled = dis
			if dis:
				btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.55, 0.6, 0.6))
			else:
				btn.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		else:
			btn.visible = false

func _on_button_clicked(index: int) -> void:
	var cur_int = get_selected_index()
	if index == cur_int:
		# Already centered -> Activate!
		if index >= 0 and index < items.size():
			var item = items[index]
			if not item.get("disabled", false):
				_play_activate_effect(index)
				item_activated.emit(index, item)
	else:
		# Roll pipe to this item!
		target_index = clampf(float(index), 0.0, float(items.size() - 1))
		if index >= 0 and index < items.size():
			item_changed.emit(index, items[index])

func _play_activate_effect(index: int) -> void:
	if index >= 0 and index < button_pool.size():
		var btn = button_pool[index]
		var tw = create_tween()
		tw.tween_property(btn, "scale", Vector2(1.1, 1.1), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func scroll_up() -> void:
	if items.is_empty():
		return
	var new_idx = clampf(target_index - 1.0, 0.0, float(items.size() - 1))
	if new_idx != target_index:
		target_index = new_idx
		item_changed.emit(int(target_index), items[int(target_index)])

func scroll_down() -> void:
	if items.is_empty():
		return
	var new_idx = clampf(target_index + 1.0, 0.0, float(items.size() - 1))
	if new_idx != target_index:
		target_index = new_idx
		item_changed.emit(int(target_index), items[int(target_index)])

func activate_current() -> void:
	var idx = get_selected_index()
	if idx >= 0 and idx < items.size():
		var item = items[idx]
		if not item.get("disabled", false):
			_play_activate_effect(idx)
			item_activated.emit(idx, item)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
		
	# Smoothly interpolate scroll position
	if not is_dragging:
		var diff = target_index - current_scroll
		if absf(diff) > 0.001:
			current_scroll = lerpf(current_scroll, target_index, 1.0 - exp(-scroll_speed * delta))
		else:
			current_scroll = target_index
			
	_update_layout()

func _update_layout() -> void:
	var effective_height = size.y if size.y > 10.0 else custom_minimum_size.y
	var center_y = effective_height / 2.0
	var step_rad = deg_to_rad(angle_step_deg)
	
	# Base left X for the protruding center item (sticking out to the left towards the battlefield)
	var base_left_x = 12.0
	var closest_idx = int(round(current_scroll))
	var center_btn_visual_right = base_left_x + item_width
	
	for i in range(items.size()):
		if i >= button_pool.size():
			break
		var btn = button_pool[i]
		var theta = (float(i) - current_scroll) * step_rad
		
		# Behind the pipe (> 85 degrees) -> hide
		if absf(theta) >= (PI * 0.46):
			btn.visible = false
			continue
			
		btn.visible = true
		
		var cos_t = cos(theta)
		var sin_t = sin(theta)
		
		# Position Y: center_y + radius * sin(theta) - (item_height / 2.0)
		var py = center_y + (radius * sin_t) - (item_height / 2.0)
		
		# Exaggerated 3D Curve (bows out to the LEFT):
		# Center item (sin_t = 0) is at base_left_x (furthest left).
		# Receding items (above & below) curve significantly to the RIGHT (+X)
		var curve_offset = pow(absf(sin_t), 1.1) * arc_curve_x
		var px = base_left_x + curve_offset
		
		btn.position = Vector2(px, py)
		
		# Perspective scale & foreshortening
		var sy = maxf(0.40, cos_t)
		var sx = lerpf(0.85, 1.04, cos_t)
		
		# Center item highlight & styling
		var is_center = (i == closest_idx)
		if is_center:
			sx *= 1.05
			sy *= 1.06
			btn.add_theme_stylebox_override("normal", style_active)
			btn.add_theme_color_override("font_color", Color(1.0, 0.96, 0.75))
			center_btn_visual_right = px + item_width * sx
		else:
			btn.add_theme_stylebox_override("normal", style_normal)
			btn.add_theme_color_override("font_color", Color(0.85, 0.90, 0.98))
			
		btn.scale = Vector2(sx, sy)
		
		# Smooth alpha fade as items roll away along the cylinder
		var alpha = pow(maxf(0.0, cos_t), 1.35)
		btn.modulate = Color(1.0, 1.0, 1.0, alpha)
		
		# Z-index: items in front render over items receding
		btn.z_index = int(cos_t * 90.0)

	# Position the Middle [X] back button stationary at the center row,
	# directly beside the right edge of the protruding center item
	if back_btn:
		back_btn.visible = show_back_button
		if show_back_button:
			back_btn.position = Vector2(
				center_btn_visual_right + back_button_gap,
				center_y - (back_button_size.y / 2.0)
			)
			back_btn.z_index = 110

func _gui_input(event: InputEvent) -> void:
	if not is_active or not is_visible_in_tree():
		return
		
	# Mouse Wheel Rolling
	if event is InputEventMouseButton:
		var mb = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				scroll_up()
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scroll_down()
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				is_dragging = true
				drag_start_y = mb.position.y
				drag_start_scroll = current_scroll
		elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if is_dragging:
				is_dragging = false
				target_index = clampf(round(current_scroll), 0.0, float(items.size() - 1))
				accept_event()
				
	elif event is InputEventMouseMotion and is_dragging:
		var mm = event as InputEventMouseMotion
		var dy = mm.position.y - drag_start_y
		# Convert pixel delta to cylinder scroll delta
		var scroll_delta = -dy / (item_height * 0.85)
		current_scroll = clampf(drag_start_scroll + scroll_delta, -0.4, float(items.size() - 1) + 0.4)
		accept_event()

func handle_external_input(event: InputEvent) -> bool:
	if not is_active or not is_visible_in_tree() or items.is_empty():
		return false
		
	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and event.keycode == KEY_W):
		scroll_up()
		return true
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and event.keycode == KEY_S):
		scroll_down()
		return true
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_ENTER or event.keycode == KEY_SPACE)):
		activate_current()
		return true
	elif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if show_back_button:
			_play_back_punch_effect()
			back_pressed.emit()
			return true
			
	return false
