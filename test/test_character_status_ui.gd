extends SceneTree

var frame: int = 0
var scene: Node = null

func log_msg(msg: String) -> void:
	print(msg)

func _init() -> void:
	log_msg("=== INITIALIZING CHARACTER STATUS UI TEST ===")
	var scene_res = load("res://scenes/battle_scene.tscn") as PackedScene
	if scene_res == null:
		log_msg("FAIL: Could not load battle_scene.tscn")
		quit(1)
		return
	scene = scene_res.instantiate()
	root.add_child(scene)

func _process(_delta: float) -> bool:
	frame += 1
	if frame < 3:
		return false
		
	log_msg("=== RUNNING CHARACTER STATUS UI ASSERTIONS ===")
	var battle_ui = scene.get_node_or_null("BattleUI")
	assert(battle_ui != null, "BattleUI exists")
	
	var status_ui = battle_ui.get_node_or_null("CharacterStatusLayer/CharacterStatusUI") as CharacterStatusUI
	assert(status_ui != null, "CharacterStatusUI exists")
	
	var party_container = status_ui.party_cards_container
	assert(party_container != null, "PartyContainer exists")
	
	# TEST 1: Exactly 3 party member columns exist
	assert(party_container.get_child_count() == 3, "Expected 3 party member columns, got %d" % party_container.get_child_count())
	log_msg("TEST 1 PASSED: Exactly 3 party member columns exist.")
	
	# TEST 2: Sharp corners & Banner assets for each character
	var expected_banners = [
		{"name": "Roy", "banner_path": "male.png"},
		{"name": "Ingrid", "banner_path": "female.png"},
		{"name": "Jacob", "banner_path": "male.png"}
	]
	
	for i in range(3):
		var col = party_container.get_child(i) as VBoxContainer
		assert(col != null, "Column %d is VBoxContainer" % i)
		assert(col.alignment == BoxContainer.ALIGNMENT_END, "Column %d is bottom-aligned" % i)
		
		var status_container = col.get_node_or_null("StatusContainer") as VBoxContainer
		assert(status_container != null, "Column %d has StatusContainer" % i)
		
		# Normal state check: 0 status indicators should be displayed!
		assert(status_container.get_child_count() == 0, "Normal state: 0 status indicators displayed for col %d" % i)
		
		var card_box = col.get_node_or_null("CardBox") as PanelContainer
		assert(card_box != null, "Column %d has CardBox" % i)
		
		# Verify CardBox sharp corners (corner_radius == 0)
		var card_style = card_box.get_theme_stylebox("panel") as StyleBoxFlat
		assert(card_style != null, "CardBox has StyleBoxFlat")
		assert(card_style.corner_radius_top_left == 0, "CardBox sharp top-left")
		assert(card_style.corner_radius_top_right == 0, "CardBox sharp top-right")
		assert(card_style.corner_radius_bottom_left == 0, "CardBox sharp bottom-left")
		assert(card_style.corner_radius_bottom_right == 0, "CardBox sharp bottom-right")
		
		# Verify Banner Frame & Texture
		var banner_frame = card_box.find_child("BannerFrame", true, false) as PanelContainer
		assert(banner_frame != null, "BannerFrame exists in card %d" % i)
		var b_style = banner_frame.get_theme_stylebox("panel") as StyleBoxFlat
		assert(b_style.corner_radius_top_left == 0, "BannerFrame sharp corners")
		
		var banner_tex = banner_frame.find_child("BannerTexture", true, false) as TextureRect
		assert(banner_tex != null, "BannerTexture exists in card %d" % i)
		assert(banner_tex.texture != null, "BannerTexture has valid texture in card %d" % i)
		var tex_path = banner_tex.texture.resource_path
		assert(expected_banners[i].banner_path in tex_path, "Expected %s in %s for %s" % [expected_banners[i].banner_path, tex_path, expected_banners[i].name])
		
		# Verify HP Bar sharp corners
		var hp_bar = card_box.find_child("HPBar", true, false) as ProgressBar
		assert(hp_bar != null, "HPBar exists in card %d" % i)
		var hp_fill = hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
		var hp_bg = hp_bar.get_theme_stylebox("background") as StyleBoxFlat
		assert(hp_fill.corner_radius_top_left == 0, "HP fill sharp corners")
		assert(hp_bg.corner_radius_top_left == 0, "HP bg sharp corners")
		
		# Verify MP Bar sharp corners
		var mp_bar = card_box.find_child("MPBar", true, false) as ProgressBar
		assert(mp_bar != null, "MPBar exists in card %d" % i)
		var mp_fill = mp_bar.get_theme_stylebox("fill") as StyleBoxFlat
		var mp_bg = mp_bar.get_theme_stylebox("background") as StyleBoxFlat
		assert(mp_fill.corner_radius_top_left == 0, "MP fill sharp corners")
		assert(mp_bg.corner_radius_top_left == 0, "MP bg sharp corners")
		
	log_msg("TEST 2 PASSED: Sharp corners & correct male/female eye-shot banners verified for all characters.")
	log_msg("TEST 3 PASSED: In normal state, no status indicator is shown for any character.")
	
	# TEST 4: Simplified Status Indicators (e.g. "Stunned")
	var roy = status_ui.party_members[0] as BattleCharacter
	var stun_def = load("res://data/status_effects/stun.tres") as StatusDefinition
	assert(stun_def != null, "Stun definition loaded")
	
	# Apply stun to Roy
	var stun_inst = StatusSystem.apply_status(roy, stun_def, "test")
	assert(stun_inst != null, "Stun instance created")
	status_ui.refresh_party_cards()
	
	var roy_col = party_container.get_child(0) as VBoxContainer
	var roy_status_container = roy_col.get_node_or_null("StatusContainer") as VBoxContainer
	assert(roy_status_container.get_child_count() == 1, "Roy should have 1 status indicator")
	
	var status_box1 = roy_status_container.get_child(0) as PanelContainer
	var status_style1 = status_box1.get_theme_stylebox("panel") as StyleBoxFlat
	assert(status_style1.corner_radius_top_left == 0, "StatusBox has sharp corners")
	var status_lbl1 = status_box1.get_child(0) as Label
	assert(status_lbl1.text == "Stunned", "Status text simplified to 'Stunned', got '%s'" % status_lbl1.text)
	log_msg("TEST 4 PASSED: 'Stunned' indicator displayed cleanly above card with sharp corners.")
	
	# TEST 5: Multiple stacked status effects (e.g. Stunned + Defending)
	roy.is_defending = true
	status_ui.refresh_party_cards()
	
	roy_col = party_container.get_child(0) as VBoxContainer
	roy_status_container = roy_col.get_node_or_null("StatusContainer") as VBoxContainer
	assert(roy_status_container.get_child_count() == 2, "Roy should now have 2 stacked status indicators")
	var status_lbl2 = roy_status_container.get_child(1).get_child(0) as Label
	assert(status_lbl2.text == "Defending", "Second status is 'Defending', got '%s'" % status_lbl2.text)
	log_msg("TEST 5 PASSED: 2 status effects stacked vertically above the card.")
	
	# TEST 6: Removal of status effects returns to clean normal state
	for inst in roy.active_statuses.duplicate():
		StatusSystem.remove_status(roy, inst)
	roy.is_defending = false
	status_ui.refresh_party_cards()
	
	roy_col = party_container.get_child(0) as VBoxContainer
	roy_status_container = roy_col.get_node_or_null("StatusContainer") as VBoxContainer
	assert(roy_status_container.get_child_count() == 0, "Roy status indicators cleanly removed upon return to normal")
	log_msg("TEST 6 PASSED: Status indicators cleanly removed in normal state.")
	
	log_msg("=== ALL CHARACTER STATUS UI TESTS PASSED SUCCESSFULLY! ===")
	quit(0)
	return true
