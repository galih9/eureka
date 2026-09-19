class_name SkillDefinition
extends ActionDefinition

@export var skill_name: String = "Skill"
@export var power: int = 100
@export var element: String = "Physical"
@export var accuracy: int = 95
@export var critical_chance: float = 0.10
@export var is_heal: bool = false
@export var status_to_apply: Resource # Optional StatusDefinition to apply
@export var status_chance: float = 1.0

func _init() -> void:
	action_type = ActionType.SKILL
