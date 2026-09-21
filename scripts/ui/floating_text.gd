class_name FloatingText
extends Label

var world_position: Vector3 = Vector3.ZERO
var camera: Camera3D = null
var lifetime: float = 1.0
var elapsed: float = 0.0

func setup(text_str: String, p_world_pos: Vector3, p_camera: Camera3D, color: Color, is_crit: bool = false, is_miss: bool = false) -> void:
	text = text_str
	world_position = p_world_pos + Vector3(0.0, 1.4, 0.0)
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
	world_position.y += delta * 0.9
	_update_screen_position()

func _update_screen_position() -> void:
	if camera != null and is_instance_valid(camera):
		if not camera.is_position_behind(world_position):
			var screen_pos = camera.unproject_position(world_position)
			position = screen_pos - size * 0.5
			visible = true
		else:
			visible = false
	else:
		visible = true
