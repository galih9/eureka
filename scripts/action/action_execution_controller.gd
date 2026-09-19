class_name ActionExecutionController
extends RefCounted

## Coordinates 2D side-scroller action animations, hit frame synchronization,
## damage/item resolution, and cinematic camera cues:
## Actor focus -> Target focus -> Return to stage.

signal action_finished(action: BattleAction)

var camera_controller: BattleCameraController = null
var turn_timeline: TurnTimeline = null
var formation_system: FormationSystem = null

func _init(p_cam_controller: BattleCameraController = null, p_timeline: TurnTimeline = null, p_formation: FormationSystem = null) -> void:
	camera_controller = p_cam_controller
	turn_timeline = p_timeline
	formation_system = p_formation

func execute(action: BattleAction, on_complete: Callable) -> void:
	var actor = action.actor
	var action_def = action.action_definition
	var targets = action.targets
	
	if actor == null or not is_instance_valid(actor) or actor.is_dead:
		if on_complete.is_valid():
			on_complete.call()
		return
		
	var events = CombatEventsBus.get_bus(actor)
	if events:
		events.action_started.emit(action)
		
	# Chance-based camera zoom-in (most of the time stay in stage overview; guaranteed if crit ready)
	var will_zoom = false
	if camera_controller != null:
		will_zoom = camera_controller.should_focus_action(actor.guaranteed_critical)
		if will_zoom:
			camera_controller.focus_on_actor(actor)
		else:
			camera_controller.return_to_stage()
		
	# Handle MOVE
	if action_def.action_type == ActionDefinition.ActionType.MOVE:
		_resolve_move(action, on_complete)
		return

	# Handle DEFEND
	if action_def.action_type == ActionDefinition.ActionType.DEFEND:
		actor.is_defending = true
		actor.set_highlight(true)
		var timer_tween = actor.create_tween()
		timer_tween.tween_interval(0.45)
		timer_tween.tween_callback(func():
			actor.set_highlight(false)
			if camera_controller != null:
				camera_controller.return_to_stage()
			if events:
				events.action_finished.emit(action)
			if on_complete.is_valid():
				on_complete.call()
		)
		return
		
	# Identify primary target
	var primary_target: BattleCharacter = null
	for t in targets:
		if t != null and is_instance_valid(t) and not t.is_dead:
			primary_target = t
			break
			
	if primary_target == null and action_def.target_type != ActionDefinition.TargetType.SELF:
		if camera_controller != null:
			camera_controller.return_to_stage()
		if events:
			events.action_finished.emit(action)
		if on_complete.is_valid():
			on_complete.call()
		return
		
	var target_pos = primary_target.global_position if primary_target != null and is_instance_valid(primary_target) else (actor.global_position if is_instance_valid(actor) else Vector2.ZERO)

	
	# Handle ITEM: user requested "for using item for now just use attack animation"
	if action_def.action_type == ActionDefinition.ActionType.ITEM:
		var on_item_use = func():
			if will_zoom and camera_controller != null and primary_target != null:
				camera_controller.focus_on_target(primary_target)
			_resolve_item(action, primary_target)
		var on_item_finish = func():
			if camera_controller != null:
				camera_controller.return_to_stage()
			if events:
				events.action_finished.emit(action)
			if on_complete.is_valid():
				on_complete.call()
		actor.play_item_anim(target_pos, on_item_use, on_item_finish)
		return
		
	# Handle ATTACK / SKILL
	var skill_def = action_def as SkillDefinition
	var is_melee: bool = action_def.is_melee if "is_melee" in action_def else true
	var on_attack_hit = func():
		_resolve_hits(action, skill_def, will_zoom)
	var on_attack_finish = func():
		if camera_controller != null:
			camera_controller.return_to_stage()
		if events:
			events.action_finished.emit(action)
		if on_complete.is_valid():
			on_complete.call()
	actor.play_attack_anim(target_pos, on_attack_hit, on_attack_finish, is_melee)

func _resolve_move(action: BattleAction, on_complete: Callable) -> void:
	var actor = action.actor
	var events = CombatEventsBus.get_bus(actor)
	var dest_slot = action.destination_slot
	if formation_system == null or dest_slot < 0 or actor == null or actor.is_dead:
		if on_complete.is_valid():
			on_complete.call()
		return
		
	var target_world_pos = formation_system.get_slot_position(actor.team, dest_slot)
	actor.play_move()
	
	var tw = actor.create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(actor, "global_position", target_world_pos, 0.4)
	tw.parallel().tween_property(actor, "position", target_world_pos, 0.4)
	tw.tween_callback(func():
		formation_system.occupy_slot(actor, dest_slot)
		actor.play_idle()
		if events:
			events.action_finished.emit(action)
		if on_complete.is_valid():
			on_complete.call()
	)

func _resolve_item(action: BattleAction, target: BattleCharacter) -> void:
	var actor = action.actor
	var events = CombatEventsBus.get_bus(actor)
	if target == null or target.is_dead:
		return
		
	# Default item prototype behavior: Restorative Field Tonic (+120 HP)
	var heal_amount = 120
	target.heal(heal_amount)
	
	var res = AttackResult.new()
	res.attacker = actor
	res.target = target
	res.is_heal = true
	res.damage = heal_amount
	res.hit = true
	
	if events:
		events.damage_dealt.emit(res)

