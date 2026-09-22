class_name BattleCameraController
extends Node3D

## Semi-3D Camera Controller for tactical timeline battles.
## Handles dynamic framing, smooth 3D transitions, action tracking, and trauma screen shake.

@export var camera: Camera3D
## When true (default), automatically initializes the stage position, rotation, and FOV from the Camera3D node's transform in the scene editor.
@export var use_camera_node_transform: bool = true
@export var stage_position: Vector3 = Vector3(0.0, 5.2, 11.8)
@export var stage_rotation_pitch: float = -19.5: ## Pitch angle in degrees
	set(value):
		stage_rotation_pitch = value
		stage_rotation.x = deg_to_rad(value)
@export var stage_rotation: Vector3 = Vector3(deg_to_rad(-19.5), 0.0, 0.0) ## Base Euler rotation (pitch, yaw, roll)
@export var stage_fov: float = 38.0
@export var normal_focus_chance: float = 0.75 # 75% chance to zoom on normal acts, 25% stays in stage view

@export_group("Critical Hit FX")
@export var crit_slowdown_enabled: bool = true
@export_range(0.01, 1.0, 0.01) var crit_time_scale: float = 0.15 ## Engine time scale during critical hit slowdown
@export_range(0.05, 1.5, 0.05) var crit_slowdown_duration: float = 0.35 ## Real-time duration of slow-down in seconds
@export var crit_fov: float = 26.0 ## Camera FOV on critical hit
@export var crit_shake_trauma: float = 0.65 ## Screen shake trauma on critical hit

@export_group("Intro Cinematic")
@export var intro_duration: float = 5.0
@export var intro_start_position: Vector3 = Vector3(6.8, 7.2, 15.8)
@export var intro_start_rotation_degrees: Vector3 = Vector3(-21.0, 15.0, -1.2)
@export var intro_start_fov: float = 50.0
@export var intro_mid_position: Vector3 = Vector3(-3.2, 6.0, 13.6)
@export var intro_mid_rotation_degrees: Vector3 = Vector3(-18.5, -7.0, 0.8)
@export var intro_mid_fov: float = 44.0

signal intro_completed()

var current_base_pos: Vector3 = Vector3(0.0, 5.2, 11.8)
var current_base_rot: Vector3 = Vector3.ZERO
var current_base_fov: float = 38.0
var _is_in_slowmo: bool = false

var active_tween: Tween = null
var intro_tween: Tween = null
var is_intro_active: bool = false
var current_shot_type: String = "STAGE"
var tracking_actor: BattleCharacter = null

# Screen Shake (Trauma system)
var trauma: float = 0.0
var trauma_decay: float = 3.6
var max_shake_offset: Vector3 = Vector3(0.32, 0.22, 0.18)
var max_shake_rot: Vector3 = Vector3(0.025, 0.025, 0.035)

## Determines whether camera should zoom in for an action; critical attacks are GUARANTEED
func should_focus_action(is_critical: bool = false) -> bool:
	if is_critical:
		return true
	return randf() < normal_focus_chance

func _ready() -> void:
	if camera == null:
		camera = get_node_or_null("Camera3D")
		
	if camera != null and use_camera_node_transform:
		stage_position = camera.position
		stage_rotation = camera.rotation
		stage_rotation_pitch = rad_to_deg(camera.rotation.x)
		stage_fov = camera.fov
	else:
		if stage_rotation == Vector3.ZERO and not is_zero_approx(stage_rotation_pitch):
			stage_rotation = Vector3(deg_to_rad(stage_rotation_pitch), 0.0, 0.0)

	current_base_pos = stage_position
	current_base_rot = stage_rotation
	current_base_fov = stage_fov
	
	if camera != null:
		camera.position = stage_position
		camera.rotation = stage_rotation
		camera.fov = stage_fov

