class_name TimelineUI
extends PanelContainer

## Minimalist, Grandia-style turn timeline matching the reference drawing.
## - Single horizontal track for players and enemies.
## - "WAIT" region on left, salmon-colored "CMD" block on right, "ACT" indicator at the end.
## - Player tokens positioned on top with stems into the bar; numbered badges with varied pastel colors.
## - Enemy tokens positioned on bottom with stems into the bar; numbered badges with red/pink background.
## - No action text labels inside the timeline: only clean character stems and numbered circles.

const CMD_RATIO: float = 0.76

var current_timeline: TurnTimeline = null
var highlighted_actor: BattleCharacter = null

# Visual palette matching sketch reference
var track_bg_color: Color = Color(0.98, 0.98, 0.99, 0.95)
var track_border_color: Color = Color(0.12, 0.14, 0.18, 1.0)
var cmd_bg_color: Color = Color(1.0, 0.72, 0.74, 1.0) # Salmon / Pink (#FFB3BA)
var text_color: Color = Color(0.12, 0.14, 0.18, 1.0)
var stem_color: Color = Color(0.12, 0.14, 0.18, 1.0)

# Varied player palette (Yellow, Green, Sky Blue, Lavender)
var player_colors: Array[Color] = [
	Color(0.99, 0.90, 0.54, 1.0), # #FDE68A Yellow (Unit 1)
	Color(0.65, 0.95, 0.82, 1.0), # #A7F3D0 Mint Green (Unit 2)
	Color(0.73, 0.90, 0.99, 1.0), # #BAE6FD Sky Blue (Unit 3)
	Color(0.91, 0.84, 1.00, 1.0)  # #E9D5FF Lavender (Unit 4)
]

# Enemy color: always red/pink background
var enemy_bg_color: Color = Color(1.0, 0.65, 0.67, 1.0) # #FFAAA6 Soft Red/Pink

# Tracking & smoothing
var unit_numbers: Dictionary = {} # BattleCharacter -> int
var character_display_x: Dictionary = {} # BattleCharacter -> float
var pulse_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if has_node("MarginContainer/HBoxContainer"):
		$MarginContainer/HBoxContainer.visible = false

func initialize(timeline: TurnTimeline) -> void:
	if current_timeline != null:
		if current_timeline.combatant_added.is_connected(_on_combatant_added):
			current_timeline.combatant_added.disconnect(_on_combatant_added)
		if current_timeline.combatant_removed.is_connected(_on_combatant_removed):
			current_timeline.combatant_removed.disconnect(_on_combatant_removed)
			
	current_timeline = timeline
	if current_timeline != null:
		if not current_timeline.combatant_added.is_connected(_on_combatant_added):
			current_timeline.combatant_added.connect(_on_combatant_added)
		if not current_timeline.combatant_removed.is_connected(_on_combatant_removed):
			current_timeline.combatant_removed.connect(_on_combatant_removed)
			
	_rebuild_unit_numbers()
	queue_redraw()

func _rebuild_unit_numbers() -> void:
	unit_numbers.clear()
	# Clean up freed/stale keys from character_display_x
	var stale_keys: Array = []
	for k in character_display_x.keys():
		if k == null or not is_instance_valid(k):
			stale_keys.append(k)
	for k in stale_keys:
		character_display_x.erase(k)
		
	if current_timeline == null:
		return
		
	var player_count = 0
	var enemy_count = 0
	for c in current_timeline.combatants:
		if c is BattleCharacter and is_instance_valid(c) and not c.is_dead:
			if c.team == 0:
				player_count += 1
				unit_numbers[c] = player_count
			else:
				enemy_count += 1
				unit_numbers[c] = enemy_count

func _on_combatant_added(_c: BattleCharacter) -> void:
	_rebuild_unit_numbers()
	queue_redraw()

