class_name BattleManager
extends Node

## Coordinates high-level battle flow, state transitions, formation layout,
## Captain direct-control system, and continuous timeline progression.

signal state_changed(new_state: BattleState.State)
signal player_turn_ready(character: BattleCharacter)
signal target_selection_started(action_def: ActionDefinition, valid_targets: Array)
signal move_selection_started(action_def: ActionDefinition, valid_slots: Array)
signal battle_finished(victory: bool)
signal battle_initialized()
signal captain_changed(new_captain: BattleCharacter)
signal party_strategy_changed(new_strategy: PartyAI.PartyStrategy)
signal autonomous_action_triggered(character: BattleCharacter, reason: String)

@export var camera_controller: BattleCameraController
@export var default_attack_skill: ActionDefinition
@export var default_defend_action: ActionDefinition
@export var default_move_action: ActionDefinition
@export var enemies_container: Node3D
@export var players_container: Node3D

var current_state: BattleState.State = BattleState.State.INTRO
var all_combatants: Array = [] # Array[BattleCharacter]

var turn_timeline: TurnTimeline
var perk_system: PerkSystem
var execution_controller: ActionExecutionController
var formation_system: FormationSystem

# Captain & Party AI State
var captain: BattleCharacter = null
var party_strategy: PartyAI.PartyStrategy = PartyAI.PartyStrategy.ATTACK

var current_actor: BattleCharacter = null
var pending_action_def: ActionDefinition = null
var com_queue: Array = [] # Array[BattleCharacter] waiting for player input
var is_active: bool = false
var state_timer: float = 0.0

func _ready() -> void:
	if default_move_action == null:
		default_move_action = load("res://data/skills/move.tres") as ActionDefinition
		
	formation_system = FormationSystem.new()
	turn_timeline = TurnTimeline.new()
	turn_timeline.formation_system = formation_system
	perk_system = PerkSystem.new(self)
	execution_controller = ActionExecutionController.new(camera_controller, turn_timeline, formation_system)
	
	# Connect to central combat events bus
	var events = CombatEventsBus.get_bus(self)
	if events:
		perk_system.connect_events(events)
		events.action_line_reached.connect(_on_action_line_reached)
		events.character_died.connect(_on_character_died)

func initialize_battle(combatants: Array) -> void:
	all_combatants.clear()
	com_queue.clear()
	
	for c in combatants:
		if c is BattleCharacter and is_instance_valid(c):
			all_combatants.append(c)
			for p in c.active_perks:
				perk_system.register_perk(p)
				
	# Initialize formation placement
	_assign_initial_formation_slots()
	
	# Designate Initial Captain (Roy by default, or first player character)
	_setup_initial_captain()
				
	turn_timeline.initialize(all_combatants)
	is_active = true
	state_timer = 0.5
	change_state(BattleState.State.INTRO)
	battle_initialized.emit()

func _assign_initial_formation_slots() -> void:
	var player_idx = 0
	var enemy_idx = 0
	for c in all_combatants:
		if c.team == 0:
			# If character already has a slot assigned, occupy it; otherwise allocate default slot
			var slot = c.formation_slot
			if slot < 0 or formation_system.is_slot_occupied(0, slot):
				# Default slots for 3-character prototype party:
				# Slot 9 = Front Col Row 1 (Roy / Brawler)
				# Slot 8 = Front Col Row 0 (Ingrid / Striker)
				# Slot 1 = Rear Col Row 1 (Jacob / Specialist)
				var default_slots = [9, 8, 1, 5]
				slot = default_slots[player_idx % default_slots.size()]
				while formation_system.is_slot_occupied(0, slot):
					slot = formation_system.get_first_open_slot(0)
			formation_system.occupy_slot(c, slot)
			player_idx += 1
		else:
			var slot = c.formation_slot
			if slot < 0 or formation_system.is_slot_occupied(1, slot):
				slot = formation_system.get_first_open_slot(1)
			if slot >= 0:
				formation_system.occupy_slot(c, slot)
			enemy_idx += 1

