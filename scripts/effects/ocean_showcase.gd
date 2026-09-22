extends Node3D

## Showcase controller for Infinite Ocean Waves Shader.
## Provides orbit camera controls and an interactive GUI to tweak wave parameters in real time.

const OceanWater = preload("res://scripts/effects/ocean_water.gd")
const ThunderLightning = preload("res://scripts/effects/thunder_lightning.gd")

@onready var ocean_water: OceanWater = $BattlefieldArena/OceanWater
@onready var thunder: ThunderLightning = $BattlefieldArena/ThunderLightning
@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

@onready var speed_slider: HSlider = %SpeedSlider
@onready var speed_val_label: Label = %SpeedValLabel
@onready var amp_slider: HSlider = %AmpSlider
@onready var amp_val_label: Label = %AmpValLabel
@onready var storm_slider: HSlider = %StormSlider
@onready var storm_val_label: Label = %StormValLabel
@onready var level_slider: HSlider = %LevelSlider
@onready var level_val_label: Label = %LevelValLabel
@onready var lightning_btn: Button = %LightningBtn

var _is_dragging: bool = false
var _last_mouse_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	if ocean_water != null:
		speed_slider.value = ocean_water.wave_speed
		speed_val_label.text = "%.2fx" % ocean_water.wave_speed
		amp_slider.value = ocean_water.wave_amplitude
		amp_val_label.text = "%.2fx" % ocean_water.wave_amplitude
		storm_slider.value = ocean_water.storm_intensity
		storm_val_label.text = "%.2fx" % ocean_water.storm_intensity
		level_slider.value = ocean_water.water_level
		level_val_label.text = "%.2fm" % ocean_water.water_level

	speed_slider.value_changed.connect(func(v: float):
		if ocean_water:
			ocean_water.wave_speed = v
		speed_val_label.text = "%.2fx" % v
	)

	amp_slider.value_changed.connect(func(v: float):
		if ocean_water:
			ocean_water.wave_amplitude = v
		amp_val_label.text = "%.2fx" % v
	)

	storm_slider.value_changed.connect(func(v: float):
		if ocean_water:
			ocean_water.storm_intensity = v
		storm_val_label.text = "%.2fx" % v
	)

	level_slider.value_changed.connect(func(v: float):
		if ocean_water:
			ocean_water.water_level = v
		level_val_label.text = "%.2fm" % v
	)

	if lightning_btn != null and thunder != null:
		lightning_btn.pressed.connect(func():
			thunder.trigger_lightning()
		)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_is_dragging = event.pressed
			_last_mouse_pos = event.position
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if camera != null:
				camera.position.z = clampf(camera.position.z - 1.0, 5.0, 50.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if camera != null:
				camera.position.z = clampf(camera.position.z + 1.0, 5.0, 50.0)

	elif event is InputEventMouseMotion and _is_dragging:
		var delta = event.position - _last_mouse_pos
		_last_mouse_pos = event.position
		if camera_pivot != null:
			camera_pivot.rotation.y -= delta.x * 0.005
			camera_pivot.rotation.x = clampf(camera_pivot.rotation.x - delta.y * 0.005, deg_to_rad(-80), deg_to_rad(10))
