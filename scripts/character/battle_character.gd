class_name BattleCharacter
extends Node3D

## Runtime Semi-3D combatant holding live battle stats, status instances, and perks.
## Displays an AnimatedSprite3D with billboard mode on a 3D arena.

signal hp_changed(current: int, maximum: int)
signal mp_changed(current: int, maximum: int)
signal died(character: BattleCharacter)

@export var character_definition: CharacterDefinition
@export var display_name_override: String = ""

func get_display_name() -> String:
	if display_name_override != "":
		return display_name_override
	if character_definition != null:
		return character_definition.display_name
	return "Combatant"

# Timeline States
enum TimelineState {
	MOVING_TO_COM,
	COMMAND_SELECTION,
	MOVING_TO_EXECUTION,
	EXECUTING_ACTION
}

# Live Combat State
var team: int = 0 # 0 = PLAYER, 1 = ENEMY
var is_player: bool:
	get:
		return team == 0
var current_hp: int = 100
var current_mp: int = 0
var timeline_position: float = 0.0
var timeline_state: TimelineState = TimelineState.MOVING_TO_COM
var pending_action: BattleAction = null
var execution_position: float = 0.0
var is_dead: bool = false
var is_defending: bool = false
var is_captain: bool = false
var formation_slot: int = -1
var protect_target: BattleCharacter = null
var protected_by: BattleCharacter = null
var lifesteal_percent: float = 0.0

var archetype: CharacterDefinition.Archetype:
	get:
		if character_definition != null:
			return character_definition.archetype
		return CharacterDefinition.Archetype.NONE

# Forced / Perk Flags
var guaranteed_hit: bool = false
var guaranteed_critical: bool = false

# Dynamic Modifiers & Tracking
var active_modifiers: Array[StatModifier] = []
var active_statuses: Array = [] # Array[StatusInstance]
var active_perks: Array = []    # Array[PerkInstance]

# 3D Node References
@onready var visual_container: Node3D = $Visual
@onready var animated_sprite: AnimatedSprite3D = $Visual/AnimatedSprite3D
@onready var shadow: Node3D = $Visual/Shadow
@onready var target_indicator: Node3D = $Indicators/TargetIndicator
@onready var selection_indicator: Node3D = $Indicators/SelectionIndicator

@onready var camera_marker: Marker3D = $CameraMarker
@onready var target_marker: Marker3D = $TargetMarker
@onready var attack_origin: Marker3D = $AttackOrigin
@onready var hit_origin: Marker3D = $HitOrigin

var initial_position: Vector3 = Vector3.ZERO
var base_modulate: Color = Color.WHITE
var target_indicator_tween: Tween = null

# Overhead Visuals (projected into screen space)
var overhead_container: Node2D = null
var overhead_hp_bar: ProgressBar = null
var overhead_hp_bg: Panel = null
var overhead_status_box: HBoxContainer = null

func _ready() -> void:
	initial_position = global_position
	if target_indicator != null:
		target_indicator.visible = false
	if selection_indicator != null:
		selection_indicator.visible = false
		
	if animated_sprite != null:
		animated_sprite.animation_finished.connect(_on_animation_finished)
		
	_setup_overhead_ui()
	
	if character_definition != null:
		initialize(character_definition)

func _process(_delta: float) -> void:
	_update_overhead_position()

func _update_overhead_position() -> void:
	if overhead_container == null:
		return
	if is_dead:
		overhead_container.visible = false
		return
	var cam = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null and is_instance_valid(cam):
		var head_world_pos = global_position + Vector3(0.0, 1.15, 0.0)
		if not cam.is_position_behind(head_world_pos):
			overhead_container.position = cam.unproject_position(head_world_pos)
			var show_bar = (team == 1) or not active_statuses.is_empty()
			overhead_container.visible = show_bar
		else:
			overhead_container.visible = false
	else:
		overhead_container.visible = (team == 1)

func _exit_tree() -> void:
	if overhead_container != null and is_instance_valid(overhead_container):
		if overhead_container.get_parent() != self:
			overhead_container.queue_free()