func _setup_initial_captain() -> void:
	var living_players = get_living_players()
	if living_players.is_empty():
		return
		
	# Find Roy first
	var candidate: BattleCharacter = null
	for p in living_players:
		var codename = p.character_definition.codename.to_upper() if p.character_definition != null else ""
		if "ROY" in codename or "BRAWLER" in codename:
			candidate = p
			break
			
	if candidate == null:
		candidate = living_players[0]
		
	set_captain(candidate)

func set_captain(new_captain: BattleCharacter) -> void:
	if captain != null and is_instance_valid(captain):
		captain.is_captain = false
	captain = new_captain
	if captain != null:
		captain.is_captain = true
	captain_changed.emit(captain)

func is_captain_functional() -> bool:
	if captain == null or not is_instance_valid(captain) or captain.is_dead:
		return false
	# Captain disabled by Stun, Silence, Sleep, or other incapacitating statuses
	if StatusSystem.is_stunned(captain) or StatusSystem.is_silenced(captain) or StatusSystem.is_sleeping(captain):
		return false
	return true

func cycle_party_strategy() -> PartyAI.PartyStrategy:
	match party_strategy:
		PartyAI.PartyStrategy.ATTACK:
			party_strategy = PartyAI.PartyStrategy.DEFEND
		PartyAI.PartyStrategy.DEFEND:
			party_strategy = PartyAI.PartyStrategy.AUTONOMOUS
		PartyAI.PartyStrategy.AUTONOMOUS:
			party_strategy = PartyAI.PartyStrategy.ATTACK
	party_strategy_changed.emit(party_strategy)
	return party_strategy

func _process(delta: float) -> void:
	if not is_active:
		return
		
	if current_state == BattleState.State.INTRO:
		state_timer -= delta
		if state_timer <= 0.0:
			change_state(BattleState.State.TIMELINE)
	elif current_state == BattleState.State.TIMELINE:
		_process_timeline(delta)

func change_state(new_state: BattleState.State) -> void:
	current_state = new_state
	state_changed.emit(new_state)

func _process_timeline(delta: float) -> void:
	var step_res = turn_timeline.advance_timeline(delta)
	var ready_to_execute: Array = step_res.get("ready_to_execute", [])
	var reached_com: Array = step_res.get("reached_com", [])
	
	# 1. Process actors that reached COM this frame
	for actor in reached_com:
		if actor == null or not is_instance_valid(actor) or actor.is_dead:
			continue
		_handle_actor_reached_com(actor)
		if not is_active:
			return
			
	# 2. Check if any actor reached their execution position
	if not ready_to_execute.is_empty():
		for chosen_exec in ready_to_execute:
			if chosen_exec == null or not is_instance_valid(chosen_exec) or chosen_exec.is_dead:
				continue
			if chosen_exec.pending_action == null:
				# Action was canceled/interrupted, return to timeline movement
				turn_timeline.finish_action(chosen_exec)
				continue
			# Transition to execution
			chosen_exec.timeline_state = BattleCharacter.TimelineState.EXECUTING_ACTION
			change_state(BattleState.State.ACTION_EXECUTION)
			_execute_action_flow(chosen_exec.pending_action)
			return
			
	# 3. If no execution triggered and we have player actors queued for COM command choice
	if current_state == BattleState.State.TIMELINE and not com_queue.is_empty():
		_process_next_com_queue()

func _on_character_died(character: BattleCharacter) -> void:
	if character == null or not is_instance_valid(character):
		return
	_handle_character_death(character)
	_check_battle_end()

