class_name ThunderLightning
extends Node3D

## Atmospheric Thunder & Lightning Controller.
## Triggers occasional multi-strobe lightning flashes in the 3D battlefield environment,
## casting dramatic directional illumination, boosting ambient light, and triggering subtle screen rumble.

@export var enabled: bool = true

@export_group("Timing")
## Delay in seconds until the first thunder/lightning strike (default 6.0s)
@export_range(1.0, 30.0, 0.5) var first_strike_delay: float = 6.0
## Minimum interval between subsequent strikes
@export_range(3.0, 30.0, 0.5) var min_interval: float = 8.0
## Maximum interval between subsequent strikes
@export_range(5.0, 45.0, 0.5) var max_interval: float = 16.0

@export_group("Flash Visuals")
@export var lightning_color: Color = Color(0.85, 0.93, 1.0)
@export_range(1.0, 15.0, 0.5) var flash_energy: float = 5.5
@export var screen_shake_enabled: bool = true

@export_group("Audio")
@export var enable_thunder_audio: bool = true
@export var thunder_sound: AudioStream = preload("res://assets/audio/thunder.wav")
@export_range(-40.0, 6.0, 0.5) var thunder_volume_db: float = 0.0
@export var randomize_pitch: bool = true
@export var thunder_player: AudioStreamPlayer

@export_group("Node References")
@export var lightning_light: DirectionalLight3D
@export var world_environment: WorldEnvironment

var _next_strike_timer: float = 0.0
var _is_flashing: bool = false
var _base_ambient_energy: float = 0.42

func _ready() -> void:
	if thunder_player == null:
		thunder_player = get_node_or_null("ThunderAudioPlayer") as AudioStreamPlayer
	if thunder_player == null and not Engine.is_editor_hint():
		thunder_player = AudioStreamPlayer.new()
		thunder_player.name = "ThunderAudioPlayer"
		add_child(thunder_player)
	if thunder_player != null:
		if thunder_player.stream == null and thunder_sound != null:
			thunder_player.stream = thunder_sound
		thunder_player.volume_db = thunder_volume_db
		thunder_player.bus = &"Master"

	if lightning_light == null:
		lightning_light = get_node_or_null("LightningLight") as DirectionalLight3D
	if lightning_light == null:
		# Auto-create if not present in tree
		lightning_light = DirectionalLight3D.new()
		lightning_light.name = "LightningLight"
		lightning_light.transform = Transform3D(
			Basis(Vector3(1, 0, 0), deg_to_rad(-65)).rotated(Vector3(0, 1, 0), deg_to_rad(35))
		)
		lightning_light.light_color = lightning_color
		lightning_light.light_energy = 0.0
		lightning_light.shadow_enabled = false
		add_child(lightning_light)
	else:
		lightning_light.light_energy = 0.0

	if world_environment == null:
		var parent = get_parent()
		if parent != null:
			world_environment = parent.get_node_or_null("WorldEnvironment") as WorldEnvironment
			
	if world_environment != null and world_environment.environment != null:
		_base_ambient_energy = world_environment.environment.ambient_light_energy

	# Set the first strike timer to fire exactly at first_strike_delay (6.0 seconds)
	_next_strike_timer = first_strike_delay

func _reset_timer() -> void:
	_next_strike_timer = randf_range(min_interval, max_interval)

func _process(delta: float) -> void:
	if not enabled or _is_flashing:
		return
		
	_next_strike_timer -= delta
	if _next_strike_timer <= 0.0:
		trigger_lightning()
		_reset_timer()

## Triggers a realistic multi-strobe lightning flash sequence
func trigger_lightning() -> void:
	if _is_flashing:
		return
		
	_is_flashing = true
	
	if not is_inside_tree():
		return
	
	if lightning_light == null:
		lightning_light = get_node_or_null("LightningLight") as DirectionalLight3D
	if lightning_light != null:
		lightning_light.light_color = lightning_color
		
	var env = world_environment.environment if world_environment != null and world_environment.environment != null else null
	if env != null:
		_base_ambient_energy = env.ambient_light_energy
		
	# Play thunder sound as lightning flash starts
	if enable_thunder_audio:
		_play_thunder_sound()
		
	# Subtle camera rumble
	if screen_shake_enabled:
		var cam_ctrl = get_tree().root.find_child("BattleCameraController", true, false)
		if cam_ctrl != null and cam_ctrl.has_method("shake"):
			cam_ctrl.shake(0.12)
			
	# Multi-strobe realistic lightning sequence:
	# Strobe 1 (quick pre-flash) -> brief dip -> Strobe 2 (main intense strike) -> smooth decay
	var tw = create_tween()
	
	# Strobe 1: initial discharge (~50% energy)
	if lightning_light != null:
		tw.tween_property(lightning_light, "light_energy", flash_energy * 0.5, 0.03)
	if env != null:
		tw.parallel().tween_property(env, "ambient_light_energy", _base_ambient_energy + 0.65, 0.03)
		
	# Dip between strobes
	if lightning_light != null:
		tw.tween_property(lightning_light, "light_energy", flash_energy * 0.15, 0.04)
	if env != null:
		tw.parallel().tween_property(env, "ambient_light_energy", _base_ambient_energy + 0.2, 0.04)
		
	# Strobe 2: Main strike burst (100% energy)
	if lightning_light != null:
		tw.tween_property(lightning_light, "light_energy", flash_energy, 0.06)
	if env != null:
		tw.parallel().tween_property(env, "ambient_light_energy", _base_ambient_energy + 1.25, 0.06)
		
	# Decay back to normal
	if lightning_light != null:
		tw.tween_property(lightning_light, "light_energy", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if env != null:
		tw.parallel().tween_property(env, "ambient_light_energy", _base_ambient_energy, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	tw.tween_callback(func():
		_is_flashing = false
		if lightning_light != null:
			lightning_light.light_energy = 0.0
		if env != null:
			env.ambient_light_energy = _base_ambient_energy
	)

func _play_thunder_sound() -> void:
	if thunder_player == null:
		thunder_player = get_node_or_null("ThunderAudioPlayer") as AudioStreamPlayer
	if thunder_player != null:
		if thunder_player.stream == null and thunder_sound != null:
			thunder_player.stream = thunder_sound
		thunder_player.volume_db = thunder_volume_db
		if randomize_pitch:
			thunder_player.pitch_scale = randf_range(0.95, 1.05)
		else:
			thunder_player.pitch_scale = 1.0
		thunder_player.play()

