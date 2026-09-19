class_name BattleCameraController
extends Node2D

## Dedicated 2D side-scroller camera controller with dynamic framing,
## smooth ease-based transitions, action tracking, and trauma screen shake.

@export var camera: Camera2D
@export var stage_position: Vector2 = Vector2(576, 324)
@export var stage_zoom: Vector2 = Vector2(1.0, 1.0)
@export var normal_focus_chance: float = 0.20 # 20% chance to zoom on normal acts, 80% stays in stage view

@export_group("Critical Hit FX")
@export var crit_slowdown_enabled: bool = true
@export_range(0.01, 1.0, 0.01) var crit_time_scale: float = 0.15 ## Engine time scale during critical hit slowdown (lower = slower)
@export_range(0.05, 1.5, 0.05) var crit_slowdown_duration: float = 0.35 ## Real-time duration of the slow-down effect in seconds
@export var crit_zoom: Vector2 = Vector2(1.52, 1.52) ## Camera zoom on critical hit
@export var crit_shake_trauma: float = 0.65 ## Screen shake trauma on critical hit

var current_base_pos: Vector2 = Vector2(576, 324)
var current_base_zoom: Vector2 = Vector2(1.0, 1.0)
var _is_in_slowmo: bool = false


var active_tween: Tween = null
var current_shot_type: String = "STAGE"
var tracking_actor: BattleCharacter = null

# Screen Shake (Trauma system)
var trauma: float = 0.0
var trauma_decay: float = 3.6
var max_shake_offset: Vector2 = Vector2(16.0, 12.0)
var max_shake_rot: float = 0.04

## Determines whether camera should zoom in for an action; critical attacks are GUARANTEED
func should_focus_action(is_critical: bool = false) -> bool:
	if is_critical:
		return true
	return randf() < normal_focus_chance

func _ready() -> void:
	if camera == null:
		camera = get_node_or_null("Camera2D")
		
	current_base_pos = stage_position
	current_base_zoom = stage_zoom
	
	if camera != null:
		camera.position = stage_position
		camera.zoom = stage_zoom

func _process(delta: float) -> void:
	if camera == null:
		return
		
	# Follow character action dynamically if tracking
	if tracking_actor != null and is_instance_valid(tracking_actor) and not tracking_actor.is_dead:
		var track_target = tracking_actor.global_position + Vector2(0, -25)
		current_base_pos = current_base_pos.lerp(track_target, delta * 8.0)
		
	# Process trauma shake
	if trauma > 0.0:
		trauma = max(0.0, trauma - delta * trauma_decay)
		var shake_amount = trauma * trauma
		
		var offset_x = (randf() * 2.0 - 1.0) * max_shake_offset.x * shake_amount
		var offset_y = (randf() * 2.0 - 1.0) * max_shake_offset.y * shake_amount
		var rot = (randf() * 2.0 - 1.0) * max_shake_rot * shake_amount
		
		camera.position = current_base_pos + Vector2(offset_x, offset_y)
		camera.rotation = rot
	else:
		camera.position = current_base_pos
		camera.rotation = 0.0
		
	camera.zoom = current_base_zoom

## Triggers impact screen shake (e.g. 0.3 for normal hit, 0.6 for critical)
func shake(amount: float = 0.3) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

## Smooth transition to target 2D position and zoom
func transition_to(target_pos: Vector2, target_zoom: Vector2, duration: float = 0.38) -> void:
	if camera == null:
		return
		
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
		
	active_tween = create_tween().set_parallel(true)
	active_tween.set_trans(Tween.TRANS_CUBIC)
	active_tween.set_ease(Tween.EASE_OUT)
	
	active_tween.tween_property(self, "current_base_pos", target_pos, duration)
	active_tween.tween_property(self, "current_base_zoom", target_zoom, duration)

# --- Camera Transition Sequence ---

## 1. Stage Overview: Neutral view when nothing is happening
func return_to_stage(duration: float = 0.42) -> void:
	current_shot_type = "STAGE"
	tracking_actor = null
	restore_time_scale()
	transition_to(stage_position, stage_zoom, duration)

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
	
	var lead_x = 35.0 if character.team == 0 else -35.0
	var target_pos = character.global_position + Vector2(lead_x, -28.0)
	var target_zoom = Vector2(1.38, 1.38)
	transition_to(target_pos, target_zoom, duration)

func focus_on_character(character: BattleCharacter) -> void:
	focus_on_command(character)

## Guaranteed dramatic camera focus and slowdown on critical hit
func focus_on_critical_hit(target: BattleCharacter, duration: float = 0.22) -> void:
	if target == null or not is_instance_valid(target):
		return
	current_shot_type = "CRITICAL"
	tracking_actor = null
	var target_pos = target.global_position + Vector2(0, -25.0)
	transition_to(target_pos, crit_zoom, duration)
	shake(crit_shake_trauma)
	if crit_slowdown_enabled:
		apply_slow_motion(crit_time_scale, crit_slowdown_duration)

## Applies hit-stop / dramatic time dilation
func apply_slow_motion(scale: float = 0.15, real_duration: float = 0.35) -> void:
	Engine.time_scale = scale
	_is_in_slowmo = true
	# SceneTreeTimer with ignore_time_scale = true measures real wall-clock seconds
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
	var target_pos = character.global_position + Vector2(0, -25.0)
	var target_zoom = Vector2(1.35, 1.35)
	transition_to(target_pos, target_zoom, duration)
	# Start following character action
	tracking_actor = character

## 4. Focus to character that has been targeted by that command
func focus_on_target(target: BattleCharacter, duration: float = 0.28) -> void:
	if target == null:
		return
		
	current_shot_type = "TARGET"
	tracking_actor = null
	var target_pos = target.global_position + Vector2(0, -25.0)
	var target_zoom = Vector2(1.48, 1.48)
	transition_to(target_pos, target_zoom, duration)

## Multi-target overview framing
func focus_on_group(targets: Array, duration: float = 0.35) -> void:
	tracking_actor = null
	if targets.is_empty():
		return_to_stage()
		return
		
	var sum_pos = Vector2.ZERO
	var count = 0
	for t in targets:
		if t != null and is_instance_valid(t):
			sum_pos += t.global_position
			count += 1
	if count == 0:
		return_to_stage()
		return
		
	var avg_pos = (sum_pos / float(count)) + Vector2(0, -20.0)
	transition_to(avg_pos, Vector2(1.2, 1.2), duration)

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
