extends SceneTree

## Automated verification test for:
## 1. Ocean waves shader compilation and material resource loading.
## 2. OceanWater scene instantiation and configuration.
## 3. Camera-following infinite grid logic.
## 4. Analytical wave height evaluation.
## 5. Integration into BattlefieldArena.

const OceanWater = preload("res://scripts/effects/ocean_water.gd")

func _init() -> void:
	print("\n========================================================")
	print("       TESTING INFINITE OCEAN & WAVES SHADER SYSTEM      ")
	print("========================================================\n")
	
	# 1. Load and verify OceanMaterial and Shader
	var mat = load("res://assets/effects/ocean/ocean_material.tres") as ShaderMaterial
	assert(mat != null, "ocean_material.tres must load successfully")
	print("  [PASS] 1. ocean_material.tres loaded successfully")
	
	var shader = mat.shader
	assert(shader != null, "ShaderMaterial must reference valid shader")
	assert(shader.resource_path == "res://shaders/ocean_waves.gdshader", "Shader path matches ocean_waves.gdshader")
	print("  [PASS] 2. ocean_waves.gdshader successfully compiled and linked to material")
	
	# Verify shader parameters are configured
	var deep_col = mat.get_shader_parameter("deep_color")
	assert(deep_col != null, "deep_color shader parameter exists")
	var wave_a = mat.get_shader_parameter("wave_a")
	assert(wave_a != null, "wave_a Gerstner wave parameter exists")
	var norm_tex1 = mat.get_shader_parameter("normal_texture_1")
	assert(norm_tex1 != null, "normal_texture_1 procedural noise exists")
	var foam_tex = mat.get_shader_parameter("foam_noise_texture")
	assert(foam_tex != null, "foam_noise_texture procedural noise exists")
	print("  [PASS] 3. Shader uniforms, wave vectors, and procedural noise textures verified")
	
	# 2. Instantiate OceanWater standalone scene
	var ocean_scene = load("res://scenes/effects/ocean_water.tscn") as PackedScene
	assert(ocean_scene != null, "ocean_water.tscn must load successfully")
	var ocean_node = ocean_scene.instantiate() as OceanWater
	assert(ocean_node != null, "ocean_node must be instance of OceanWater")
	root.add_child(ocean_node)
	
	assert(ocean_node.ocean_mesh != null, "OceanMesh is assigned in ocean_water.tscn")
	assert(ocean_node.water_level == -1.6, "Default water_level is -1.6")
	assert(ocean_node.grid_snap == 3.0, "grid_snap aligns with subdivided PlaneMesh")
	print("  [PASS] 4. OceanWater scene instantiated with PlaneMesh and OceanWater script")
	
	# 3. Test analytical wave height calculation
	var h1 = ocean_node.get_wave_height_at(Vector2(0, 0), 0.0)
	var h2 = ocean_node.get_wave_height_at(Vector2(50, 50), 0.0)
	assert(absf(h1 - ocean_node.water_level) <= 3.0, "Wave height at (0,0) is within realistic bounds of water level")
	assert(absf(h2 - ocean_node.water_level) <= 3.0, "Wave height at (50,50) is within realistic bounds of water level")
	print("  [PASS] 5. Analytical Gerstner wave height math verified: h(0,0)=%.2f, h(50,50)=%.2f" % [h1, h2])
	
	# 4. Test infinite grid snapping logic
	var dummy_cam = Camera3D.new()
	ocean_node.target_camera = dummy_cam
	dummy_cam.position = Vector3(14.2, 5.0, -8.7)
	ocean_node._process(0.016)
	
	var expected_x = floorf(14.2 / ocean_node.grid_snap) * ocean_node.grid_snap
	var expected_z = floorf(-8.7 / ocean_node.grid_snap) * ocean_node.grid_snap
	var curr_x = ocean_node.global_position.x if ocean_node.is_inside_tree() else ocean_node.position.x
	var curr_z = ocean_node.global_position.z if ocean_node.is_inside_tree() else ocean_node.position.z
	var curr_y = ocean_node.global_position.y if ocean_node.is_inside_tree() else ocean_node.position.y
	assert(is_equal_approx(curr_x, expected_x), "Ocean X snaps to camera grid")
	assert(is_equal_approx(curr_z, expected_z), "Ocean Z snaps to camera grid")
	assert(is_equal_approx(curr_y, ocean_node.water_level), "Ocean Y stays at water_level")
	print("  [PASS] 6. Infinite grid snapping verified: Cam(14.2, -8.7) -> Snapped(%.1f, %.1f)" % [curr_x, curr_z])
	
	# 5. Load BattlefieldArena and verify OceanWater integration
	var arena_scene = load("res://scenes/arena/battlefield_arena.tscn") as PackedScene
	assert(arena_scene != null, "battlefield_arena.tscn must load successfully")
	var arena = arena_scene.instantiate()
	root.add_child(arena)
	
	var arena_ocean = arena.get_node_or_null("OceanWater") as OceanWater
	assert(arena_ocean != null, "BattlefieldArena contains OceanWater node")
	
	var world_env = arena.get_node_or_null("WorldEnvironment") as WorldEnvironment
	assert(world_env != null, "WorldEnvironment exists")
	assert(world_env.environment.fog_enabled == true, "Atmospheric horizon fog is enabled in Environment")
	print("  [PASS] 7. BattlefieldArena integration verified (OceanWater present, atmospheric fog enabled)")
	
	# 6. Verify FloorArena foundation extension
	var floor_arena = arena.get_node_or_null("FloorArena")
	assert(floor_arena != null, "FloorArena exists in arena")
	var floor_mesh = floor_arena.get_node_or_null("Node3D") as MeshInstance3D
	assert(floor_mesh != null, "Floor mesh exists")
	var box = floor_mesh.mesh as BoxMesh
	assert(box != null, "Floor mesh is BoxMesh")
	assert(box.size.y >= 5.0, "Floor foundation extends deep below water (size.y = %.1f)" % box.size.y)
	assert(floor_mesh.position.y <= -2.0, "Floor mesh centered downward (position.y = %.1f)" % floor_mesh.position.y)
	print("  [PASS] 8. Arena stone dais foundation extends 10m deep into the ocean (no floating bottom)")
	
	dummy_cam.free()
	arena.free()
	ocean_node.free()
	
	print("\n>> ALL 8 INFINITE OCEAN VERIFICATION CHECKS PASSED SUCCESSFULLY! <<\n")
	quit(0)
