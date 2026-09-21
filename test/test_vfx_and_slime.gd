extends SceneTree

const HitVFX = preload("res://scripts/effects/hit_vfx.gd")

func _init() -> void:
	print("==================================================")
	print("TESTING VFX ANIMATIONS & SLIME SPRITE INTEGRATION")
	print("==================================================")
	
	# Test 1: Slime Resource has custom SpriteFrames
	var slime_def: CharacterDefinition = load("res://data/enemies/slime.tres")
	assert(slime_def != null, "slime.tres should load successfully")
	assert(slime_def.sprite_frames != null, "slime_def.sprite_frames should not be null")
	print("  [PASS] 1. slime.tres has sprite_frames assigned")
	
	# Test 2: Slime SpriteFrames contains idle, move, attack, hurt
	var sf: SpriteFrames = slime_def.sprite_frames
	assert(sf.has_animation(&"idle"), "Slime must have 'idle' animation")
	assert(sf.has_animation(&"move"), "Slime must have 'move' animation")
	assert(sf.has_animation(&"attack"), "Slime must have 'attack' animation")
	assert(sf.has_animation(&"hurt"), "Slime must have 'hurt' animation")
	assert(sf.get_animation_loop(&"attack") == false, "Slime 'attack' should not loop")
	assert(sf.get_animation_loop(&"hurt") == false, "Slime 'hurt' should not loop")
	assert(sf.get_animation_loop(&"idle") == true, "Slime 'idle' should loop")
	print("  [PASS] 2. Slime animations (idle, move, attack, hurt) verified with proper loop settings")
	
	# Test 3: VFX Resource contains all 5 animations with loop == false
	var vfx_res: SpriteFrames = load("res://data/vfx.tres")
	assert(vfx_res != null, "vfx.tres should load successfully")
	var expected_vfx = [&"punch", &"slash", &"slash_h", &"slash_small", &"slash_v"]
	for anim in expected_vfx:
		assert(vfx_res.has_animation(anim), "vfx.tres missing animation: %s" % anim)
		assert(vfx_res.get_animation_loop(anim) == false, "VFX anim %s must not loop" % anim)
	print("  [PASS] 3. vfx.tres verified with all 5 one-shot animations")
	
	# Test 4: BattleCharacter instantiation with Slime definition
	var char_scene: PackedScene = load("res://scenes/character/battle_character.tscn")
	var slime_char: BattleCharacter = char_scene.instantiate()
	slime_char.character_definition = slime_def
	root.add_child(slime_char)
	if slime_char.animated_sprite == null:
		slime_char.animated_sprite = slime_char.get_node("Visual/AnimatedSprite3D")
	slime_char.initialize(slime_def)
	
	assert(slime_char.animated_sprite != null, "AnimatedSprite3D must exist")
	assert(slime_char.animated_sprite.sprite_frames == sf, "AnimatedSprite3D must use slime SpriteFrames")
	assert(slime_char.base_modulate == Color.WHITE, "Slime should not be tinted red; base_modulate should be WHITE")
	assert(slime_char.animated_sprite.position.y > 0.6, "Slime offset should elevate sprite properly above ground")
	
	slime_char.play_move()
	assert(slime_char.animated_sprite.animation == &"move", "Slime should play 'move'")
	slime_char.play_attack()
	assert(slime_char.animated_sprite.animation == &"attack", "Slime should play 'attack'")
	slime_char.play_hit_anim()
	assert(slime_char.animated_sprite.animation == &"hurt", "Slime should play 'hurt' on hit")
	slime_char.play_idle()
	assert(slime_char.animated_sprite.animation == &"idle", "Slime should play 'idle'")
	print("  [PASS] 4. Slime BattleCharacter visual setup, animations, and ground offset verified")
	
	# Test 5: HitVFX Spawning
	var test_parent = Node3D.new()
	root.add_child(test_parent)
	var spawned_vfx = HitVFX.spawn(test_parent, Vector3(1, 2, 3), &"punch", false, true)
	assert(spawned_vfx != null, "HitVFX.spawn should return an instance")
	assert(spawned_vfx.get_parent() == test_parent, "HitVFX should be attached to parent")
	assert(spawned_vfx.position == Vector3(1, 2, 3), "HitVFX should be placed at target location")
	assert(spawned_vfx.animation == &"punch", "HitVFX should play 'punch'")
	assert(spawned_vfx.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "HitVFX should billboard")
	print("  [PASS] 5. HitVFX 3D billboard spawning, position, and animation verified")
	
	# Test 6: ActionDefinition VFX mapping
	var slam_skill: SkillDefinition = load("res://data/skills/slime_basic_attack.tres")
	assert(slam_skill.get_vfx_name(slime_char) == &"punch", "Slime Slam should produce 'punch' VFX")
	var ingrid_skill: SkillDefinition = load("res://data/skills/ingrid_basic_attack.tres")
	assert(ingrid_skill.get_vfx_name() == &"slash", "Fast Slash should produce 'slash' VFX")
	var quick_skill: SkillDefinition = load("res://data/skills/quick_slash.tres")
	assert(quick_skill.get_vfx_name() == &"slash_small", "Quick Slash should produce 'slash_small' VFX")
	var heavy_skill: SkillDefinition = load("res://data/skills/heavy_smash.tres")
	assert(heavy_skill.get_vfx_name() == &"slash_v", "Heavy Smash should produce 'slash_v' VFX")
	var aoe_skill: SkillDefinition = load("res://data/skills/slug_area_attack.tres")
	assert(aoe_skill.get_vfx_name() == &"slash_h", "Area Acid Burst should produce 'slash_h' VFX")
	print("  [PASS] 6. ActionDefinition / SkillDefinition VFX animation resolution verified")
	
	# Cleanup test nodes
	slime_char.queue_free()
	test_parent.queue_free()
	
	print("==================================================")
	print("ALL VFX & SLIME SPRITE TESTS PASSED SUCCESSFULLY!")
	print("==================================================")
	quit(0)
