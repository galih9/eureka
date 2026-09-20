class_name TutorialManager
extends BattleManager

## Orchestrates the step-by-step interactive tutorial arena scenario.
## Coordinates combatant states, guided objectives, interrupts, skills,
## and formation movement dodging.

enum TutorialStep {
	TIMELINE_INTRO = 0,
	COMMAND_ATTACK = 1,
	ACTION_CANCEL = 2,
	SKILLS_STATUS = 3,
	MOVE_DODGE = 4,
	COMPLETED = 5
}

const TutorialUIScript = preload("res://scripts/tutorial/tutorial_ui.gd")

@export var tutorial_ui: CanvasLayer = null

var current_tutorial_step: TutorialStep = TutorialStep.TIMELINE_INTRO
var player_unit: BattleCharacter = null
var enemy_unit: BattleCharacter = null
var step_initialized: bool = false
var waiting_for_proceed: bool = false

# Preloaded tutorial skill assets
var heavy_slam_skill: SkillDefinition = preload("res://data/skills/tutorial_heavy_slam.tres")
var acid_dart_skill: SkillDefinition = preload("res://data/skills/tutorial_acid_dart.tres")
var flinch_strike_skill: SkillDefinition = preload("res://data/skills/flinch_strike.tres")

func _ready() -> void:
	super._ready()
	
	if tutorial_ui != null:
		tutorial_ui.proceed_pressed.connect(_on_tutorial_proceed_pressed)
		tutorial_ui.return_to_menu_pressed.connect(_on_tutorial_return_to_menu)
		if tutorial_ui.has_signal("help_requested"):
			tutorial_ui.help_requested.connect(_on_help_requested)
		
	var events = CombatEventsBus.get_bus(self)
	if events:
		events.action_canceled.connect(_on_combat_action_canceled)
		events.status_applied.connect(_on_combat_status_applied)
		events.attack_missed.connect(_on_combat_attack_missed)

func initialize_battle(combatants: Array) -> void:
	super.initialize_battle(combatants)
	
	# Identify Roy and Training Slime
	for c in all_combatants:
		if c.team == 0:
			player_unit = c
		else:
			enemy_unit = c
			
	# Ensure Roy has ample MP and tutorial skills
	if player_unit != null:
		player_unit.current_mp = 60
		player_unit.mp_changed.emit(60, 60)
		
	# Start Step 1
	_setup_step(TutorialStep.TIMELINE_INTRO)

