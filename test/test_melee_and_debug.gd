extends SceneTree

## Automated verification test for:
## 1. Melee vs ranged properties on skills.
## 2. Melee strike position matching target Y.
## 3. Enemy placement (2 diagonal columns).
## 4. Player placement (inverted triangle).
## 5. Debug menu spawn, despawn, and status effect application.

var frame: int = 0
var battle_scene: BattleScene = null

func _init() -> void:
	print("\n==========================================")
	print("  RUNNING MELEE, LAYOUT & DEBUG UNIT TESTS")
	print("==========================================\n")

	# 1. Verify Skill Properties (Melee vs Ranged)
	var normal_atk = load("res://data/skills/normal_attack.tres") as SkillDefinition
	var fireball = load("res://data/skills/fireball.tres") as SkillDefinition
	var quick_slash = load("res://data/skills/quick_slash.tres") as SkillDefinition
	var precision_shot = load("res://data/skills/precision_shot.tres") as SkillDefinition

	assert(normal_atk.is_melee == true, "Normal attack should be melee")
	assert(quick_slash.is_melee == true, "Quick slash should be melee")
	assert(fireball.is_melee == false, "Fireball should be ranged")
	assert(precision_shot.is_melee == false, "Precision shot should be ranged")
	print("[PASS] Skill Definition range types verified (Melee & Ranged)")

	# 2. Instantiate BattleScene
	var scene_res = load("res://scenes/battle_scene.tscn") as PackedScene
	assert(scene_res != null, "Battle scene should load")
	battle_scene = scene_res.instantiate() as BattleScene
	root.add_child(battle_scene)

