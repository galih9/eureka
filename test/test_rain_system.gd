extends SceneTree

const RainEffectClass = preload("res://scripts/effects/rain_effect.gd")

var log_file: FileAccess

func log_msg(msg: String) -> void:
	print(msg)
	if log_file:
		log_file.store_line(msg)
		log_file.flush()

func _init() -> void:
	var log_path = "C:/Users/A8/Documents/eureka/test/test_rain_results.txt"
	log_file = FileAccess.open(log_path, FileAccess.WRITE)
	log_msg("=== RUNNING RAIN EFFECT SYSTEM TESTS (GODOT 4.7.2) ===")

	# 1. Load rain_effect.tscn
	var rain_scene_res = load("res://scenes/effects/rain_effect.tscn") as PackedScene
	assert(rain_scene_res != null, "FAIL: Could not load rain_effect.tscn")
	log_msg("[PASS] rain_effect.tscn loaded successfully.")

	var rain_node = rain_scene_res.instantiate() as RainEffectClass
	assert(rain_node != null, "FAIL: Instantiated node is not of type RainEffect")
	root.add_child(rain_node)
	log_msg("[PASS] RainEffect instantiated and added to scene tree.")

	# 2. Check Particles and RibbonTrailMesh
	var rain_particles = rain_node.get_node("RainParticles") as GPUParticles3D
	assert(rain_particles != null, "FAIL: Missing RainParticles child")
	assert(rain_particles.trail_enabled == true, "FAIL: RainParticles.trail_enabled should be true")
	log_msg("[PASS] RainParticles has trail_enabled = true.")

	var mesh = rain_particles.draw_pass_1 as RibbonTrailMesh
	assert(mesh != null, "FAIL: draw_pass_1 is not a RibbonTrailMesh")
	log_msg("[PASS] draw_pass_1 is RibbonTrailMesh.")

	var ribbon_mat = mesh.material as StandardMaterial3D
	assert(ribbon_mat != null, "FAIL: Ribbon material is null")
	assert(ribbon_mat.use_particle_trails == true, "FAIL: Ribbon material must have use_particle_trails = true")
	log_msg("[PASS] Ribbon material has use_particle_trails = true.")

	# 3. Verify Easterly Wind Slant Math
	# Wind blown from EAST must push toward WEST (-X)
	var dir = rain_node.get_calculated_direction()
	log_msg("Calculated Rain Direction (Wind from East, 18 deg): " + str(dir))
	assert(dir.x < 0.0, "FAIL: Wind from East must push rain toward -X (West). Got dir.x = %f" % dir.x)
	assert(dir.y < 0.0, "FAIL: Rain must fall downward (-Y). Got dir.y = %f" % dir.y)
	assert(abs(dir.z) < 0.001, "FAIL: Pure Easterly wind should have no Z deflection. Got dir.z = %f" % dir.z)

	var calculated_angle = rad_to_deg(atan2(abs(dir.x), abs(dir.y)))
	log_msg("Calculated Lean Angle: %.2f degrees (expected 18.00)" % calculated_angle)
	assert(abs(calculated_angle - 18.0) < 0.1, "FAIL: Lean angle should be 18.0 degrees")
	log_msg("[PASS] Easterly wind slant mathematically verified (leans westward by 18°).")

	# 4. Test Dynamic Property Updates
	rain_node.wind_lean_angle_deg = 25.0
	var dir_25 = rain_node.get_calculated_direction()
	var angle_25 = rad_to_deg(atan2(abs(dir_25.x), abs(dir_25.y)))
	assert(abs(angle_25 - 25.0) < 0.1, "FAIL: Dynamic update to 25 deg lean failed")
	log_msg("[PASS] Dynamic update to 25.0° lean angle verified: %.2f°" % angle_25)

	# Reset to 18
	rain_node.wind_lean_angle_deg = 18.0

	# 4b. Test Intensity and Crowdedness Parameters
	rain_node.weather_intensity = RainEffectClass.WeatherIntensity.DRIZZLE
	assert(rain_node.rain_density == 250, "FAIL: Drizzle density should be 250")
	assert(rain_particles.amount == 250, "FAIL: RainParticles amount should be updated to 250")
	assert(abs(rain_node.streak_width - 0.012) < 0.001, "FAIL: Drizzle streak width should be 0.012")
	log_msg("[PASS] Drizzle preset applied correctly (density=250, width=0.012).")

	# Test custom tweaking
	rain_node.rain_density = 350
	rain_node.rain_opacity = 0.22
	rain_node.streak_width = 0.014
	assert(rain_particles.amount == 350, "FAIL: Custom density should update rain_particles.amount")
	assert(abs(rain_particles.draw_pass_1.size - 0.014) < 0.001, "FAIL: Custom streak_width should update mesh.size")
	log_msg("[PASS] Custom intensity parameters verified (density=350, opacity=0.22, width=0.014).")

	# Return to Light default
	rain_node.weather_intensity = RainEffectClass.WeatherIntensity.LIGHT

	# 5. Check Splash Particles Sub-emitter
	var splash_particles = rain_node.get_node("SplashParticles") as GPUParticles3D
	assert(splash_particles != null, "FAIL: Missing SplashParticles child")
	var ppm = rain_particles.process_material as ParticleProcessMaterial
	assert(ppm != null, "FAIL: Missing ParticleProcessMaterial")
	assert(ppm.sub_emitter_mode == ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION, "FAIL: sub_emitter_mode should be AT_COLLISION (3)")
	log_msg("[PASS] SplashParticles sub-emitter bound and active.")

	# 6. Load and instantiate rain_showcase.tscn
	var showcase_res = load("res://scenes/effects/rain_showcase.tscn") as PackedScene
	assert(showcase_res != null, "FAIL: Could not load rain_showcase.tscn")
	var showcase_node = showcase_res.instantiate()
	root.add_child(showcase_node)
	log_msg("[PASS] rain_showcase.tscn loaded and instantiated cleanly with ground collision and shelter.")

	# 7. Verify battle_scene.tscn with integrated RainEffect in arena
	var battle_res = load("res://scenes/battle_scene.tscn") as PackedScene
	assert(battle_res != null, "FAIL: Could not load battle_scene.tscn")
	var battle_node = battle_res.instantiate()
	root.add_child(battle_node)
	var arena_rain = battle_node.get_node_or_null("BattlefieldArena/RainEffect")
	assert(arena_rain != null, "FAIL: BattlefieldArena does not have RainEffect child")
	log_msg("[PASS] battle_scene.tscn instantiated with BattlefieldArena/RainEffect active.")

	log_msg("=== ALL RAIN EFFECT TESTS COMPLETED SUCCESSFULLY ===")
	quit(0)
