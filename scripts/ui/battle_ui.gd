class_name BattleUI
extends CanvasLayer

## Root Battle UI manager connecting state transitions, menus, targeting, and HUD layers.

signal battle_start_displayed()

@export var battle_manager: BattleManager
@export var camera: Camera3D
## The grid visual lives in the world scene (not in this CanvasLayer) so the
## camera transform is applied correctly when zoomed in.
@export var grid_visual: FormationGridVisual = null

@onready var timeline_layer: Control = $TimelineLayer
@onready var character_status_layer: Control = $CharacterStatusLayer
@onready var timeline_ui: TimelineUI = $TimelineLayer/TimelineUI
@onready var status_ui: CharacterStatusUI = $CharacterStatusLayer/CharacterStatusUI
@onready var command_menu: CommandMenuUI = $CommandLayer/CommandMenuUI
@onready var enemy_info: EnemyInfoUI = $EnemyInfoLayer/EnemyInfoUI
@onready var perk_notification: PerkNotificationUI = $PerkNotificationLayer/PerkNotificationUI
@onready var floating_spawner: FloatingTextSpawner = $BattlefieldIndicators/FloatingTextSpawner
@onready var target_prompt_panel: PanelContainer = $TargetLayer/PromptPanel
@onready var action_banner: Label = $BattleMessageLayer/ActionBanner
@onready var transition_panel: PanelContainer = $TransitionLayer/EndPanel
@onready var end_title: Label = $TransitionLayer/EndPanel/VBox/EndTitle
@onready var restart_btn: Button = $TransitionLayer/EndPanel/VBox/RestartBtn

@onready var intro_layer: Control = get_node_or_null("IntroLayer")
@onready var skip_hint: Control = get_node_or_null("IntroLayer/SkipHint")
@onready var battle_start_container: Control = get_node_or_null("IntroLayer/BattleStartContainer")
@onready var battle_start_title: Label = get_node_or_null("IntroLayer/BattleStartContainer/VBox/BattleStartTitle")

var is_intro_active: bool = false
var intro_banner_tween: Tween = null
var skip_hint_tween: Tween = null

var valid_targets: Array = []
var selected_target_idx: int = 0
var is_targeting: bool = false
var is_moving: bool = false
var pending_action_def: ActionDefinition = null

const DebugMenuUIScript = preload("res://scripts/ui/debug_menu_ui.gd")
var debug_menu: Control = null
var debug_toggle_btn: Button = null

func _ready() -> void:
	_ensure_intro_ui()
	target_prompt_panel.visible = false
	action_banner.visible = false
	transition_panel.visible = false
	if battle_start_container:
		battle_start_container.visible = false
	if skip_hint:
		skip_hint.visible = false
	# Note: grid_visual signals are connected in battle_scene.gd after the node
	# is created, because grid_visual is null here (assigned post-_ready).
	
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)
		
	if command_menu:
		command_menu.action_selected.connect(_on_command_action_selected)
		command_menu.tactics_toggled.connect(_on_tactics_toggled)
		
	_setup_debug_menu()
		
	if battle_manager != null:
		connect_battle_manager(battle_manager)
		
	var events = get_node_or_null("/root/CombatEvents")
	if events:
		events.action_started.connect(_on_action_started)

func _setup_debug_menu() -> void:
	var debug_layer = CanvasLayer.new()
	debug_layer.name = "DebugLayer"
	debug_layer.layer = 120
	add_child(debug_layer)
	
	debug_toggle_btn = Button.new()
	debug_toggle_btn.name = "DebugToggleBtn"
	debug_toggle_btn.text = "🛠 DEBUG"
	debug_toggle_btn.custom_minimum_size = Vector2(85, 28)
	debug_toggle_btn.position = Vector2(1055, 10)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.1, 0.12, 0.2, 0.85)
	btn_style.border_color = Color(0.95, 0.75, 0.2, 0.9)
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	debug_toggle_btn.add_theme_stylebox_override("normal", btn_style)
	debug_toggle_btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	debug_toggle_btn.add_theme_font_size_override("font_size", 11)
	debug_layer.add_child(debug_toggle_btn)
	
	debug_menu = DebugMenuUIScript.new()
	debug_menu.name = "DebugMenu"
	debug_menu.battle_manager = battle_manager
	debug_menu.position = Vector2(790, 45)
	debug_layer.add_child(debug_menu)
	
	debug_toggle_btn.pressed.connect(func():
		debug_menu.toggle_menu()
	)

