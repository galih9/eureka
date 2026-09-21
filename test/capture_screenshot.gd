extends SceneTree

var frames: int = 0
var battle_scene: BattleScene = null

func _init() -> void:
	var scene_res = load("res://scenes/battle_scene.tscn") as PackedScene
	battle_scene = scene_res.instantiate() as BattleScene
	root.add_child(battle_scene)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 15:
		var image = root.get_texture().get_image()
		var out_path = "C:/Users/A8/.gemini/antigravity/brain/58199fe4-99e3-4615-be80-9dd3bfb0df48/semi_3d_battlefield.png"
		var err = image.save_png(out_path)
		if err == OK:
			print("Screenshot successfully saved to: ", out_path)
		else:
			printerr("Failed to save screenshot: ", err)
		quit(0)
		return true
	return false
