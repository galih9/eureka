class_name FloatingTextSpawner
extends Control

## Spawns stylized 2D damage numbers, critical notices, and miss indicators.

@export var camera: Camera2D

func _ready() -> void:
	var events = get_node_or_null("/root/CombatEvents")
	if events:
		events.damage_dealt.connect(_on_damage_dealt)
		events.attack_missed.connect(_on_attack_missed)
		events.action_canceled.connect(_on_action_canceled)

func _on_damage_dealt(result: AttackResult) -> void:
	if result == null or result.target == null or not is_instance_valid(result.target):
		return
		
	var target_pos = result.target.global_position
	var label = FloatingText.new()
	add_child(label)
	
	if result.is_heal:
		label.setup("+%d HP" % result.damage, target_pos, camera, Color(0.3, 1.0, 0.4))
	elif result.critical:
		label.setup("CRITICAL!\n%d" % result.damage, target_pos, camera, Color(1.0, 0.85, 0.2), true, false)
	else:
		label.setup("%d" % result.damage, target_pos, camera, Color(1.0, 1.0, 1.0), false, false)

func _on_action_canceled(target: Node, _disruptor: Node, _result: RefCounted) -> void:
	if target == null or not is_instance_valid(target):
		return
	var cancel_label = FloatingText.new()
	add_child(cancel_label)
	cancel_label.setup("CANCEL!", target.global_position + Vector2(0, -32.0), camera, Color(1.0, 0.35, 0.15), true, false)


func _on_attack_missed(result: AttackResult) -> void:
	if result == null or result.target == null:
		return
	var target_pos = result.target.global_position
	var label = FloatingText.new()
	add_child(label)
	label.setup("MISS!", target_pos, camera, Color(0.7, 0.8, 1.0), false, true)
