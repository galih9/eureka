class_name StatusInstance
extends RefCounted

var definition: StatusDefinition = null
var owner: Node = null # BattleCharacter
var source: String = ""
var duration: int = 3
var stacks: int = 1
var time_remaining: float = 0.0
var com_charges: int = 1
var modifier_ref: StatModifier = null

func _init(p_definition: StatusDefinition = null, p_owner: Node = null, p_source: String = "") -> void:
	definition = p_definition
	owner = p_owner
	source = p_source
	if definition != null:
		duration = definition.duration_turns
		time_remaining = definition.real_time_duration
		com_charges = definition.com_charge_count

func is_stun() -> bool:
	return definition != null and definition.status_type == StatusDefinition.StatusType.STUN

func is_sleep() -> bool:
	return definition != null and definition.status_type == StatusDefinition.StatusType.SLEEP

func is_flinch() -> bool:
	return definition != null and definition.status_type == StatusDefinition.StatusType.FLINCH

func is_silence() -> bool:
	return definition != null and definition.status_type == StatusDefinition.StatusType.SILENCE

func is_disarm() -> bool:
	return definition != null and definition.status_type == StatusDefinition.StatusType.DISARM
