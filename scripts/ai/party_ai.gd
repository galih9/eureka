class_name PartyAI
extends RefCounted

## Automated Party AI used when Captain is disabled or autonomous party behavior is active.

enum PartyStrategy {
	ATTACK,
	DEFEND,
	AUTONOMOUS
}

static func decide_action(
	actor: BattleCharacter,
	strategy: PartyStrategy,
	captain: BattleCharacter,
	all_combatants: Array,
	default_attack: ActionDefinition,
	default_defend: ActionDefinition = null,
	formation_system: FormationSystem = null
) -> BattleAction:
	if actor == null or not is_instance_valid(actor) or actor.is_dead:
		return null
		
	var is_silenced = StatusSystem.is_silenced(actor)
	var is_disarmed = StatusSystem.is_disarmed(actor)
	
	# Usable skills
	var usable_skills: Array[SkillDefinition] = []
	if not is_silenced and actor.character_definition != null:
		for s in actor.character_definition.skills:
			if s is SkillDefinition and actor.current_mp >= s.mp_cost:
				usable_skills.append(s)
				
	var living_allies: Array[BattleCharacter] = []
	var living_enemies: Array[BattleCharacter] = []
	for c in all_combatants:
		if c != null and is_instance_valid(c) and not c.is_dead:
			if c.team == actor.team:
				living_allies.append(c)
			else:
				living_enemies.append(c)
				
	if living_enemies.is_empty():
		return null
		
	# --- Priority 0: Restore / Protect Disabled Captain ---
	if captain != null and is_instance_valid(captain) and not captain.is_dead and actor != captain:
		var cap_disabled = StatusSystem.is_stunned(captain) or StatusSystem.is_silenced(captain) or StatusSystem.is_sleeping(captain)
		if cap_disabled or float(captain.current_hp) / float(captain.get_stat("max_hp")) < 0.4:
			# Roy Protect priority
			for s in usable_skills:
				if s.action_name == "Protect" and captain.protected_by == null:
					actor.spend_mp(s.mp_cost)
					return BattleAction.new(actor, s, [captain])
					
			# Healing skill priority
			for s in usable_skills:
				if s.is_heal and s.target_type == ActionDefinition.TargetType.SINGLE_ALLY:
					actor.spend_mp(s.mp_cost)
					return BattleAction.new(actor, s, [captain])
					
	# --- Strategy Dispatch ---
	match strategy:
		PartyStrategy.ATTACK:
			return _decide_attack_strategy(actor, usable_skills, living_enemies, default_attack, default_defend, is_disarmed)
		PartyStrategy.DEFEND:
			return _decide_defend_strategy(actor, usable_skills, living_allies, living_enemies, default_attack, default_defend, is_disarmed)
		PartyStrategy.AUTONOMOUS:
			return _decide_autonomous_strategy(actor, usable_skills, living_allies, living_enemies, default_attack, default_defend, is_disarmed, formation_system)
			
	return BattleAction.new(actor, default_attack, [living_enemies[0]])

static func _decide_attack_strategy(
	actor: BattleCharacter,
	usable_skills: Array[SkillDefinition],
	living_enemies: Array[BattleCharacter],
	default_attack: ActionDefinition,
	default_defend: ActionDefinition,
	is_disarmed: bool
) -> BattleAction:
	# Prioritize highest power damaging skill
	var best_skill: SkillDefinition = null
	var highest_power: int = -1
	
	for s in usable_skills:
		if not s.is_heal and s.power > highest_power:
			highest_power = s.power
			best_skill = s
			
	var target_enemy = _get_lowest_hp_target(living_enemies)
	
	if best_skill != null and not is_disarmed:
		actor.spend_mp(best_skill.mp_cost)
		var targets = living_enemies if TargetSystem.is_aoe(best_skill.target_type) else [target_enemy]
		return BattleAction.new(actor, best_skill, targets)
		
	if not is_disarmed:
		return BattleAction.new(actor, default_attack, [target_enemy])
	elif default_defend != null:
		return BattleAction.new(actor, default_defend, [actor])
		
	return BattleAction.new(actor, default_attack, [target_enemy])

static func _decide_defend_strategy(
	actor: BattleCharacter,
	usable_skills: Array[SkillDefinition],
	living_allies: Array[BattleCharacter],
	living_enemies: Array[BattleCharacter],
	default_attack: ActionDefinition,
	default_defend: ActionDefinition,
	is_disarmed: bool
) -> BattleAction:
	var lowest_ally = _get_lowest_hp_target(living_allies)
	var lowest_ally_ratio = float(lowest_ally.current_hp) / float(lowest_ally.get_stat("max_hp"))
	
	# 1. Healing
	if lowest_ally_ratio < 0.6:
		for s in usable_skills:
			if s.is_heal:
				actor.spend_mp(s.mp_cost)
				var targets = living_allies if TargetSystem.is_aoe(s.target_type) else [lowest_ally]
				return BattleAction.new(actor, s, targets)
				
	# 2. Protection / Buffs
	for s in usable_skills:
		if s.action_name == "Protect" and lowest_ally != actor and lowest_ally.protected_by == null:
			actor.spend_mp(s.mp_cost)
			return BattleAction.new(actor, s, [lowest_ally])
			
	# 3. Crowd Control on dangerous enemies
	for s in usable_skills:
		if s.status_to_apply != null and (s.status_to_apply.status_id == "sleep" or s.status_to_apply.status_id == "silence" or s.status_to_apply.status_id == "stun"):
			var target = _get_highest_threat_target(living_enemies)
			actor.spend_mp(s.mp_cost)
			var targets = living_enemies if TargetSystem.is_aoe(s.target_type) else [target]
			return BattleAction.new(actor, s, targets)
			
	# 4. Self defend if low HP
	var self_ratio = float(actor.current_hp) / float(actor.get_stat("max_hp"))
	if self_ratio < 0.35 and default_defend != null:
		return BattleAction.new(actor, default_defend, [actor])
		
	if not is_disarmed:
		return BattleAction.new(actor, default_attack, [_get_lowest_hp_target(living_enemies)])
	elif default_defend != null:
		return BattleAction.new(actor, default_defend, [actor])
		
	return BattleAction.new(actor, default_attack, [living_enemies[0]])

