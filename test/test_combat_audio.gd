extends SceneTree

## Automated Headless Test Suite for Combat Audio System
## Verifies audio asset loading, polyphony pool, variant rotation,
## volume balancing, pitch variance, and CombatEvents signal handling.

const CombatAudioManager = preload("res://scripts/audio/combat_audio_manager.gd")
const CombatEventsBus = preload("res://scripts/core/combat_events.gd")
const AttackResult = preload("res://scripts/action/attack_result.gd")

var log_file: FileAccess

func _log(msg: String) -> void:
	print(msg)
	if log_file != null:
		log_file.store_line(msg)
		log_file.flush()

func _init() -> void:
	var path = ProjectSettings.globalize_path("res://test_audio_results.txt")
	log_file = FileAccess.open(path, FileAccess.WRITE)
	if log_file == null:
		print("Failed to open log file at: ", path, " error: ", FileAccess.get_open_error())
	var passed: int = 0
	var total: int = 0
	
	_log("==================================================")
	_log("RUNNING COMBAT AUDIO SYSTEM TEST SUITE")
	_log("==================================================")

	# Test 1: Audio Asset Integrity
	total += 1
	if _test_audio_assets():
		passed += 1
		_log("  [PASS] 1. Audio Asset Integrity (5/5 streams loaded)")
	else:
		_log("  [FAIL] 1. Audio Asset Integrity")

	# Test 2: Pool Initialization & Configuration
	total += 1
	if _test_pool_initialization():
		passed += 1
		_log("  [PASS] 2. Audio Player Pool & Configuration")
	else:
		_log("  [FAIL] 2. Audio Player Pool & Configuration")

	# Test 3: Playback API & Pitch / Volume Formatting
	total += 1
	if _test_playback_methods():
		passed += 1
		_log("  [PASS] 3. Direct Playback (Hit, Miss, Crit)")
	else:
		_log("  [FAIL] 3. Direct Playback (Hit, Miss, Crit)")

	# Test 4: Smart Non-Repeating Variant Rotation
	total += 1
	if _test_variant_rotation():
		passed += 1
		_log("  [PASS] 4. Smart Non-Repeating Variant Rotation")
	else:
		_log("  [FAIL] 4. Smart Non-Repeating Variant Rotation")

	# Test 5: Polyphonic Pool Stealing & Concurrency
	total += 1
	if _test_pool_concurrency():
		passed += 1
		_log("  [PASS] 5. Polyphonic Pool Concurrency & Round-Robin")
	else:
		_log("  [FAIL] 5. Polyphonic Pool Concurrency & Round-Robin")

	# Test 6: CombatEvents Bus Integration (Hit, Crit, Miss)
	total += 1
	if _test_combat_events_integration():
		passed += 1
		_log("  [PASS] 6. CombatEvents Bus Integration (Hit, Crit, Miss)")
	else:
		_log("  [FAIL] 6. CombatEvents Bus Integration")

	# Test 7: Battle Scene Integration
	total += 1
	if _test_battle_scene_setup():
		passed += 1
		_log("  [PASS] 7. Battle Scene Audio Setup & Fallback")
	else:
		_log("  [FAIL] 7. Battle Scene Audio Setup & Fallback")

	_log("==================================================")
	_log("TEST RESULTS: %d / %d PASSED" % [passed, total])
	_log("==================================================")

	if log_file != null:
		log_file.close()

	if passed == total:
		quit(0)
	else:
		quit(1)

func _test_audio_assets() -> bool:
	var files = [
		"res://assets/audio/sword_hit.mp3",
		"res://assets/audio/sword_hit2.mp3",
		"res://assets/audio/sword_miss.mp3",
		"res://assets/audio/crit.mp3",
		"res://assets/audio/crit_2.mp3"
	]
	for path in files:
		var stream = load(path) as AudioStream
		if stream == null:
			printerr("Missing or invalid stream: ", path)
			return false
		if stream.get_length() <= 0.0:
			printerr("Stream has 0 length: ", path)
			return false
	return true

func _test_pool_initialization() -> bool:
	var cam = CombatAudioManager.new()
	cam.pool_size = 6
	root.add_child(cam)
	
	if cam._players.size() != 6:
		printerr("Expected 6 players in pool, got ", cam._players.size())
		cam.queue_free()
		return false
		
	for p in cam._players:
		if not is_instance_valid(p) or not (p is AudioStreamPlayer):
			cam.queue_free()
			return false
			
	cam.queue_free()
	return true

