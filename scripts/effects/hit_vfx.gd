class_name HitVFX
extends AnimatedSprite3D

## 3D Billboard Animated Sprite effect for combat attacks and impacts.
## Plays an animation from data/vfx.tres at a world location and auto-frees.

const VFX_RESOURCE = preload("res://data/vfx.tres")

static func spawn(
	parent: Node,
	world_pos: Vector3,
	anim_name: StringName,
	facing_flip: bool = false,
	is_critical: bool = false,
	scale_mult: float = 1.0
) -> HitVFX:
	if parent == null:
		return null
		
	var vfx = new()
	vfx.name = "HitVFX_%s" % anim_name
	vfx.sprite_frames = VFX_RESOURCE
	vfx.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	vfx.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	vfx.shaded = false
	vfx.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	vfx.pixel_size = 0.032
	vfx.flip_h = facing_flip
	
	var base_scale = 1.35 if is_critical else 1.0
	vfx.scale = Vector3.ONE * base_scale * scale_mult
	
	if is_critical:
		vfx.modulate = Color(1.35, 1.2, 0.7, 1.0)
	else:
		vfx.modulate = Color(1.15, 1.15, 1.15, 1.0)
		
	# Add to tree
	parent.add_child(vfx)
	vfx.position = world_pos
	
	# Verify animation exists
	if vfx.sprite_frames != null and vfx.sprite_frames.has_animation(anim_name):
		vfx.play(anim_name)
	elif vfx.sprite_frames != null and vfx.sprite_frames.has_animation(&"slash"):
		vfx.play(&"slash")
		
	vfx.animation_finished.connect(vfx.queue_free)
	
	# Safety cleanup timer in case animation is stopped or blocked
	if vfx.is_inside_tree():
		var timer = vfx.get_tree().create_timer(0.55)
		timer.timeout.connect(vfx.queue_free)
	else:
		vfx.tree_entered.connect(func():
			if is_instance_valid(vfx) and vfx.is_inside_tree():
				var timer = vfx.get_tree().create_timer(0.55)
				timer.timeout.connect(vfx.queue_free)
		, Object.CONNECT_ONE_SHOT)
	
	return vfx
