class_name PerkSystem
extends RefCounted

## Generic PerkSystem that monitors CombatEvents and processes PerkInstances.

var registered_perks: Array = [] # Array[PerkInstance]
var battle_manager: Node = null
var events_bus: CombatEventsBus = null

# Cached status definitions for perks
var bleed_status_def: StatusDefinition = null
var agi_up_status_def: StatusDefinition = null
var eva_up_status_def: StatusDefinition = null

func _init(p_battle_manager: Node = null) -> void:
	battle_manager = p_battle_manager
	_load_status_defs()

func _load_status_defs() -> void:
	if ResourceLoader.exists("res://data/status_effects/bleed.tres"):
		bleed_status_def = load("res://data/status_effects/bleed.tres")
	if ResourceLoader.exists("res://data/status_effects/agility_up.tres"):
		agi_up_status_def = load("res://data/status_effects/agility_up.tres")
	if ResourceLoader.exists("res://data/status_effects/evasion_up.tres"):
		eva_up_status_def = load("res://data/status_effects/evasion_up.tres")

func register_perk(perk: PerkInstance) -> void:
	if perk not in registered_perks:
		registered_perks.append(perk)

func unregister_character_perks(character: Node) -> void:
	var to_remove: Array = []
	for p in registered_perks:
		if p.owner == character:
			p.cleanup_modifiers()
			to_remove.append(p)
	for p in to_remove:
		registered_perks.erase(p)

func connect_events(events: CombatEventsBus) -> void:
	if events == null:
		return
	events_bus = events
	events.character_died.connect(_on_character_died)
	events.attack_hit.connect(_on_attack_hit)
	events.attack_missed.connect(_on_attack_missed)
	events.damage_taken.connect(_on_damage_taken)
	events.turn_ended.connect(_on_turn_ended)

# --- Event Handlers ---

func _on_damage_taken(result: AttackResult) -> void:
	if result == null or result.target == null:
		return
	for perk in registered_perks:
		if perk.owner == result.target and not perk.owner.is_dead:
			match perk.definition.perk_id:
				"ingrid_transform":
					_check_ingrid_transform(perk)

func _on_character_died(dead_character: Node) -> void:
	for perk in registered_perks:
		match perk.definition.perk_id:
			"roy_backup":
				if dead_character == perk.owner:
					_check_roy_backup(perk)
			"brute_awaken":
				if perk.owner != null and not perk.owner.is_dead:
					_check_brute_awaken(perk, dead_character)

func _on_attack_missed(result: AttackResult) -> void:
	for perk in registered_perks:
		if perk.owner == null or perk.owner.is_dead:
			continue
			
		match perk.definition.perk_id:
			"striker_focus":
				if result.attacker == perk.owner:
					_check_striker_miss(perk, result)
			"specialist_tactics":
				if result.target == perk.owner and result.attacker != null and result.attacker.team != perk.owner.team:
					_check_specialist_miss(perk, result)

func _on_attack_hit(result: AttackResult) -> void:
	for perk in registered_perks:
		if perk.owner == null or perk.owner.is_dead:
			continue
			
		match perk.definition.perk_id:
			"striker_focus":
				if result.attacker == perk.owner:
					_check_striker_hit(perk, result)
			"brute_awaken":
				if result.attacker == perk.owner:
					_check_brute_hit(perk, result)

func _on_turn_ended(character: Node) -> void:
	for perk in registered_perks:
		if perk.owner == character:
			perk.tick_cooldown()

# --- Specific Perk Handlers ---