func _handle_actor_reached_com(actor: BattleCharacter) -> void:
	# Reset defend state & tick turn-start status effects (Poison / Bleed)
	actor.is_defending = false
	var _status_logs = StatusSystem.process_turn_start(actor)
	
	if actor.is_dead:
		_handle_character_death(actor)
		if _check_battle_end():
			return
		return
		
	var events = CombatEventsBus.get_bus(self)
	if events:
		events.turn_started.emit(actor)
		
	if actor.team == 0: # Player combatant
		# Captain System Check:
		# If the Captain is functional, player can issue commands normally
		if is_captain_functional():
			if actor not in com_queue:
				com_queue.append(actor)
		else:
			# Captain is disabled! Autonomous ally action triggers immediately
			var auto_action = PartyAI.decide_action(
				actor,
				party_strategy,
				captain,
				all_combatants,
				default_attack_skill,
				default_defend_action,
				formation_system
			)
			if auto_action == null:
				auto_action = BattleAction.new(actor, default_defend_action, [actor])
			turn_timeline.schedule_action(actor, auto_action)
			autonomous_action_triggered.emit(actor, "Captain Disabled")
	else: # Enemy combatant
		var enemy_action = EnemyAI.decide_action(actor, all_combatants, default_attack_skill, default_defend_action, captain)
		if enemy_action == null:
			enemy_action = BattleAction.new(actor, default_defend_action, [actor])
		turn_timeline.schedule_action(actor, enemy_action)

func _process_next_com_queue() -> void:
	while not com_queue.is_empty():
		var actor: BattleCharacter = com_queue.pop_front()
		if actor != null and not actor.is_dead and actor.timeline_state == BattleCharacter.TimelineState.COMMAND_SELECTION:
			# Double check Captain functionality before handing over command menu
			if not is_captain_functional():
				var auto_action = PartyAI.decide_action(
					actor,
					party_strategy,
					captain,
					all_combatants,
					default_attack_skill,
					default_defend_action,
					formation_system
				)
				if auto_action == null:
					auto_action = BattleAction.new(actor, default_defend_action, [actor])
				turn_timeline.schedule_action(actor, auto_action)
				autonomous_action_triggered.emit(actor, "Captain Disabled")
				continue
				
			current_actor = actor
			change_state(BattleState.State.PLAYER_ACTION)
			if camera_controller != null:
				camera_controller.focus_on_command(actor)
			player_turn_ready.emit(actor)
			return

# --- Player Action & Target Flow ---

func request_action_selection(action_def: ActionDefinition) -> void:
	if current_state != BattleState.State.PLAYER_ACTION:
		return
		
	pending_action_def = action_def
	
	if action_def.action_type == ActionDefinition.ActionType.MOVE:
		var valid_slots = formation_system.get_valid_moves(current_actor)
		if valid_slots.is_empty():
			return
		if current_actor.current_mp < action_def.mp_cost:
			return
		change_state(BattleState.State.TARGET_SELECTION)
		move_selection_started.emit(action_def, valid_slots)
		return

	if action_def.action_type == ActionDefinition.ActionType.DEFEND:
		# Defend is scheduled as a future timeline action with short delay
		var action = BattleAction.new(current_actor, action_def, [current_actor])
		_schedule_and_resume(action)
		return
		
	# Transition to target selection
	var valid_targets = TargetSystem.get_valid_targets(action_def.target_type, current_actor, all_combatants)
	if valid_targets.is_empty():
		return
		
	change_state(BattleState.State.TARGET_SELECTION)
	target_selection_started.emit(action_def, valid_targets)

func confirm_player_move(slot_idx: int) -> void:
	if current_state != BattleState.State.TARGET_SELECTION or pending_action_def == null:
		return
	if pending_action_def.action_type != ActionDefinition.ActionType.MOVE:
		return
	if not current_actor.spend_mp(pending_action_def.mp_cost):
		return
	var action = BattleAction.new(current_actor, pending_action_def, [], 0, slot_idx)
	_schedule_and_resume(action)

func confirm_player_target(targets: Array) -> void:
	if current_state != BattleState.State.TARGET_SELECTION or pending_action_def == null:
		return
		
	# Spend MP if skill or action has cost
	if pending_action_def is SkillDefinition:
		var skill_def = pending_action_def as SkillDefinition
		if not current_actor.spend_mp(skill_def.mp_cost):
			return
	elif pending_action_def.mp_cost > 0:
		if not current_actor.spend_mp(pending_action_def.mp_cost):
			return
			
	var action = BattleAction.new(current_actor, pending_action_def, targets)
	_schedule_and_resume(action)