func _setup_step(step: TutorialStep) -> void:
	current_tutorial_step = step
	step_initialized = true
	waiting_for_proceed = true
	
	# Timeline is frozen while the player reads the explanation modal
	set_timeline_speed(0.0)
	
	match step:
		TutorialStep.TIMELINE_INTRO:
			if player_unit != null:
				player_unit.timeline_position = 20.0
				player_unit.timeline_state = BattleCharacter.TimelineState.MOVING_TO_COM
				player_unit.pending_action = null
			if enemy_unit != null:
				enemy_unit.timeline_position = 0.0
				enemy_unit.timeline_state = BattleCharacter.TimelineState.MOVING_TO_COM
				enemy_unit.pending_action = null
				
			if tutorial_ui != null:
				var body_text = (
					"Eureka features a dynamic Grandia-style turn timeline (shown at the top of your screen).\n\n"
					+ "• [b]WAIT Phase (White Track)[/b]: Combatants advance toward the right based on [b]Agility[/b].\n"
					+ "• [b]COM Line (Command Phase)[/b]: When a unit reaches [b]COM[/b], battle pauses and commands are chosen.\n"
					+ "• [b]ACT Line (Action Execution)[/b]: Units charge through the salmon [b]CMD[/b] zone to [b]ACT[/b]. Stronger actions have longer cast delays.\n\n"
					+ "Click [b]START TIMELINE ▶[/b] to begin!"
				)
				tutorial_ui.show_explanation(
					0, 5,
					"THE TIMELINE SYSTEM",
					body_text,
					"Observe the timeline until Roy reaches COM.",
					"START TIMELINE ▶"
				)
				
		TutorialStep.COMMAND_ATTACK:
			if player_unit != null:
				player_unit.timeline_position = TurnTimeline.COM_LINE
				player_unit.timeline_state = BattleCharacter.TimelineState.COMMAND_SELECTION
				player_unit.pending_action = null
			if enemy_unit != null:
				enemy_unit.timeline_position = 0.0
				enemy_unit.timeline_state = BattleCharacter.TimelineState.MOVING_TO_COM
				enemy_unit.pending_action = null
				
			if tutorial_ui != null:
				var body_text = (
					"Roy has arrived at the [b]COM[/b] line! The command menu is now ready.\n\n"
					+ "• Select [b]⚔ ATTACK[/b] from the circular menu.\n"
					+ "• Use [b]Left Click / Enter / Space[/b] to target the Training Slime and confirm.\n\n"
					+ "Once confirmed, Roy will charge through the pink CMD zone and execute his strike!"
				)
				tutorial_ui.show_explanation(
					1, 5,
					"COMMANDS, TARGETING & ATTACK",
					body_text,
					"Select ATTACK and strike the Training Slime.",
					"GOT IT — ISSUE COMMAND ▶"
				)
				
		TutorialStep.ACTION_CANCEL:
			if tutorial_ui != null:
				var body_text = (
					"One of Eureka's most vital tactical mechanics is [b]Action Cancelling[/b]!\n\n"
					+ "When an enemy reaches COM and is charging toward ACT (in the salmon CMD zone), striking them before they act will [b]CANCEL[/b] their action!\n\n"
					+ "• The enemy loses their queued attack completely.\n"
					+ "• The enemy is knocked backwards along the timeline into the WAIT area.\n\n"
					+ "The Slime is about to charge a slow [b]Heavy Slam[/b]! Strike the Slime before it reaches ACT to cancel it!"
				)
				tutorial_ui.show_explanation(
					2, 5,
					"ACTION CANCELLING (INTERRUPT)",
					body_text,
					"Attack the charging Slime to CANCEL its action.",
					"READY — PREPARE CANCEL ▶"
				)
				
		TutorialStep.SKILLS_STATUS:
			if tutorial_ui != null:
				var body_text = (
					"Characters can unleash specialized [b]Skills[/b] that consume [b]MP[/b].\n\n"
					+ "Skills alter the battle through tactical [b]Status Effects[/b]:\n"
					+ "• [b]Flinch[/b]: Heavily slows timeline speed to 25%.\n"
					+ "• [b]Stun[/b]: Freezes the combatant in place on the timeline.\n"
					+ "• [b]Silence[/b]: Prohibits casting Skills.\n"
					+ "• [b]Disarm[/b]: Prohibits normal Attacks.\n\n"
					+ "Select [b]✦ SKILL[/b] from the menu and execute [b]Flinch Strike[/b] to slow down the Slime!"
				)
				tutorial_ui.show_explanation(
					3, 5,
					"SKILLS & STATUS EFFECTS",
					body_text,
					"Cast Flinch Strike to afflict the Slime with Flinch.",
					"READY — CAST SKILL ▶"
				)
				
		TutorialStep.MOVE_DODGE:
			if tutorial_ui != null:
				var body_text = (
					"Combat in Eureka takes place on a [b]3 x 4 Formation Grid[/b].\n\n"
					+ "Attacks and ranged projectiles are [b]spot-targeted[/b] at the grid tile you currently occupy!\n\n"
					+ "• If an enemy aims at your tile, use the [b]📍 MOVE[/b] command before the attack lands.\n"
					+ "• When their projectile fires, it will [b]WHIFF[/b] (miss) because you are no longer in that spot!\n\n"
					+ "The Slime is charging a ranged [b]Acid Dart[/b] aimed at your slot!\n"
					+ "Select [b]MOVE[/b] and pick an open adjacent tile to dodge!"
				)
				tutorial_ui.show_explanation(
					4, 5,
					"FORMATION GRID & DODGING PROJECTILES",
					body_text,
					"Select MOVE and reposition to dodge the Acid Dart.",
					"READY — INITIATE DODGE ▶"
				)
				
		TutorialStep.COMPLETED:
			if tutorial_ui != null:
				var body_text = (
					"[b]Outstanding work, Captain![/b] You have mastered all core systems of Eureka:\n\n"
					+ "✔ [b]The Timeline System[/b]: Agility pacing, WAIT region, COM pauses, and ACT execution.\n"
					+ "✔ [b]Commands & Direct Targeting[/b]: Command selection and target execution.\n"
					+ "✔ [b]Action Cancelling[/b]: Striking charging foes to interrupt their attacks.\n"
					+ "✔ [b]Skills & Status Effects[/b]: Tactical MP usage and status afflictions.\n"
					+ "✔ [b]Formation & Movement[/b]: Repositioning to dodge spot-targeted projectiles.\n\n"
					+ "You are fully prepared to lead your squad in the full Battle Arena!"
				)
				tutorial_ui.show_explanation(
					5, 5,
					"★ TUTORIAL COMPLETE! ★",
					body_text,
					"",
					"RETURN TO MAIN MENU"
				)

