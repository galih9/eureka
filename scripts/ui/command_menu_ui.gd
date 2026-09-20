class_name CommandMenuUI
extends Control

## PSX-era bottom-right command menu featuring 3D cylindrical "Rolling Pipe" selection.
## The rolling pipe projects buttons onto a vertical cylinder with cosine foreshortening
## and organic alpha fading.
## In sub-menus (like Skills), an anchored [X] back button remains fixed at the center row.

signal action_selected(action_def: ActionDefinition)
signal tactics_toggled()

@export var default_attack_action: ActionDefinition
@export var default_defend_action: ActionDefinition
@export var default_item_action: ActionDefinition
@export var default_move_action: ActionDefinition

var current_actor: BattleCharacter = null
var current_strategy_name: String = "ATTACK"
var in_skill_submenu: bool = false

var rolling_main_menu: RollingPipeMenu = null
var rolling_skill_menu: RollingPipeMenu = null

# Reference to legacy nodes to hide them gracefully
@onready var legacy_main_container: VBoxContainer = get_node_or_null("MainContainer")
@onready var legacy_skill_container: VBoxContainer = get_node_or_null("SkillContainer")

func _ready() -> void:
	if default_item_action == null:
		default_item_action = load("res://data/skills/use_item.tres") as ActionDefinition
	if default_move_action == null:
		default_move_action = load("res://data/skills/move.tres") as ActionDefinition
		
	# Hide legacy container lists if they exist in the scene tree
	if legacy_main_container:
		legacy_main_container.visible = false
	if legacy_skill_container:
		legacy_skill_container.visible = false
		
	_setup_rolling_menus()
	hide_menu()

func _setup_rolling_menus() -> void:
	# Main Actions Rolling Pipe Menu (no back button at root level)
	rolling_main_menu = RollingPipeMenu.new()
	rolling_main_menu.name = "RollingMainMenu"
	rolling_main_menu.radius = 100.0
	rolling_main_menu.angle_step_deg = 24.0
	rolling_main_menu.item_width = 215.0
	rolling_main_menu.item_height = 28.0
	rolling_main_menu.arc_curve_x = 65.0
	rolling_main_menu.show_back_button = false
	rolling_main_menu.set_anchors_preset(PRESET_FULL_RECT)
	rolling_main_menu.item_activated.connect(_on_main_item_activated)
	add_child(rolling_main_menu)
	
	# Skill Submenu Rolling Pipe Menu (with anchored center [X] back button!)
	rolling_skill_menu = RollingPipeMenu.new()
	rolling_skill_menu.name = "RollingSkillMenu"
	rolling_skill_menu.radius = 100.0
	rolling_skill_menu.angle_step_deg = 24.0
	rolling_skill_menu.item_width = 215.0
	rolling_skill_menu.item_height = 28.0
	rolling_skill_menu.arc_curve_x = 65.0
	rolling_skill_menu.show_back_button = true
	rolling_skill_menu.set_anchors_preset(PRESET_FULL_RECT)
	rolling_skill_menu.visible = false
	rolling_skill_menu.item_activated.connect(_on_skill_item_activated)
	rolling_skill_menu.back_pressed.connect(_on_back_pressed)
	add_child(rolling_skill_menu)

func open_for_actor(actor: BattleCharacter) -> void:
	current_actor = actor
	visible = true
	in_skill_submenu = false
	
	rolling_skill_menu.visible = false
	rolling_main_menu.visible = true
	
	_populate_main_menu()

