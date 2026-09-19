class_name BattleAction
extends RefCounted

var actor: Node = null # BattleCharacter
var action_definition: ActionDefinition = null
var targets: Array = [] # Array[BattleCharacter]
var priority: int = 0
var timeline_cost: float = 35.0
var target_slot_indices: Dictionary = {} # BattleCharacter -> int (slot index when scheduled)
var destination_slot: int = -1 # Destination slot for Move action

func _init(p_actor: Node = null, p_action_def: ActionDefinition = null, p_targets: Array = [], p_priority: int = 0, p_dest_slot: int = -1) -> void:
	actor = p_actor
	action_definition = p_action_def
	targets = p_targets
	priority = p_priority
	destination_slot = p_dest_slot
	if action_definition != null:
		timeline_cost = action_definition.timeline_delay
	for t in targets:
		if t != null and "formation_slot" in t:
			target_slot_indices[t] = t.formation_slot