func _on_combatant_removed(c: BattleCharacter) -> void:
	if character_display_x.has(c):
		character_display_x.erase(c)
	if unit_numbers.has(c):
		unit_numbers.erase(c)
	_rebuild_unit_numbers()
	queue_redraw()

func set_highlighted_actor(actor: BattleCharacter) -> void:
	highlighted_actor = actor
	queue_redraw()

func _process(delta: float) -> void:
	if current_timeline == null:
		return
		
	pulse_time += delta * 4.0
	
	var track_w = size.x
	var bar_start_x = 44.0
	var bar_end_x = max(bar_start_x + 100.0, track_w - 54.0)
	var cmd_start_x = bar_start_x + (bar_end_x - bar_start_x) * CMD_RATIO
	
	# Smoothly interpolate X positions
	for c in current_timeline.combatants:
		if c == null or not is_instance_valid(c) or c.is_dead:
			continue
			
		var target_x: float = bar_start_x
		if c.timeline_state == BattleCharacter.TimelineState.MOVING_TO_COM:
			var t = clamp(c.timeline_position / TurnTimeline.COM_LINE, 0.0, 1.0)
			target_x = bar_start_x + t * (cmd_start_x - bar_start_x)
		elif c.timeline_state == BattleCharacter.TimelineState.COMMAND_SELECTION:
			target_x = cmd_start_x
		elif c.timeline_state == BattleCharacter.TimelineState.MOVING_TO_EXECUTION:
			var delay = max(1.0, c.pending_action.timeline_cost if c.pending_action != null else 30.0)
			var t = clamp((c.timeline_position - TurnTimeline.COM_LINE) / delay, 0.0, 1.0)
			target_x = cmd_start_x + t * (bar_end_x - cmd_start_x)
		elif c.timeline_state == BattleCharacter.TimelineState.EXECUTING_ACTION:
			target_x = bar_end_x
			
		if not character_display_x.has(c):
			character_display_x[c] = target_x
		else:
			character_display_x[c] = lerp(character_display_x[c], target_x, delta * 14.0)
			
	queue_redraw()