func _check_brute_awaken(perk: PerkInstance, dead_character: Node) -> void:
	# Ally on Brute's team died while Brute is alive
	if dead_character != perk.owner and dead_character.team == perk.owner.team and perk.can_activate():
		perk.activation_count += 1
		perk.activated = true
		
		# Stat Modifiers
		var hp_pct: float = perk.definition.params.get("hp_bonus_pct", 0.30)
		var atk_pct: float = perk.definition.params.get("atk_bonus_pct", 0.25)
		
		var hp_mod = StatModifier.new("max_hp", StatModifier.Type.PERCENT, hp_pct, "perk_brute_hp")
		var atk_mod = StatModifier.new("attack", StatModifier.Type.PERCENT, atk_pct, "perk_brute_atk")
		
		perk.owner.add_stat_modifier(hp_mod)
		perk.owner.add_stat_modifier(atk_mod)
		perk.applied_modifiers.append(hp_mod)
		perk.applied_modifiers.append(atk_mod)
		
		# Heal Brute for bonus HP
		var bonus_hp: int = int(perk.owner.character_definition.max_hp * hp_pct)
		perk.owner.heal(bonus_hp)
		
		# Set guaranteed critical for next attack
		perk.owner.guaranteed_critical = true
		perk.set_counter("awaiting_crit_attack", 1)
		
		var events = _get_events(perk.owner)
		if events:
			events.perk_activated.emit(perk, "BRUTE AWAKENS!\nHP & ATK +%d%%! Next attack Guaranteed Critical!" % int(atk_pct * 100))

func _check_brute_hit(perk: PerkInstance, result: AttackResult) -> void:
	if perk.get_counter("awaiting_crit_attack") == 1:
		perk.owner.guaranteed_critical = false
		perk.set_counter("awaiting_crit_attack", 0)
		
		# If attack hit and target survives, apply Bleed
		if result.hit and result.target != null and not result.target.is_dead:
			if bleed_status_def == null:
				_load_status_defs()
			if bleed_status_def != null:
				StatusSystem.apply_status(result.target, bleed_status_def, perk.owner.character_definition.codename)

func _check_striker_miss(perk: PerkInstance, _result: AttackResult) -> void:
	if not perk.is_on_cooldown():
		var misses = perk.increment_counter("consecutive_misses", 1)
		var threshold = perk.definition.params.get("miss_threshold", 3)
		
		if misses >= threshold and perk.can_activate():
			perk.activation_count += 1
			perk.activated = true
			perk.owner.guaranteed_hit = true
			perk.owner.guaranteed_critical = true
			perk.set_counter("awaiting_focus_attack", 1)
			
			var events = _get_events(perk.owner)
			if events:
				events.perk_activated.emit(perk, "STRIKER FOCUS!\nNext Attack Guaranteed HIT + CRITICAL!")

func _check_striker_hit(perk: PerkInstance, _result: AttackResult) -> void:
	if perk.get_counter("awaiting_focus_attack") == 1:
		perk.owner.guaranteed_hit = false
		perk.owner.guaranteed_critical = false
		perk.set_counter("awaiting_focus_attack", 0)
		perk.cooldown_remaining = perk.definition.cooldown_turns
		
	# Reset consecutive misses on any successful hit
	perk.reset_counter("consecutive_misses")

func _check_specialist_miss(perk: PerkInstance, _result: AttackResult) -> void:
	if not perk.is_on_cooldown():
		var evades = perk.increment_counter("enemy_misses", 1)
		var threshold = perk.definition.params.get("evade_threshold", 2)
		
		if evades >= threshold and perk.can_activate():
			perk.activation_count += 1
			perk.activated = true
			perk.reset_counter("enemy_misses")
			
			if agi_up_status_def == null or eva_up_status_def == null:
				_load_status_defs()
				
			# Apply temporary buff to entire active team
			var teammates: Array = []
			if battle_manager != null and battle_manager.has_method("get_living_combatants"):
				for c in battle_manager.get_living_combatants():
					if c.team == perk.owner.team:
						teammates.append(c)
			else:
				teammates.append(perk.owner)
				
			for ally in teammates:
				if agi_up_status_def != null:
					StatusSystem.apply_status(ally, agi_up_status_def, perk.owner.character_definition.codename)
				if eva_up_status_def != null:
					StatusSystem.apply_status(ally, eva_up_status_def, perk.owner.character_definition.codename)
					
			perk.cooldown_remaining = perk.definition.cooldown_turns
			
			var events = _get_events(perk.owner)
			if events:
				events.perk_activated.emit(perk, "TACTICAL FORESIGHT!\nTeam Agility & Evasion Up for 3 turns!")

