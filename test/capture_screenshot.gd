extends SceneTree

var frames: int = 0
var battle_scene: BattleScene = null

func _init() -> void:
	var scene_res = load("res://scenes/battle_scene.tscn") as PackedScene
	battle_scene = scene_res.instantiate() as BattleScene
	root.add_child(battle_scene)

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 10:
		var image = root.get_texture().get_image()
		var out_path = "C:/Users/A8/.gemini/antigravity/brain/a4db6551-ade4-465d-ac02-143c12074137/party_hud_verified.png"
		var err = image.save_png(out_path)
		if err == OK:
			print("Screenshot successfully saved to: ", out_path)
		else:
			printerr("Failed to save screenshot: ", err)
		quit(0)
		return true
	return false
