class_name EnemyInfoUI
extends PanelContainer

## Top-right card showing targeted combatant details.

@onready var name_label: Label = $VBox/NameLabel
@onready var hp_bar: ProgressBar = $VBox/HPBar
@onready var hp_label: Label = $VBox/HPBar/HPLabel
@onready var status_label: Label = $VBox/StatusLabel

func _ready() -> void:
	visible = false

func show_target_info(target: BattleCharacter) -> void:
	if target == null:
		visible = false
		return
		
	visible = true
	var def = target.character_definition
	name_label.text = target.get_display_name() if target.has_method("get_display_name") else (def.display_name if def != null else "Combatant")
	
	var max_hp = target.get_stat("max_hp")
	hp_bar.max_value = max_hp
	hp_bar.value = target.current_hp
	hp_label.text = "%d / %d" % [target.current_hp, max_hp]
	
	var status_texts: Array[String] = []
	for s in target.active_statuses:
		status_texts.append("%s (%d)" % [s.definition.status_name, s.duration])
	if target.is_defending:
		status_texts.append("Defending")
		
	if status_texts.is_empty():
		status_label.text = "Status: Normal"
	else:
		status_label.text = "Status: " + ", ".join(status_texts)

func hide_target_info() -> void:
	visible = false