func connect_battle_manager(bm: BattleManager) -> void:
	battle_manager = bm
	if debug_menu != null:
		debug_menu.battle_manager = bm
	if not bm.state_changed.is_connected(_on_state_changed):
		bm.state_changed.connect(_on_state_changed)
	if not bm.player_turn_ready.is_connected(_on_player_turn_ready):
		bm.player_turn_ready.connect(_on_player_turn_ready)
	if not bm.target_selection_started.is_connected(_on_target_selection_started):
		bm.target_selection_started.connect(_on_target_selection_started)
	if not bm.move_selection_started.is_connected(_on_move_selection_started):
		bm.move_selection_started.connect(_on_move_selection_started)
	if not bm.captain_changed.is_connected(_on_captain_changed):
		bm.captain_changed.connect(_on_captain_changed)
	if not bm.party_strategy_changed.is_connected(_on_party_strategy_changed):
		bm.party_strategy_changed.connect(_on_party_strategy_changed)
	if not bm.autonomous_action_triggered.is_connected(_on_autonomous_action_triggered):
		bm.autonomous_action_triggered.connect(_on_autonomous_action_triggered)
	if not bm.battle_finished.is_connected(_on_battle_finished):
		bm.battle_finished.connect(_on_battle_finished)
	if not bm.battle_initialized.is_connected(_on_battle_initialized):
		bm.battle_initialized.connect(_on_battle_initialized)
	if not bm.battle_intro_started.is_connected(_on_battle_intro_started):
		bm.battle_intro_started.connect(_on_battle_intro_started)
	if not bm.battle_intro_finished.is_connected(_on_battle_intro_finished):
		bm.battle_intro_finished.connect(_on_battle_intro_finished)
		
	if bm.current_state == BattleState.State.INTRO:
		_on_intro_started()
	
	if grid_visual != null and bm.formation_system != null:
		grid_visual.formation_system = bm.formation_system
		grid_visual.visible = false
	if timeline_ui and bm.turn_timeline != null and not bm.all_combatants.is_empty():
		timeline_ui.initialize(bm.turn_timeline)
	if status_ui:
		var living_players = bm.get_living_players()
		if not living_players.is_empty():
			status_ui.setup_party(living_players)

func _on_battle_initialized() -> void:
	if battle_manager == null:
		return
	if timeline_ui and battle_manager.turn_timeline != null:
		timeline_ui.initialize(battle_manager.turn_timeline)
	if status_ui:
		var living_players = battle_manager.get_living_players()
		if not living_players.is_empty():
			status_ui.setup_party(living_players)

func _on_state_changed(new_state: BattleState.State) -> void:
	if status_ui and status_ui.party_members.is_empty() and battle_manager != null:
		var living_players = battle_manager.get_living_players()
		if not living_players.is_empty():
			status_ui.setup_party(living_players)
			
	match new_state:
		BattleState.State.INTRO:
			_on_intro_started()
			
		BattleState.State.TIMELINE:
			_on_intro_concluded()
			is_targeting = false
			if is_moving:
				is_moving = false
				if grid_visual != null:
					grid_visual.cancel_move_selection()
			target_prompt_panel.visible = false
			transition_panel.visible = false
			enemy_info.hide_target_info()
			_clear_target_highlights()
			timeline_ui.set_highlighted_actor(null)
			
		BattleState.State.PLAYER_ACTION:
			is_targeting = false
			if is_moving:
				is_moving = false
				if grid_visual != null:
					grid_visual.cancel_move_selection()
			target_prompt_panel.visible = false
			enemy_info.hide_target_info()
			_clear_target_highlights()
			
		BattleState.State.ACTION_EXECUTION:
			is_targeting = false
			if is_moving:
				is_moving = false
				if grid_visual != null:
					grid_visual.cancel_move_selection()
			target_prompt_panel.visible = false
			command_menu.hide_menu()
			_clear_target_highlights()

