extends SceneTree

var log_file: FileAccess

func log_msg(msg: String) -> void:
	print(msg)
	if log_file:
		log_file.store_line(msg)
		log_file.flush()

func _init() -> void:
	log_file = FileAccess.open("C:/Users/A8/.gemini/antigravity/brain/78f55c80-76b9-4458-9ad5-089623e82c2b/scratch/test_results.txt", FileAccess.WRITE)
	log_msg("--- BEGINNING COMPREHENSIVE COMBAT TESTS ---")

	
	var scene_res = load("res://scenes/battle_scene.tscn")
	if scene_res == null:
		print("FAIL: Could not load battle_scene.tscn")
		quit(1)
		return
		
	var scene = scene_res.instantiate()
	root.add_child(scene)
	
	var bm = scene.get_node("BattleManager")
	var cam = scene.get_node("BattleCameraController")
	var timeline = bm.turn_timeline
	var alpha_def = load("res://data/enemies/drone_alpha.tres")
	var beta_def = load("res://data/enemies/drone_beta.tres")
	
	# TEST 1: Initial Enemy Count is 3
	var living_enemies = bm.get_living_enemies()
	log_msg("TEST 1 - Initial living enemies: " + str(living_enemies.size()))
	assert(living_enemies.size() == 3, "Expected 3 initial enemies, got %d" % living_enemies.size())
	log_msg("TEST 1 PASSED: Initial enemy count is 3.")
	
	# TEST 2: Max 8 enemies cap
	log_msg("TEST 2 - Testing max enemy cap (8)...")
	var spawned_list: Array = []
	for i in range(5): # 3 + 5 = 8
		var spawned = bm.spawn_enemy(beta_def)
		assert(spawned != null, "Enemy #%d should spawn successfully" % (4 + i))
		spawned_list.append(spawned)
	
	assert(bm.get_living_enemies().size() == 8, "Expected 8 living enemies")
	log_msg("8 enemies currently living.")
	
	# Try spawning 9th enemy
	var ninth_enemy = bm.spawn_enemy(beta_def)
	assert(ninth_enemy == null, "9th enemy should NOT spawn (capped at 8)")
	log_msg("TEST 2 PASSED: 8 max enemies enforced cleanly.")
	
	# TEST 3: Timeline & Debug Despawn / Kill without Freeze
	log_msg("TEST 3 - Testing debug kill and despawn without freezing...")
	# Kill one enemy with play_death = true
	var enemy_to_kill = spawned_list.pop_back()
	bm.despawn_enemy(enemy_to_kill, true)
	assert(enemy_to_kill.is_dead, "Enemy should be marked dead")
	
	# Despawn one enemy with play_death = false
	var enemy_to_despawn = spawned_list.pop_back()
	bm.despawn_enemy(enemy_to_despawn, false)
	
	# Process timeline frames to verify no freeze
	for i in range(60):
		bm._process(0.016)
		if scene.battle_ui:
			scene.battle_ui._process(0.016)
			scene.battle_ui.timeline_ui._process(0.016)
			
	log_msg("TEST 3 PASSED: Debug kill/despawn and timeline progression run smoothly without freezing.")
	
	# TEST 4: Action Cancel / Interrupt Mechanic
	log_msg("TEST 4 - Testing action cancellation & pushback...")
	var players = bm.get_living_players()
	var test_player = players[0]
	var test_enemy = bm.get_living_enemies()[0]
	
	# Set test_enemy into MOVING_TO_EXECUTION state
	var dummy_action = BattleAction.new(test_enemy, bm.default_attack_skill, [test_player])
	timeline.schedule_action(test_enemy, dummy_action)
	assert(test_enemy.timeline_state == BattleCharacter.TimelineState.MOVING_TO_EXECUTION, "Enemy should be moving to execution")
	assert(test_enemy.pending_action != null, "Enemy should have pending action")
	
	# Simulate an attack from test_player hitting test_enemy
	# Test SHORT attack (e.g. normal attack, delay 20.0) -> pushback = 16.0
	var quick_action = BattleAction.new(test_player, bm.default_attack_skill, [test_enemy])
	var skill_def = load("res://data/skills/normal_attack.tres") # delay 20
	bm.execution_controller._resolve_hits(quick_action, skill_def)
	
	assert(test_enemy.pending_action == null, "Enemy pending action should be CANCELED")
	assert(test_enemy.timeline_state == BattleCharacter.TimelineState.MOVING_TO_COM, "Enemy timeline state should reset to MOVING_TO_COM")
	assert(test_enemy.timeline_position <= 100.0 - 16.0 + 0.1, "Enemy timeline position should be pushed back to <= 84.0, got %f" % test_enemy.timeline_position)
	log_msg("Cancel with SHORT disruptor successful! Position pushed back to: " + str(test_enemy.timeline_position))
	
	# Test LONG attack (e.g. heavy smash, delay 55.0) -> pushback = 52.0
	timeline.schedule_action(test_enemy, dummy_action)
	var heavy_skill = load("res://data/skills/heavy_smash.tres") # delay 55
	var heavy_action = BattleAction.new(test_player, heavy_skill, [test_enemy])
	bm.execution_controller._resolve_hits(heavy_action, heavy_skill)
	
	assert(test_enemy.pending_action == null, "Enemy pending action should be CANCELED again")
	assert(test_enemy.timeline_position <= 100.0 - 52.0 + 0.1, "Enemy timeline position should be pushed back to <= 48.0, got %f" % test_enemy.timeline_position)
	log_msg("Cancel with LONG disruptor successful! Position pushed back to: " + str(test_enemy.timeline_position))
	log_msg("TEST 4 PASSED: Action cancel and dynamic pushback working accurately.")
	
	# TEST 5: Critical Hit Dramatic Slowdown
	log_msg("TEST 5 - Testing critical hit slowdown FX...")
	assert(cam.crit_slowdown_enabled == true, "Crit slowdown should be enabled by default")
	cam.focus_on_critical_hit(test_enemy)
	assert(is_equal_approx(Engine.time_scale, cam.crit_time_scale), "Engine.time_scale should be %f, got %f" % [cam.crit_time_scale, Engine.time_scale])
	log_msg("Engine time scale during critical slowdown: " + str(Engine.time_scale))
	
	cam.restore_time_scale()
	assert(Engine.time_scale == 1.0, "Engine.time_scale should be restored to 1.0")
	log_msg("Engine time scale restored: " + str(Engine.time_scale))
	log_msg("TEST 5 PASSED: Critical hit slowdown functions cleanly.")
	
	log_msg("--- ALL COMBAT TESTS PASSED SUCCESSFULLY! ---")
	if log_file:
		log_file.close()
	quit(0)

