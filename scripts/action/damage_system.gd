class_name DamageSystem
extends RefCounted

## Handles hit, miss, critical, damage and healing calculations.

static func calculate_attack(attacker: Node, target: Node, skill: SkillDefinition = null) -> AttackResult:
	var result = AttackResult.new()
	result.attacker = attacker
	result.target = target
	
	if skill != null and skill.is_heal:
		result.is_heal = true
		result.hit = true
		result.critical = false
		var heal_power: int = skill.power
		var raw_heal: float = attacker.get_stat("attack") * (float(heal_power) / 100.0)
		result.damage = max(1, int(raw_heal))
		result.damage_type = skill.element
		return result
		
	# Check guaranteed hit flag from perks/states
	var has_guaranteed_hit: bool = attacker.guaranteed_hit if "guaranteed_hit" in attacker else false
	var has_guaranteed_crit: bool = attacker.guaranteed_critical if "guaranteed_critical" in attacker else false
	
	result.guaranteed_hit = has_guaranteed_hit
	result.guaranteed_critical = has_guaranteed_crit
	
	# Determine Hit/Miss
	if has_guaranteed_hit:
		result.hit = true
	else:
		var base_acc: int = skill.accuracy if skill != null else 95
		var att_acc: int = attacker.get_stat("accuracy") if attacker.has_method("get_stat") else 90
		var tar_eva: int = target.get_stat("evasion") if target.has_method("get_stat") else 10
		
		# hit_chance formula: skill_acc * (attacker_acc - target_eva) / 100
		var net_chance: float = float(base_acc + att_acc - tar_eva - 90)
		net_chance = clamp(net_chance, 5.0, 95.0)
		
		var roll: float = randf() * 100.0
		result.hit = (roll < net_chance)
		
	if not result.hit:
		result.damage = 0
		return result
		
	# Determine Critical
	if has_guaranteed_crit:
		result.critical = true
	else:
		var base_crit: float = skill.critical_chance if skill != null else 0.05
		var roll_crit: float = randf()
		result.critical = (roll_crit < base_crit)
		
	# Calculate Damage
	var att_atk: int = attacker.get_stat("attack") if attacker.has_method("get_stat") else 20
	var tar_def: int = target.get_stat("defense") if target.has_method("get_stat") else 10
	var power: int = skill.power if skill != null else 100
	
	var base_dmg: float = (float(att_atk) * float(power) / 100.0) - (float(tar_def) * 0.5)
	if base_dmg < 1.0:
		base_dmg = 1.0
		
	if result.critical:
		base_dmg *= 1.6 # 60% bonus damage on critical
		
	# Defend check
	if target.is_defending:
		base_dmg *= 0.5
		
	# Small random variance (+- 5%)
	var variance: float = randf_range(0.95, 1.05)
	var final_damage: int = max(1, int(round(base_dmg * variance)))
	
	result.damage = final_damage
	result.damage_type = skill.element if skill != null else "Physical"
	
	# Status effect application check
	if skill != null and skill.status_to_apply != null:
		if randf() < skill.status_chance:
			result.status_applied = skill.status_to_apply
			
	return result