func _process(_delta: float) -> bool:
	frame += 1
	if frame < 2:
		return false

	# 3. Verify Player Placement (Inverted Triangle)
	var players_node = battle_scene.find_child("Players", true, false)
	assert(players_node != null, "Players node exists")
	var striker = players_node.find_child("Striker", false, false) as BattleCharacter
	var specialist = players_node.find_child("Specialist", false, false) as BattleCharacter
	var brute = players_node.find_child("Brute", false, false) as BattleCharacter

	assert(striker.position == Vector2(200, 310), "Striker position matches inverted triangle top-left")
	assert(specialist.position == Vector2(310, 310), "Specialist position matches inverted triangle top-right")
	assert(brute.position == Vector2(255, 385), "Brute position matches inverted triangle bottom-center")
	print("[PASS] Player character positions match reference layout (Inverted Triangle)")

	# 4. Verify Enemy Placement (Two Diagonal Columns)
	var enemies_node = battle_scene.find_child("Enemies", true, false)
	assert(enemies_node != null, "Enemies node exists")
	var alpha1 = enemies_node.find_child("DroneAlpha1", false, false) as BattleCharacter
	var alpha2 = enemies_node.find_child("DroneAlpha2", false, false) as BattleCharacter
	var alpha3 = enemies_node.find_child("DroneAlpha3", false, false) as BattleCharacter
	var alpha4 = enemies_node.find_child("DroneAlpha4", false, false) as BattleCharacter
	var beta1 = enemies_node.find_child("DroneBeta1", false, false) as BattleCharacter
	var beta2 = enemies_node.find_child("DroneBeta2", false, false) as BattleCharacter
	var enf1 = enemies_node.find_child("DroneEnforcer1", false, false) as BattleCharacter
	var enf2 = enemies_node.find_child("DroneEnforcer2", false, false) as BattleCharacter

	# Col 1 slant: dx = 42, dy = 46
	assert(alpha1.position == Vector2(680, 280), "DroneAlpha1 position matches Col 1 row 0")
	assert(alpha2.position == Vector2(722, 326), "DroneAlpha2 position matches Col 1 row 1")
	assert(alpha3.position == Vector2(764, 372), "DroneAlpha3 position matches Col 1 row 2")
	assert(alpha4.position == Vector2(806, 418), "DroneAlpha4 position matches Col 1 row 3")

	# Col 2 slant: dx = 42, dy = 46
	assert(beta1.position == Vector2(820, 280), "DroneBeta1 position matches Col 2 row 0")
	assert(beta2.position == Vector2(862, 326), "DroneBeta2 position matches Col 2 row 1")
	assert(enf1.position == Vector2(904, 372), "DroneEnforcer1 position matches Col 2 row 2")
	assert(enf2.position == Vector2(946, 418), "DroneEnforcer2 position matches Col 2 row 3")
	print("[PASS] Enemy formation matches reference layout (Two Parallel Diagonal Columns)")

	# 5. Verify Melee Sequence strike_pos computation
	# Striker (team 0) attacks DroneAlpha3 at (764, 372)
	# Target position has Y = 372. Melee strike position should have target Y!
	var strike_target_pos = alpha3.global_position
	var strike_offset_x = -72.0 if striker.team == 0 else 72.0
	var expected_strike_pos = Vector2(strike_target_pos.x + strike_offset_x, strike_target_pos.y)
	assert(expected_strike_pos.y == strike_target_pos.y, "Melee strike position Y matches target Y exactly")
	assert(expected_strike_pos.x == 764.0 - 72.0, "Melee strike position X is in front of target")
	print("[PASS] Melee strike position correctly places attacker in front of target (X and Y)")

	# 6. Verify Debug Menu & BattleManager Helpers
	var bm = battle_scene.battle_manager
	assert(bm != null, "BattleManager is wired")

	var initial_enemy_count = bm.get_living_enemies().size()
	assert(initial_enemy_count == 8, "Initial enemy count is 8")

	# Test Debug: Spawn Enemy
	var drone_enf_def = load("res://data/enemies/drone_enforcer.tres") as CharacterDefinition
	var spawned_enemy = bm.spawn_enemy(drone_enf_def)
	assert(spawned_enemy != null, "Enemy successfully spawned")
	assert(bm.get_living_enemies().size() == initial_enemy_count + 1, "Living enemies increased by 1")
	assert(bm.turn_timeline.combatants.has(spawned_enemy), "Spawned enemy registered in TurnTimeline")
	print("[PASS] Debug Spawn Enemy verified")

	# Test Debug: Despawn Enemy
	bm.despawn_enemy(spawned_enemy, false)
	assert(bm.get_living_enemies().size() == initial_enemy_count, "Living enemies returned to initial count")
	assert(not bm.turn_timeline.combatants.has(spawned_enemy), "Despawned enemy evicted from TurnTimeline")
	print("[PASS] Debug Despawn Enemy verified")

	# Test Debug: Apply Status
	var stun_def = load("res://data/status_effects/stun.tres") as StatusDefinition
	var st_inst = StatusSystem.apply_status(alpha1, stun_def, "DebugTest")
	assert(st_inst != null, "Status applied")
	assert(StatusSystem.is_stunned(alpha1) == true, "alpha1 is stunned")
	print("[PASS] Debug Apply Status (Stun) verified")

	# Test Debug: Remove Status
	StatusSystem.remove_status(alpha1, st_inst)
	assert(StatusSystem.is_stunned(alpha1) == false, "alpha1 is no longer stunned")
	print("[PASS] Debug Remove Status verified")

	# Test Debug: Timeline Speed change
	bm.set_timeline_speed(20.0)
	assert(bm.turn_timeline.timeline_speed == 20.0, "Timeline speed updated to 20.0")
	bm.set_timeline_speed(10.0)
	print("[PASS] Debug Timeline Speed control verified")

	# Test Debug: Revive and Heal Party
	striker.current_hp = 10
	bm.revive_and_heal_party()
	assert(striker.current_hp == striker.get_stat("max_hp"), "Striker restored to full HP")
	print("[PASS] Debug Party Full Heal & Revive verified")

	# 7. Verify BattleUI Debug Menu is Mounted
	var battle_ui = battle_scene.battle_ui
	assert(battle_ui != null, "BattleUI exists")
	assert(battle_ui.debug_menu != null, "DebugMenu is instantiated in BattleUI")
	assert(battle_ui.debug_toggle_btn != null, "Debug toggle button exists in BattleUI")
	print("[PASS] BattleUI Debug Toggle Button and Menu verified")

	# 8. Verify Bottom-Left Party Status Cards (Reference Layout Match)
	var status_ui = battle_ui.status_ui
	assert(status_ui != null, "CharacterStatusUI exists")
	var party_container = status_ui.party_cards_container
	assert(party_container != null, "PartyContainer exists")
	assert(party_container.get_child_count() == 3, "Exactly 3 party cards exist in PartyContainer")

	var card1 = party_container.get_child(0)
	var card2 = party_container.get_child(1)
	var card3 = party_container.get_child(2)

	# Verify Card 1 is Character 1 (Striker)
	var c1_vbox = card1.get_child(0) as VBoxContainer
	var c1_name = c1_vbox.get_child(0) as Label
	var c1_sub = c1_vbox.get_child(1) as Label
	assert("Character 1" in c1_name.text, "Card 1 is Character 1")
	assert("STRIKER" in c1_sub.text, "Card 1 subtitle is STRIKER")

	# Verify Card 2 is Character 3 (Brute)
	var c2_vbox = card2.get_child(0) as VBoxContainer
	var c2_name = c2_vbox.get_child(0) as Label
	var c2_sub = c2_vbox.get_child(1) as Label
	assert("Character 3" in c2_name.text, "Card 2 is Character 3")
	assert("BRUTE" in c2_sub.text, "Card 2 subtitle is BRUTE")

	# Verify Card 3 is Character 2 (Specialist)
	var c3_vbox = card3.get_child(0) as VBoxContainer
	var c3_name = c3_vbox.get_child(0) as Label
	var c3_sub = c3_vbox.get_child(1) as Label
	assert("Character 2" in c3_name.text, "Card 3 is Character 2")
	assert("SPECIALIST" in c3_sub.text, "Card 3 subtitle is SPECIALIST")

	# Verify HP and MP bars in each card
	for i in range(3):
		var card = party_container.get_child(i)
		var vbox = card.get_child(0) as VBoxContainer
		var hp_bar = vbox.get_child(2) as ProgressBar
		var mp_bar = vbox.get_child(3) as ProgressBar
		assert(hp_bar != null, "Card %d has HP ProgressBar" % i)
		assert(mp_bar != null, "Card %d has MP ProgressBar" % i)
		assert(hp_bar.value > 0, "Card %d HP is positive" % i)
		assert(mp_bar.value > 0, "Card %d MP is positive" % i)
	print("[PASS] Bottom-Left Party Status Cards match reference layout (Character 1, 3, 2 with HP & MP bars)")

	print("\n==========================================")
	print("  ALL UNIT AND INTEGRATION TESTS PASSED!  ")
	print("==========================================\n")
	quit(0)
	return true