func _on_tutorial_proceed_pressed() -> void:
	waiting_for_proceed = false
	
	match current_tutorial_step:
		TutorialStep.TIMELINE_INTRO:
			# Hide big modal card and show slim top mini-bar so entire arena is visible!
			if tutorial_ui != null:
				tutorial_ui.enter_action_phase(0, 5, "Observe the timeline until Roy reaches COM.")
			set_timeline_speed(14.0)
			
		TutorialStep.COMMAND_ATTACK:
			# Hide big modal card, show slim mini bar, and open command menu
			if tutorial_ui != null:
				tutorial_ui.enter_action_phase(1, 5, "Select ATTACK and strike the Training Slime.")
			if player_unit != null:
				player_unit.timeline_position = TurnTimeline.COM_LINE
				player_unit.timeline_state = BattleCharacter.TimelineState.COMMAND_SELECTION
				com_queue = [player_unit]
			if enemy_unit != null:
				enemy_unit.timeline_position = 0.0
				enemy_unit.timeline_state = BattleCharacter.TimelineState.MOVING_TO_COM
				enemy_unit.pending_action = null
			set_timeline_speed(14.0)
			_process_next_com_queue()
				
		TutorialStep.ACTION_CANCEL:
			if tutorial_ui != null:
				tutorial_ui.enter_action_phase(2, 5, "Attack the charging Slime to CANCEL its action.")
				
			# Set up Slime in MOVING_TO_EXECUTION with Heavy Slam (high delay)
			if enemy_unit != null and player_unit != null:
				var slam_action = BattleAction.new(enemy_unit, heavy_slam_skill, [player_unit])
				turn_timeline.schedule_action(enemy_unit, slam_action)
				enemy_unit.timeline_position = TurnTimeline.COM_LINE + 6.0
				enemy_unit.execution_position = TurnTimeline.COM_LINE + 65.0
				
				# Place Roy at COM ready to act
				player_unit.timeline_position = TurnTimeline.COM_LINE
				player_unit.timeline_state = BattleCharacter.TimelineState.COMMAND_SELECTION
				player_unit.pending_action = null
				com_queue = [player_unit]
				
			set_timeline_speed(14.0)
			_process_next_com_queue()
			
		TutorialStep.SKILLS_STATUS:
			if tutorial_ui != null:
				tutorial_ui.enter_action_phase(3, 5, "Select SKILL -> Flinch Strike to afflict the Slime.")
				
			# Restore Roy's MP and position at COM
			if player_unit != null and enemy_unit != null:
				player_unit.current_mp = 60
				player_unit.mp_changed.emit(60, 60)
				player_unit.timeline_position = TurnTimeline.COM_LINE
				player_unit.timeline_state = BattleCharacter.TimelineState.COMMAND_SELECTION
				player_unit.pending_action = null
				com_queue = [player_unit]
				
				# Position Slime in WAIT with full HP and no statuses
				enemy_unit.heal(2000)
				StatusSystem.clear_all(enemy_unit)
				enemy_unit.timeline_position = 25.0
				enemy_unit.timeline_state = BattleCharacter.TimelineState.MOVING_TO_COM
				enemy_unit.pending_action = null
				
			set_timeline_speed(14.0)
			_process_next_com_queue()
			
		TutorialStep.MOVE_DODGE:
			if tutorial_ui != null:
				tutorial_ui.enter_action_phase(4, 5, "Select MOVE and pick an open tile to dodge.")
				
			# Set up Slime charging ranged Acid Dart aimed at Roy's slot
			if enemy_unit != null and player_unit != null:
				StatusSystem.clear_all(enemy_unit)
				player_unit.current_mp = 60
				player_unit.mp_changed.emit(60, 60)
				
				var dart_action = BattleAction.new(enemy_unit, acid_dart_skill, [player_unit])
				turn_timeline.schedule_action(enemy_unit, dart_action)
				enemy_unit.timeline_position = TurnTimeline.COM_LINE + 10.0
				enemy_unit.execution_position = TurnTimeline.COM_LINE + 35.0
				
				# Place Roy at COM
				player_unit.timeline_position = TurnTimeline.COM_LINE
				player_unit.timeline_state = BattleCharacter.TimelineState.COMMAND_SELECTION
				player_unit.pending_action = null
				com_queue = [player_unit]
				
			set_timeline_speed(14.0)
			_process_next_com_queue()

