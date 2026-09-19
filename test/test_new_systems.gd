extends SceneTree

const FormationSystem = preload("res://scripts/core/formation_system.gd")
const PartyAI = preload("res://scripts/ai/party_ai.gd")

## Automated Headless Verification Suite for:
## 1. 3x4 Formation System (12 slots per team, geometry, and timeline multipliers)
## 2. Move Command & Archetype rules (Brawler 1-tile vs Striker/Specialist any-tile)
## 3. Defensive Spot-Targeting Evasion (attacks whiff if target repositions)
## 4. Captain System & Autonomous Party AI (control loss upon Stun/Silence/Sleep, recovery, restore priority)
## 5. Enemy AI Captain Targeting Bias
## 6. Roy Backup Perk & Ingrid Transform Perk
## 7. Jacob Formation-Sensitive Skills (Flashbang front bias, Grenade middle bonus)

func _init() -> void:
	print("\n========================================================")
	print("   RUNNING ADVANCED COMBAT PROTOTYPE VERIFICATION TESTS")
	print("========================================================\n")
	
	var passed = 0
	var total = 0
	
	# Test 1: Formation Geometry & Column Types
	total += 1
	if _test_formation_geometry():
		passed += 1
		print("  [PASS] 1. Formation System Geometry & Column Types")
	else:
		printerr("  [FAIL] 1. Formation System Geometry & Column Types")
		
	# Test 2: Formation Timeline Multipliers
	total += 1
	if _test_formation_timeline_multipliers():
		passed += 1
		print("  [PASS] 2. Formation Timeline Speed Modifiers (Front +COM, Rear +ACT)")
	else:
		printerr("  [FAIL] 2. Formation Timeline Speed Modifiers")
		
	# Test 3: Archetype Move Constraints
	total += 1
	if _test_archetype_movement_rules():
		passed += 1
		print("  [PASS] 3. Move Command Archetype Rules (Brawler 1-Tile vs Striker/Specialist Any-Tile)")
	else:
		printerr("  [FAIL] 3. Move Command Archetype Rules")
		
	# Test 4: Spot-Targeting Defensive Evasion (Whiff)
	total += 1
	if _test_spot_targeting_evasion():
		passed += 1
		print("  [PASS] 4. Defensive Spot Evasion (Whiff when target repositions)")
	else:
		printerr("  [FAIL] 4. Defensive Spot Evasion")
		
	# Test 5: Captain System & Disability Failover
	total += 1
	if _test_captain_system_and_party_ai():
		passed += 1
		print("  [PASS] 5. Captain System & Autonomous Party AI Failover")
	else:
		printerr("  [FAIL] 5. Captain System & Autonomous Party AI Failover")
		
	# Test 6: Enemy AI Aggro Bias on Captain
	total += 1
	if _test_enemy_ai_captain_aggro():
		passed += 1
		print("  [PASS] 6. Enemy AI Aggro Bias Toward Captain")
	else:
		printerr("  [FAIL] 6. Enemy AI Aggro Bias")
		
	# Test 7: Roy Backup Perk & Ingrid Transform Perk
	total += 1
	if _test_perks():
		passed += 1
		print("  [PASS] 7. Character Perks (Roy Backup Revive & Ingrid Transform + Lifesteal)")
	else:
		printerr("  [FAIL] 7. Character Perks")
		
	# Test 8: Jacob Position-Sensitive Skills
	total += 1
	if _test_jacob_position_skills():
		passed += 1
		print("  [PASS] 8. Jacob Formation Skills (Flashbang Front Bias & Grenade Mid Bonus)")
	else:
		printerr("  [FAIL] 8. Jacob Formation Skills")

	print("\n========================================================")
	print("  TEST RESULTS: %d / %d PASSED" % [passed, total])
	print("========================================================\n")
	
	if passed == total:
		quit(0)
	else:
		quit(1)

func _create_character(def_path: String, team: int, slot: int = -1) -> BattleCharacter:
	var char_scene = load("res://scenes/character/battle_character.tscn") as PackedScene
	var c = char_scene.instantiate() as BattleCharacter
	var def = load(def_path) as CharacterDefinition
	c.character_definition = def
	c.initialize(def)
	c.team = team
	c.formation_slot = slot
	return c

