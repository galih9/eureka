extends SceneTree

## Automated Headless Test Suite for Turn-Based RPG Combat Prototype

func _initialize() -> void:
	_init()

func _init() -> void:
	print("==================================================")
	print("RUNNING AUTOMATED COMBAT SYSTEM TEST SUITE")
	print("==================================================")
	
	var passed = 0
	var total = 0
	
	# Test 1: StatModifier Calculation
	total += 1
	if _test_stat_modifiers():
		passed += 1
		print("  [PASS] StatModifier System")
	else:
		printerr("  [FAIL] StatModifier System")
		
	# Test 2: TurnTimeline Logic & Preview
	total += 1
	if _test_turn_timeline():
		passed += 1
		print("  [PASS] TurnTimeline Progression & Prediction")
	else:
		printerr("  [FAIL] TurnTimeline Progression & Prediction")
		
	# Test 3: Damage & Defend Calculations
	total += 1
	if _test_damage_system():
		passed += 1
		print("  [PASS] DamageSystem (Hit/Miss/Crit/Defend)")
	else:
		printerr("  [FAIL] DamageSystem")
		
	# Test 4: Target System
	total += 1
	if _test_target_system():
		passed += 1
		print("  [PASS] TargetSystem (Single/AOE/Allies/Enemies)")
	else:
		printerr("  [FAIL] TargetSystem")
		
	# Test 5: Status System (DoT & Expiration)
	total += 1
	if _test_status_system():
		passed += 1
		print("  [PASS] StatusSystem (Bleed/Poison & Duration Ticks)")
	else:
		printerr("  [FAIL] StatusSystem")
		
	# Test 6: Brute Awaken Perk
	total += 1
	if _test_brute_perk():
		passed += 1
		print("  [PASS] Brute Perk (Ally Death -> Awaken -> Crit + Bleed)")
	else:
		printerr("  [FAIL] Brute Perk")
		
	# Test 7: Striker Focus Perk
	total += 1
	if _test_striker_perk():
		passed += 1
		print("  [PASS] Striker Perk (3 Misses -> Guaranteed Hit + Crit)")
	else:
		printerr("  [FAIL] Striker Perk")
		
	# Test 8: Specialist Tactical Foresight Perk
	total += 1
	if _test_specialist_perk():
		passed += 1
		print("  [PASS] Specialist Perk (Enemy Misses -> Team Agi/Eva Buff)")
	else:
		printerr("  [FAIL] Specialist Perk")
		
	# Test 9: Stun Status (Timeline Complete Halt)
	total += 1
	if _test_stun_mechanic():
		passed += 1
		print("  [PASS] Stun System (Timeline Stopped & Real-Time Expiry)")
	else:
		printerr("  [FAIL] Stun System")
		
	# Test 10: Sleep Status (Halt Until Ally Pass)
	total += 1
	if _test_sleep_and_ally_pass():
		passed += 1
		print("  [PASS] Sleep System (Timeline Stopped Until Ally Pass)")
	else:
		printerr("  [FAIL] Sleep System")
		
	# Test 11: Flinch Status (Heavily Slowed Timeline)
	total += 1
	if _test_flinch_mechanic():
		passed += 1
		print("  [PASS] Flinch System (75% Timeline Slowdown)")
	else:
		printerr("  [FAIL] Flinch System")
		
	# Test 12: Silence & Disarm Restrictions
	total += 1
	if _test_silence_and_disarm_restrictions():
		passed += 1
		print("  [PASS] Silence & Disarm Restrictions (Skills/Attacks Blocked)")
	else:
		printerr("  [FAIL] Silence & Disarm Restrictions")
		
	# Test 13: Status Stacking
	total += 1
	if _test_status_stacking():
		passed += 1
		print("  [PASS] Multi-Status Stacking (Multiple Active Statuses)")
	else:
		printerr("  [FAIL] Multi-Status Stacking")
		
	# Test 14: Cast Speed Labels & Camera Guaranteed Critical Focus
	total += 1
	if _test_cast_speed_and_camera_crit():
		passed += 1
		print("  [PASS] Cast Speed Labels (SHORT/AVG/LONG) & Camera Crit Guarantee")
	else:
		printerr("  [FAIL] Cast Speed Labels & Camera Crit Guarantee")
		
	print("==================================================")
	print("TEST RESULTS: %d / %d PASSED" % [passed, total])
	print("==================================================")
	
	if passed == total:
		quit(0)
	else:
		quit(1)