func _resolve_hits(action: BattleAction, skill_def: SkillDefinition, will_zoom: bool = false) -> void:
	var actor = action.actor
	var events = CombatEventsBus.get_bus(actor)
	
	for target in action.targets:
		if target == null or not is_instance_valid(target) or target.is_dead:
			continue
			
		# 1. Spot-Targeting Check: If target has moved away from their targeted spot, the attack WHIFFS!
		var scheduled_slot = action.target_slot_indices.get(target, -1)
		if scheduled_slot >= 0 and formation_system != null:
			if not formation_system.is_target_still_at_spot(target, scheduled_slot):
				target.play_dodge_anim()
				var whiff_res = AttackResult.new()
				whiff_res.attacker = actor
				whiff_res.target = target
				whiff_res.hit = false
				if events:
					events.attack_missed.emit(whiff_res)
				continue
				
		# 2. Protect Intercept Check: If target has an active protector, Roy intercepts the attack
		var hit_recipient: BattleCharacter = target
		var is_intercepted: bool = false
		if target.protected_by != null and is_instance_valid(target.protected_by) and not target.protected_by.is_dead:
			hit_recipient = target.protected_by
			is_intercepted = true
			
		# Handle Roy's Protect skill assignment
		if skill_def != null and skill_def.action_name == "Protect":
			target.protected_by = actor
			actor.protect_target = target
			var prot_res = AttackResult.new()
			prot_res.attacker = actor
			prot_res.target = target
			prot_res.hit = true
			if events:
				events.damage_dealt.emit(prot_res)
			continue
			
		# Calculate attack result
		var result: AttackResult = DamageSystem.calculate_attack(actor, hit_recipient, skill_def)
		
		# Jacob Grenade middle column damage modifier
		if skill_def != null and skill_def.action_name == "Grenade" and formation_system != null:
			var col_type = formation_system.get_column_type(target.team, target.formation_slot)
			if col_type == FormationSystem.ColumnType.MIDDLE:
				result.damage = int(result.damage * 1.45)
			else:
				result.damage = max(1, int(result.damage * 0.70))
				
		# Jacob Flashbang front column Silence bias
		if skill_def != null and skill_def.action_name == "Flashbang" and formation_system != null and skill_def.status_to_apply != null:
			var col_type = formation_system.get_column_type(target.team, target.formation_slot)
			var chance = 0.95 if col_type == FormationSystem.ColumnType.FRONT else (0.55 if col_type == FormationSystem.ColumnType.MIDDLE else 0.20)
			if randf() < chance:
				result.status_applied = skill_def.status_to_apply
			else:
				result.status_applied = null
		
		if result.is_heal:
			hit_recipient.heal(result.damage)
			if events:
				events.damage_dealt.emit(result)
		elif result.hit:
			hit_recipient.take_damage(result.damage, result.damage_type)
			hit_recipient.play_hit_anim(result.critical)
			
			# Lifesteal check (Ingrid Transform perk)
			if actor.lifesteal_percent > 0.0:
				var ls_amount = max(1, int(result.damage * actor.lifesteal_percent))
				actor.heal(ls_amount)
				actor.lifesteal_percent = 0.0
			
			# Grandia-style Action Cancel / Interrupt:
			# If the hit recipient is preparing and not protected:
			# Note: When Roy protects an ally, attacks against that ally DO NOT disrupt the ally!
			var victim_for_interrupt = hit_recipient if not is_intercepted else null
			if victim_for_interrupt != null:
				var is_preparing = (victim_for_interrupt.timeline_state == BattleCharacter.TimelineState.MOVING_TO_EXECUTION or victim_for_interrupt.pending_action != null)
				if is_preparing and not victim_for_interrupt.is_defending and not victim_for_interrupt.is_dead:
					var disruptor_action = action.action_definition
					var delay = disruptor_action.timeline_delay if disruptor_action != null else 35.0
					var pushback: float = 16.0
					
					# Roy Tackle specialization: Strong timeline pushback
					if skill_def != null and skill_def.action_name == "Tackle":
						pushback = 45.0
					elif delay <= 25.0:
						pushback = 16.0
					elif delay <= 45.0:
						pushback = 32.0
					else:
						pushback = 52.0
						
					if turn_timeline != null:
						turn_timeline.cancel_combatant_action(victim_for_interrupt, pushback)
					else:
						victim_for_interrupt.pending_action = null
						victim_for_interrupt.execution_position = 0.0
						victim_for_interrupt.timeline_state = BattleCharacter.TimelineState.MOVING_TO_COM
						victim_for_interrupt.timeline_position = clamp(TurnTimeline.COM_LINE - pushback, TurnTimeline.START_LINE, TurnTimeline.COM_LINE)
						
					result.was_canceled = true
					result.pushback_amount = pushback
					result.disruptor_action = disruptor_action
					
					if events:
						events.action_canceled.emit(victim_for_interrupt, actor, result)
			
			if camera_controller != null:
				if result.critical:
					camera_controller.focus_on_critical_hit(hit_recipient)
				elif will_zoom:
					camera_controller.focus_on_target(hit_recipient)
				else:
					camera_controller.shake(0.28)
				
			if events:
				if result.critical:
					events.critical_hit.emit(result)
				events.attack_hit.emit(result)
				events.damage_dealt.emit(result)
				events.damage_taken.emit(result)
				
			if result.status_applied != null:
				StatusSystem.apply_status(hit_recipient, result.status_applied, actor.character_definition.codename)
		else:
			# Missed
			hit_recipient.play_dodge_anim()
			if events:
				events.attack_missed.emit(result)