func _on_player_turn_ready(actor: BattleCharacter) -> void:
	if status_ui and status_ui.party_members.is_empty() and battle_manager != null:
		var living_players = battle_manager.get_living_players()
		if not living_players.is_empty():
			status_ui.setup_party(living_players)
			
	timeline_ui.set_highlighted_actor(actor)
	status_ui.set_active_character(actor)
	command_menu.open_for_actor(actor)

func _on_command_action_selected(action_def: ActionDefinition) -> void:
	if battle_manager != null:
		battle_manager.request_action_selection(action_def)

func _on_target_selection_started(action_def: ActionDefinition, targets: Array) -> void:
	pending_action_def = action_def
	valid_targets = targets
	selected_target_idx = 0
	is_targeting = true
	target_prompt_panel.visible = true
	_update_target_selection()

func _update_target_selection() -> void:
	_clear_target_highlights()
	# Clean out dead or freed targets (e.g. from debug despawn)
	var cleaned: Array = []
	for t in valid_targets:
		if t != null and is_instance_valid(t) and not t.is_dead:
			cleaned.append(t)
	valid_targets = cleaned
	
	if valid_targets.is_empty():
		_cancel_target()
		return
		
	selected_target_idx = clamp(selected_target_idx, 0, valid_targets.size() - 1)
	
	if TargetSystem.is_aoe(pending_action_def.target_type):
		for t in valid_targets:
			if is_instance_valid(t) and t.has_method("set_target_selected"):
				t.set_target_selected(true)
		if battle_manager.camera_controller != null:
			battle_manager.camera_controller.focus_on_battlefield()
		enemy_info.hide_target_info()
	else:
		var cur_target = valid_targets[selected_target_idx] as BattleCharacter
		if is_instance_valid(cur_target):
			cur_target.set_target_selected(true)
			enemy_info.show_target_info(cur_target)
		if battle_manager.camera_controller != null:
			battle_manager.camera_controller.return_to_stage()


func _clear_target_highlights() -> void:
	for t in valid_targets:
		if is_instance_valid(t) and t.has_method("set_target_selected"):
			t.set_target_selected(false)

func _unhandled_input(event: InputEvent) -> void:
	if is_intro_active:
		if _is_skip_intro_input(event):
			_skip_intro()
			get_viewport().set_input_as_handled()
			return
			
	if not is_targeting:
		return
		
	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and event.keycode == KEY_D):
		if not TargetSystem.is_aoe(pending_action_def.target_type) and not valid_targets.is_empty():
			selected_target_idx = (selected_target_idx + 1) % valid_targets.size()
			_update_target_selection()
			get_viewport().set_input_as_handled()
			
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and event.keycode == KEY_A):
		if not TargetSystem.is_aoe(pending_action_def.target_type) and not valid_targets.is_empty():
			selected_target_idx = (selected_target_idx - 1 + valid_targets.size()) % valid_targets.size()
			_update_target_selection()
			get_viewport().set_input_as_handled()
			
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER)):
		_confirm_target()
		get_viewport().set_input_as_handled()
		
	elif event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_cancel_target()
		get_viewport().set_input_as_handled()
		
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_confirm_target()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_target()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if not TargetSystem.is_aoe(pending_action_def.target_type) and not valid_targets.is_empty():
				selected_target_idx = (selected_target_idx + 1) % valid_targets.size()
				_update_target_selection()
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if not TargetSystem.is_aoe(pending_action_def.target_type) and not valid_targets.is_empty():
				selected_target_idx = (selected_target_idx - 1 + valid_targets.size()) % valid_targets.size()
				_update_target_selection()
				get_viewport().set_input_as_handled()