func _process(delta: float) -> void:
	if camera == null:
		return
		
	# Follow character action dynamically if tracking
	if tracking_actor != null and is_instance_valid(tracking_actor) and not tracking_actor.is_dead:
		var track_target = Vector3(tracking_actor.global_position.x, 3.5, 9.5)
		current_base_pos = current_base_pos.lerp(track_target, delta * 7.0)
		
	# Process trauma shake in 3D
	var base_rot = current_base_rot
	if trauma > 0.0:
		trauma = max(0.0, trauma - delta * trauma_decay)
		var shake_amount = trauma * trauma
		
		var offset_x = (randf() * 2.0 - 1.0) * max_shake_offset.x * shake_amount
		var offset_y = (randf() * 2.0 - 1.0) * max_shake_offset.y * shake_amount
		var offset_z = (randf() * 2.0 - 1.0) * max_shake_offset.z * shake_amount
		
		var rot_x = (randf() * 2.0 - 1.0) * max_shake_rot.x * shake_amount
		var rot_y = (randf() * 2.0 - 1.0) * max_shake_rot.y * shake_amount
		var rot_z = (randf() * 2.0 - 1.0) * max_shake_rot.z * shake_amount
		
		camera.position = current_base_pos + Vector3(offset_x, offset_y, offset_z)
		camera.rotation = base_rot + Vector3(rot_x, rot_y, rot_z)
	else:
		camera.position = current_base_pos
		camera.rotation = base_rot
		
	camera.fov = current_base_fov

## Triggers impact screen shake (e.g. 0.3 for normal hit, 0.6 for critical)
func shake(amount: float = 0.3) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

## Smooth transition to target 3D position, rotation and FOV
func transition_to(target_pos: Vector3, target_fov: float, duration: float = 0.38, target_rot: Vector3 = stage_rotation) -> void:
	if camera == null:
		return
		
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
		
	active_tween = create_tween().set_parallel(true)
	active_tween.set_trans(Tween.TRANS_CUBIC)
	active_tween.set_ease(Tween.EASE_OUT)
	
	active_tween.tween_property(self, "current_base_pos", target_pos, duration)
	active_tween.tween_property(self, "current_base_rot", target_rot, duration)
	active_tween.tween_property(self, "current_base_fov", target_fov, duration)