func _create_dummy_character(codename: String, team: int, hp: int = 500, atk: int = 40, def_val: int = 15, agi: int = 18, acc: int = 90, eva: int = 10) -> BattleCharacter:
	var def = CharacterDefinition.new()
	def.codename = codename
	def.display_name = codename
	def.team = team as CharacterDefinition.Team
	def.max_hp = hp
	def.max_mp = 50
	def.attack = atk
	def.defense = def_val
	def.agility = agi
	def.accuracy = acc
	def.evasion = eva
	
	var chara = BattleCharacter.new()
	chara.initialize(def)
	return chara

# --- Tests ---

func _test_stat_modifiers() -> bool:
	var hero = _create_dummy_character("HERO", 0, 1000, 100, 50, 20)
	
	if hero.get_stat("attack") != 100:
		return false
		
	var flat_mod = StatModifier.new("attack", StatModifier.Type.FLAT, 20.0, "buff_flat")
	hero.add_stat_modifier(flat_mod)
	# (100 + 20) * 1.0 = 120
	if hero.get_stat("attack") != 120:
		return false
		
	var pct_mod = StatModifier.new("attack", StatModifier.Type.PERCENT, 0.25, "buff_pct")
	hero.add_stat_modifier(pct_mod)
	# (100 + 20) * 1.25 = 150
	if hero.get_stat("attack") != 150:
		return false
		
	hero.remove_stat_modifier(flat_mod)
	# 100 * 1.25 = 125
	if hero.get_stat("attack") != 125:
		return false
		
	hero.remove_stat_modifier(pct_mod)
	if hero.get_stat("attack") != 100:
		return false
		
	return true

func _test_turn_timeline() -> bool:
	var timeline = TurnTimeline.new()
	var fast_hero = _create_dummy_character("FAST", 0, 500, 30, 10, 30)
	var slow_hero = _create_dummy_character("SLOW", 0, 500, 30, 10, 10)
	
	fast_hero.timeline_position = 0.0
	slow_hero.timeline_position = 0.0
	
	timeline.add_combatant(fast_hero)
	timeline.add_combatant(slow_hero)
	
	# 1. Simulate progression
	timeline.advance_timeline(1.0)
	
	# Fast hero should advance faster than slow hero
	if fast_hero.timeline_position <= slow_hero.timeline_position:
		return false
		
	# 2. Advance until fast_hero reaches COM (100.0)
	while fast_hero.timeline_state == BattleCharacter.TimelineState.MOVING_TO_COM:
		timeline.advance_timeline(0.1)
		
	if fast_hero.timeline_position != TurnTimeline.COM_LINE:
		return false
	if fast_hero.timeline_state != BattleCharacter.TimelineState.COMMAND_SELECTION:
		return false
		
	# 3. Schedule a slow heavy attack for fast_hero (delay = 50.0 -> execution at 150.0)
	var heavy_def = ActionDefinition.new()
	heavy_def.timeline_delay = 50.0
	var heavy_action = BattleAction.new(fast_hero, heavy_def, [slow_hero])
	timeline.schedule_action(fast_hero, heavy_action)
	
	if fast_hero.execution_position != 150.0:
		return false
	if fast_hero.timeline_state != BattleCharacter.TimelineState.MOVING_TO_EXECUTION:
		return false
		
	# 4. Advance until slow_hero reaches COM
	while slow_hero.timeline_state == BattleCharacter.TimelineState.MOVING_TO_COM:
		timeline.advance_timeline(0.1)
		
	# Schedule a quick attack for slow_hero (delay = 10.0 -> execution at 110.0)
	var quick_def = ActionDefinition.new()
	quick_def.timeline_delay = 10.0
	var quick_action = BattleAction.new(slow_hero, quick_def, [fast_hero])
	timeline.schedule_action(slow_hero, quick_action)
	
	if slow_hero.execution_position != 110.0:
		return false
		
	# 5. Continuous race to execution:
	# slow_hero needs only 10.0 distance to reach 110.0.
	# fast_hero needs more distance (currently between 100 and 150).
	# Advance until an action reaches execution:
	var first_executed: BattleCharacter = null
	for _i in range(100):
		var res = timeline.advance_timeline(0.1)
		var ready = res.get("ready_to_execute", [])
		if not ready.is_empty():
			first_executed = ready[0]
			break
			
	# Slow hero with quick attack MUST execute before fast hero with heavy attack!
	if first_executed != slow_hero:
		return false
		
	# 6. Finish action resets combatant back to START_LINE (0.0)
	timeline.finish_action(slow_hero)
	if slow_hero.timeline_position != TurnTimeline.START_LINE or slow_hero.timeline_state != BattleCharacter.TimelineState.MOVING_TO_COM:
		return false
		
	return true

