class_name CharacterStatusUI
extends Control

## Displays active character status (bottom-left) and party member overview cards.

@onready var active_panel: PanelContainer = $ActivePanel
@onready var active_name: Label = $ActivePanel/VBox/NameLabel
@onready var active_hp_bar: ProgressBar = $ActivePanel/VBox/HPBar
@onready var active_hp_text: Label = $ActivePanel/VBox/HPBar/HPText
@onready var active_mp_bar: ProgressBar = $ActivePanel/VBox/MPBar
@onready var active_mp_text: Label = $ActivePanel/VBox/MPBar/MPText
@onready var active_perk_tags: Label = $ActivePanel/VBox/PerkTags
@onready var party_cards_container: HBoxContainer = $PartyContainer

var current_actor: BattleCharacter = null
var party_members: Array = [] # Array[BattleCharacter]

func _ready() -> void:
	var bus = CombatEventsBus.get_bus(self)
	if bus != null:
		if not bus.status_applied.is_connected(_on_combat_status_changed):
			bus.status_applied.connect(_on_combat_status_changed)
		if not bus.status_removed.is_connected(_on_combat_status_changed):
			bus.status_removed.connect(_on_combat_status_changed)

func _on_combat_status_changed(_char: Node, _stat: RefCounted) -> void:
	refresh_party_cards()

func setup_party(party: Array) -> void:
	party_members = _sort_party_members(party)
	for p in party_members:
		if p != null and is_instance_valid(p):
			if not p.hp_changed.is_connected(_on_member_stat_changed):
				p.hp_changed.connect(func(_c, _m): _on_member_stat_changed())
			if not p.mp_changed.is_connected(_on_member_stat_changed):
				p.mp_changed.connect(func(_c, _m): _on_member_stat_changed())
			if not p.died.is_connected(_on_member_died):
				p.died.connect(func(_c): _on_member_stat_changed())
	refresh_active_panel()
	refresh_party_cards()

func _sort_party_members(party: Array) -> Array:
	var result: Array = []
	var roy = null
	var ingrid = null
	var jacob = null
	var rest: Array = []
	
	for p in party:
		if p == null or not is_instance_valid(p):
			continue
		var name_str = ""
		if p.character_definition != null:
			name_str = p.character_definition.codename.to_upper()
		elif p.display_name_override != "":
			name_str = p.display_name_override.to_upper()
		else:
			name_str = p.name.to_upper()
			
		if "ROY" in name_str or "BRAWLER" in name_str:
			roy = p
		elif "INGRID" in name_str or "STRIKER" in name_str:
			ingrid = p
		elif "JACOB" in name_str or "SPECIALIST" in name_str:
			jacob = p
		else:
			rest.append(p)
			
	if roy != null:
		result.append(roy)
	if ingrid != null:
		result.append(ingrid)
	if jacob != null:
		result.append(jacob)
	result.append_array(rest)
	
	if result.is_empty():
		return party
	return result

func _get_character_label(p: BattleCharacter) -> String:
	if p == null:
		return "Character"
	if p.character_definition != null:
		return p.character_definition.display_name
	if p.display_name_override != "":
		return p.display_name_override
	return p.name

func _on_member_stat_changed() -> void:
	refresh_active_panel()
	refresh_party_cards()

func _on_member_died(_character: BattleCharacter) -> void:
	refresh_active_panel()
	refresh_party_cards()

func set_active_character(actor: BattleCharacter) -> void:
	current_actor = actor
	if party_members.is_empty() and actor != null and actor.is_player:
		if actor.get_parent() != null:
			var found: Array = []
			for c in actor.get_parent().get_children():
				if c is BattleCharacter and c.is_player:
					found.append(c)
			if not found.is_empty():
				setup_party(found)
				return
	refresh_active_panel()
	refresh_party_cards()

func refresh_active_panel() -> void:
	if active_panel != null:
		active_panel.visible = false

