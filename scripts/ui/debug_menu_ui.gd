class_name DebugMenuUI
extends PanelContainer

## In-game Debug Menu for combat prototyping.
## Supports:
## 1. Adding/removing enemies (individual defeat/despawn or kill all)
## 2. Applying and removing status effects on any combatant
## 3. Party cheats (full heal, max MP, awaken perks)
## 4. Timeline pacing control (0.5x, 1x, 2x, 3x, Pause)

@export var battle_manager: BattleManager

# Preloaded enemy resources
var enemy_defs: Dictionary = {
	"Slime": preload("res://data/enemies/slime.tres"),
	"Slug": preload("res://data/enemies/slug.tres")
}

# Preloaded status resources
var status_defs: Dictionary = {
	"Stun": preload("res://data/status_effects/stun.tres"),
	"Sleep": preload("res://data/status_effects/sleep.tres"),
	"Flinch": preload("res://data/status_effects/flinch.tres"),
	"Silence": preload("res://data/status_effects/silence.tres"),
	"Disarm": preload("res://data/status_effects/disarm.tres"),
	"Poison": preload("res://data/status_effects/poison.tres"),
	"Bleed": preload("res://data/status_effects/bleed.tres"),
	"Attack Up": preload("res://data/status_effects/atk_up.tres"),
	"Defense Up": preload("res://data/status_effects/def_up.tres"),
	"Agility Up": preload("res://data/status_effects/agility_up.tres"),
	"Evasion Up": preload("res://data/status_effects/evasion_up.tres")
}

var enemy_spawn_dropdown: OptionButton
var enemy_remove_dropdown: OptionButton
var combatant_target_dropdown: OptionButton
var status_apply_dropdown: OptionButton
var active_status_list_container: VBoxContainer
var speed_label: Label
var spawn_lbl: Label
var btn_spawn: Button
var crit_status_label: Label
var is_paused: bool = false
var saved_speed: float = 10.0


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(340, 440)
	_build_ui()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1 or event.keycode == KEY_QUOTELEFT:
			toggle_menu()
			get_viewport().set_input_as_handled()

func toggle_menu() -> void:
	visible = not visible
	if visible:
		refresh_dropdowns()

