class_name FloatingText
extends Label

var world_position: Vector2 = Vector2.ZERO
var camera: Camera2D = null
var lifetime: float = 1.0
var elapsed: float = 0.0

func setup(text_str: String, p_world_pos: Vector2, p_camera: Camera2D, color: Color, is_crit: bool = false, is_miss: bool = false) -> void:
	text = text_str
	world_position = p_world_pos + Vector2(0.0, -42.0)
	camera = p_camera
	
	modulate = color
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Stylized bold retro font styling
	add_theme_font_size_override("font_size", 28 if is_crit else (22 if not is_miss else 18))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	add_theme_constant_override("outline_size", 8 if is_crit else 5)
	
	_update_screen_position()
	
	# Scale punch animation
	var tw = create_tween()
	scale = Vector2(1.5, 1.5) if is_crit else Vector2(1.2, 1.2)
	tw.tween_property(self, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.4)
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.tween_callback(queue_free)

func _process(delta: float) -> void:
	world_position.y -= delta * 36.0
	_update_screen_position()

func _update_screen_position() -> void:
	if camera != null and is_instance_valid(camera):
		var canvas_transform = camera.get_canvas_transform()
		var screen_pos = canvas_transform * world_position
		position = screen_pos - size * 0.5
	else:
		position = world_position - size * 0.5