func _check_roy_backup(perk: PerkInstance) -> void:
	if perk.activation_count > 0:
		return
		
	var owner = perk.owner
	if owner == null:
		return
		
	# Check if at least one usable ally remains active
	var living_allies: int = 0
	if battle_manager != null and battle_manager.has_method("get_living_players"):
		living_allies = battle_manager.get_living_players().size()
	elif owner.is_inside_tree():
		var tree = owner.get_tree()
		if tree != null:
			for node in tree.get_nodes_in_group("combatants"):
				if node is BattleCharacter and node != owner and node.team == owner.team and not node.is_dead:
					living_allies += 1
	else:
		# Standalone / test fallback
		living_allies = 1
					
	if living_allies <= 0:
		return
		
	perk.activation_count += 1
	perk.activated = true
	
	# Roy immediately revives
	owner.is_dead = false
	var max_hp = owner.get_stat("max_hp")
	var restore_hp = max(1, int(max_hp * 0.50))
	owner.current_hp = restore_hp
	owner.hp_changed.emit(owner.current_hp, max_hp)
	owner.refresh_overhead_hp()
	owner.play_idle()
	
	if battle_manager != null and battle_manager.turn_timeline != null:
		battle_manager.turn_timeline.add_combatant(owner)
		if battle_manager.formation_system != null and owner.formation_slot >= 0:
			battle_manager.formation_system.occupy_slot(owner, owner.formation_slot)
			
	# Increased Attack buff
	var atk_mod = StatModifier.new("attack", StatModifier.Type.PERCENT, 0.35, "perk_backup_atk")
	owner.add_stat_modifier(atk_mod)
	perk.applied_modifiers.append(atk_mod)
	
	# Apply Exhausted status effect
	var exh_def = load("res://data/status_effects/exhausted.tres") as StatusDefinition
	if exh_def != null:
		StatusSystem.apply_status(owner, exh_def, "Backup")
		
	var events = _get_events(owner)
	if events:
		events.perk_activated.emit(perk, "BACKUP!\nRoy revives with increased Attack, but Exhausted!")

func _check_ingrid_transform(perk: PerkInstance) -> void:
	var owner = perk.owner
	if owner == null or owner.is_dead:
		return
		
	var max_hp = owner.get_stat("max_hp")
	var hp_ratio = float(owner.current_hp) / float(max_hp)
	
	if hp_ratio <= 0.20 and not perk.activated:
		perk.activated = true
		perk.activation_count += 1
		perk.remaining_duration = 3
		
		# Enhanced offensive capability & increased critical
		var atk_mod = StatModifier.new("attack", StatModifier.Type.PERCENT, 0.40, "perk_transform_atk")
		var crit_mod = StatModifier.new("accuracy", StatModifier.Type.FLAT, 10, "perk_transform_acc")
		owner.add_stat_modifier(atk_mod)
		owner.add_stat_modifier(crit_mod)
		perk.applied_modifiers.append(atk_mod)
		perk.applied_modifiers.append(crit_mod)
		
		owner.guaranteed_critical = true
		owner.lifesteal_percent = 0.50 # Next attack gains 50% Lifesteal
		
		# Visual aura flash
		if owner.animated_sprite != null and owner.is_inside_tree():
			var tw = owner.create_tween()
			tw.tween_property(owner.animated_sprite, "modulate", Color(1.5, 0.4, 0.8), 0.2)
			tw.tween_property(owner.animated_sprite, "modulate", owner.base_modulate, 0.3)
			
		var events = _get_events(owner)
		if events:
			events.perk_activated.emit(perk, "TRANSFORM!\nIngrid enters high-risk offensive state with 50% Lifesteal!")

func _get_events(context: Node) -> CombatEventsBus:
	if events_bus != null:
		return events_bus
	return CombatEventsBus.get_bus(context)
