class_name TutorialBattleScene
extends Node2D

## Main scene setup script for the 1v1 tutorial arena scenario.

@onready var battle_manager: Node = $TutorialManager
@onready var camera_controller: BattleCameraController = $BattleCameraController
@onready var battle_ui: BattleUI = $BattleUI
@onready var tutorial_ui: CanvasLayer = $TutorialUI
@onready var players_group: Node2D = $Combatants/Players
@onready var enemies_group: Node2D = $Combatants/Enemies

func _ready() -> void:
	var all_chars: Array = []
	for p in players_group.get_children():
		if p is BattleCharacter:
			all_chars.append(p)
			p.initial_position = p.global_position
			
	for e in enemies_group.get_children():
		if e is BattleCharacter:
			all_chars.append(e)
			e.initial_position = e.global_position
			
	# Connect references
	battle_manager.camera_controller = camera_controller
	battle_manager.enemies_container = enemies_group
	battle_manager.players_container = players_group
	battle_manager.tutorial_ui = tutorial_ui
	
	if camera_controller != null and camera_controller.camera != null:
		battle_ui.camera = camera_controller.camera
		if battle_ui.floating_spawner != null:
			battle_ui.floating_spawner.camera = camera_controller.camera

	# Setup FormationGridVisual in world space
	var grid_visual = FormationGridVisual.new()
	grid_visual.name = "FormationGridVisual"
	grid_visual.camera = camera_controller.camera if camera_controller != null else null
	grid_visual.visible = false
	add_child(grid_visual)
	battle_ui.grid_visual = grid_visual
	grid_visual.slot_clicked.connect(battle_ui._on_grid_slot_clicked)
	grid_visual.move_canceled.connect(battle_ui._on_grid_move_canceled)

	# Initialize battle and UI
	battle_manager.initialize_battle(all_chars)
	battle_ui.connect_battle_manager(battle_manager)