func _on_help_requested() -> void:
	# Pause timeline when player clicks info to read card
	set_timeline_speed(0.0)

func _on_tutorial_return_to_menu() -> void:
	var tw = create_tween()
	if tutorial_ui != null and tutorial_ui.card_panel != null:
		tw.tween_property(tutorial_ui.card_panel, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/menu_scene.tscn")
	)

# --- Overrides to coordinate step completions ---

func _handle_actor_reached_com(actor: BattleCharacter) -> void:
	if current_tutorial_step == TutorialStep.TIMELINE_INTRO and actor == player_unit:
		# Roy reached COM! Immediately pause timeline and transition to Step 2
		set_timeline_speed(0.0)
		_setup_step(TutorialStep.COMMAND_ATTACK)
		return
		
	super._handle_actor_reached_com(actor)

func _on_action_finished(action: BattleAction) -> void:
	super._on_action_finished(action)
	
	if current_tutorial_step == TutorialStep.COMMAND_ATTACK and action.actor == player_unit:
		# Player performed their first attack! Complete Step 2
		set_timeline_speed(0.0)
		if tutorial_ui != null:
			tutorial_ui.update_objective("Direct attack executed!", true)
			tutorial_ui.show_banner("TARGET STRUCK!")
			
		var timer = get_tree().create_timer(1.2)
		timer.timeout.connect(func():
			_setup_step(TutorialStep.ACTION_CANCEL)
		)
	elif current_tutorial_step == TutorialStep.ACTION_CANCEL and action.actor == player_unit:
		# Action finished after cancel
		set_timeline_speed(0.0)
		var timer = get_tree().create_timer(1.2)
		timer.timeout.connect(func():
			_setup_step(TutorialStep.SKILLS_STATUS)
		)
	elif current_tutorial_step == TutorialStep.SKILLS_STATUS and action.actor == player_unit:
		# Action finished after skill
		set_timeline_speed(0.0)
		var timer = get_tree().create_timer(1.2)
		timer.timeout.connect(func():
			_setup_step(TutorialStep.MOVE_DODGE)
		)

func _on_combat_action_canceled(victim: BattleCharacter, _attacker: BattleCharacter, _result: AttackResult) -> void:
	if current_tutorial_step == TutorialStep.ACTION_CANCEL and victim == enemy_unit:
		if tutorial_ui != null:
			tutorial_ui.update_objective("Slime attack canceled and knocked back!", true)
			tutorial_ui.show_banner("💥 ACTION CANCELED! SLIME KNOCKED BACK", 2.2, Color(1.0, 0.4, 0.4))

func _on_combat_status_applied(character: Node, instance: StatusInstance) -> void:
	if current_tutorial_step == TutorialStep.SKILLS_STATUS and character == enemy_unit:
		var s_name = instance.definition.status_name if instance.definition != null else "Status"
		if tutorial_ui != null:
			tutorial_ui.update_objective("%s inflicted on Slime!" % s_name, true)
			tutorial_ui.show_banner("✦ %s APPLIED! SLIME TIMELINE SLOWED" % s_name.to_upper(), 2.2, Color(0.4, 0.9, 1.0))

func _on_combat_attack_missed(result: AttackResult) -> void:
	if current_tutorial_step == TutorialStep.MOVE_DODGE and result.target == player_unit:
		if tutorial_ui != null:
			tutorial_ui.update_objective("Repositioned and dodged Acid Dart!", true)
			tutorial_ui.show_banner("🛡 ATTACK DODGED! PROJECTILE WHIFFED", 2.4, Color(0.4, 1.0, 0.5))
			
		set_timeline_speed(0.0)
		var timer = get_tree().create_timer(1.5)
		timer.timeout.connect(func():
			_setup_step(TutorialStep.COMPLETED)
		)

# Prevent premature battle end checks during tutorial
func _check_battle_end() -> bool:
	if current_tutorial_step != TutorialStep.COMPLETED:
		return false
	return super._check_battle_end()