func _setup_overhead_ui() -> void:
	if overhead_container != null:
		return
		
	overhead_container = Node2D.new()
	overhead_container.name = "OverheadUI_%s" % name
	
	if is_inside_tree():
		var ui_node = get_tree().root.find_child("BattleUI", true, false)
		if ui_node != null:
			ui_node.add_child(overhead_container)
		else:
			add_child(overhead_container)
	else:
		add_child(overhead_container)
	
	# Mini Overhead HP bar (displayed for enemies by default)
	overhead_hp_bg = Panel.new()
	overhead_hp_bg.name = "HPBarBackground"
	overhead_hp_bg.custom_minimum_size = Vector2(52, 6)
	overhead_hp_bg.position = Vector2(-26, 0)
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.08, 0.1, 0.15, 0.9)
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.35, 0.35, 0.4, 0.8)
	bg_style.corner_radius_top_left = 2
	bg_style.corner_radius_top_right = 2
	bg_style.corner_radius_bottom_right = 2
	bg_style.corner_radius_bottom_left = 2
	overhead_hp_bg.add_theme_stylebox_override("panel", bg_style)
	
	overhead_hp_bar = ProgressBar.new()
	overhead_hp_bar.name = "OverheadHPBar"
	overhead_hp_bar.custom_minimum_size = Vector2(50, 4)
	overhead_hp_bar.position = Vector2(-25, 1)
	overhead_hp_bar.show_percentage = false
	overhead_hp_bar.max_value = get_stat("max_hp")
	overhead_hp_bar.value = current_hp
	
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.9, 0.25, 0.25) if team == 1 else Color(0.25, 0.85, 0.35)
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_right = 2
	fill_style.corner_radius_bottom_left = 2
	overhead_hp_bar.add_theme_stylebox_override("fill", fill_style)
	
	var empty_bg = StyleBoxEmpty.new()
	overhead_hp_bar.add_theme_stylebox_override("background", empty_bg)
	
	overhead_container.add_child(overhead_hp_bg)
	overhead_container.add_child(overhead_hp_bar)
	
	# Overhead Status Chips Container
	overhead_status_box = HBoxContainer.new()
	overhead_status_box.name = "StatusChips"
	overhead_status_box.alignment = BoxContainer.ALIGNMENT_CENTER
	overhead_status_box.position = Vector2(-75, -20)
	overhead_status_box.custom_minimum_size = Vector2(150, 16)
	overhead_container.add_child(overhead_status_box)
	
	var show_bar = (team == 1)
	overhead_hp_bg.visible = show_bar
	overhead_hp_bar.visible = show_bar

func refresh_overhead_hp() -> void:
	if overhead_hp_bar == null:
		return
	var max_h = get_stat("max_hp")
	overhead_hp_bar.max_value = max_h
	overhead_hp_bar.value = current_hp
	if is_dead and overhead_container != null:
		overhead_container.visible = false

func refresh_overhead_status() -> void:
	if overhead_status_box == null:
		return
	for child in overhead_status_box.get_children():
		child.queue_free()
		
	if is_dead:
		return
		
	for st in active_statuses:
		var chip = PanelContainer.new()
		var chip_style = StyleBoxFlat.new()
		chip_style.corner_radius_top_left = 3
		chip_style.corner_radius_top_right = 3
		chip_style.corner_radius_bottom_right = 3
		chip_style.corner_radius_bottom_left = 3
		chip_style.content_margin_left = 4
		chip_style.content_margin_right = 4
		chip_style.content_margin_top = 1
		chip_style.content_margin_bottom = 1
		
		var label = Label.new()
		label.add_theme_font_size_override("font_size", 9)
		
		var s_name = st.definition.status_name.to_upper()
		var color = Color(0.9, 0.9, 0.9)
		
		match st.definition.status_type:
			StatusDefinition.StatusType.STUN:
				color = Color(1.0, 0.85, 0.1) # Gold
				s_name = "STUN"
			StatusDefinition.StatusType.SLEEP:
				color = Color(0.4, 0.75, 1.0) # Light blue
				s_name = "SLEEP"
			StatusDefinition.StatusType.FLINCH:
				color = Color(1.0, 0.55, 0.15) # Orange
				s_name = "SLOW"
			StatusDefinition.StatusType.SILENCE:
				color = Color(0.8, 0.4, 1.0) # Purple
				s_name = "MUTE"
			StatusDefinition.StatusType.DISARM:
				color = Color(1.0, 0.25, 0.35) # Red
				s_name = "DISARM"
			_:
				if st.definition.status_id == "poison":
					color = Color(0.4, 0.9, 0.3)
					s_name = "TOXIC"
				elif st.definition.status_id == "bleed":
					color = Color(0.95, 0.2, 0.2)
					s_name = "BLEED"
					
		if st.stacks > 1:
			s_name += "x%d" % st.stacks
			
		chip_style.bg_color = Color(color.r * 0.2, color.g * 0.2, color.b * 0.2, 0.9)
		chip_style.border_color = color
		chip_style.border_width_left = 1
		chip_style.border_width_right = 1
		chip_style.border_width_top = 1
		chip_style.border_width_bottom = 1
		label.text = s_name
		label.add_theme_color_override("font_color", color)
		
		chip.add_theme_stylebox_override("panel", chip_style)
		chip.add_child(label)
		overhead_status_box.add_child(chip)

