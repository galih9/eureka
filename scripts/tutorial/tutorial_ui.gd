class_name TutorialUI
extends CanvasLayer

## Dedicated UI overlay for the interactive 1v1 tutorial.
## Features:
## 1. Explanation Phase: Centered modal card explaining the concept while battle is paused.
## 2. Action Phase: Big card disappears, replaced by a slim 34px top mini bar under the timeline,
##    leaving the entire arena 100% visible and unobstructed!

signal proceed_pressed()
signal return_to_menu_pressed()
signal help_requested()

# Modal Explanation Card nodes
@onready var card_panel: PanelContainer = $CardContainer
@onready var step_badge: Label = %StepBadge
@onready var title_label: Label = %TitleLabel
@onready var body_label: RichTextLabel = %BodyLabel
@onready var action_button: Button = %ActionButton

# Slim Top Mini-Bar nodes
@onready var minibar_panel: PanelContainer = %MiniBarContainer
@onready var mini_step_badge: Label = %MiniStepBadge
@onready var mini_objective_label: Label = %MiniObjectiveLabel
@onready var mini_help_btn: Button = %MiniHelpButton

# Big Milestones Banner
@onready var banner_label: Label = %BannerLabel

var current_step_index: int = 0
var total_steps_count: int = 5
var current_step_title: String = ""
var current_step_body: String = ""
var current_objective_text: String = ""

var card_tween: Tween = null
var minibar_tween: Tween = null
var banner_tween: Tween = null

func _ready() -> void:
	layer = 110
	if banner_label != null:
		banner_label.visible = false
	if minibar_panel != null:
		minibar_panel.visible = false
	if action_button != null:
		action_button.pressed.connect(_on_action_button_pressed)
	if mini_help_btn != null:
		mini_help_btn.pressed.connect(_on_mini_help_pressed)

## Shows the centered modal explanation card while the game is paused.
func show_explanation(step_idx: int, total_steps: int, title: String, text_content: String, objective: String, button_text: String) -> void:
	current_step_index = step_idx
	total_steps_count = total_steps
	current_step_title = title
	current_step_body = text_content
	current_objective_text = objective
	
	if card_tween != null and card_tween.is_valid():
		card_tween.kill()
	if minibar_tween != null and minibar_tween.is_valid():
		minibar_tween.kill()
	
	# Hide the mini bar while reading the full card
	if minibar_panel != null:
		minibar_panel.visible = false
		
	card_panel.visible = true
	
	if step_idx < total_steps:
		step_badge.text = "STEP %d OF %d" % [step_idx + 1, total_steps]
		step_badge.add_theme_color_override("font_color", Color(0.38, 0.75, 1.0))
	else:
		step_badge.text = "★ COMPLETE ★"
		step_badge.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		
	title_label.text = title
	body_label.text = text_content
	
	action_button.text = button_text
	action_button.visible = true
	action_button.grab_focus()
	
	# Smooth entry bounce & fade
	card_panel.modulate.a = 0.0
	card_panel.scale = Vector2(0.96, 0.96)
	card_tween = create_tween().set_parallel(true)
	card_tween.tween_property(card_panel, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	card_tween.tween_property(card_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Hides the big modal card and shows the slim top mini-bar so the entire arena is completely visible!
func enter_action_phase(step_idx: int, total_steps: int, objective: String) -> void:
	current_step_index = step_idx
	total_steps_count = total_steps
	current_objective_text = objective
	
	if card_tween != null and card_tween.is_valid():
		card_tween.kill()
	
	# Fade out modal card
	card_tween = create_tween()
	card_tween.tween_property(card_panel, "modulate:a", 0.0, 0.15)
	card_tween.tween_callback(func():
		card_panel.visible = false
	)
	
	if minibar_tween != null and minibar_tween.is_valid():
		minibar_tween.kill()
	
	# Slide in slim mini-bar at top under timeline
	if minibar_panel != null:
		minibar_panel.visible = true
		mini_step_badge.text = "STEP %d/%d" % [step_idx + 1, total_steps]
		mini_objective_label.text = "🎯 %s" % objective
		mini_objective_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))
		
		minibar_panel.modulate.a = 0.0
		minibar_tween = create_tween()
		minibar_tween.tween_property(minibar_panel, "modulate:a", 1.0, 0.2)

## Updates the objective status on the slim mini bar
func update_objective(new_objective: String, is_complete: bool = false) -> void:
	if minibar_panel == null or mini_objective_label == null:
		return
		
	minibar_panel.visible = true
	if is_complete:
		mini_objective_label.text = "✔ COMPLETED: %s" % new_objective
		mini_objective_label.add_theme_color_override("font_color", Color(0.3, 0.95, 0.4))
	else:
		mini_objective_label.text = "🎯 %s" % new_objective
		mini_objective_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.65))

## Shows a big center celebratory banner for milestones (e.g. CANCEL!, DODGED!)
func show_banner(text: String, duration: float = 2.0, color: Color = Color(1.0, 0.85, 0.2)) -> void:
	if banner_label == null:
		return
		
	if banner_tween != null and banner_tween.is_valid():
		banner_tween.kill()
		
	banner_label.text = text
	banner_label.add_theme_color_override("font_color", color)
	banner_label.visible = true
	banner_label.modulate.a = 0.0
	
	banner_tween = create_tween()
	banner_tween.tween_property(banner_label, "modulate:a", 1.0, 0.18)
	banner_tween.tween_interval(duration)
	banner_tween.tween_property(banner_label, "modulate:a", 0.0, 0.25)
	banner_tween.tween_callback(func():
		banner_label.visible = false
	)

func _on_action_button_pressed() -> void:
	if current_step_index >= total_steps_count: # Final step (recap)
		return_to_menu_pressed.emit()
	else:
		proceed_pressed.emit()

func _on_mini_help_pressed() -> void:
	# Player clicked "Info" on the mini bar to re-read the explanation card
	help_requested.emit()
	show_explanation(current_step_index, total_steps_count, current_step_title, current_step_body, current_objective_text, "RESUME ACTION ▶")
