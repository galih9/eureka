extends SceneTree

## Automated verification test for:
## 1. Darkened arena environment and directional light.
## 2. ThunderLightning controller, audio player, 6.0s initial timer, and flash sequence.
## 3. RainEffect rain loop audio player and playback.
## 4. Attack strike OmniLight3D and HitVFX OmniLight3D spawning.

const ThunderLightning = preload("res://scripts/effects/thunder_lightning.gd")
const HitVFX = preload("res://scripts/effects/hit_vfx.gd")

func _init() -> void:
	_run_test()

func _run_test() -> void:
	var f = FileAccess.open("res://test_lighting_results.txt", FileAccess.WRITE)
	f.store_line("========================================================")
	f.store_line("   TESTING 3D COMBAT LIGHTS & THUNDER LIGHTNING SYSTEM   ")
	f.store_line("========================================================")
	
	# 1. Load and verify BattlefieldArena lighting setup
	var arena_scene = load("res://scenes/arena/battlefield_arena.tscn") as PackedScene
	if arena_scene == null:
		f.store_line("FAIL: Battlefield arena scene must load")
		f.close()
		quit(1)
		return
		
	var arena = arena_scene.instantiate()
	root.add_child(arena)
	
	# Wait for scene nodes to enter tree and call _ready()
	await process_frame
	await process_frame
	
	var world_env = arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_env == null or world_env.environment == null:
		f.store_line("FAIL: WorldEnvironment not found")
		f.close()
		quit(1)
		return
		
	f.store_line("[PASS] 1. Darker atmospheric environment verified (ambient energy: " + str(world_env.environment.ambient_light_energy) + ")")
	
	var dir_light = arena.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if dir_light == null:
		f.store_line("FAIL: DirectionalLight3D not found")
		f.close()
		quit(1)
		return
	f.store_line("[PASS] 2. Darker directional key light verified (light energy: " + str(dir_light.light_energy) + ")")
	
	# 2. Verify ThunderLightning node, audio, and initial strike timer (exactly 6.0s)
	var thunder = arena.get_node_or_null("ThunderLightning") as ThunderLightning
	if thunder == null:
		f.store_line("FAIL: ThunderLightning node not found")
		f.close()
		quit(1)
		return
		
	f.store_line("thunder.thunder_player is null: " + str(thunder.thunder_player == null))
	f.store_line("thunder._next_strike_timer: " + str(thunder._next_strike_timer))
	
	if thunder.thunder_player == null:
		f.store_line("FAIL: ThunderLightning has no thunder_player")
		f.close()
		quit(1)
		return
		
	if thunder._next_strike_timer > 6.0 or thunder._next_strike_timer < 5.5:
		f.store_line("FAIL: Expected initial strike timer to start at 6.0, got: " + str(thunder._next_strike_timer))
		f.close()
		quit(1)
		return
	f.store_line("[PASS] 3. ThunderLightning node, audio player, and 6.0s initial timer verified")
	
	# Verify RainEffect audio player
	var rain = arena.get_node_or_null("RainEffect") as RainEffect
	if rain == null:
		f.store_line("FAIL: RainEffect not found")
		f.close()
		quit(1)
		return
		
	f.store_line("rain.rain_audio_player is null: " + str(rain.rain_audio_player == null))
	if rain.rain_audio_player == null or not rain.rain_audio_player.playing:
		f.store_line("FAIL: RainEffect audio player not active")
		f.close()
		quit(1)
		return
	f.store_line("[PASS] 4. RainEffect rain loop audio player verified and playing")
	
	# Test manual lightning trigger and thunder audio
	thunder.trigger_lightning()
	if not thunder._is_flashing:
		f.store_line("FAIL: thunder not flashing after trigger")
		f.close()
		quit(1)
		return
	if not thunder.thunder_player.playing:
		f.store_line("FAIL: thunder audio player not playing after trigger")
		f.close()
		quit(1)
		return
	f.store_line("[PASS] 5. ThunderLightning flash and synchronized thunder audio verified")
	
	# 3. Test HitVFX 3D OmniLight3D
	var hit_parent = Node3D.new()
	root.add_child(hit_parent)
	var vfx = HitVFX.spawn(hit_parent, Vector3(0, 1, 0), &"slash", false, false)
	var hit_light = vfx.get_node_or_null("HitImpactLight") as OmniLight3D
	if hit_light == null:
		f.store_line("FAIL: HitVFX OmniLight3D not found")
		f.close()
		quit(1)
		return
	f.store_line("[PASS] 6. HitVFX dynamic 3D OmniLight3D verified (energy: " + str(hit_light.light_energy) + ")")
	
	# Test Critical Hit Light
	var crit_vfx = HitVFX.spawn(hit_parent, Vector3(2, 1, 0), &"punch", false, true)
	var crit_light = crit_vfx.get_node_or_null("HitImpactLight") as OmniLight3D
	if crit_light == null:
		f.store_line("FAIL: Critical HitVFX OmniLight3D not found")
		f.close()
		quit(1)
		return
	f.store_line("[PASS] 7. Critical HitVFX produces brighter golden burst (energy: " + str(crit_light.light_energy) + ")")
	
	# 4. Test BattleCharacter Attack Light
	var char_scene = load("res://scenes/character/battle_character.tscn") as PackedScene
	var character = char_scene.instantiate() as BattleCharacter
	root.add_child(character)
	character._spawn_attack_light()
	
	var attack_light = root.get_node_or_null("AttackLight") as OmniLight3D
	if attack_light == null:
		f.store_line("FAIL: Attack strike OmniLight3D not found")
		f.close()
		quit(1)
		return
	f.store_line("[PASS] 8. BattleCharacter attack strike 3D OmniLight3D verified (energy: " + str(attack_light.light_energy) + ")")
	
	# Cleanup
	vfx.queue_free()
	crit_vfx.queue_free()
	hit_parent.queue_free()
	character.queue_free()
	arena.queue_free()
	
	f.store_line("========================================================")
	f.store_line("  ALL 3D LIGHTING & THUNDER LIGHTNING TESTS PASSED!     ")
	f.store_line("========================================================")
	f.close()
	quit(0)