func _schedule_and_resume(action: BattleAction) -> void:
	# Schedule action onto timeline as a future event
	turn_timeline.schedule_action(current_actor, action)
	pending_action_def = null
	
	if camera_controller != null:
		camera_controller.return_to_stage()
		
	# If another player is already waiting in com_queue, open their menu next
	if not com_queue.is_empty():
		_process_next_com_queue()
	else:
		change_state(BattleState.State.TIMELINE)

func cancel_target_selection() -> void:
	if current_state == BattleState.State.TARGET_SELECTION:
		change_state(BattleState.State.PLAYER_ACTION)
		if camera_controller != null and current_actor != null:
			camera_controller.focus_on_command(current_actor)
		player_turn_ready.emit(current_actor)

# --- Action Execution Pipeline ---

func _execute_action_flow(action: BattleAction) -> void:
	# Ensure living targets; auto-retarget if all original targets died while actor traveled to execution
	var living_targets: Array = []
	for t in action.targets:
		if t != null and is_instance_valid(t) and not t.is_dead:
			living_targets.append(t)

			
	if living_targets.is_empty() and action.action_definition.target_type != ActionDefinition.TargetType.SELF:
		var valid = TargetSystem.get_valid_targets(action.action_definition.target_type, action.actor, all_combatants)
		if not valid.is_empty():
			if TargetSystem.is_aoe(action.action_definition.target_type):
				action.targets = valid
			else:
				action.targets = [valid[0]]
		else:
			action.targets = []
	else:
		action.targets = living_targets

	execution_controller.execute(action, func():
		_on_action_finished(action)
	)

func _on_action_finished(action: BattleAction) -> void:
	change_state(BattleState.State.ACTION_RESULT)
	
	# Perk Resolution phase
	change_state(BattleState.State.PERK_RESOLUTION)
	
	# Status Resolution phase & Death Check
	change_state(BattleState.State.STATUS_RESOLUTION)
	StatusSystem.process_com_reached(action.actor)
	_clean_dead_combatants()
	
	if _check_battle_end():
		return
		
	# Actor returns to START of timeline and resumes moving to COM
	turn_timeline.finish_action(action.actor)
	
	var events = get_node_or_null("/root/CombatEvents")
	if events:
		events.turn_ended.emit(action.actor)
		
	# Short tactical pause for hit result / floating text readability
	var pause_timer = get_tree().create_timer(0.4)
	pause_timer.timeout.connect(func():
		if not is_inside_tree() or not is_active:
			return
		# Check if another character is waiting at COM
		if not com_queue.is_empty():
			_process_next_com_queue()
		else:
			# Resume Timeline movement
			change_state(BattleState.State.TIMELINE)
	)

func _handle_character_death(character: BattleCharacter) -> void:
	if character in com_queue:
		com_queue.erase(character)
	if formation_system != null:
		formation_system.vacate_character(character)
	turn_timeline.remove_combatant(character)
	perk_system.unregister_character_perks(character)

func _clean_dead_combatants() -> void:
	for c in all_combatants:
		if c != null and is_instance_valid(c) and c.is_dead:
			_handle_character_death(c)

func _check_battle_end() -> bool:
	if not is_active:
		return false
	var living_players = get_living_players()
	var living_enemies = get_living_enemies()
	
	if living_enemies.is_empty():
		_end_battle(true)
		return true
	elif living_players.is_empty():
		_end_battle(false)
		return true
		
	return false

func _end_battle(victory: bool) -> void:
	is_active = false
	change_state(BattleState.State.BATTLE_END)
	battle_finished.emit(victory)
	var events = get_node_or_null("/root/CombatEvents")
	if events:
		events.battle_ended.emit(victory)

# --- Queries ---

func get_living_combatants() -> Array:
	var res: Array = []
	for c in all_combatants:
		if c != null and is_instance_valid(c) and not c.is_dead:
			res.append(c)
	return res

func get_living_players() -> Array:
	var res: Array = []
	for c in all_combatants:
		if c != null and is_instance_valid(c) and not c.is_dead and c.team == 0:
			res.append(c)
	return res

