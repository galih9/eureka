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

func refresh_party_cards() -> void:
	if party_cards_container == null:
		return
		
	for child in party_cards_container.get_children():
		party_cards_container.remove_child(child)
		child.queue_free()
		
	for p in party_members:
		if p == null or not is_instance_valid(p):
			continue
			
		var card = PanelContainer.new()
		var is_active = (p == current_actor)
		var is_dead = p.is_dead
		
		# Reference sketch: 3 yellow rounded cards with dark border
		var style = StyleBoxFlat.new()
		if is_dead:
			style.bg_color = Color(0.65, 0.65, 0.65, 0.85)
			style.border_color = Color(0.35, 0.35, 0.35, 1.0)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
		elif is_active:
			style.bg_color = Color(1.0, 0.93, 0.58, 0.98) # Bright warm yellow
			style.border_color = Color(0.95, 0.40, 0.05, 1.0) # Vivid amber active highlight
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
		else:
			style.bg_color = Color(0.96, 0.88, 0.52, 0.95) # Warm yellow matching sketch
			style.border_color = Color(0.22, 0.20, 0.14, 1.0) # Crisp dark border
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		card.add_theme_stylebox_override("panel", style)
		card.custom_minimum_size = Vector2(148, 122)
		
		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		
		# Name Label (Character 1 / Character 3 / Character 2)
		var name_lbl = Label.new()
		var char_title = _get_character_label(p)
		if is_active:
			name_lbl.text = "▶ " + char_title
			name_lbl.add_theme_color_override("font_color", Color(0.85, 0.25, 0.0))
		elif is_dead:
			name_lbl.text = char_title + " [DEAD]"
			name_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		else:
			name_lbl.text = char_title
			name_lbl.add_theme_color_override("font_color", Color(0.12, 0.12, 0.15))
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(name_lbl)
		
		# Class Subtitle (Archetype & Captain badge)
		var class_lbl = Label.new()
		var arch_str = ""
		match p.archetype:
			CharacterDefinition.Archetype.BRAWLER: arch_str = "BRAWLER"
			CharacterDefinition.Archetype.STRIKER: arch_str = "STRIKER"
			CharacterDefinition.Archetype.SPECIALIST: arch_str = "SPECIALIST"
			_: arch_str = "COMBATANT"
			
		var sub_text = arch_str
		if p.is_captain:
			var is_disabled = StatusSystem.is_stunned(p) or StatusSystem.is_silenced(p) or StatusSystem.is_sleeping(p)
			if is_disabled:
				sub_text = "👑 [CAPTAIN - DISABLED] " + arch_str
			else:
				sub_text = "👑 [CAPTAIN] " + arch_str
				
		class_lbl.text = sub_text
		class_lbl.add_theme_font_size_override("font_size", 9)
		class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if p.is_captain and (StatusSystem.is_stunned(p) or StatusSystem.is_silenced(p) or StatusSystem.is_sleeping(p)):
			class_lbl.add_theme_color_override("font_color", Color(0.95, 0.2, 0.2))
		elif is_active:
			class_lbl.add_theme_color_override("font_color", Color(0.65, 0.32, 0.0))
		elif is_dead:
			class_lbl.add_theme_color_override("font_color", Color(0.48, 0.48, 0.48))
		else:
			class_lbl.add_theme_color_override("font_color", Color(0.38, 0.32, 0.18))
		vbox.add_child(class_lbl)
		
		# Green Bar: HP Bar
		var max_hp = p.get_stat("max_hp")
		var hp_bar = ProgressBar.new()
		hp_bar.custom_minimum_size = Vector2(132, 16)
		hp_bar.max_value = max_hp
		hp_bar.value = p.current_hp
		hp_bar.show_percentage = false
		
		var hp_bg = StyleBoxFlat.new()
		hp_bg.bg_color = Color(0.12, 0.20, 0.14, 0.9)
		hp_bg.corner_radius_top_left = 4
		hp_bg.corner_radius_top_right = 4
		hp_bg.corner_radius_bottom_right = 4
		hp_bg.corner_radius_bottom_left = 4
		hp_bar.add_theme_stylebox_override("background", hp_bg)
		
		var hp_fill = StyleBoxFlat.new()
		hp_fill.bg_color = Color(0.18, 0.78, 0.32) if not is_dead else Color(0.4, 0.4, 0.4)
		hp_fill.corner_radius_top_left = 4
		hp_fill.corner_radius_top_right = 4
		hp_fill.corner_radius_bottom_right = 4
		hp_fill.corner_radius_bottom_left = 4
		hp_bar.add_theme_stylebox_override("fill", hp_fill)
		
		var hp_text = Label.new()
		hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hp_text.text = "HP %d / %d" % [p.current_hp, max_hp]
		hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		hp_text.add_theme_font_size_override("font_size", 9)
		hp_text.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		hp_text.add_theme_constant_override("outline_size", 2)
		hp_bar.add_child(hp_text)
		vbox.add_child(hp_bar)
		
		# Blue Bar: MP Bar
		var max_mp = p.get_stat("max_mp")
		var mp_bar = ProgressBar.new()
		mp_bar.custom_minimum_size = Vector2(132, 14)
		mp_bar.max_value = max_mp
		mp_bar.value = p.current_mp
		mp_bar.show_percentage = false
		
		var mp_bg = StyleBoxFlat.new()
		mp_bg.bg_color = Color(0.10, 0.16, 0.26, 0.9)
		mp_bg.corner_radius_top_left = 4
		mp_bg.corner_radius_top_right = 4
		mp_bg.corner_radius_bottom_right = 4
		mp_bg.corner_radius_bottom_left = 4
		mp_bar.add_theme_stylebox_override("background", mp_bg)
		
		var mp_fill = StyleBoxFlat.new()
		mp_fill.bg_color = Color(0.22, 0.58, 0.95) if not is_dead else Color(0.4, 0.4, 0.4)
		mp_fill.corner_radius_top_left = 4
		mp_fill.corner_radius_top_right = 4
		mp_fill.corner_radius_bottom_right = 4
		mp_fill.corner_radius_bottom_left = 4
		mp_bar.add_theme_stylebox_override("fill", mp_fill)
		
		var mp_text = Label.new()
		mp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mp_text.text = "MP %d / %d" % [p.current_mp, max_mp]
		mp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mp_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mp_text.add_theme_font_size_override("font_size", 9)
		mp_text.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		mp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		mp_text.add_theme_constant_override("outline_size", 2)
		mp_bar.add_child(mp_text)
		vbox.add_child(mp_bar)
		
		# Status chips label
		var status_lbl = Label.new()
		status_lbl.add_theme_font_size_override("font_size", 9)
		status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var p_tags: Array[String] = []
		if p.is_defending:
			p_tags.append("[DEF]")
		for st in p.active_statuses:
			p_tags.append("[%s]" % st.definition.status_name.to_upper())
		for perk in p.active_perks:
			if perk.activated:
				p_tags.append("[AWAKEN]")
		if p_tags.is_empty():
			status_lbl.text = "Normal"
			status_lbl.add_theme_color_override("font_color", Color(0.42, 0.36, 0.22) if not is_dead else Color(0.4, 0.4, 0.4))
		else:
			status_lbl.text = " ".join(p_tags)
			status_lbl.add_theme_color_override("font_color", Color(0.85, 0.25, 0.0) if not is_dead else Color(0.4, 0.4, 0.4))
		vbox.add_child(status_lbl)
		
		card.add_child(vbox)
		party_cards_container.add_child(card)
