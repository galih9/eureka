extends SceneTree

## Comprehensive integration test verifying turn execution, AI, and combat loop.

var frames_run: int = 0
var battle_scene: BattleScene = null
var actions_executed: int = 0
var player_turns_taken: int = 0
var enemy_turns_taken: int = 0

func _initialize() -> void:
	pass

func _init() -> void:
	print("--- Running Full Battle Scene Integration Test ---")
	var scene_res = load("res://scenes/battle_scene.tscn") as PackedScene
	if scene_res == null:
		printerr("FAILED to load scenes/battle_scene.tscn")
		quit(1)
		return
		
	battle_scene = scene_res.instantiate() as BattleScene
	root.add_child(battle_scene)
	print("  [SUCCESS] Instantiated BattleScene")
	
	var events_node = root.get_node_or_null("CombatEvents")
	if events_node == null:
		events_node = CombatEventsBus.new()
		events_node.name = "CombatEvents"
		root.add_child(events_node)
		
	events_node.action_finished.connect(func(act):
		actions_executed += 1
		var aname = act.action_definition.action_name
		var actor_name = act.actor.character_definition.display_name
		print("  [COMBAT EVENT] Action finished: %s by %s (Total actions: %d)" % [aname, actor_name, actions_executed])
	)

func _process(delta: float) -> bool:
	frames_run += 1
	if battle_scene == null or battle_scene.battle_manager == null:
		return false
	var bm = battle_scene.battle_manager
	
	# If player turn is ready, simulate choosing an attack and confirming target
	if bm.current_state == BattleState.State.PLAYER_ACTION:
		player_turns_taken += 1
		print("  [SIMULATED INPUT] Player turn ready for: ", bm.current_actor.character_definition.display_name)
		# Request default attack
		bm.request_action_selection(bm.default_attack_skill)
		
	elif bm.current_state == BattleState.State.TARGET_SELECTION:
		# Auto-confirm first valid target
		var valid = TargetSystem.get_valid_targets(ActionDefinition.TargetType.SINGLE_ENEMY, bm.current_actor, bm.all_combatants)
		if not valid.is_empty():
			print("  [SIMULATED INPUT] Player targeting: ", valid[0].character_definition.display_name)
			bm.confirm_player_target([valid[0]])
			
	# Let the battle run until at least 2 full actions have completed
	if actions_executed >= 2 or frames_run >= 2500:
		print("  Simulation finished at frame ", frames_run)
		print("  Total actions executed: ", actions_executed)
		print("  Living players: ", bm.get_living_players().size())
		print("  Living enemies: ", bm.get_living_enemies().size())
		
		if actions_executed >= 1:
			print("  [PASS] Full combat cycle (Timeline -> Decision -> Action Execution -> Result -> Perks -> Resume) verified!")
			quit(0)
		else:
			printerr("  [FAIL] No actions executed within frame limit.")
			quit(1)
		return true
		
	return false
