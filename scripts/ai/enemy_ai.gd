class_name EnemyAI
extends RefCounted

## Decides enemy action and targets using the unified BattleAction pipeline.

static func decide_action(actor: BattleCharacter, all_combatants: Array, default_attack: ActionDefinition, defend_action: ActionDefinition = null, captain: BattleCharacter = null) -> BattleAction:
	if actor == null or actor.is_dead:
		return null
		
	var chosen_action_def: ActionDefinition = default_attack
	
	var is_silenced = StatusSystem.is_silenced(actor)
	var is_disarmed = StatusSystem.is_disarmed(actor)
	
	# Check if actor has usable skills
	var usable_skills: Array[SkillDefinition] = []
	if not is_silenced and actor.character_definition != null:
		for s in actor.character_definition.skills:
			if s is SkillDefinition:
				if actor.current_mp >= s.mp_cost:
					usable_skills.append(s)
					
	# AI tactical choice:
	# Low HP defend chance
	var max_hp = actor.get_stat("max_hp")
	if defend_action != null and float(actor.current_hp) / float(max_hp) < 0.20 and randf() < 0.3:
		chosen_action_def = defend_action
	elif not usable_skills.is_empty() and (is_disarmed or randf() < 0.55):
		# Pick random usable skill
		chosen_action_def = usable_skills.pick_random()
		actor.spend_mp((chosen_action_def as SkillDefinition).mp_cost)
	elif is_disarmed:
		# Cannot basic attack while disarmed; fallback to defend
		chosen_action_def = defend_action if defend_action != null else default_attack
		
	if chosen_action_def == null:
		chosen_action_def = default_attack
	if chosen_action_def == null and not usable_skills.is_empty():
		chosen_action_def = usable_skills[0]
	if chosen_action_def == null:
		return null
		
	# Target Selection
	var valid_targets = TargetSystem.get_valid_targets(chosen_action_def.target_type, actor, all_combatants)
	if valid_targets.is_empty():
		# Fallback to default attack on single enemy
		chosen_action_def = default_attack
		valid_targets = TargetSystem.get_valid_targets(ActionDefinition.TargetType.SINGLE_ENEMY, actor, all_combatants)
		if valid_targets.is_empty():
			return null
			
	var targets: Array = []
	if TargetSystem.is_aoe(chosen_action_def.target_type):
		targets = valid_targets
	elif chosen_action_def.target_type == ActionDefinition.TargetType.SELF:
		targets = [actor]
	else:
		# Tactical single target selection:
		# Captain Aggro Check: Enemies are more likely to target the Captain
		var captain_in_targets = captain != null and is_instance_valid(captain) and not captain.is_dead and captain in valid_targets
		if captain_in_targets and randf() < 0.60:
			targets = [captain]
		elif randf() < 0.5:
			# Target lowest HP ally/enemy
			var lowest_target = valid_targets[0]
			for t in valid_targets:
				if t.current_hp < lowest_target.current_hp:
					lowest_target = t
			targets = [lowest_target]
		else:
			targets = [valid_targets.pick_random()]
			
	return BattleAction.new(actor, chosen_action_def, targets)