func _confirm_target() -> void:
	if not is_targeting or valid_targets.is_empty():
		return
	is_targeting = false
	target_prompt_panel.visible = false
	enemy_info.hide_target_info()
	_clear_target_highlights()
	
	if TargetSystem.is_aoe(pending_action_def.target_type):
		battle_manager.confirm_player_target(valid_targets)
	else:
		battle_manager.confirm_player_target([valid_targets[selected_target_idx]])

func _cancel_target() -> void:
	if not is_targeting:
		return
	is_targeting = false
	target_prompt_panel.visible = false
	enemy_info.hide_target_info()
	_clear_target_highlights()
	battle_manager.cancel_target_selection()

func _on_action_started(action: BattleAction) -> void:
	if action == null or action.actor == null or action.action_definition == null:
		return
		
	var aname = action.action_definition.action_name
	var act_name = action.actor.get_display_name() if action.actor.has_method("get_display_name") else "Combatant"
	action_banner.text = "%s uses %s!" % [act_name, aname]
	action_banner.visible = true
	
	var tw = create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(func():
		action_banner.visible = false
	)

func _on_battle_finished(victory: bool) -> void:
	transition_panel.visible = true
	if victory:
		end_title.text = "★ VICTORY ★"
		end_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	else:
		end_title.text = "DEFEAT"
		end_title.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))

func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()

func _on_tactics_toggled() -> void:
	if battle_manager != null:
		var strat = battle_manager.cycle_party_strategy()
		var s_str = "ATTACK" if strat == PartyAI.PartyStrategy.ATTACK else ("DEFEND" if strat == PartyAI.PartyStrategy.DEFEND else "AUTONOMOUS")
		command_menu.set_strategy_name(s_str)

func _on_party_strategy_changed(strat: PartyAI.PartyStrategy) -> void:
	var s_str = "ATTACK" if strat == PartyAI.PartyStrategy.ATTACK else ("DEFEND" if strat == PartyAI.PartyStrategy.DEFEND else "AUTONOMOUS")
	if command_menu != null:
		command_menu.set_strategy_name(s_str)

func _on_captain_changed(_new_captain: BattleCharacter) -> void:
	if status_ui != null:
		status_ui.refresh_party_cards()

func _on_autonomous_action_triggered(character: BattleCharacter, reason: String) -> void:
	var c_name = character.get_display_name()
	action_banner.text = "⚠ %s: CAPTAIN DISABLED — AUTONOMOUS (%s)" % [c_name, reason]
	action_banner.visible = true
	var tw = create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(func():
		action_banner.visible = false
	)

func _on_move_selection_started(action_def: ActionDefinition, valid_slots: Array) -> void:
	pending_action_def = action_def
	is_moving = true
	target_prompt_panel.visible = true
	var prompt_lbl = target_prompt_panel.find_child("PromptLabel", true, false) as Label
	if prompt_lbl != null:
		prompt_lbl.text = "SELECT DESTINATION TILE [ARROWS/CLICK TO MOVE, ESC TO CANCEL]"
	if grid_visual != null:
		grid_visual.start_move_selection(battle_manager.formation_system, valid_slots)

func _on_grid_slot_clicked(slot_idx: int) -> void:
	if not is_moving:
		return
	is_moving = false
	target_prompt_panel.visible = false
	if grid_visual != null:
		grid_visual.cancel_move_selection()
	if battle_manager != null:
		battle_manager.confirm_player_move(slot_idx)

func _on_grid_move_canceled() -> void:
	if not is_moving:
		return
	is_moving = false
	target_prompt_panel.visible = false
	if grid_visual != null:
		grid_visual.cancel_move_selection()
	if battle_manager != null:
		battle_manager.cancel_target_selection()

# --- Intro Sequence & "Battle Start" Announcement ---

func _on_battle_intro_started() -> void:
	_on_intro_started()

func _on_battle_intro_finished() -> void:
	_on_intro_concluded()