func _get_banner_texture(p: BattleCharacter) -> Texture2D:
	if p != null and p.character_definition != null and p.character_definition.banner != null:
		return p.character_definition.banner
		
	var name_upper = ""
	if p != null:
		if p.character_definition != null:
			name_upper = p.character_definition.codename.to_upper()
		elif p.display_name_override != "":
			name_upper = p.display_name_override.to_upper()
		else:
			name_upper = p.name.to_upper()
			
	if "INGRID" in name_upper or "FEMALE" in name_upper or "STRIKER" in name_upper:
		return preload("res://assets/banner/female.png")
	return preload("res://assets/banner/male.png")

func _get_simplified_status_list(p: BattleCharacter) -> Array[String]:
	if p == null or not is_instance_valid(p):
		return []
		
	var result: Array[String] = []
	
	if p.is_dead:
		result.append("KO")
		return result
		
	for st in p.active_statuses:
		if st == null or st.definition == null:
			continue
		var s_id = st.definition.status_id.to_lower()
		var s_name = st.definition.status_name
		match s_id:
			"stun":
				result.append("Stunned")
			"sleep":
				result.append("Sleeping")
			"silence":
				result.append("Silenced")
			"disarm":
				result.append("Disarmed")
			"flinch":
				result.append("Flinched")
			"bleed":
				result.append("Bleeding")
			"poison":
				result.append("Poisoned")
			"atk_up":
				result.append("ATK Up")
			"def_up":
				result.append("DEF Up")
			"agility_up", "agi_up":
				result.append("AGI Up")
			"evasion_up", "eva_up":
				result.append("EVA Up")
			"exhausted":
				result.append("Exhausted")
			_:
				if s_name != "":
					result.append(s_name)
				else:
					result.append(s_id.capitalize())
					
	if p.is_defending:
		result.append("Defending")
		
	for perk in p.active_perks:
		if perk.activated:
			result.append("Awakened")
			break
			
	return result