func initialize(def: CharacterDefinition) -> void:
	character_definition = def
	team = def.team
	current_hp = def.max_hp
	current_mp = def.max_mp
	is_dead = false
	is_defending = false
	timeline_position = 0.0
	timeline_state = TimelineState.MOVING_TO_COM
	pending_action = null
	execution_position = 0.0
	guaranteed_hit = false
	guaranteed_critical = false
	active_modifiers.clear()
	active_statuses.clear()
	active_perks.clear()
	
	_setup_overhead_ui()
	_setup_visuals()
	
	if overhead_hp_bg != null and overhead_hp_bar != null:
		var show_bar = (team == 1)
		overhead_hp_bg.visible = show_bar
		overhead_hp_bar.visible = show_bar
	
	# Instantiate PerkInstances
	for perk_def in def.perks:
		if perk_def is PerkDefinition:
			var p_inst = PerkInstance.new(perk_def, self)
			active_perks.append(p_inst)
			
	hp_changed.emit(current_hp, get_stat("max_hp"))
	mp_changed.emit(current_mp, get_stat("max_mp"))
	refresh_overhead_hp()
	refresh_overhead_status()

func _setup_visuals() -> void:
	if animated_sprite == null:
		animated_sprite = get_node_or_null("Visual/AnimatedSprite3D")
	if animated_sprite == null:
		return
		
	# Apply custom SpriteFrames and sizing if provided by CharacterDefinition
	if character_definition != null and character_definition.sprite_frames != null:
		animated_sprite.sprite_frames = character_definition.sprite_frames
		animated_sprite.pixel_size = character_definition.sprite_pixel_size
		animated_sprite.position.y = 0.395 + character_definition.sprite_offset_y
	else:
		animated_sprite.position.y = 0.395
		
	# Side perspective facing:
	# Player team (0) faces right (+X), Enemy team (1) faces left (-X)
	if team == 0:
		animated_sprite.flip_h = false
		base_modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		animated_sprite.flip_h = true
		if character_definition != null and character_definition.sprite_frames != null:
			# Custom animated monsters retain their natural palette
			base_modulate = Color.WHITE
		elif character_definition != null and character_definition.accent_color != Color.TRANSPARENT:
			base_modulate = character_definition.accent_color.lerp(Color(1.0, 0.45, 0.45), 0.5)
		else:
			base_modulate = Color(1.0, 0.55, 0.55, 1.0)
			
	animated_sprite.modulate = base_modulate
	play_idle()

func _on_animation_finished() -> void:
	if animated_sprite == null:
		return
	if animated_sprite.animation == &"death":
		# Hold final knocked out pose
		if animated_sprite.sprite_frames.has_animation(&"death_static"):
			animated_sprite.play(&"death_static")
		else:
			animated_sprite.stop()
			animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count(&"death") - 1

func set_target_selected(selected: bool) -> void:
	if target_indicator == null:
		return
	target_indicator.visible = selected
	if selected:
		if target_indicator_tween != null and target_indicator_tween.is_valid():
			target_indicator_tween.kill()
		target_indicator.position.y = 1.25
		if is_inside_tree():
			target_indicator_tween = create_tween()
			if target_indicator_tween != null:
				target_indicator_tween.set_loops()
				target_indicator_tween.tween_property(target_indicator, "position:y", 1.48, 0.3).set_trans(Tween.TRANS_SINE)
				target_indicator_tween.tween_property(target_indicator, "position:y", 1.25, 0.3).set_trans(Tween.TRANS_SINE)
	else:
		if target_indicator_tween != null and target_indicator_tween.is_valid():
			target_indicator_tween.kill()

func set_highlight(active: bool) -> void:
	if selection_indicator != null:
		selection_indicator.visible = active
		if active and is_inside_tree():
			var tw = create_tween()
			if tw != null:
				tw.set_loops()
				tw.tween_property(selection_indicator, "scale", Vector3(1.18, 1.0, 1.18), 0.35)
				tw.tween_property(selection_indicator, "scale", Vector3(1.0, 1.0, 1.0), 0.35)
		else:
			selection_indicator.scale = Vector3.ONE