func _on_intro_started() -> void:
	if is_intro_active:
		return
	is_intro_active = true
	_ensure_intro_ui()
	
	# Keep battle combat HUD hidden during cinematic camera sweep
	if timeline_layer:
		timeline_layer.modulate.a = 0.0
	if character_status_layer:
		character_status_layer.modulate.a = 0.0
	if command_menu:
		command_menu.hide_menu()
	if target_prompt_panel:
		target_prompt_panel.visible = false
		
	# Display pulsing skip hint
	if skip_hint:
		skip_hint.visible = true
		skip_hint.modulate.a = 0.0
		if skip_hint_tween and skip_hint_tween.is_valid():
			skip_hint_tween.kill()
		skip_hint_tween = create_tween().set_loops()
		skip_hint_tween.tween_property(skip_hint, "modulate:a", 0.9, 0.75)
		skip_hint_tween.tween_property(skip_hint, "modulate:a", 0.4, 0.75)
		
	# Schedule the "Battle Start" banner at ~3.0s as camera zooms in to stage position
	if intro_banner_tween and intro_banner_tween.is_valid():
		intro_banner_tween.kill()
		
	var delay = 3.0
	if battle_manager != null and battle_manager.get("intro_duration") != null:
		delay = max(0.4, battle_manager.intro_duration - 1.9)
		
	intro_banner_tween = create_tween()
	intro_banner_tween.tween_interval(delay)
	intro_banner_tween.tween_callback(func():
		_show_battle_start_banner()
	)