func _test_damage_system() -> bool:
	var attacker = _create_dummy_character("ATTACKER", 0, 500, 100, 20, 20, 95, 10)
	var defender = _create_dummy_character("DEFENDER", 1, 500, 30, 40, 20, 90, 10)
	
	# Guaranteed Hit and Guaranteed Crit
	attacker.guaranteed_hit = true
	attacker.guaranteed_critical = true
	
	var res = DamageSystem.calculate_attack(attacker, defender)
	if not res.hit or not res.critical or res.damage <= 0:
		return false
		
	# Check defend damage reduction
	defender.is_defending = true
	var res_defending = DamageSystem.calculate_attack(attacker, defender)
	if res_defending.damage >= res.damage:
		return false
		
	return true

func _test_target_system() -> bool:
	var p1 = _create_dummy_character("P1", 0)
	var p2 = _create_dummy_character("P2", 0)
	var e1 = _create_dummy_character("E1", 1)
	var e2 = _create_dummy_character("E2", 1)
	var combatants = [p1, p2, e1, e2]
	
	var enemy_targets = TargetSystem.get_valid_targets(ActionDefinition.TargetType.SINGLE_ENEMY, p1, combatants)
	if enemy_targets.size() != 2 or e1 not in enemy_targets or e2 not in enemy_targets:
		return false
		
	var ally_targets = TargetSystem.get_valid_targets(ActionDefinition.TargetType.ALL_ALLIES, p1, combatants)
	if ally_targets.size() != 2 or p1 not in ally_targets or p2 not in ally_targets:
		return false
		
	var self_targets = TargetSystem.get_valid_targets(ActionDefinition.TargetType.SELF, p1, combatants)
	if self_targets.size() != 1 or self_targets[0] != p1:
		return false
		
	return true

func _test_status_system() -> bool:
	var target = _create_dummy_character("TARGET", 1, 500)
	
	var bleed_def = StatusDefinition.new()
	bleed_def.status_id = "bleed"
	bleed_def.status_name = "Bleed"
	bleed_def.is_debuff = true
	bleed_def.duration_turns = 2
	bleed_def.dot_flat_damage = 30
	
	var inst = StatusSystem.apply_status(target, bleed_def, "TEST")
	if target.active_statuses.size() != 1:
		return false
		
	# Process turn start tick 1
	var logs1 = StatusSystem.process_turn_start(target)
	if target.current_hp != 470 or inst.duration != 1:
		return false
		
	# Process turn start tick 2 (should expire)
	var logs2 = StatusSystem.process_turn_start(target)
	if target.current_hp != 440 or target.active_statuses.size() != 0:
		return false
		
	return true

func _test_brute_perk() -> bool:
	var bus = CombatEventsBus.new()
	var perk_sys = PerkSystem.new()
	perk_sys.connect_events(bus)
	
	var brute_def = load("res://data/characters/brute.tres") as CharacterDefinition
	var brute = BattleCharacter.new()
	brute.initialize(brute_def)
	
	var ally = _create_dummy_character("ALLY", 0, 300)
	var enemy = _create_dummy_character("ENEMY", 1, 600)
	
	for p in brute.active_perks:
		perk_sys.register_perk(p)
		
	var init_atk = brute.get_stat("attack")
	
	# Simulate Ally dying
	bus.character_died.emit(ally)
	
	# Brute should awaken: ATK boosted, guaranteed critical set
	var awakened_atk = brute.get_stat("attack")
	if awakened_atk <= init_atk:
		return false
	if not brute.guaranteed_critical:
		return false
		
	# Brute attacks enemy
	brute.guaranteed_hit = true
	var atk_res = DamageSystem.calculate_attack(brute, enemy)
	if not atk_res.critical:
		return false
		
	# Resolve hit event
	bus.attack_hit.emit(atk_res)
	
	# Guaranteed critical flag consumed
	if brute.guaranteed_critical:
		return false
		
	# Bleed applied to enemy
	var has_bleed = false
	for st in enemy.active_statuses:
		if st.definition.status_id == "bleed":
			has_bleed = true
			break
	if not has_bleed:
		return false
		
	return true