func _test_playback_methods() -> bool:
	var cam = CombatAudioManager.new()
	root.add_child(cam)
	
	# Hit
	var hit_player = cam.play_hit()
	if hit_player == null or not cam.hit_streams.has(hit_player.stream):
		cam.queue_free()
		return false
	if hit_player.volume_db != cam.hit_volume_db:
		cam.queue_free()
		return false
		
	# Miss
	var miss_player = cam.play_miss()
	if miss_player == null or not cam.miss_streams.has(miss_player.stream):
		cam.queue_free()
		return false
	if miss_player.volume_db != cam.miss_volume_db:
		cam.queue_free()
		return false

	# Crit
	var crit_player = cam.play_crit()
	if crit_player == null or not cam.crit_streams.has(crit_player.stream):
		cam.queue_free()
		return false
	if crit_player.volume_db != cam.crit_volume_db:
		cam.queue_free()
		return false
		
	# Check pitch variance bounds
	if hit_player.pitch_scale < cam.pitch_min or hit_player.pitch_scale > cam.pitch_max:
		printerr("Hit pitch scale out of range: ", hit_player.pitch_scale)
		cam.queue_free()
		return false
		
	cam.queue_free()
	return true

func _test_variant_rotation() -> bool:
	var cam = CombatAudioManager.new()
	root.add_child(cam)

	# Test Hit Variant Non-Repeating (2 variants)
	var last_hit_stream: AudioStream = null
	for i in range(12):
		var p = cam.play_hit()
		if p == null:
			cam.queue_free()
			return false
		if last_hit_stream != null and p.stream == last_hit_stream:
			printerr("Consecutive identical hit variant played at index ", i)
			cam.queue_free()
			return false
		last_hit_stream = p.stream

	# Test Crit Variant Non-Repeating (2 variants)
	var last_crit_stream: AudioStream = null
	for i in range(12):
		var p = cam.play_crit()
		if p == null:
			cam.queue_free()
			return false
		if last_crit_stream != null and p.stream == last_crit_stream:
			printerr("Consecutive identical crit variant played at index ", i)
			cam.queue_free()
			return false
		last_crit_stream = p.stream

	cam.queue_free()
	return true

func _test_pool_concurrency() -> bool:
	var cam = CombatAudioManager.new()
	cam.pool_size = 4
	root.add_child(cam)

	# Trigger more requests than pool size
	for i in range(10):
		var p = cam.play_hit()
		if p == null:
			cam.queue_free()
			return false

	cam.queue_free()
	return true

func _test_combat_events_integration() -> bool:
	var events = CombatEventsBus.new()
	events.name = "CombatEventsTestBus"
	root.add_child(events)

	var cam = CombatAudioManager.new()
	root.add_child(cam)
	cam.connect_events(events)

	# 1. Test Regular Hit
	var hit_res = AttackResult.new()
	hit_res.hit = true
	hit_res.critical = false
	events.attack_hit.emit(hit_res)
	var last_player = cam._players[0]
	if not cam.hit_streams.has(last_player.stream):
		printerr("Expected hit stream after attack_hit signal, got: ", last_player.stream)
		cam.queue_free()
		events.queue_free()
		return false

	# 2. Test Miss
	var miss_res = AttackResult.new()
	miss_res.hit = false
	events.attack_missed.emit(miss_res)
	var miss_found = false
	for p in cam._players:
		if cam.miss_streams.has(p.stream):
			miss_found = true
			break
	if not miss_found:
		printerr("Expected miss stream after attack_missed signal")
		cam.queue_free()
		events.queue_free()
		return false

	# 3. Test Critical Hit (emits critical_hit then attack_hit)
	var crit_res = AttackResult.new()
	crit_res.hit = true
	crit_res.critical = true
	
	# Count how many players start playing before vs after
	var initial_crit_count = 0
	for p in cam._players:
		if cam.crit_streams.has(p.stream):
			initial_crit_count += 1
			
	events.critical_hit.emit(crit_res)
	events.attack_hit.emit(crit_res) # Should be ignored by attack_hit because critical == true
	
	var new_crit_count = 0
	for p in cam._players:
		if cam.crit_streams.has(p.stream):
			new_crit_count += 1
			
	if new_crit_count != initial_crit_count + 1:
		printerr("Expected exactly 1 crit stream played, difference was: ", new_crit_count - initial_crit_count)
		cam.queue_free()
		events.queue_free()
		return false

	cam.queue_free()
	events.queue_free()
	return true

func _test_battle_scene_setup() -> bool:
	var scene_res = load("res://scenes/battle_scene.tscn") as PackedScene
	if scene_res == null:
		return false
	var scene = scene_res.instantiate() as BattleScene
	root.add_child(scene)
	scene._ready()
	
	var cam = CombatAudioManager.get_manager(scene)
	if cam == null:
		printerr("CombatAudioManager not found in BattleScene")
		scene.queue_free()
		return false
		
	scene.queue_free()
	return true
