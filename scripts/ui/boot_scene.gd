class_name BootScene
extends Control

## Boot splash sequence that smoothly transitions to Main Menu.
## Allows immediate skip on any keypress or mouse click.

@onready var content_container: Control = $CenterContainer/VBoxContainer
@onready var skip_hint: Label = $SkipHint

var is_transitioning: bool = false

func _ready() -> void:
	content_container.modulate.a = 0.0
	skip_hint.modulate.a = 0.0
	
	var tween = create_tween()
	# Fade in content
	tween.tween_property(content_container, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(skip_hint, "modulate:a", 0.6, 0.7)
	# Hold
	tween.tween_interval(1.4)
	# Fade out
	tween.tween_property(content_container, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(skip_hint, "modulate:a", 0.0, 0.4)
	# Switch to menu
	tween.tween_callback(_go_to_menu)

func _unhandled_input(event: InputEvent) -> void:
	if is_transitioning:
		return
	if (event is InputEventKey and event.is_pressed()) or (event is InputEventMouseButton and event.is_pressed()):
		_go_to_menu()

func _go_to_menu() -> void:
	if is_transitioning:
		return
	is_transitioning = true
	get_tree().change_scene_to_file("res://scenes/menu_scene.tscn")