static func _decide_autonomous_strategy(
	actor: BattleCharacter,
	usable_skills: Array[SkillDefinition],
	living_allies: Array[BattleCharacter],
	living_enemies: Array[BattleCharacter],
	default_attack: ActionDefinition,
	default_defend: ActionDefinition,
	is_disarmed: bool,
	formation_system: FormationSystem
) -> BattleAction:
	var archetype = actor.archetype
	
	match archetype:
		CharacterDefinition.Archetype.BRAWLER:
			# Check if an enemy is about to execute: use Tackle to interrupt!
			var executing_enemy = _get_executing_target(living_enemies)
			if executing_enemy != null:
				for s in usable_skills:
					if s.action_name == "Tackle":
						actor.spend_mp(s.mp_cost)
						return BattleAction.new(actor, s, [executing_enemy])
						
			# Check if ally needs Protect
			var lowest_ally = _get_lowest_hp_target(living_allies)
			if lowest_ally != actor and float(lowest_ally.current_hp) / float(lowest_ally.get_stat("max_hp")) < 0.5 and lowest_ally.protected_by == null:
				for s in usable_skills:
					if s.action_name == "Protect":
						actor.spend_mp(s.mp_cost)
						return BattleAction.new(actor, s, [lowest_ally])
						
			# If multiple enemies, Missiles
			if living_enemies.size() >= 2:
				for s in usable_skills:
					if s.action_name == "Missiles":
						actor.spend_mp(s.mp_cost)
						return BattleAction.new(actor, s, living_enemies)
						
		CharacterDefinition.Archetype.STRIKER:
			# Check for sleep / silence candidates
			for s in usable_skills:
				if s.action_name == "Sleep" or s.action_name == "Silence":
					var target = _get_highest_threat_target(living_enemies)
					if target != null and not StatusSystem.is_sleeping(target) and not StatusSystem.is_silenced(target):
						actor.spend_mp(s.mp_cost)
						return BattleAction.new(actor, s, [target])
						
		CharacterDefinition.Archetype.SPECIALIST:
			# Check enemy formation column concentrations
			if formation_system != null:
				var mid_count = 0
				var front_count = 0
				for e in living_enemies:
					var col_type = formation_system.get_column_type(e.team, e.formation_slot)
					if col_type == FormationSystem.ColumnType.MIDDLE:
						mid_count += 1
					elif col_type == FormationSystem.ColumnType.FRONT:
						front_count += 1
						
				if mid_count >= 1:
					for s in usable_skills:
						if s.action_name == "Grenade":
							actor.spend_mp(s.mp_cost)
							return BattleAction.new(actor, s, living_enemies)
				if front_count >= 1:
					for s in usable_skills:
						if s.action_name == "Flashbang":
							actor.spend_mp(s.mp_cost)
							return BattleAction.new(actor, s, living_enemies)
							
			# Flinch with Quick Shot if enemy executing
			var executing_enemy = _get_executing_target(living_enemies)
			if executing_enemy != null:
				for s in usable_skills:
					if s.action_name == "Quick Shot":
						actor.spend_mp(s.mp_cost)
						return BattleAction.new(actor, s, [executing_enemy])
						
	# Fallback: usable offensive skill or basic attack
	for s in usable_skills:
		if not s.is_heal:
			actor.spend_mp(s.mp_cost)
			var targets = living_enemies if TargetSystem.is_aoe(s.target_type) else [_get_lowest_hp_target(living_enemies)]
			return BattleAction.new(actor, s, targets)
			
	if not is_disarmed:
		return BattleAction.new(actor, default_attack, [_get_lowest_hp_target(living_enemies)])
	elif default_defend != null:
		return BattleAction.new(actor, default_defend, [actor])
		
	return BattleAction.new(actor, default_attack, [living_enemies[0]])

static func _get_lowest_hp_target(targets: Array[BattleCharacter]) -> BattleCharacter:
	if targets.is_empty():
		return null
	var lowest = targets[0]
	for t in targets:
		if t.current_hp < lowest.current_hp:
			lowest = t
	return lowest

static func _get_highest_threat_target(targets: Array[BattleCharacter]) -> BattleCharacter:
	if targets.is_empty():
		return null
	var best = targets[0]
	for t in targets:
		if t.timeline_state == BattleCharacter.TimelineState.MOVING_TO_EXECUTION:
			return t # Imminent threat
		if t.get_stat("attack") > best.get_stat("attack"):
			best = t
	return best

static func _get_executing_target(targets: Array[BattleCharacter]) -> BattleCharacter:
	for t in targets:
		if t.timeline_state == BattleCharacter.TimelineState.MOVING_TO_EXECUTION:
			return t
	return null