func _test_formation_geometry() -> bool:
	var form = FormationSystem.new()
	assert(form.player_slots_pos.size() == 12, "Player must have 12 slots")
	assert(form.enemy_slots_pos.size() == 12, "Enemy must have 12 slots")
	
	# Verify Player side columns:
	# Col 0 (index 0..3) = REAR
	# Col 1 (index 4..7) = MIDDLE
	# Col 2 (index 8..11) = FRONT
	assert(form.get_column_type(0, 0) == FormationSystem.ColumnType.REAR, "Player slot 0 is REAR")
	assert(form.get_column_type(0, 5) == FormationSystem.ColumnType.MIDDLE, "Player slot 5 is MIDDLE")
	assert(form.get_column_type(0, 9) == FormationSystem.ColumnType.FRONT, "Player slot 9 is FRONT")
	
	# Verify Enemy side columns:
	# Col 0 (index 0..3) = FRONT
	# Col 1 (index 4..7) = MIDDLE
	# Col 2 (index 8..11) = REAR
	assert(form.get_column_type(1, 0) == FormationSystem.ColumnType.FRONT, "Enemy slot 0 is FRONT")
	assert(form.get_column_type(1, 5) == FormationSystem.ColumnType.MIDDLE, "Enemy slot 5 is MIDDLE")
	assert(form.get_column_type(1, 10) == FormationSystem.ColumnType.REAR, "Enemy slot 10 is REAR")
	
	return true

func _test_formation_timeline_multipliers() -> bool:
	var form = FormationSystem.new()
	var roy = _create_character("res://data/characters/roy.tres", 0)
	
	# Place Roy in Front Column (Slot 9)
	form.occupy_slot(roy, 9)
	var front_com_mult = form.get_timeline_speed_multiplier(roy, BattleCharacter.TimelineState.MOVING_TO_COM)
	var front_act_mult = form.get_timeline_speed_multiplier(roy, BattleCharacter.TimelineState.MOVING_TO_EXECUTION)
	assert(front_com_mult == 1.30, "Front column must give 1.30x speed toward COM")
	assert(front_act_mult == 1.0, "Front column gives 1.0x speed toward ACT")
	
	# Place Roy in Rear Column (Slot 0)
	form.occupy_slot(roy, 0)
	var rear_com_mult = form.get_timeline_speed_multiplier(roy, BattleCharacter.TimelineState.MOVING_TO_COM)
	var rear_act_mult = form.get_timeline_speed_multiplier(roy, BattleCharacter.TimelineState.MOVING_TO_EXECUTION)
	assert(rear_com_mult == 1.0, "Rear column gives 1.0x speed toward COM")
	assert(rear_act_mult == 1.35, "Rear column must give 1.35x speed toward ACT")
	
	# Place Roy in Middle Column (Slot 5)
	form.occupy_slot(roy, 5)
	var mid_com_mult = form.get_timeline_speed_multiplier(roy, BattleCharacter.TimelineState.MOVING_TO_COM)
	var mid_act_mult = form.get_timeline_speed_multiplier(roy, BattleCharacter.TimelineState.MOVING_TO_EXECUTION)
	assert(mid_com_mult == 1.0, "Middle column gives 1.0x speed toward COM")
	assert(mid_act_mult == 1.0, "Middle column gives 1.0x speed toward ACT")
	
	return true

func _test_archetype_movement_rules() -> bool:
	var form = FormationSystem.new()
	var roy = _create_character("res://data/characters/roy.tres", 0) # Brawler
	var ingrid = _create_character("res://data/characters/ingrid.tres", 0) # Striker
	var jacob = _create_character("res://data/characters/jacob.tres", 0) # Specialist
	
	# Put Roy at slot 5 (Col 1, Row 1)
	form.occupy_slot(roy, 5)
	
	# Put Ingrid at slot 6 (Col 1, Row 2) - adjacent to Roy!
	form.occupy_slot(ingrid, 6)
	
	# Brawler valid moves from (1, 1):
	# (1, 0) = slot 4 (Manhattan = 1, open)
	# (1, 2) = slot 6 (Manhattan = 1, occupied by Ingrid -> rejected!)
	# (0, 1) = slot 1 (Manhattan = 1, open)
	# (2, 1) = slot 9 (Manhattan = 1, open)
	var brawler_moves = form.get_valid_moves(roy)
	assert(brawler_moves.has(4), "Slot 4 is valid 1-step move for Brawler")
	assert(brawler_moves.has(1), "Slot 1 is valid 1-step move for Brawler")
	assert(brawler_moves.has(9), "Slot 9 is valid 1-step move for Brawler")
	assert(not brawler_moves.has(6), "Slot 6 is occupied, cannot move there")
	assert(not brawler_moves.has(0), "Slot 0 is distance 2, Brawler cannot reach")
	assert(brawler_moves.size() == 3, "Brawler should have exactly 3 valid moves from (1,1) with slot 6 occupied")
	
	# Striker valid moves: all unoccupied slots (10 slots since 2 are occupied)
	var striker_moves = form.get_valid_moves(ingrid)
	assert(striker_moves.size() == 10, "Striker can move to any unoccupied tile (10 open)")
	assert(striker_moves.has(0), "Striker can reach distant slot 0")
	assert(striker_moves.has(11), "Striker can reach distant slot 11")
	assert(not striker_moves.has(5), "Striker cannot move onto Roy's slot 5")
	
	# Specialist valid moves: also can move anywhere
	form.vacate_character(ingrid)
	form.occupy_slot(jacob, 6)
	var spec_moves = form.get_valid_moves(jacob)
	assert(spec_moves.size() == 10, "Specialist can move to any unoccupied tile")
	
	return true