func _build_ui() -> void:
	# Style the main debug panel
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.08, 0.14, 0.95)
	panel_style.border_color = Color(0.9, 0.75, 0.2, 0.9)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 10
	panel_style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", panel_style)

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	add_child(main_vbox)

	# Header: Title + Close Button
	var header = HBoxContainer.new()
	var title = Label.new()
	title.text = "🛠 DEBUG & CHEATS"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = " ✕ "
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)
	main_vbox.add_child(header)

	# Tab Container
	var tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(tabs)

	# --- TAB 1: ENEMIES ---
	var enemy_tab = VBoxContainer.new()
	enemy_tab.name = "Enemies"
	enemy_tab.add_theme_constant_override("separation", 6)
	tabs.add_child(enemy_tab)

	spawn_lbl = Label.new()
	spawn_lbl.text = "SPAWN ENEMY (Max 8):"
	spawn_lbl.add_theme_font_size_override("font_size", 11)
	spawn_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	enemy_tab.add_child(spawn_lbl)

	var spawn_row = HBoxContainer.new()
	enemy_spawn_dropdown = OptionButton.new()
	enemy_spawn_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in enemy_defs.keys():
		enemy_spawn_dropdown.add_item(k)
	spawn_row.add_child(enemy_spawn_dropdown)

	btn_spawn = Button.new()
	btn_spawn.text = "+ Spawn"
	btn_spawn.pressed.connect(_on_spawn_pressed)
	spawn_row.add_child(btn_spawn)
	enemy_tab.add_child(spawn_row)


	var sep1 = HSeparator.new()
	enemy_tab.add_child(sep1)

	var rem_lbl = Label.new()
	rem_lbl.text = "TARGET / REMOVE ENEMY:"
	rem_lbl.add_theme_font_size_override("font_size", 11)
	rem_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	enemy_tab.add_child(rem_lbl)

	enemy_remove_dropdown = OptionButton.new()
	enemy_tab.add_child(enemy_remove_dropdown)

	var rem_btns = HBoxContainer.new()
	var btn_kill = Button.new()
	btn_kill.text = "💀 Defeat (Kill)"
	btn_kill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_kill.pressed.connect(_on_kill_selected_enemy)
	rem_btns.add_child(btn_kill)

	var btn_despawn = Button.new()
	btn_despawn.text = "🗑 Despawn"
	btn_despawn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_despawn.pressed.connect(_on_despawn_selected_enemy)
	rem_btns.add_child(btn_despawn)
	enemy_tab.add_child(rem_btns)

	var btn_kill_all = Button.new()
	btn_kill_all.text = "💥 Kill All Enemies"
	btn_kill_all.pressed.connect(_on_kill_all_enemies)
	enemy_tab.add_child(btn_kill_all)

	# --- TAB 2: STATUS EFFECTS ---
	var status_tab = VBoxContainer.new()
	status_tab.name = "Statuses"
	status_tab.add_theme_constant_override("separation", 6)
	tabs.add_child(status_tab)

	var target_lbl = Label.new()
	target_lbl.text = "SELECT COMBATANT:"
	target_lbl.add_theme_font_size_override("font_size", 11)
	target_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	status_tab.add_child(target_lbl)

	combatant_target_dropdown = OptionButton.new()
	combatant_target_dropdown.item_selected.connect(_on_target_changed)
	status_tab.add_child(combatant_target_dropdown)

	var give_lbl = Label.new()
	give_lbl.text = "GIVE STATUS:"
	give_lbl.add_theme_font_size_override("font_size", 11)
	give_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	status_tab.add_child(give_lbl)

	var status_row = HBoxContainer.new()
	status_apply_dropdown = OptionButton.new()
	status_apply_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in status_defs.keys():
		status_apply_dropdown.add_item(k)
	status_row.add_child(status_apply_dropdown)

	var btn_apply = Button.new()
	btn_apply.text = "+ Apply"
	btn_apply.pressed.connect(_on_apply_status)
	status_row.add_child(btn_apply)
	status_tab.add_child(status_row)

	var sep2 = HSeparator.new()
	status_tab.add_child(sep2)

	var active_lbl = Label.new()
	active_lbl.text = "ACTIVE STATUSES ON TARGET:"
	active_lbl.add_theme_font_size_override("font_size", 11)
	active_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	status_tab.add_child(active_lbl)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 95)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	active_status_list_container = VBoxContainer.new()
	active_status_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(active_status_list_container)
	status_tab.add_child(scroll)

	var btn_clear_statuses = Button.new()
	btn_clear_statuses.text = "Clear All Statuses on Target"
	btn_clear_statuses.pressed.connect(_on_clear_all_statuses)
	status_tab.add_child(btn_clear_statuses)

	# --- TAB 3: CHEATS & TIMELINE ---
	var cheat_tab = VBoxContainer.new()
	cheat_tab.name = "Cheats"
	cheat_tab.add_theme_constant_override("separation", 6)
	tabs.add_child(cheat_tab)

	var party_lbl = Label.new()
	party_lbl.text = "PARTY ACTIONS:"
	party_lbl.add_theme_font_size_override("font_size", 11)
	party_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	cheat_tab.add_child(party_lbl)

	var btn_heal = Button.new()
	btn_heal.text = "💚 Full Heal & Revive Party"
	btn_heal.pressed.connect(func():
		if battle_manager != null:
			battle_manager.revive_and_heal_party()
	)
	cheat_tab.add_child(btn_heal)

	var btn_mp = Button.new()
	btn_mp.text = "⚡ Fill All Players' MP"
	btn_mp.pressed.connect(_on_fill_all_mp)
	cheat_tab.add_child(btn_mp)

	var btn_awaken = Button.new()
	btn_awaken.text = "★ Awaken All Perks"
	btn_awaken.pressed.connect(_on_awaken_all_perks)
	cheat_tab.add_child(btn_awaken)

	var sep_cap = HSeparator.new()
	cheat_tab.add_child(sep_cap)

	var cap_lbl = Label.new()
	cap_lbl.text = "CAPTAIN & PARTY AI TESTING:"
	cap_lbl.add_theme_font_size_override("font_size", 11)
	cap_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
	cheat_tab.add_child(cap_lbl)

	var cap_row = HBoxContainer.new()
	for p_name in ["Roy", "Ingrid", "Jacob"]:
		var btn = Button.new()
		btn.text = "👑 " + p_name
		var codename = p_name.to_upper()
		btn.pressed.connect(func():
			if battle_manager != null:
				for p in battle_manager.get_living_players():
					if codename in p.character_definition.codename.to_upper():
						battle_manager.set_captain(p)
						break
		)
		cap_row.add_child(btn)
	cheat_tab.add_child(cap_row)

	var cap_dis_row = HBoxContainer.new()
	var btn_dis_silence = Button.new()
	btn_dis_silence.text = "Mute Captain"
	btn_dis_silence.pressed.connect(func():
		if battle_manager != null and battle_manager.captain != null:
			var s_def = status_defs.get("Silence")
			if s_def != null:
				StatusSystem.apply_status(battle_manager.captain, s_def, "Debug")
	)
	cap_dis_row.add_child(btn_dis_silence)

	var btn_dis_stun = Button.new()
	btn_dis_stun.text = "Stun Captain"
	btn_dis_stun.pressed.connect(func():
		if battle_manager != null and battle_manager.captain != null:
			var s_def = status_defs.get("Stun")
			if s_def != null:
				StatusSystem.apply_status(battle_manager.captain, s_def, "Debug")
	)
	cap_dis_row.add_child(btn_dis_stun)

	var btn_dis_sleep = Button.new()
	btn_dis_sleep.text = "Sleep Captain"
	btn_dis_sleep.pressed.connect(func():
		if battle_manager != null and battle_manager.captain != null:
			var s_def = status_defs.get("Sleep")
			if s_def != null:
				StatusSystem.apply_status(battle_manager.captain, s_def, "Debug")
	)
	cap_dis_row.add_child(btn_dis_sleep)
	cheat_tab.add_child(cap_dis_row)

	var sep3 = HSeparator.new()
	cheat_tab.add_child(sep3)

	var time_lbl = Label.new()
	time_lbl.text = "TIMELINE SPEED:"
	time_lbl.add_theme_font_size_override("font_size", 11)
	time_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	cheat_tab.add_child(time_lbl)

	var speed_row = HBoxContainer.new()
	var speeds = [0.5, 1.0, 2.0, 3.0]
	for spd in speeds:
		var btn = Button.new()
		btn.text = "%.1fx" % spd
		btn.pressed.connect(func():
			if battle_manager != null:
				battle_manager.set_timeline_speed(10.0 * spd)
				_update_speed_label()
		)
		speed_row.add_child(btn)

	var btn_pause = Button.new()
	btn_pause.text = "⏸ Pause"
	btn_pause.pressed.connect(_on_toggle_pause)
	speed_row.add_child(btn_pause)
	cheat_tab.add_child(speed_row)

	speed_label = Label.new()
	speed_label.add_theme_font_size_override("font_size", 10)
	speed_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	cheat_tab.add_child(speed_label)
	_update_speed_label()

	var sep4 = HSeparator.new()
	cheat_tab.add_child(sep4)

	var crit_lbl = Label.new()
	crit_lbl.text = "CRITICAL HIT SLOWDOWN:"
	crit_lbl.add_theme_font_size_override("font_size", 11)
	crit_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	cheat_tab.add_child(crit_lbl)

	var crit_row = HBoxContainer.new()
	var scales = [0.05, 0.15, 0.30, 1.0]
	for sc in scales:
		var btn = Button.new()
		btn.text = "Off" if sc >= 1.0 else ("%.2fx" % sc)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(func():
			if battle_manager != null and battle_manager.camera_controller != null:
				battle_manager.camera_controller.crit_slowdown_enabled = (sc < 1.0)
				battle_manager.camera_controller.crit_time_scale = sc
				_update_crit_label()
		)
		crit_row.add_child(btn)
	cheat_tab.add_child(crit_row)

	crit_status_label = Label.new()
	crit_status_label.add_theme_font_size_override("font_size", 10)
	crit_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	cheat_tab.add_child(crit_status_label)
	_update_crit_label()

