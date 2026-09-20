class_name MenuScene
extends Control

## Main menu scene controller providing battle start, display toggle, and quit actions.

@onready var start_button: Button = %StartButton
@onready var tutorial_button: Button = %TutorialButton
@onready var fullscreen_button: Button = %FullscreenButton
@onready var quit_button: Button = %QuitButton
@onready var main_container: Control = $MainContainer

func _ready() -> void:
	# Fade in menu
	main_container.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(main_container, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	start_button.pressed.connect(_on_start_pressed)
	tutorial_button.pressed.connect(_on_tutorial_pressed)
	fullscreen_button.pressed.connect(_on_fullscreen_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	start_button.grab_focus()

func _on_start_pressed() -> void:
	# Fade out then transition to loading scene
	var tween = create_tween()
	tween.tween_property(main_container, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/loading_scene.tscn")
	)

func _on_tutorial_pressed() -> void:
	# Fade out then transition to tutorial arena
	var tween = create_tween()
	tween.tween_property(main_container, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/tutorial_battle_scene.tscn")
	)

func _on_fullscreen_pressed() -> void:
	var mode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		fullscreen_button.text = "FULLSCREEN: OFF"
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		fullscreen_button.text = "FULLSCREEN: ON"

func _on_quit_pressed() -> void:
	get_tree().quit()