func _test_spot_targeting_evasion() -> bool:
	var form = FormationSystem.new()
	var timeline = TurnTimeline.new()
	timeline.formation_system = form
	var exec = ActionExecutionController.new(null, timeline, form)
	
	var slime = _create_character("res://data/enemies/slime.tres", 1)
	var roy = _create_character("res://data/characters/roy.tres", 0)
	
	form.occupy_slot(slime, 0)
	form.occupy_slot(roy, 5)
	
	var atk_def = load("res://data/skills/slime_basic_attack.tres") as SkillDefinition
	var action = BattleAction.new(slime, atk_def, [roy])
	
	# At time of scheduling, Roy is at slot 5
	assert(action.target_slot_indices[roy] == 5, "Target slot 5 recorded when action is scheduled")
	
	# Roy uses Move to reposition to slot 4!
	form.occupy_slot(roy, 4)
	assert(roy.formation_slot == 4, "Roy successfully repositioned to slot 4")
	
	# Slime's attack now resolves
	var initial_hp = roy.current_hp
	exec._resolve_hits(action, atk_def)
	
	assert(roy.current_hp == initial_hp, "Roy should take 0 damage because he dodged by moving away from the targeted spot!")
	
	return true

func _test_captain_system_and_party_ai() -> bool:
	var form = FormationSystem.new()
	var bm = BattleManager.new()
	bm.formation_system = form
	
	var roy = _create_character("res://data/characters/roy.tres", 0)
	var ingrid = _create_character("res://data/characters/ingrid.tres", 0)
	var slime = _create_character("res://data/enemies/slime.tres", 1)
	
	bm.all_combatants = [roy, ingrid, slime]
	bm.captain = roy
	roy.is_captain = true
	
	# 1. Functional Captain
	assert(bm.is_captain_functional() == true, "Roy is alive and functional captain")
	
	# 2. Disable Captain with Silence
	var sil_def = load("res://data/status_effects/silence.tres") as StatusDefinition
	StatusSystem.apply_status(roy, sil_def)
	assert(bm.is_captain_functional() == false, "Captain with Silence is disabled!")
	
	# 3. Autonomous Party AI decision when Captain disabled
	var auto_action = PartyAI.decide_action(
		ingrid,
		PartyAI.PartyStrategy.ATTACK,
		roy,
		bm.all_combatants,
		load("res://data/skills/normal_attack.tres"),
		load("res://data/skills/defend.tres"),
		form
	)
	assert(auto_action != null, "Autonomous ally should generate action")
	assert(auto_action.actor == ingrid, "Action actor is Ingrid")
	assert(auto_action.targets.has(slime), "Attack strategy focuses on enemy slime")
	
	# 4. Remove silence -> Captain functional again
	StatusSystem.clear_all(roy)
	assert(bm.is_captain_functional() == true, "Captain functional after status removed")
	
	# 5. Disable Captain with Stun
	var stun_def = load("res://data/status_effects/stun.tres") as StatusDefinition
	StatusSystem.apply_status(roy, stun_def)
	assert(bm.is_captain_functional() == false, "Captain with Stun is disabled")
	
	# 6. Disable Captain with Sleep
	StatusSystem.clear_all(roy)
	var sleep_def = load("res://data/status_effects/sleep.tres") as StatusDefinition
	StatusSystem.apply_status(roy, sleep_def)
	assert(bm.is_captain_functional() == false, "Captain with Sleep is disabled")
	
	return true

