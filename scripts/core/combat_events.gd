class_name CombatEventsBus
extends Node

## Central combat event bus providing signals for decoupled systems.

signal turn_started(character: Node)
signal turn_ended(character: Node)

signal action_started(action: RefCounted)
signal action_finished(action: RefCounted)

signal attack_hit(result: RefCounted)
signal attack_missed(result: RefCounted)
signal critical_hit(result: RefCounted)
signal action_canceled(target: Node, disruptor: Node, result: RefCounted)


signal damage_dealt(result: RefCounted)
signal damage_taken(result: RefCounted)

signal character_died(character: Node)

signal skill_used(character: Node, skill: Resource)

signal perk_activated(perk: RefCounted, message: String)

signal status_applied(character: Node, status: RefCounted)
signal status_removed(character: Node, status: RefCounted)

signal battle_ended(victory: bool)

signal timeline_progress_updated(combatants: Array)
signal action_line_reached(character: Node)

static func get_bus(context: Node = null) -> CombatEventsBus:
	if context != null and context.is_inside_tree():
		return context.get_node_or_null("/root/CombatEvents") as CombatEventsBus
	var tree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		return tree.root.get_node_or_null("CombatEvents") as CombatEventsBus
	return null