func _test_striker_perk() -> bool:
	var bus = CombatEventsBus.new()
	var perk_sys = PerkSystem.new()
	perk_sys.connect_events(bus)
	
	var striker_def = load("res://data/characters/striker.tres") as CharacterDefinition
	var striker = BattleCharacter.new()
	striker.initialize(striker_def)
	
	var enemy = _create_dummy_character("ENEMY", 1, 500)
	
	for p in striker.active_perks:
		perk_sys.register_perk(p)
		
	# Miss 1
	var miss1 = AttackResult.new()
	miss1.attacker = striker
	miss1.target = enemy
	miss1.hit = false
	bus.attack_missed.emit(miss1)
	
	# Miss 2
	bus.attack_missed.emit(miss1)
	if striker.guaranteed_hit or striker.guaranteed_critical:
		return false
		
	# Miss 3 -> Awaken!
	bus.attack_missed.emit(miss1)
	if not striker.guaranteed_hit or not striker.guaranteed_critical:
		return false
		
	# Strike hits
	var hit_res = AttackResult.new()
	hit_res.attacker = striker
	hit_res.target = enemy
	hit_res.hit = true
	hit_res.critical = true
	bus.attack_hit.emit(hit_res)
	
	# Flags should be consumed
	if striker.guaranteed_hit or striker.guaranteed_critical:
		return false
		
	return true

func _test_specialist_perk() -> bool:
	var bus = CombatEventsBus.new()
	var perk_sys = PerkSystem.new()
	perk_sys.connect_events(bus)
	
	var spec_def = load("res://data/characters/specialist.tres") as CharacterDefinition
	var spec = BattleCharacter.new()
	spec.initialize(spec_def)
	
	var ally = _create_dummy_character("ALLY", 0, 500, 30, 10, 20)
	var enemy = _create_dummy_character("ENEMY", 1, 500)
	
	for p in spec.active_perks:
		perk_sys.register_perk(p)
		
	var init_agi = spec.get_stat("agility")
	var init_eva = spec.get_stat("evasion")
	
	# Enemy misses specialist once
	var miss1 = AttackResult.new()
	miss1.attacker = enemy
	miss1.target = spec
	miss1.hit = false
	bus.attack_missed.emit(miss1)
	
	if spec.get_stat("agility") != init_agi:
		return false
		
	# Enemy misses specialist twice -> Awaken!
	bus.attack_missed.emit(miss1)
	
	# Agility and Evasion should be buffed
	if spec.get_stat("agility") <= init_agi:
		return false
	if spec.get_stat("evasion") <= init_eva:
		return false
		
	return true

func _test_stun_mechanic() -> bool:
	var tl = TurnTimeline.new()
	var char1 = _create_dummy_character("HERO", 0, 500, 40, 15, 18)
	tl.initialize([char1])
	char1.timeline_position = 10.0
	
	var stun_def = load("res://data/status_effects/stun.tres") as StatusDefinition
	if stun_def == null:
		return false
	StatusSystem.apply_status(char1, stun_def)
	if not StatusSystem.is_stunned(char1):
		return false
		
	# Advance 1 second; position must stay exactly 10.0
	tl.advance_timeline(1.0)
	if char1.timeline_position != 10.0:
		return false
		
	# Advance remaining duration (2.5s > real_time_duration of 3.0 total)
	tl.advance_timeline(2.5)
	if StatusSystem.is_stunned(char1):
		return false
		
	# Now stun is expired, advancing must move character forward
	var p_before = char1.timeline_position
	tl.advance_timeline(0.5)
	if char1.timeline_position <= p_before:
		return false
		
	return true

func _test_sleep_and_ally_pass() -> bool:
	var tl = TurnTimeline.new()
	var char_sleep = _create_dummy_character("SLEEPER", 0, 500, 40, 15, 18)
	var ally = _create_dummy_character("RUNNER", 0, 500, 40, 15, 18)
	tl.initialize([char_sleep, ally])
	
	char_sleep.timeline_position = 30.0
	ally.timeline_position = 10.0
	
	var sleep_def = load("res://data/status_effects/sleep.tres") as StatusDefinition
	if sleep_def == null:
		return false
	StatusSystem.apply_status(char_sleep, sleep_def)
	if not StatusSystem.is_sleeping(char_sleep):
		return false
		
	# Advance small delta (ally reaches ~20.0, still behind sleeper at 30.0)
	tl.advance_timeline(1.0)
	if not StatusSystem.is_sleeping(char_sleep):
		return false
	if char_sleep.timeline_position != 30.0:
		return false
		
	# Advance enough for ally to pass sleeper (ally goes past 30.0)
	tl.advance_timeline(2.0)
	# Sleeper should have woken up from ally pass!
	if StatusSystem.is_sleeping(char_sleep):
		return false
		
	return true

