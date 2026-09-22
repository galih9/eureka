class_name BattleScene
extends Node3D

const CombatAudioManager = preload("res://scripts/audio/combat_audio_manager.gd")

## Main Semi-3D scene setup script wiring combatants, manager, camera, and UI.

@onready var battle_manager: BattleManager = $BattleManager
@onready var camera_controller: BattleCameraController = $BattleCameraController
@onready var battle_ui: BattleUI = $BattleUI
@onready var players_group: Node3D = $Combatants/Players
@onready var enemies_group: Node3D = $Combatants/Enemies
@onready var bgm_player: AudioStreamPlayer = get_node_or_null("BGMPlayer")

@export_group("Battle Audio")
@export var enable_bgm: bool = true
@export var bgm_stream: AudioStream = preload("res://assets/audio/bgm.mp3")
@export_range(-40.0, 6.0, 0.5) var bgm_volume_db: float = -6.0

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
	if camera_controller != null and camera_controller.camera != null:
		battle_ui.camera = camera_controller.camera
		if battle_ui.floating_spawner != null:
			battle_ui.floating_spawner.camera = camera_controller.camera

	# Create FormationGridVisual in 3D world space (child of BattleScene)
	var grid_visual = FormationGridVisual.new()
	grid_visual.name = "FormationGridVisual"
	grid_visual.camera = camera_controller.camera if camera_controller != null else null
	grid_visual.visible = false
	add_child(grid_visual)
	battle_ui.grid_visual = grid_visual
	grid_visual.slot_clicked.connect(battle_ui._on_grid_slot_clicked)
	grid_visual.move_canceled.connect(battle_ui._on_grid_move_canceled)

	# Connect UI to battle manager
	battle_ui.connect_battle_manager(battle_manager)

	# Setup Battle BGM & Combat Audio
	_setup_battle_bgm()
	_setup_combat_audio()

	# Initialize battle (populates combatants, starts intro camera & UI sequence)
	battle_manager.initialize_battle(all_chars)

func _setup_combat_audio() -> void:
	if CombatAudioManager.get_manager(self) == null:
		var cam = CombatAudioManager.new()
		cam.name = "CombatAudio"
		add_child(cam)

func _setup_battle_bgm() -> void:
	if not enable_bgm:
		return
	if bgm_player == null:
		bgm_player = get_node_or_null("BGMPlayer") as AudioStreamPlayer
	if bgm_player == null:
		bgm_player = AudioStreamPlayer.new()
		bgm_player.name = "BGMPlayer"
		add_child(bgm_player)
		
	if bgm_player.stream == null and bgm_stream != null:
		bgm_player.stream = bgm_stream
		
	if bgm_player.stream is AudioStreamMP3:
		(bgm_player.stream as AudioStreamMP3).loop = true
		
	bgm_player.volume_db = bgm_volume_db
	bgm_player.bus = &"Master"
	
	if not bgm_player.finished.is_connected(_on_bgm_finished):
		bgm_player.finished.connect(_on_bgm_finished)
		
	# Connect to BattleUI signal for "Battle Start" banner (fail-safe)
	if battle_ui != null and battle_ui.has_signal("battle_start_displayed"):
		if not battle_ui.battle_start_displayed.is_connected(play_bgm):
			battle_ui.battle_start_displayed.connect(play_bgm)
			
	# Also connect to BattleManager state change as guarantee
	if battle_manager != null:
		if not battle_manager.state_changed.is_connected(_on_battle_state_changed_for_bgm):
			battle_manager.state_changed.connect(_on_battle_state_changed_for_bgm)
		if not battle_manager.battle_finished.is_connected(_on_battle_finished_for_bgm):
			battle_manager.battle_finished.connect(_on_battle_finished_for_bgm)

	# Start BGM immediately at scene start / load completion
	play_bgm()

func play_bgm() -> void:
	if not enable_bgm or bgm_player == null:
		return
	if not bgm_player.playing:
		bgm_player.volume_db = bgm_volume_db
		bgm_player.play()

func fade_out_bgm(duration: float = 1.0) -> void:
	if bgm_player == null or not bgm_player.playing:
		return
	var tw = create_tween()
	tw.tween_property(bgm_player, "volume_db", -45.0, duration)
	tw.tween_callback(func():
		if bgm_player:
			bgm_player.stop()
			bgm_player.volume_db = bgm_volume_db
	)

func _on_bgm_finished() -> void:
	if enable_bgm and bgm_player != null and is_inside_tree():
		bgm_player.play()

func _on_battle_state_changed_for_bgm(new_state: BattleState.State) -> void:
	if new_state == BattleState.State.TIMELINE:
		play_bgm()

func _on_battle_finished_for_bgm(_victory: bool) -> void:
	fade_out_bgm(1.2)