func _update_crit_label() -> void:
	if crit_status_label == null:
		return
	if battle_manager != null and battle_manager.camera_controller != null:
		var cam = battle_manager.camera_controller
		if cam.crit_slowdown_enabled:
			crit_status_label.text = "Crit Slowdown: %.2fx (%.2fs)" % [cam.crit_time_scale, cam.crit_slowdown_duration]
		else:
			crit_status_label.text = "Crit Slowdown: OFF"
	else:
		crit_status_label.text = "Crit Slowdown: 0.15x (0.35s)"

func _update_speed_label() -> void:
	if speed_label == null:
		return
	if battle_manager != null and battle_manager.turn_timeline != null:
		var spd = battle_manager.turn_timeline.timeline_speed / 10.0
		speed_label.text = "Current Speed: %.1fx %s" % [spd, "(PAUSED)" if is_paused else ""]
	else:
		speed_label.text = "Current Speed: 1.0x"

func _on_toggle_pause() -> void:
	if battle_manager == null or battle_manager.turn_timeline == null:
		return
	is_paused = not is_paused
	if is_paused:
		saved_speed = battle_manager.turn_timeline.timeline_speed
		battle_manager.set_timeline_speed(0.0)
	else:
		battle_manager.set_timeline_speed(saved_speed)
	_update_speed_label()

