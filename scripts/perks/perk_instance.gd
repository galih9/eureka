class_name PerkInstance
extends RefCounted

var definition: PerkDefinition = null
var owner: Node = null # BattleCharacter
var activated: bool = false
var activation_count: int = 0
var remaining_duration: int = 0
var cooldown_remaining: int = 0
var counters: Dictionary = {}
var applied_modifiers: Array = []

func _init(p_definition: PerkDefinition = null, p_owner: Node = null) -> void:
	definition = p_definition
	owner = p_owner
	counters = {}
	applied_modifiers = []

func is_on_cooldown() -> bool:
	return cooldown_remaining > 0

func can_activate() -> bool:
	if owner == null or owner.is_dead:
		return false
	if definition.activation_type == PerkDefinition.ActivationType.ONE_SHOT and activation_count > 0:
		return false
	if is_on_cooldown():
		return false
	return true

func get_counter(key: String, default_val: int = 0) -> int:
	return counters.get(key, default_val)

func set_counter(key: String, val: int) -> void:
	counters[key] = val

func increment_counter(key: String, amount: int = 1) -> int:
	var cur = get_counter(key, 0) + amount
	counters[key] = cur
	return cur

func reset_counter(key: String) -> void:
	counters[key] = 0

func tick_cooldown() -> void:
	if cooldown_remaining > 0:
		cooldown_remaining -= 1

func cleanup_modifiers() -> void:
	if owner != null:
		for mod in applied_modifiers:
			owner.remove_stat_modifier(mod)
	applied_modifiers.clear()
