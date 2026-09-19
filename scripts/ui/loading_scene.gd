class_name LoadingScene
extends Control

## Asynchronous loading scene with smooth progress visualization and gameplay tips.

const TARGET_SCENE_PATH: String = "res://scenes/battle_scene.tscn"
const MIN_LOADING_TIME: float = 1.0

@onready var progress_bar: ProgressBar = %ProgressBar
@onready var tip_label: Label = %TipLabel
@onready var status_label: Label = %StatusLabel

var progress_array: Array = []
var display_progress: float = 0.0
var elapsed_time: float = 0.0
var is_loaded: bool = false
var loaded_resource: PackedScene = null

var tips: Array[String] = [
	"Grandia Timeline: Combatants advance from WAIT to CMD based on Agility.",
	"CMD Phase: Selecting skills schedules your charge towards ACT.",
	"Action Timing: Stronger skills have higher delay to reach the ACT line.",
	"Positioning: Red tokens represent enemies; varied pastel tokens represent your squad."
]

func _ready() -> void:
	if not tips.is_empty():
		tip_label.text = tips[randi() % tips.size()]
		
	progress_bar.value = 0.0
	status_label.text = "LOADING BATTLE ARENA..."
	
	# Request threaded load
	ResourceLoader.load_threaded_request(TARGET_SCENE_PATH)

func _process(delta: float) -> void:
	elapsed_time += delta
	
	var status = ResourceLoader.load_threaded_get_status(TARGET_SCENE_PATH, progress_array)
	var real_progress = 0.0
	if not progress_array.is_empty():
		real_progress = progress_array[0]
		
	# Minimum display progress ramp up to avoid instant flashing
	var time_ratio = clamp(elapsed_time / MIN_LOADING_TIME, 0.0, 1.0)
	var target_progress = max(real_progress, time_ratio)
	display_progress = lerp(display_progress, target_progress, delta * 8.0)
	progress_bar.value = display_progress * 100.0
	
	if status == ResourceLoader.THREAD_LOAD_LOADED and elapsed_time >= MIN_LOADING_TIME and not is_loaded:
		is_loaded = true
		loaded_resource = ResourceLoader.load_threaded_get(TARGET_SCENE_PATH) as PackedScene
		status_label.text = "READY! ENTERING COMBAT..."
		
		# Short smooth fade out before scene switch
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func():
			if loaded_resource != null:
				get_tree().change_scene_to_packed(loaded_resource)
			else:
				get_tree().change_scene_to_file(TARGET_SCENE_PATH)
		)
	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		status_label.text = "ERROR LOADING BATTLE SCENE"