func _populate_main_menu() -> void:
	if current_actor == null:
		return
		
	var main_items: Array[Dictionary] = []
	
	# 1. Attack
	var is_disarmed = StatusSystem.is_disarmed(current_actor)
	var atk_speed = default_attack_action.get_cast_speed_label() if default_attack_action != null else "SHORT"
	var atk_text = "⚔ ATTACK  [DISARMED]" if is_disarmed else "⚔ ATTACK  [%s]" % atk_speed
	main_items.append({
		"id": "attack",
		"text": atk_text,
		"disabled": is_disarmed,
		"data": default_attack_action
	})
	
	# 2. Skill
	var is_silenced = StatusSystem.is_silenced(current_actor)
	var skl_text = "✦ SKILL  [SILENCED]" if is_silenced else "✦ SKILL"
	main_items.append({
		"id": "skill",
		"text": skl_text,
		"disabled": is_silenced,
		"data": null
	})
	
	# 3. Defend
	main_items.append({
		"id": "defend",
		"text": "🛡 DEFEND",
		"disabled": false,
		"data": default_defend_action
	})
	
	# 4. Item
	main_items.append({
		"id": "item",
		"text": "🧪 ITEM",
		"disabled": false,
		"data": default_item_action
	})
	
	# 5. Move
	var move_cost = default_move_action.mp_cost if default_move_action != null else 8
	var can_move = (current_actor.current_mp >= move_cost)
	var arch_desc = " [1 TILE]" if current_actor.archetype == CharacterDefinition.Archetype.BRAWLER else " [ANY]"
	main_items.append({
		"id": "move",
		"text": "📍 MOVE (%d MP)%s" % [move_cost, arch_desc],
		"disabled": not can_move,
		"data": default_move_action
	})
	
	# 6. Tactics
	main_items.append({
		"id": "tactics",
		"text": "⚙ TACTICS: [%s]" % current_strategy_name,
		"disabled": false,
		"data": null
	})
	
	var initial_idx = 0
	if is_disarmed:
		initial_idx = 1 if not is_silenced else 2
		
	rolling_main_menu.set_items(main_items, initial_idx)

func _on_main_item_activated(_index: int, item_data: Dictionary) -> void:
	var item_id = item_data.get("id", "")
	match item_id:
		"attack":
			hide_menu()
			action_selected.emit(default_attack_action)
		"skill":
			_open_skill_submenu()
		"defend":
			hide_menu()
			action_selected.emit(default_defend_action)
		"item":
			hide_menu()
			var item_act = default_item_action
			if item_act == null:
				item_act = load("res://data/skills/use_item.tres") as ActionDefinition
			action_selected.emit(item_act)
		"move":
			hide_menu()
			var move_act = default_move_action
			if move_act == null:
				move_act = load("res://data/skills/move.tres") as ActionDefinition
			action_selected.emit(move_act)
		"tactics":
			tactics_toggled.emit()

func _open_skill_submenu() -> void:
	in_skill_submenu = true
	rolling_main_menu.visible = false
	rolling_skill_menu.visible = true
	
	var skill_items: Array[Dictionary] = []
	if current_actor != null and current_actor.character_definition != null:
		var skills = current_actor.character_definition.skills
		for s in skills:
			if s is SkillDefinition:
				var speed_label = s.get_cast_speed_label()
				var disabled = (current_actor.current_mp < s.mp_cost)
				skill_items.append({
					"id": s.action_name,
					"text": "%s (%d MP) [%s]" % [s.action_name, s.mp_cost, speed_label],
					"disabled": disabled,
					"data": s
				})
				
	if skill_items.is_empty():
		skill_items.append({
			"id": "none",
			"text": "NO SKILLS",
			"disabled": true,
			"data": null
		})
		
	rolling_skill_menu.set_items(skill_items, 0)
	
	# Entry animation: quick slide/fade
	rolling_skill_menu.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(rolling_skill_menu, "modulate:a", 1.0, 0.12)

func _on_skill_item_activated(_index: int, item_data: Dictionary) -> void:
	var skill_def = item_data.get("data") as ActionDefinition
	if skill_def != null:
		hide_menu()
		action_selected.emit(skill_def)

func _on_back_pressed() -> void:
	in_skill_submenu = false
	rolling_skill_menu.visible = false
	rolling_main_menu.visible = true
	
	# Smoothly return focus to Skill option on the main drum
	rolling_main_menu.set_selected_index(1)
	
	# Entry animation back to main
	rolling_main_menu.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(rolling_main_menu, "modulate:a", 1.0, 0.12)

func set_strategy_name(s_name: String) -> void:
	current_strategy_name = s_name.to_upper()
	if rolling_main_menu != null and visible and not in_skill_submenu:
		_populate_main_menu()

func hide_menu() -> void:
	visible = false
	in_skill_submenu = false
	if rolling_main_menu:
		rolling_main_menu.is_active = false
	if rolling_skill_menu:
		rolling_skill_menu.is_active = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
		
	if in_skill_submenu:
		if rolling_skill_menu and rolling_skill_menu.handle_external_input(event):
			get_viewport().set_input_as_handled()
	else:
		if rolling_main_menu and rolling_main_menu.handle_external_input(event):
			get_viewport().set_input_as_handled()