## Plays a cinematic arena sweep before the battle starts.
## Lasts total duration (default 5.0s), showing the arena from around and zooming into stage view.
func play_arena_intro(duration: float = -1.0) -> void:
	if camera == null:
		intro_completed.emit()
		return
		
	var anim_duration = duration if duration > 0.0 else intro_duration
	
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	if intro_tween != null and intro_tween.is_valid():
		intro_tween.kill()
		
	is_intro_active = true
	current_shot_type = "INTRO"
	tracking_actor = null
	
	var start_pos = intro_start_position
	var start_rot = Vector3(
		deg_to_rad(intro_start_rotation_degrees.x),
		deg_to_rad(intro_start_rotation_degrees.y),
		deg_to_rad(intro_start_rotation_degrees.z)
	)
	var start_fov = intro_start_fov
	
	var mid_pos = intro_mid_position
	var mid_rot = Vector3(
		deg_to_rad(intro_mid_rotation_degrees.x),
		deg_to_rad(intro_mid_rotation_degrees.y),
		deg_to_rad(intro_mid_rotation_degrees.z)
	)
	var mid_fov = intro_mid_fov
	
	var end_pos = stage_position
	var end_rot = stage_rotation
	var end_fov = stage_fov
	
	current_base_pos = start_pos
	current_base_rot = start_rot
	current_base_fov = start_fov
	camera.position = start_pos
	camera.rotation = start_rot
	camera.fov = start_fov
	
	var part1_time = anim_duration * 0.48
	var part2_time = anim_duration * 0.52
	
	intro_tween = create_tween()
	
	# Part 1: Wide angled overview sweeping across the arena
	intro_tween.parallel().tween_property(self, "current_base_pos", mid_pos, part1_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	intro_tween.parallel().tween_property(self, "current_base_rot", mid_rot, part1_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	intro_tween.parallel().tween_property(self, "current_base_fov", mid_fov, part1_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Part 2: Dynamic zoom-in and alignment to standard battle stage
	intro_tween.chain().parallel().tween_property(self, "current_base_pos", end_pos, part2_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro_tween.chain().parallel().tween_property(self, "current_base_rot", end_rot, part2_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	intro_tween.chain().parallel().tween_property(self, "current_base_fov", end_fov, part2_time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	intro_tween.chain().tween_callback(func():
		is_intro_active = false
		current_shot_type = "STAGE"
		intro_completed.emit()
	)

## Skips the intro camera sequence immediately, smoothly blending or snapping to stage view
func skip_arena_intro(quick_blend: bool = true) -> void:
	if not is_intro_active:
		return
		
	if intro_tween != null and intro_tween.is_valid():
		intro_tween.kill()
		
	is_intro_active = false
	current_shot_type = "STAGE"
	
	if quick_blend:
		transition_to(stage_position, stage_fov, 0.18, stage_rotation)
	else:
		current_base_pos = stage_position
		current_base_rot = stage_rotation
		current_base_fov = stage_fov
		if camera != null:
			camera.position = stage_position
			camera.rotation = stage_rotation
			camera.fov = stage_fov
			
	intro_completed.emit()

# --- Camera Transition Sequence ---

## 1. Stage Overview: Neutral view when nothing is happening
func return_to_stage(duration: float = 0.42) -> void:
	current_shot_type = "STAGE"
	tracking_actor = null
	restore_time_scale()
	transition_to(stage_position, stage_fov, duration, stage_rotation)

func return_to_idle() -> void:
	return_to_stage()

func focus_on_battlefield() -> void:
	return_to_stage(0.35)

## 2. Focus to character that has command (chance-based unless forced)
func focus_on_command(character: BattleCharacter, duration: float = 0.36, force: bool = false) -> void:
	if character == null or (not force and not should_focus_action(false)):
		return_to_stage(duration)
		return
		
	current_shot_type = "COMMAND"
	tracking_actor = null
	
	var lead_x = 0.6 if character.team == 0 else -0.6
	var target_pos = Vector3(character.global_position.x + lead_x, 3.4, 9.2)
	transition_to(target_pos, 35.0, duration)

func focus_on_character(character: BattleCharacter) -> void:
	focus_on_command(character)

## Guaranteed dramatic camera focus and slowdown on critical hit
func focus_on_critical_hit(target: BattleCharacter, duration: float = 0.22) -> void:
	if target == null or not is_instance_valid(target):
		return
	current_shot_type = "CRITICAL"
	tracking_actor = null
	var target_pos = Vector3(target.global_position.x, 3.0, 7.8)
	transition_to(target_pos, crit_fov, duration)
	shake(crit_shake_trauma)
	if crit_slowdown_enabled:
		apply_slow_motion(crit_time_scale, crit_slowdown_duration)

## Applies hit-stop / dramatic time dilation
func apply_slow_motion(scale: float = 0.15, real_duration: float = 0.35) -> void:
	Engine.time_scale = scale
	_is_in_slowmo = true
	var timer = get_tree().create_timer(real_duration, true, false, true)
	timer.timeout.connect(func():
		restore_time_scale()
	)

## Restores engine speed to normal 1.0x
func restore_time_scale() -> void:
	if _is_in_slowmo:
		Engine.time_scale = 1.0
		_is_in_slowmo = false

func _exit_tree() -> void:
	Engine.time_scale = 1.0

## 3. Focus to character that acts the command and follow their action
func focus_on_actor(character: BattleCharacter, duration: float = 0.3) -> void:
	if character == null:
		return_to_stage()
		return
		
	current_shot_type = "ACTOR"
	var target_pos = Vector3(character.global_position.x, 3.4, 9.2)
	transition_to(target_pos, 35.0, duration)
	tracking_actor = character

## 4. Focus to character that has been targeted by that command
func focus_on_target(target: BattleCharacter, duration: float = 0.28) -> void:
	if target == null:
		return
		
	current_shot_type = "TARGET"
	tracking_actor = null
	var target_pos = Vector3(target.global_position.x, 3.4, 8.8)
	transition_to(target_pos, 32.0, duration)

## Multi-target overview framing
func focus_on_group(targets: Array, duration: float = 0.35) -> void:
	tracking_actor = null
	if targets.is_empty():
		return_to_stage()
		return
		
	var sum_pos = Vector3.ZERO
	var count = 0
	for t in targets:
		if t != null and is_instance_valid(t):
			sum_pos += t.global_position
			count += 1
	if count == 0:
		return_to_stage()
		return
		
	var avg_pos = sum_pos / float(count)
	transition_to(Vector3(avg_pos.x, 3.8, 10.2), 38.0, duration)

## Action camera sequence initiation
func play_action_camera(actor: BattleCharacter, target: BattleCharacter, action_def: ActionDefinition = null) -> void:
	if actor == null:
		return
	if action_def != null and action_def.action_type == ActionDefinition.ActionType.DEFEND:
		focus_on_actor(actor, 0.3)
	elif target != null:
		focus_on_actor(actor, 0.25)
	else:
		focus_on_actor(actor, 0.3)