func refresh_party_cards() -> void:
	if party_cards_container == null:
		return
		
	for child in party_cards_container.get_children():
		party_cards_container.remove_child(child)
		child.queue_free()
		
	for p in party_members:
		if p == null or not is_instance_valid(p):
			continue
			
		var is_active = (p == current_actor)
		var is_dead = p.is_dead
		
		# Vertical column for status indicators + character card
		var col = VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_END
		col.custom_minimum_size = Vector2(160, 0)
		col.add_theme_constant_override("separation", 6)
		
		# 1. Status Indicator Container (placed above card box)
		var status_container = VBoxContainer.new()
		status_container.name = "StatusContainer"
		status_container.alignment = BoxContainer.ALIGNMENT_END
		status_container.add_theme_constant_override("separation", 3)
		
		var statuses = _get_simplified_status_list(p)
		for status_text in statuses:
			var status_box = PanelContainer.new()
			status_box.name = "StatusBox"
			
			var s_style = StyleBoxFlat.new()
			# Warm yellow background matching reference sketch
			s_style.bg_color = Color(0.98, 0.84, 0.36, 0.95)
			s_style.border_color = Color(0.18, 0.16, 0.10, 1.0)
			s_style.border_width_left = 2
			s_style.border_width_right = 2
			s_style.border_width_top = 2
			s_style.border_width_bottom = 2
			# Sharp corners!
			s_style.corner_radius_top_left = 0
			s_style.corner_radius_top_right = 0
			s_style.corner_radius_bottom_left = 0
			s_style.corner_radius_bottom_right = 0
			s_style.content_margin_left = 8
			s_style.content_margin_right = 8
			s_style.content_margin_top = 2
			s_style.content_margin_bottom = 2
			status_box.add_theme_stylebox_override("panel", s_style)
			status_box.custom_minimum_size = Vector2(110, 20)
			status_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			
			var s_lbl = Label.new()
			s_lbl.text = status_text
			s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			s_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			s_lbl.add_theme_font_size_override("font_size", 10)
			s_lbl.add_theme_color_override("font_color", Color(0.15, 0.12, 0.08, 1.0))
			status_box.add_child(s_lbl)
			status_container.add_child(status_box)
			
		col.add_child(status_container)
		
		# 2. Main Character Card Box (Sharp Corners)
		var card_box = PanelContainer.new()
		card_box.name = "CardBox"
		card_box.custom_minimum_size = Vector2(160, 96)
		
		var card_style = StyleBoxFlat.new()
		# Sharp corners
		card_style.corner_radius_top_left = 0
		card_style.corner_radius_top_right = 0
		card_style.corner_radius_bottom_left = 0
		card_style.corner_radius_bottom_right = 0
		card_style.content_margin_left = 5
		card_style.content_margin_right = 5
		card_style.content_margin_top = 5
		card_style.content_margin_bottom = 5
		
		if is_dead:
			card_style.bg_color = Color(0.12, 0.12, 0.14, 0.90)
			card_style.border_color = Color(0.35, 0.35, 0.35, 1.0)
			card_style.border_width_left = 2
			card_style.border_width_right = 2
			card_style.border_width_top = 2
			card_style.border_width_bottom = 2
		elif is_active:
			card_style.bg_color = Color(0.12, 0.15, 0.22, 0.98)
			card_style.border_color = Color(1.0, 0.76, 0.18, 1.0) # Vivid amber active highlight
			card_style.border_width_left = 3
			card_style.border_width_right = 3
			card_style.border_width_top = 3
			card_style.border_width_bottom = 3
		else:
			card_style.bg_color = Color(0.08, 0.10, 0.15, 0.92)
			card_style.border_color = Color(0.20, 0.22, 0.28, 1.0)
			card_style.border_width_left = 2
			card_style.border_width_right = 2
			card_style.border_width_top = 2
			card_style.border_width_bottom = 2
			
		card_box.add_theme_stylebox_override("panel", card_style)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		
		# A. Eye-Shot Banner Frame (Sharp corners)
		var banner_frame = PanelContainer.new()
		banner_frame.name = "BannerFrame"
		banner_frame.clip_contents = true
		banner_frame.custom_minimum_size = Vector2(150, 48)
		
		var b_style = StyleBoxFlat.new()
		b_style.bg_color = Color(0.05, 0.05, 0.08, 1.0)
		b_style.border_color = Color(0.22, 0.25, 0.32, 1.0)
		b_style.border_width_left = 1
		b_style.border_width_right = 1
		b_style.border_width_top = 1
		b_style.border_width_bottom = 1
		b_style.corner_radius_top_left = 0
		b_style.corner_radius_top_right = 0
		b_style.corner_radius_bottom_left = 0
		b_style.corner_radius_bottom_right = 0
		banner_frame.add_theme_stylebox_override("panel", b_style)
		
		var banner_tex = TextureRect.new()
		banner_tex.name = "BannerTexture"
		banner_tex.texture = _get_banner_texture(p)
		banner_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		banner_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		banner_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if is_dead:
			banner_tex.modulate = Color(0.4, 0.4, 0.4, 0.7)
		banner_frame.add_child(banner_tex)
		
		# Name & Captain overlay tag on banner
		var char_title = _get_character_label(p)
		var name_tag = Label.new()
		name_tag.text = ("👑 " if p.is_captain else "") + char_title
		name_tag.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_tag.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		name_tag.offset_left = 4
		name_tag.offset_bottom = -2
		name_tag.add_theme_font_size_override("font_size", 10)
		name_tag.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		name_tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		name_tag.add_theme_constant_override("outline_size", 3)
		banner_frame.add_child(name_tag)
		
		vbox.add_child(banner_frame)
		
		# B. Green Bar: HP Bar (Sharp corners)
		var max_hp = p.get_stat("max_hp")
		var hp_bar = ProgressBar.new()
		hp_bar.name = "HPBar"
		hp_bar.custom_minimum_size = Vector2(150, 16)
		hp_bar.max_value = max_hp
		hp_bar.value = p.current_hp
		hp_bar.show_percentage = false
		
		var hp_bg = StyleBoxFlat.new()
		hp_bg.bg_color = Color(0.10, 0.16, 0.12, 0.95)
		hp_bg.border_color = Color(0.18, 0.25, 0.18, 1.0)
		hp_bg.border_width_left = 1
		hp_bg.border_width_right = 1
		hp_bg.border_width_top = 1
		hp_bg.border_width_bottom = 1
		hp_bg.corner_radius_top_left = 0
		hp_bg.corner_radius_top_right = 0
		hp_bg.corner_radius_bottom_right = 0
		hp_bg.corner_radius_bottom_left = 0
		hp_bar.add_theme_stylebox_override("background", hp_bg)
		
		var hp_fill = StyleBoxFlat.new()
		hp_fill.bg_color = Color(0.24, 0.84, 0.42, 1.0) if not is_dead else Color(0.4, 0.4, 0.4, 1.0)
		hp_fill.corner_radius_top_left = 0
		hp_fill.corner_radius_top_right = 0
		hp_fill.corner_radius_bottom_right = 0
		hp_fill.corner_radius_bottom_left = 0
		hp_bar.add_theme_stylebox_override("fill", hp_fill)
		
		var hp_text = Label.new()
		hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hp_text.text = "HP  %d / %d" % [p.current_hp, max_hp]
		hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hp_text.add_theme_font_size_override("font_size", 9)
		hp_text.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		hp_text.add_theme_constant_override("outline_size", 2)
		hp_bar.add_child(hp_text)
		vbox.add_child(hp_bar)
		
		# C. Blue Bar: MP Bar (Sharp corners)
		var max_mp = p.get_stat("max_mp")
		var mp_bar = ProgressBar.new()
		mp_bar.name = "MPBar"
		mp_bar.custom_minimum_size = Vector2(150, 14)
		mp_bar.max_value = max_mp
		mp_bar.value = p.current_mp
		mp_bar.show_percentage = false
		
		var mp_bg = StyleBoxFlat.new()
		mp_bg.bg_color = Color(0.08, 0.14, 0.22, 0.95)
		mp_bg.border_color = Color(0.15, 0.22, 0.32, 1.0)
		mp_bg.border_width_left = 1
		mp_bg.border_width_right = 1
		mp_bg.border_width_top = 1
		mp_bg.border_width_bottom = 1
		mp_bg.corner_radius_top_left = 0
		mp_bg.corner_radius_top_right = 0
		mp_bg.corner_radius_bottom_right = 0
		mp_bg.corner_radius_bottom_left = 0
		mp_bar.add_theme_stylebox_override("background", mp_bg)
		
		var mp_fill = StyleBoxFlat.new()
		mp_fill.bg_color = Color(0.28, 0.65, 0.98, 1.0) if not is_dead else Color(0.4, 0.4, 0.4, 1.0)
		mp_fill.corner_radius_top_left = 0
		mp_fill.corner_radius_top_right = 0
		mp_fill.corner_radius_bottom_right = 0
		mp_fill.corner_radius_bottom_left = 0
		mp_bar.add_theme_stylebox_override("fill", mp_fill)
		
		var mp_text = Label.new()
		mp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mp_text.text = "MP  %d / %d" % [p.current_mp, max_mp]
		mp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mp_text.add_theme_font_size_override("font_size", 9)
		mp_text.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		mp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		mp_text.add_theme_constant_override("outline_size", 2)
		mp_bar.add_child(mp_text)
		vbox.add_child(mp_bar)
		
		card_box.add_child(vbox)
		col.add_child(card_box)
		party_cards_container.add_child(col)