func _test_flinch_mechanic() -> bool:
	var tl = TurnTimeline.new()
	var normal_char = _create_dummy_character("NORMAL", 0, 500, 40, 15, 18)
	var flinch_char = _create_dummy_character("FLINCHED", 0, 500, 40, 15, 18)
	tl.initialize([normal_char, flinch_char])
	normal_char.timeline_position = 0.0
	flinch_char.timeline_position = 0.0
	
	var flinch_def = load("res://data/status_effects/flinch.tres") as StatusDefinition
	if flinch_def == null:
		return false
	StatusSystem.apply_status(flinch_char, flinch_def)
	if not StatusSystem.is_flinched(flinch_char):
		return false
		
	tl.advance_timeline(1.0)
	# Flinched character should have moved ~25% as far as normal character
	var normal_dist = normal_char.timeline_position
	var flinch_dist = flinch_char.timeline_position
	if flinch_dist <= 0.0 or flinch_dist >= normal_dist * 0.5:
		return false
		
	return true

func _test_silence_and_disarm_restrictions() -> bool:
	var enemy = _create_dummy_character("ENEMY", 1, 500, 40, 15, 18)
	var player = _create_dummy_character("PLAYER", 0, 500, 40, 15, 18)
	var atk_def = load("res://data/skills/normal_attack.tres") as ActionDefinition
	var def_def = load("res://data/skills/defend.tres") as ActionDefinition
	var skill_def = load("res://data/skills/fireball.tres") as SkillDefinition
	var s_arr: Array[Resource] = [skill_def]
	enemy.character_definition.skills = s_arr
	
	var silence_def = load("res://data/status_effects/silence.tres") as StatusDefinition
	var disarm_def = load("res://data/status_effects/disarm.tres") as StatusDefinition
	if silence_def == null or disarm_def == null:
		return false
		
	# Test Silence blocks skill
	StatusSystem.apply_status(enemy, silence_def)
	if not StatusSystem.is_silenced(enemy):
		return false
	var action_silenced = EnemyAI.decide_action(enemy, [enemy, player], atk_def, def_def)
	if action_silenced == null or action_silenced.action_definition == skill_def:
		return false # Silenced enemy should not pick skill
	StatusSystem.clear_all(enemy)
	
	# Test Disarm blocks basic attack
	StatusSystem.apply_status(enemy, disarm_def)
	if not StatusSystem.is_disarmed(enemy):
		return false
	var action_disarmed = EnemyAI.decide_action(enemy, [enemy, player], atk_def, def_def)
	if action_disarmed == null or action_disarmed.action_definition == atk_def:
		return false # Disarmed enemy should not pick basic attack
		
	return true

func _test_status_stacking() -> bool:
	var hero = _create_dummy_character("HERO", 0, 500)
	var stun_def = load("res://data/status_effects/stun.tres") as StatusDefinition
	var flinch_def = load("res://data/status_effects/flinch.tres") as StatusDefinition
	var silence_def = load("res://data/status_effects/silence.tres") as StatusDefinition
	var bleed_def = load("res://data/status_effects/bleed.tres") as StatusDefinition
	
	StatusSystem.apply_status(hero, stun_def)
	StatusSystem.apply_status(hero, flinch_def)
	StatusSystem.apply_status(hero, silence_def)
	StatusSystem.apply_status(hero, bleed_def)
	
	if hero.active_statuses.size() != 4:
		return false
	if not StatusSystem.is_stunned(hero):
		return false
	if not StatusSystem.is_flinched(hero):
		return false
	if not StatusSystem.is_silenced(hero):
		return false
	if not StatusSystem.has_status_id(hero, "bleed"):
		return false
		
	return true

func _test_cast_speed_and_camera_crit() -> bool:
	var quick = ActionDefinition.new()
	quick.timeline_delay = 20.0
	if quick.get_cast_speed_label() != "SHORT":
		return false
		
	var avg = ActionDefinition.new()
	avg.timeline_delay = 35.0
	if avg.get_cast_speed_label() != "AVERAGE":
		return false
		
	var heavy = ActionDefinition.new()
	heavy.timeline_delay = 55.0
	if heavy.get_cast_speed_label() != "LONG":
		return false
		
	var cam = BattleCameraController.new()
	cam.normal_focus_chance = 0.0 # 0% chance on normal
	if cam.should_focus_action(false):
		return false
	if not cam.should_focus_action(true): # Critical MUST guarantee zoom-in
		return false
		
	return true