# --- Stat Management ---

func get_stat(stat_name: String) -> int:
	if character_definition == null:
		return 10
		
	var base_val: float = 0.0
	match stat_name:
		"max_hp": base_val = float(character_definition.max_hp)
		"max_mp": base_val = float(character_definition.max_mp)
		"attack": base_val = float(character_definition.attack)
		"defense": base_val = float(character_definition.defense)
		"agility": base_val = float(character_definition.agility)
		"accuracy": base_val = float(character_definition.accuracy)
		"evasion": base_val = float(character_definition.evasion)
		_: base_val = 10.0
		
	var flat_sum: float = 0.0
	var pct_sum: float = 0.0
	
	for mod in active_modifiers:
		if mod.stat_name == stat_name:
			if mod.type == StatModifier.Type.FLAT:
				flat_sum += mod.value
			elif mod.type == StatModifier.Type.PERCENT:
				pct_sum += mod.value
				
	var final_val: float = (base_val + flat_sum) * (1.0 + pct_sum)
	return max(1, int(round(final_val)))

func add_stat_modifier(mod: StatModifier) -> void:
	active_modifiers.append(mod)

func remove_stat_modifier(mod: StatModifier) -> void:
	active_modifiers.erase(mod)

# --- Combat Actions ---

func take_damage(amount: int, _source_type: String = "Physical") -> int:
	if is_dead:
		return 0
		
	if StatusSystem.is_sleeping(self):
		StatusSystem.wake_from_sleep(self)
		
	current_hp = max(0, current_hp - amount)
	hp_changed.emit(current_hp, get_stat("max_hp"))
	refresh_overhead_hp()
	
	if current_hp <= 0:
		die()
		
	return amount

func heal(amount: int) -> int:
	if is_dead:
		return 0
		
	var max_h = get_stat("max_hp")
	var prev_hp = current_hp
	current_hp = min(max_h, current_hp + amount)
	hp_changed.emit(current_hp, max_h)
	refresh_overhead_hp()
	
	if animated_sprite != null and is_inside_tree():
		var tw = create_tween()
		if tw != null:
			tw.tween_property(animated_sprite, "modulate", Color(0.4, 2.0, 0.6), 0.1)
			tw.tween_property(animated_sprite, "modulate", base_modulate, 0.25)
	
	return current_hp - prev_hp

func spend_mp(amount: int) -> bool:
	if current_mp < amount:
		return false
	current_mp -= amount
	mp_changed.emit(current_mp, get_stat("max_mp"))
	return true

func die() -> void:
	if is_dead:
		return
	is_dead = true
	current_hp = 0
	if overhead_container != null:
		overhead_container.visible = false
	timeline_state = TimelineState.MOVING_TO_COM
	pending_action = null
	execution_position = 0.0
	
	var events = CombatEventsBus.get_bus(self)
	if events:
		events.character_died.emit(self)
		
	died.emit(self)
	play_death_anim()

# --- Semi-3D Animation Control ---

func play_idle() -> void:
	if animated_sprite == null or is_dead:
		return
	animated_sprite.offset = Vector2.ZERO
	if animated_sprite.sprite_frames.has_animation(&"idle"):
		animated_sprite.play(&"idle")

func play_move() -> void:
	if animated_sprite == null or is_dead:
		return
	animated_sprite.offset = Vector2.ZERO
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(&"move"):
		animated_sprite.play(&"move")
	else:
		play_idle()

func play_attack() -> void:
	if animated_sprite == null or is_dead:
		return
	animated_sprite.offset = Vector2.ZERO
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(&"attack"):
		animated_sprite.play(&"attack")

func play_death_anim() -> void:
	if animated_sprite == null:
		return
	set_target_selected(false)
	set_highlight(false)
	animated_sprite.offset = Vector2.ZERO
	if animated_sprite.sprite_frames != null:
		if animated_sprite.sprite_frames.has_animation(&"death"):
			animated_sprite.play(&"death")
		elif animated_sprite.sprite_frames.has_animation(&"death_static"):
			animated_sprite.play(&"death_static")
		elif animated_sprite.sprite_frames.has_animation(&"hurt"):
			animated_sprite.play(&"hurt")
		
	if is_inside_tree():
		var tw = create_tween()
		if tw != null:
			tw.tween_property(animated_sprite, "modulate:a", 0.6, 0.6)

