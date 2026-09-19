class_name CommandMenuUI
extends Control

## Compact PSX-era bottom-right command menu for player turns.

signal action_selected(action_def: ActionDefinition)
signal tactics_toggled()

@onready var main_container: VBoxContainer = $MainContainer
@onready var skill_container: VBoxContainer = $SkillContainer
@onready var skill_list: VBoxContainer = $SkillContainer/ScrollContainer/SkillList

@export var default_attack_action: ActionDefinition
@export var default_defend_action: ActionDefinition
@export var default_item_action: ActionDefinition
@export var default_move_action: ActionDefinition

var current_actor: BattleCharacter = null
var current_strategy_name: String = "ATTACK"

func _ready() -> void:
	if default_item_action == null:
		default_item_action = load("res://data/skills/use_item.tres") as ActionDefinition
	if default_move_action == null:
		default_move_action = load("res://data/skills/move.tres") as ActionDefinition
		
	hide_menu()
	var btn_atk = $MainContainer/BtnAttack
	var btn_skl = $MainContainer/BtnSkill
	var btn_def = $MainContainer/BtnDefend
	var btn_itm = $MainContainer/BtnItem
	var btn_mov = $MainContainer.get_node_or_null("BtnMove")
	var btn_tac = $MainContainer.get_node_or_null("BtnTactics")
	var btn_back = $SkillContainer/BtnBack
	
	if btn_atk: btn_atk.pressed.connect(_on_attack_pressed)
	if btn_skl: btn_skl.pressed.connect(_on_skill_menu_pressed)
	if btn_def: btn_def.pressed.connect(_on_defend_pressed)
	if btn_itm: btn_itm.pressed.connect(_on_item_pressed)
	if btn_mov: btn_mov.pressed.connect(_on_move_pressed)
	if btn_tac: btn_tac.pressed.connect(_on_tactics_pressed)
	if btn_back: btn_back.pressed.connect(_on_back_pressed)

func open_for_actor(actor: BattleCharacter) -> void:
	current_actor = actor
	visible = true
	main_container.visible = true
	skill_container.visible = false
	
	var btn_atk = $MainContainer/BtnAttack
	var btn_skl = $MainContainer/BtnSkill
	
	# Check Disarm
	var is_disarmed = StatusSystem.is_disarmed(actor)
	var atk_speed = default_attack_action.get_cast_speed_label() if default_attack_action != null else "SHORT"
	if is_disarmed:
		btn_atk.disabled = true
		btn_atk.text = "⚔ ATTACK  [DISARMED]"
	else:
		btn_atk.disabled = false
		btn_atk.text = "⚔ ATTACK  [%s]" % atk_speed
		
	# Check Silence
	var is_silenced = StatusSystem.is_silenced(actor)
	if is_silenced:
		btn_skl.disabled = true
		btn_skl.text = "✦ SKILL  [SILENCED]"
	else:
		btn_skl.disabled = false
		btn_skl.text = "✦ SKILL"
		
	# Check Move
	var btn_mov = $MainContainer.get_node_or_null("BtnMove")
	if btn_mov != null:
		var move_cost = default_move_action.mp_cost if default_move_action != null else 8
		btn_mov.disabled = (actor.current_mp < move_cost)
		var arch_desc = " [1 TILE]" if actor.archetype == CharacterDefinition.Archetype.BRAWLER else " [ANY]"
		btn_mov.text = "📍 MOVE (%d MP)%s" % [move_cost, arch_desc]
		
	# Update Tactics button label
	var btn_tac = $MainContainer.get_node_or_null("BtnTactics")
	if btn_tac != null:
		btn_tac.text = "⚙ TACTICS: [%s]" % current_strategy_name
		
	# Grab focus on first available button
	if not btn_atk.disabled:
		btn_atk.grab_focus()
	elif not btn_skl.disabled:
		btn_skl.grab_focus()
	else:
		$MainContainer/BtnDefend.grab_focus()

func set_strategy_name(s_name: String) -> void:
	current_strategy_name = s_name.to_upper()
	var btn_tac = $MainContainer.get_node_or_null("BtnTactics")
	if btn_tac != null:
		btn_tac.text = "⚙ TACTICS: [%s]" % current_strategy_name

func hide_menu() -> void:
	visible = false

func _on_attack_pressed() -> void:
	hide_menu()
	action_selected.emit(default_attack_action)

func _on_defend_pressed() -> void:
	hide_menu()
	action_selected.emit(default_defend_action)

func _on_item_pressed() -> void:
	hide_menu()
	var item_act = default_item_action
	if item_act == null:
		item_act = load("res://data/skills/use_item.tres") as ActionDefinition
	action_selected.emit(item_act)

func _on_move_pressed() -> void:
	hide_menu()
	var move_act = default_move_action
	if move_act == null:
		move_act = load("res://data/skills/move.tres") as ActionDefinition
	action_selected.emit(move_act)

func _on_tactics_pressed() -> void:
	tactics_toggled.emit()

func _on_skill_menu_pressed() -> void:
	main_container.visible = false
	skill_container.visible = true
	
	# Clear skill list
	for child in skill_list.get_children():
		child.queue_free()
		
	if current_actor != null and current_actor.character_definition != null:
		var skills = current_actor.character_definition.skills
		for s in skills:
			if s is SkillDefinition:
				var btn = Button.new()
				var speed_label = s.get_cast_speed_label()
				btn.text = "%s (%d MP) [%s]" % [s.action_name, s.mp_cost, speed_label]
				btn.disabled = (current_actor.current_mp < s.mp_cost)
				btn.custom_minimum_size = Vector2(190, 32)
				btn.pressed.connect(func():
					hide_menu()
					action_selected.emit(s)
				)
				skill_list.add_child(btn)
				
		if skill_list.get_child_count() > 0:
			var first_btn = skill_list.get_child(0) as Button
			if not first_btn.disabled:
				first_btn.grab_focus()

func _on_back_pressed() -> void:
	skill_container.visible = false
	main_container.visible = true
	$MainContainer/BtnSkill.grab_focus()