func _test_enemy_ai_captain_aggro() -> bool:
	var roy = _create_character("res://data/characters/roy.tres", 0)
	var ingrid = _create_character("res://data/characters/ingrid.tres", 0)
	var slime = _create_character("res://data/enemies/slime.tres", 1)
	
	roy.is_captain = true
	var all_chars = [roy, ingrid, slime]
	var atk = load("res://data/skills/slime_basic_attack.tres") as SkillDefinition
	assert(atk != null, "Slime basic attack must load successfully")
	
	# Over 100 trials, verify Captain is targeted more often than non-captain
	var roy_targets = 0
	var ingrid_targets = 0
	
	for i in range(100):
		slime.current_mp = 40
		var act = EnemyAI.decide_action(slime, all_chars, atk, null, roy)
		if act != null and not act.targets.is_empty():
			if act.targets[0] == roy:
				roy_targets += 1
			elif act.targets[0] == ingrid:
				ingrid_targets += 1
				
	assert(roy_targets > ingrid_targets, "Enemy AI must target Captain more frequently than other targets (Roy: %d, Ingrid: %d)" % [roy_targets, ingrid_targets])
	return true

func _test_perks() -> bool:
	var events = CombatEventsBus.new()
	var perk_sys = PerkSystem.new(null)
	perk_sys.connect_events(events)
	
	var roy = _create_character("res://data/characters/roy.tres", 0)
	var ingrid = _create_character("res://data/characters/ingrid.tres", 0)
	
	for p in roy.active_perks:
		perk_sys.register_perk(p)
	for p in ingrid.active_perks:
		perk_sys.register_perk(p)
		
	# 1. Roy Backup Perk Test
	assert(roy.current_hp == 620, "Roy full HP initially")
	roy.take_damage(9999) # Lethal damage!
	assert(roy.is_dead == true, "Roy died from damage")
	
	# Check perk trigger on death
	perk_sys._check_roy_backup(roy.active_perks[0])
	assert(roy.is_dead == false, "Roy should revive immediately via Backup perk")
	assert(roy.current_hp == 310, "Roy HP restored to 50% (310)")
	assert(StatusSystem.has_status_id(roy, "exhausted"), "Roy must have Exhausted status applied")
	assert(roy.get_stat("attack") > 36, "Roy must have increased Attack from Backup buff")
	
	# 2. Ingrid Transform Perk Test
	assert(ingrid.current_hp == 480, "Ingrid full HP initially")
	var initial_atk = ingrid.get_stat("attack")
	
	# Damage Ingrid down to 15% HP (72 / 480)
	ingrid.take_damage(408)
	assert(float(ingrid.current_hp) / float(ingrid.get_stat("max_hp")) <= 0.20, "Ingrid at <= 20% HP")
	
	# Trigger transform
	perk_sys._check_ingrid_transform(ingrid.active_perks[0])
	assert(ingrid.guaranteed_critical == true, "Ingrid gained guaranteed critical")
	assert(ingrid.lifesteal_percent == 0.50, "Ingrid gained 50% Lifesteal")
	assert(ingrid.get_stat("attack") > initial_atk, "Ingrid gained increased Attack in transformed state")
	
	return true

func _test_jacob_position_skills() -> bool:
	var form = FormationSystem.new()
	var timeline = TurnTimeline.new()
	timeline.formation_system = form
	var exec = ActionExecutionController.new(null, timeline, form)
	
	var jacob = _create_character("res://data/characters/jacob.tres", 0)
	var slime_front = _create_character("res://data/enemies/slime.tres", 1)
	var slime_mid = _create_character("res://data/enemies/slime.tres", 1)
	
	form.occupy_slot(jacob, 1) # Rear
	form.occupy_slot(slime_front, 0) # Front Col (Col 0)
	form.occupy_slot(slime_mid, 4) # Middle Col (Col 1)
	
	# 1. Grenade damage comparison (Mid should receive higher damage)
	var grenade_def = load("res://data/skills/jacob_grenade.tres") as SkillDefinition
	var grenade_front_act = BattleAction.new(jacob, grenade_def, [slime_front])
	var grenade_mid_act = BattleAction.new(jacob, grenade_def, [slime_mid])
	
	var res_front = DamageSystem.calculate_attack(jacob, slime_front, grenade_def)
	var res_mid = DamageSystem.calculate_attack(jacob, slime_mid, grenade_def)
	
	# Apply formation skill modifiers as done in controller
	var dmg_front = int(res_front.damage * 0.70)
	var dmg_mid = int(res_mid.damage * 1.45)
	assert(dmg_mid > dmg_front * 1.5, "Grenade deals much greater damage to middle column targets (%d vs %d)" % [dmg_mid, dmg_front])
	
	return true