func _show_battle_start_banner() -> void:
	battle_start_displayed.emit()
	if battle_start_container == null:
		return
		
	battle_start_container.visible = true
	battle_start_container.modulate.a = 0.0
	battle_start_container.scale = Vector2(1.35, 1.35)
	
	if intro_banner_tween and intro_banner_tween.is_valid():
		intro_banner_tween.kill()
		
	intro_banner_tween = create_tween()
	# Impact punch: scale down with back ease & rapid fade-in
	intro_banner_tween.parallel().tween_property(battle_start_container, "scale", Vector2(1.0, 1.0), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	intro_banner_tween.parallel().tween_property(battle_start_container, "modulate:a", 1.0, 0.15)
	
	# Hold for visual impact
	intro_banner_tween.chain().tween_interval(1.15)
	
	# Smooth fade out as combat commences
	intro_banner_tween.chain().parallel().tween_property(battle_start_container, "scale", Vector2(1.08, 1.08), 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	intro_banner_tween.parallel().tween_property(battle_start_container, "modulate:a", 0.0, 0.4)
	intro_banner_tween.chain().tween_callback(func():
		if battle_start_container:
			battle_start_container.visible = false
	)

func _on_intro_concluded() -> void:
	is_intro_active = false
	
	# Stop skip hint
	if skip_hint_tween and skip_hint_tween.is_valid():
		skip_hint_tween.kill()
	if skip_hint:
		skip_hint.visible = false
		
	# Smoothly reveal standard battle HUD
	var hud_tween = create_tween().set_parallel(true)
	if timeline_layer:
		hud_tween.tween_property(timeline_layer, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if character_status_layer:
		hud_tween.tween_property(character_status_layer, "modulate:a", 1.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _is_skip_intro_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_ESCAPE:
			return true
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			return true
	return false

func _skip_intro() -> void:
	if not is_intro_active:
		return
		
	is_intro_active = false
	battle_start_displayed.emit()
	
	# Quick flash of "Battle Start" if it hasn't popped up yet
	if battle_start_container and not battle_start_container.visible:
		battle_start_container.visible = true
		battle_start_container.scale = Vector2(1.2, 1.2)
		battle_start_container.modulate.a = 1.0
		if intro_banner_tween and intro_banner_tween.is_valid():
			intro_banner_tween.kill()
		var quick_tw = create_tween()
		quick_tw.parallel().tween_property(battle_start_container, "scale", Vector2(1.0, 1.0), 0.15)
		quick_tw.chain().tween_interval(0.3)
		quick_tw.chain().parallel().tween_property(battle_start_container, "modulate:a", 0.0, 0.2)
		quick_tw.chain().tween_callback(func():
			if battle_start_container:
				battle_start_container.visible = false
		)
		
	if battle_manager != null and battle_manager.has_method("skip_intro"):
		battle_manager.skip_intro()
		
	_on_intro_concluded()

func _ensure_intro_ui() -> void:
	if intro_layer == null:
		intro_layer = get_node_or_null("IntroLayer") as Control
		
	if intro_layer == null:
		intro_layer = Control.new()
		intro_layer.name = "IntroLayer"
		intro_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		intro_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(intro_layer)
		
	if skip_hint == null and intro_layer != null:
		skip_hint = intro_layer.get_node_or_null("SkipHint") as Control
	if skip_hint == null and intro_layer != null:
		var sh_panel = PanelContainer.new()
		sh_panel.name = "SkipHint"
		sh_panel.anchor_left = 1.0
		sh_panel.anchor_top = 1.0
		sh_panel.anchor_right = 1.0
		sh_panel.anchor_bottom = 1.0
		sh_panel.offset_left = -220.0
		sh_panel.offset_top = -46.0
		sh_panel.offset_right = -18.0
		sh_panel.offset_bottom = -16.0
		sh_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		sh_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
		
		var sh_style = StyleBoxFlat.new()
		sh_style.bg_color = Color(0.05, 0.08, 0.16, 0.72)
		sh_style.border_color = Color(0.3, 0.55, 0.85, 0.6)
		sh_style.set_border_width_all(1)
		sh_style.set_corner_radius_all(4)
		sh_panel.add_theme_stylebox_override("panel", sh_style)
		
		var lbl = Label.new()
		lbl.name = "SkipLabel"
		lbl.text = "[SPACE / CLICK TO SKIP]"
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.92, 1, 0.8))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sh_panel.add_child(lbl)
		intro_layer.add_child(sh_panel)
		skip_hint = sh_panel
		skip_hint.visible = false
		
	if battle_start_container == null and intro_layer != null:
		battle_start_container = intro_layer.get_node_or_null("BattleStartContainer") as Control
	if battle_start_container == null and intro_layer != null:
		var bs_panel = PanelContainer.new()
		bs_panel.name = "BattleStartContainer"
		bs_panel.anchor_left = 0.5
		bs_panel.anchor_top = 0.5
		bs_panel.anchor_right = 0.5
		bs_panel.anchor_bottom = 0.5
		bs_panel.offset_left = -220.0
		bs_panel.offset_top = -54.0
		bs_panel.offset_right = 220.0
		bs_panel.offset_bottom = 54.0
		bs_panel.pivot_offset = Vector2(220, 54)
		
		var bs_style = StyleBoxFlat.new()
		bs_style.bg_color = Color(0.04, 0.07, 0.15, 0.92)
		bs_style.border_color = Color(1, 0.84, 0.22, 0.95)
		bs_style.border_width_left = 3
		bs_style.border_width_right = 3
		bs_style.border_width_top = 2
		bs_style.border_width_bottom = 2
		bs_style.set_corner_radius_all(6)
		bs_panel.add_theme_stylebox_override("panel", bs_style)
		
		var vbox = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var sub = Label.new()
		sub.text = "TACTICAL COMBAT ENGAGED"
		sub.add_theme_font_size_override("font_size", 11)
		sub.add_theme_color_override("font_color", Color(0.35, 0.75, 1, 0.9))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(sub)
		
		var main_l = Label.new()
		main_l.name = "BattleStartTitle"
		main_l.text = "⚔ BATTLE START ⚔"
		main_l.add_theme_font_size_override("font_size", 32)
		main_l.add_theme_color_override("font_color", Color(1, 0.88, 0.22, 1))
		main_l.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0, 0.95))
		main_l.add_theme_constant_override("outline_size", 6)
		main_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(main_l)
		
		bs_panel.add_child(vbox)
		intro_layer.add_child(bs_panel)
		battle_start_container = bs_panel
		battle_start_title = main_l
		battle_start_container.visible = false
