class_name AttackResult
extends RefCounted

var attacker: Node = null # BattleCharacter
var target: Node = null   # BattleCharacter
var hit: bool = false
var critical: bool = false
var damage: int = 0
var damage_type: String = "Physical"
var status_applied: Resource = null # StatusDefinition
var guaranteed_hit: bool = false
var guaranteed_critical: bool = false
var is_heal: bool = false
var was_canceled: bool = false
var pushback_amount: float = 0.0
var disruptor_action: ActionDefinition = null


func is_miss() -> bool:
	return not hit
