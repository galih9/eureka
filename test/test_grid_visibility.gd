extends SceneTree

func _init() -> void:
	print("--- Testing FormationGridVisual Visibility & Lifecycle ---")
	var scene_res = load("res://scenes/battle_scene.tscn") as PackedScene
	assert(scene_res != null, "Failed to load battle_scene.tscn")
	
	var scene: BattleScene = scene_res.instantiate() as BattleScene
	root.add_child(scene)
	
	var grid_visual: FormationGridVisual = scene.get_node_or_null("FormationGridVisual") as FormationGridVisual
	assert(grid_visual != null, "FormationGridVisual node must exist in BattleScene")
	
	# 1. Verify Grid is hidden by default upon battle load
	assert(grid_visual.visible == false, "Grid visual must be HIDDEN by default in battle")
	assert(grid_visual.is_move_targeting == false, "Grid visual must NOT be in move targeting state initially")
	print("  [PASSED] Grid is hidden by default")
	
	# 2. Simulate start_move_selection
	var bm = scene.battle_manager
	var form = bm.formation_system
	var valid_slots = [1, 2, 5]
	grid_visual.start_move_selection(form, valid_slots)
	
	assert(grid_visual.visible == true, "Grid visual must become VISIBLE when move selection starts")
	assert(grid_visual.is_move_targeting == true, "is_move_targeting must be true")
	assert(grid_visual.valid_slot_indices.size() == 3, "Valid slots properly tracked")
	print("  [PASSED] Grid is visible during move selection")
	
	# 3. Simulate cancel_move_selection
	grid_visual.cancel_move_selection()
	assert(grid_visual.visible == false, "Grid visual must HIDE on cancel_move_selection")
	assert(grid_visual.is_move_targeting == false, "is_move_targeting must be false on cancel")
	print("  [PASSED] Grid hides cleanly on cancel")
	
	# 4. Test BattleUI move selection trigger and cancel
	var ui = scene.battle_ui
	var move_action_def = bm.default_move_action
	ui._on_move_selection_started(move_action_def, [0, 4, 8])
	assert(grid_visual.visible == true, "BattleUI move selection started makes grid visible")
	assert(ui.is_moving == true, "BattleUI is_moving set to true")
	
	# Simulate slot click
	ui._on_grid_slot_clicked(4)
	assert(grid_visual.visible == false, "Clicking slot immediately hides grid visual")
	assert(ui.is_moving == false, "BattleUI is_moving resets to false")
	print("  [PASSED] BattleUI flow opens and closes grid visual seamlessly")
	
	print("--- ALL FORMATION GRID VISUAL TESTS PASSED! ---")
	quit(0)
