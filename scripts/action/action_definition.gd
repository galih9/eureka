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
@export var vfx_animation: String = ""

func get_cast_speed_label() -> String:
	if timeline_delay <= 25.0:
		return "SHORT"
	elif timeline_delay <= 45.0:
		return "AVERAGE"
	else:
		return "LONG"

func get_vfx_name(actor: BattleCharacter = null) -> StringName:
	if vfx_animation != "":
		return StringName(vfx_animation)
		
	var a_lower = action_name.to_lower()
	if "punch" in a_lower or "tackle" in a_lower or "smash" in a_lower or "slam" in a_lower:
		return &"punch"
	if "heavy" in a_lower or "big" in a_lower:
		return &"slash_v"
	if "quick" in a_lower or "dart" in a_lower or "shot" in a_lower:
		return &"slash_small"
	if "area" in a_lower or "sweep" in a_lower or "horizontal" in a_lower:
		return &"slash_h"
		
	if actor != null:
		var codename = actor.character_definition.codename.to_lower() if actor.character_definition != null else ""
		if "roy" in codename or "brawler" in codename:
			return &"punch"
		if "slime" in codename:
			return &"punch"
		if "jacob" in codename:
			return &"slash_small"
			
	return &"slash"
