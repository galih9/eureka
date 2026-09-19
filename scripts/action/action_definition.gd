class_name ActionDefinition
extends Resource

enum ActionType {
	ATTACK,
	SKILL,
	DEFEND,
	ITEM,
	MOVE
}

enum TargetType {
	SELF,
	SINGLE_ALLY,
	ALL_ALLIES,
	SINGLE_ENEMY,
	ALL_ENEMIES,
	FORMATION_SLOT
}

enum CastSpeed {
	SHORT,
	AVERAGE,
	LONG
}

@export var action_name: String = "Action"
@export var description: String = ""
@export var action_type: ActionType = ActionType.ATTACK
@export var target_type: TargetType = TargetType.SINGLE_ENEMY
@export var mp_cost: int = 0
@export var timeline_delay: float = 35.0
@export var is_melee: bool = true
@export var icon: Texture2D

func get_cast_speed_label() -> String:
	if timeline_delay <= 25.0:
		return "SHORT"
	elif timeline_delay <= 45.0:
		return "AVERAGE"
	else:
		return "LONG"