func _draw() -> void:
	var track_w = size.x
	var track_h = size.y
	if track_w < 120.0 or track_h < 40.0:
		return
		
	var font = ThemeDB.fallback_font
	var font_size = 11
	
	# Timeline bar geometry
	var bar_y = track_h * 0.5 - 12.0
	var bar_h = 24.0
	var bar_start_x = 44.0
	var bar_end_x = max(bar_start_x + 100.0, track_w - 54.0)
	var bar_w = bar_end_x - bar_start_x
	var cmd_start_x = bar_start_x + bar_w * CMD_RATIO
	var cmd_w = bar_end_x - cmd_start_x
	var corner_radius = 12.0
	
	# 1. Draw Main Track Background (White pill shape)
	var bar_style = StyleBoxFlat.new()
	bar_style.bg_color = track_bg_color
	bar_style.border_color = track_border_color
	bar_style.border_width_left = 2
	bar_style.border_width_top = 2
	bar_style.border_width_right = 2
	bar_style.border_width_bottom = 2
	bar_style.corner_radius_top_left = int(corner_radius)
	bar_style.corner_radius_bottom_left = int(corner_radius)
	bar_style.corner_radius_top_right = int(corner_radius)
	bar_style.corner_radius_bottom_right = int(corner_radius)
	draw_style_box(bar_style, Rect2(bar_start_x, bar_y, bar_w, bar_h))
	
	# 2. Draw CMD Section (Salmon/Pink block on the right)
	var cmd_style = StyleBoxFlat.new()
	cmd_style.bg_color = cmd_bg_color
	cmd_style.border_color = track_border_color
	cmd_style.border_width_left = 2
	cmd_style.border_width_top = 2
	cmd_style.border_width_right = 2
	cmd_style.border_width_bottom = 2
	cmd_style.corner_radius_top_right = int(corner_radius)
	cmd_style.corner_radius_bottom_right = int(corner_radius)
	draw_style_box(cmd_style, Rect2(cmd_start_x, bar_y, cmd_w, bar_h))
	
	# 3. Draw Track Labels: WAIT, CMD, ACT
	# "WAIT"
	var wait_text = "WAIT"
	var wait_size = font.get_string_size(wait_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var wait_pos = Vector2(bar_start_x + 12.0, bar_y + (bar_h + wait_size.y) * 0.5 - 2.0)
	draw_string(font, wait_pos, wait_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	
	# "CMD"
	var cmd_text = "CMD"
	var cmd_size = font.get_string_size(cmd_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var cmd_pos = Vector2(cmd_start_x + (cmd_w - cmd_size.x) * 0.5, bar_y + (bar_h + cmd_size.y) * 0.5 - 2.0)
	draw_string(font, cmd_pos, cmd_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	
	# "ACT"
	var act_text = "ACT"
	var act_size = font.get_string_size(act_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var act_pos = Vector2(bar_end_x + 8.0, bar_y + (bar_h + act_size.y) * 0.5 - 2.0)
	draw_string(font, act_pos, act_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
	
	if current_timeline == null:
		return
		
	# 4. Draw Character Stems and Circular Badges
	var circle_radius = 13.0
	
	for c in current_timeline.combatants:
		if c == null or not is_instance_valid(c) or c.is_dead:
			continue

			
		var pos_x = character_display_x.get(c, bar_start_x)
		var num_idx = unit_numbers.get(c, 1)
		var is_player = (c.team == 0)
		var is_active = (c == highlighted_actor or c.timeline_state == BattleCharacter.TimelineState.COMMAND_SELECTION)
		
		if is_player:
			# Player: positioned ABOVE the bar
			var circle_center = Vector2(pos_x, bar_y - 20.0)
			# Vertical stem entering cleanly into the bar
			draw_line(Vector2(pos_x, circle_center.y + circle_radius), Vector2(pos_x, bar_y + 12.0), stem_color, 2.0, true)
			
			# Background fill: varied player colors
			var bg = player_colors[(num_idx - 1) % player_colors.size()]
			draw_circle(circle_center, circle_radius, bg)
			# Black outline
			draw_arc(circle_center, circle_radius, 0.0, TAU, 32, stem_color, 2.0, true)
			
			# Active highlight
			if is_active:
				var pulse = 1.0 + sin(pulse_time) * 0.15
				draw_arc(circle_center, (circle_radius + 3.5) * pulse, 0.0, TAU, 32, Color(0.96, 0.62, 0.04, 1.0), 2.5, true)
				
			# Unit number
			var num_str = str(num_idx)
			var num_size = font.get_string_size(num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
			var num_pos = Vector2(circle_center.x - num_size.x * 0.5, circle_center.y + num_size.y * 0.35)
			draw_string(font, num_pos, num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_color)
		else:
			# Enemy: positioned BELOW the bar
			var circle_center = Vector2(pos_x, bar_y + bar_h + 20.0)
			# Vertical stem entering cleanly into the bar
			draw_line(Vector2(pos_x, circle_center.y - circle_radius), Vector2(pos_x, bar_y + bar_h - 12.0), stem_color, 2.0, true)
			
			# Background fill: always red/pink
			draw_circle(circle_center, circle_radius, enemy_bg_color)
			# Black outline
			draw_arc(circle_center, circle_radius, 0.0, TAU, 32, stem_color, 2.0, true)
			
			# Active highlight
			if is_active:
				var pulse = 1.0 + sin(pulse_time) * 0.15
				draw_arc(circle_center, (circle_radius + 3.5) * pulse, 0.0, TAU, 32, Color(0.95, 0.2, 0.2, 1.0), 2.5, true)
				
			# Unit number
			var num_str = str(num_idx)
			var num_size = font.get_string_size(num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
			var num_pos = Vector2(circle_center.x - num_size.x * 0.5, circle_center.y + num_size.y * 0.35)
			draw_string(font, num_pos, num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, text_color)
