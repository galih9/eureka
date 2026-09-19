class_name BattleUI
extends CanvasLayer

## Root Battle UI manager connecting state transitions, menus, targeting, and HUD layers.

@export var battle_manager: BattleManager
@export var camera: Camera2D

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

var valid_targets: Array = []
var selected_target_idx: int = 0
var is_targeting: bool = false
var is_moving: bool = false
var pending_action_def: ActionDefinition = null
var grid_visual: FormationGridVisual = null

const DebugMenuUIScript = preload("res://scripts/ui/debug_menu_ui.gd")
var debug_menu: Control = null
var debug_toggle_btn: Button = null

func _ready() -> void:
	target_prompt_panel.visible = false
	action_banner.visible = false
	transition_panel.visible = false
	
	grid_visual = FormationGridVisual.new()
	grid_visual.name = "FormationGridVisual"
	add_child(grid_visual)
	grid_visual.slot_clicked.connect(_on_grid_slot_clicked)
	grid_visual.move_canceled.connect(_on_grid_move_canceled)
	
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
	
	if grid_visual != null and bm.formation_system != null:
		grid_visual.formation_system = bm.formation_system
		grid_visual.queue_redraw()
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
		BattleState.State.TIMELINE:
			is_targeting = false
			target_prompt_panel.visible = false
			transition_panel.visible = false
			enemy_info.hide_target_info()
			_clear_target_highlights()
			timeline_ui.set_highlighted_actor(null)
			
		BattleState.State.PLAYER_ACTION:
			is_targeting = false
			target_prompt_panel.visible = false
			enemy_info.hide_target_info()
			_clear_target_highlights()
			
		BattleState.State.ACTION_EXECUTION:
			is_targeting = false
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