func refresh_dropdowns() -> void:
	if battle_manager == null:
		return

	# Refresh enemy remove list
	enemy_remove_dropdown.clear()
	var living_enemies = battle_manager.get_living_enemies()
	for i in range(living_enemies.size()):
		var e = living_enemies[i] as BattleCharacter
		var dname = e.get_display_name()
		enemy_remove_dropdown.add_item("%s (HP: %d)" % [dname, e.current_hp], i)

	if spawn_lbl != null:
		spawn_lbl.text = "SPAWN ENEMY (%d/8 Max):" % living_enemies.size()
	if btn_spawn != null:
		btn_spawn.disabled = (living_enemies.size() >= BattleManager.MAX_ENEMIES)

	# Refresh target list for status effects
	combatant_target_dropdown.clear()
	var all_c = battle_manager.get_living_combatants()
	for i in range(all_c.size()):
		var c = all_c[i] as BattleCharacter
		var tag = "[PLY]" if c.team == 0 else "[ENM]"
		combatant_target_dropdown.add_item("%s %s" % [tag, c.get_display_name()], i)

	_refresh_active_status_list()
	_update_speed_label()
	_update_crit_label()

func _on_target_changed(_idx: int) -> void:
	_refresh_active_status_list()

func _get_selected_target() -> BattleCharacter:
	if battle_manager == null:
		return null
	var all_c = battle_manager.get_living_combatants()
	var idx = combatant_target_dropdown.selected
	if idx >= 0 and idx < all_c.size():
		return all_c[idx]
	return null

func _get_selected_enemy() -> BattleCharacter:
	if battle_manager == null:
		return null
	var living = battle_manager.get_living_enemies()
	var idx = enemy_remove_dropdown.selected
	if idx >= 0 and idx < living.size():
		return living[idx]
	return null

func _on_spawn_pressed() -> void:
	if battle_manager == null:
		return
	if battle_manager.get_living_enemies().size() >= BattleManager.MAX_ENEMIES:
		return
	var selected_name = enemy_spawn_dropdown.get_item_text(enemy_spawn_dropdown.selected)
	var def = enemy_defs.get(selected_name)
	if def != null:
		battle_manager.spawn_enemy(def)
		refresh_dropdowns()


func _on_kill_selected_enemy() -> void:
	var e = _get_selected_enemy()
	if e != null:
		battle_manager.despawn_enemy(e, true)
		refresh_dropdowns()

func _on_despawn_selected_enemy() -> void:
	var e = _get_selected_enemy()
	if e != null:
		battle_manager.despawn_enemy(e, false)
		refresh_dropdowns()

func _on_kill_all_enemies() -> void:
	if battle_manager != null:
		battle_manager.kill_all_enemies()
		refresh_dropdowns()

func _on_apply_status() -> void:
	var target = _get_selected_target()
	if target == null:
		return
	var s_name = status_apply_dropdown.get_item_text(status_apply_dropdown.selected)
	var s_def = status_defs.get(s_name)
	if s_def != null:
		StatusSystem.apply_status(target, s_def, "Debug")
		_refresh_active_status_list()

func _on_clear_all_statuses() -> void:
	var target = _get_selected_target()
	if target != null:
		StatusSystem.clear_all(target)
		_refresh_active_status_list()

func _refresh_active_status_list() -> void:
	for child in active_status_list_container.get_children():
		child.queue_free()

	var target = _get_selected_target()
	if target == null:
		var empty_lbl = Label.new()
		empty_lbl.text = "(No target selected)"
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		active_status_list_container.add_child(empty_lbl)
		return

	if target.active_statuses.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "(No active statuses)"
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		active_status_list_container.add_child(empty_lbl)
		return

	for inst in target.active_statuses:
		var row = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = "• %s (turns: %d, stacks: %d)" % [inst.definition.status_name, inst.duration, inst.stacks]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 10)
		row.add_child(lbl)

		var btn_rem = Button.new()
		btn_rem.text = "X"
		btn_rem.pressed.connect(func():
			StatusSystem.remove_status(target, inst)
			_refresh_active_status_list()
		)
		row.add_child(btn_rem)
		active_status_list_container.add_child(row)

func _on_fill_all_mp() -> void:
	if battle_manager == null:
		return
	for p in battle_manager.get_living_players():
		var max_m = p.get_stat("max_mp")
		p.current_mp = max_m
		p.mp_changed.emit(p.current_mp, max_m)

func _on_awaken_all_perks() -> void:
	if battle_manager == null:
		return
	for p in battle_manager.get_living_players():
		for perk in p.active_perks:
			perk.activated = true
			p.guaranteed_critical = true
			p.guaranteed_hit = true
	var bus = CombatEventsBus.get_bus(self)
	if bus and not battle_manager.get_living_players().is_empty():
		bus.perk_activated.emit(battle_manager.get_living_players()[0].active_perks[0])
