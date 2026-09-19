class_name PerkNotificationUI
extends PanelContainer

## Prominent animated banner for reactive perk activations.

@onready var title_label: Label = $VBox/TitleLabel
@onready var desc_label: Label = $VBox/DescLabel

func _ready() -> void:
	visible = false
	var events = get_node_or_null("/root/CombatEvents")
	if events:
		events.perk_activated.connect(_on_perk_activated)

func _on_perk_activated(perk: PerkInstance, message: String) -> void:
	if perk == null:
		return
		
	title_label.text = "⚡ %s ⚡" % perk.definition.perk_name.to_upper()
	desc_label.text = message
	
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	
	var tw = create_tween()
	# Pop in
	tw.parallel().tween_property(self, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Display duration
	tw.tween_interval(1.8)
	# Fade out
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		visible = false
	)