func get_living_enemies() -> Array:
	var res: Array = []
	for c in all_combatants:
		if c != null and is_instance_valid(c) and not c.is_dead and c.team == 1:
			res.append(c)
	return res

func _on_action_line_reached(_actor: BattleCharacter) -> void:
	pass

# --- Runtime Debug Management Helpers ---

const MAX_ENEMIES: int = 12

func spawn_enemy(enemy_def: CharacterDefinition, custom_pos: Vector3 = Vector3.ZERO) -> BattleCharacter:
	if get_living_enemies().size() >= MAX_ENEMIES:
		push_warning("Cannot spawn enemy: maximum living enemy count (%d) reached." % MAX_ENEMIES)
		return null
		
	if enemies_container == null:
		var scene = get_tree().current_scene
		if scene != null:
			enemies_container = scene.find_child("Enemies", true, false)
			
	if enemies_container == null:
		push_error("Cannot spawn enemy: enemies_container is null")
		return null
		
	var target_pos = custom_pos
	var target_slot = -1
	if target_pos == Vector3.ZERO:
		if formation_system != null:
			target_slot = formation_system.get_first_open_slot(1)
			if target_slot >= 0:
				target_pos = formation_system.get_slot_position(1, target_slot)
				
		if target_pos == Vector3.ZERO:
			var extra_idx = get_living_enemies().size()
			target_pos = Vector3(5.5, 0.0, float(extra_idx % 4) * 1.5 - 2.25)
			
	var char_scene = preload("res://scenes/character/battle_character.tscn")
	var new_enemy: BattleCharacter = char_scene.instantiate()
	new_enemy.character_definition = enemy_def
	new_enemy.display_name_override = "%s %d" % [enemy_def.display_name, get_living_enemies().size() + 1]
	new_enemy.position = target_pos
	new_enemy.global_position = target_pos
	new_enemy.initial_position = target_pos
	
	enemies_container.add_child(new_enemy)
	all_combatants.append(new_enemy)
	turn_timeline.add_combatant(new_enemy)
	
	if target_slot >= 0 and formation_system != null:
		formation_system.occupy_slot(new_enemy, target_slot)
	
	for perk_def in enemy_def.perks:
		if perk_def is PerkDefinition:
			var p_inst = PerkInstance.new(perk_def, new_enemy)
			new_enemy.active_perks.append(p_inst)
			perk_system.register_perk(p_inst)
			
	# If battle had ended, revive flow
	if not is_active or current_state == BattleState.State.BATTLE_END:
		is_active = true
		change_state(BattleState.State.TIMELINE)
	return new_enemy

func despawn_enemy(enemy: BattleCharacter, play_death: bool = false) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
		
	if play_death:
		enemy.take_damage(99999, "Debug")
		_handle_character_death(enemy)
		_check_battle_end()
		return
		
	_handle_character_death(enemy)
	all_combatants.erase(enemy)
	enemy.queue_free()
	_check_battle_end()

func kill_all_enemies() -> void:
	var living = get_living_enemies()
	for e in living:
		despawn_enemy(e, true)


func revive_and_heal_party() -> void:
	for c in all_combatants:
		if c != null and is_instance_valid(c) and c.team == 0:
			var max_h = c.get_stat("max_hp")
			var max_m = c.get_stat("max_mp")
			if c.is_dead:
				c.is_dead = false
				c.current_hp = max_h
				c.current_mp = max_m
				c.hp_changed.emit(c.current_hp, max_h)
				c.mp_changed.emit(c.current_mp, max_m)
				turn_timeline.add_combatant(c)
				c.play_idle()
			else:
				c.heal(max_h)
				c.current_mp = max_m
				c.mp_changed.emit(c.current_mp, max_m)
				
	if not is_active or current_state == BattleState.State.BATTLE_END:
		is_active = true
		change_state(BattleState.State.TIMELINE)

func set_timeline_speed(speed: float) -> void:
	if turn_timeline != null:
		turn_timeline.timeline_speed = speed