## 3D Arena attack sequence: lunge forward across the 3D ground plane, strike, retreat back
func play_attack_anim(target_pos: Vector3, on_hit_frame: Callable, on_complete: Callable, is_melee: bool = true) -> void:
	if is_dead:
		if on_complete.is_valid():
			on_complete.call()
		return
		
	var tween = create_tween()
	
	if is_melee:
		# Determine strike position directly in front of target in 3D arena space
		var strike_offset_x = -1.4 if team == 0 else 1.4
		var strike_pos = Vector3(target_pos.x + strike_offset_x, 0.0, target_pos.z)
		
		# 1. Dash toward target playing 'move' animation
		play_move()
		tween.tween_property(self, "global_position", strike_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
		# 2. Strike frame with 'attack' animation
		tween.tween_callback(func():
			play_attack()
			var hit_timer = get_tree().create_timer(0.24)
			hit_timer.timeout.connect(func():
				if on_hit_frame.is_valid():
					on_hit_frame.call()
			)
		)
		tween.tween_interval(0.42)
		
		# 3. Retreat back to home position playing 'move'
		tween.tween_callback(func():
			play_move()
		)
		tween.tween_property(self, "global_position", initial_position, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		
		# 4. Return to idle
		tween.tween_callback(func():
			play_idle()
			if on_complete.is_valid():
				on_complete.call()
		)
	else:
		# Ranged attack / skill: step forward slightly along X, strike from distance, step back
		var step_dir = 1.0 if team == 0 else -1.0
		var step_pos = initial_position + Vector3(step_dir * 0.7, 0.0, 0.0)
		
		play_move()
		tween.tween_property(self, "global_position", step_pos, 0.14)
		tween.tween_callback(func():
			play_attack()
			var hit_timer = get_tree().create_timer(0.24)
			hit_timer.timeout.connect(func():
				if on_hit_frame.is_valid():
					on_hit_frame.call()
			)
		)
		tween.tween_interval(0.42)
		
		tween.tween_property(self, "global_position", initial_position, 0.18)
		tween.tween_callback(func():
			play_idle()
			if on_complete.is_valid():
				on_complete.call()
		)

## Item usage animation in 3D
func play_item_anim(target_pos: Vector3, on_use_frame: Callable, on_complete: Callable) -> void:
	if is_dead:
		if on_complete.is_valid():
			on_complete.call()
		return
		
	var step_dir = 1.0 if team == 0 else -1.0
	var step_pos = initial_position + Vector3(step_dir * 0.7, 0.0, 0.0)
	
	var tween = create_tween()
	play_move()
	tween.tween_property(self, "global_position", step_pos, 0.14)
	tween.tween_callback(func():
		play_attack()
		var action_timer = get_tree().create_timer(0.25)
		action_timer.timeout.connect(func():
			if on_use_frame.is_valid():
				on_use_frame.call()
		)
	)
	tween.tween_interval(0.45)
	
	tween.tween_property(self, "global_position", initial_position, 0.18)
	tween.tween_callback(func():
		play_idle()
		if on_complete.is_valid():
			on_complete.call()
	)

func play_hit_anim(is_crit: bool = false) -> void:
	if animated_sprite == null or is_dead:
		return
		
	var recoil_dir = -1.0 if team == 0 else 1.0
	var recoil_dist = 0.65 if is_crit else 0.35
	var recoil_pos = initial_position + Vector3(recoil_dir * recoil_dist, 0.0, 0.0)
	
	animated_sprite.modulate = Color(2.5, 0.3, 0.3, 1.0) if is_crit else Color(2.0, 1.8, 1.8, 1.0)
	
	if animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(&"hurt"):
		animated_sprite.play(&"hurt")
	
	if is_inside_tree():
		var tw = create_tween()
		if tw != null:
			tw.tween_property(self, "global_position", recoil_pos, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(animated_sprite, "modulate", base_modulate, 0.15)
			tw.tween_property(self, "global_position", initial_position, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			tw.tween_callback(func():
				if not is_dead and animated_sprite != null and animated_sprite.sprite_frames != null:
					if animated_sprite.animation == &"hurt":
						play_idle()
			)

func play_dodge_anim() -> void:
	if is_dead or not is_inside_tree():
		return
	var dodge_dir = -1.0 if team == 0 else 1.0
	var dodge_pos = initial_position + Vector3(dodge_dir * 0.65, 0.0, -0.45)
	
	var tw = create_tween()
	tw.tween_property(self, "global_position", dodge_pos, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.12)
	tw.tween_property(self, "global_position", initial_position, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
