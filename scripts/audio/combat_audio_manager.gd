class_name CombatAudioManager
extends Node

## Centralized audio manager handling combat attack, hit, miss, and critical SFX.
## Features polyphonic audio pooling, non-repeating variant selection,
## subtle pitch variation to prevent ear fatigue, and decoupled event listening.

static var instance: CombatAudioManager = null

@export_group("Audio Settings")
@export var enabled: bool = true
@export var audio_bus: StringName = &"Master"
@export var pool_size: int = 8:
	set(value):
		pool_size = value
		_init_pool()

@export_group("Volumes (dB)")
@export_range(-40.0, 6.0, 0.5) var hit_volume_db: float = -1.0
@export_range(-40.0, 6.0, 0.5) var miss_volume_db: float = 0.0
@export_range(-40.0, 6.0, 0.5) var crit_volume_db: float = 1.5

@export_group("Pitch Variation")
@export var enable_pitch_variance: bool = true
@export_range(0.8, 1.2, 0.01) var pitch_min: float = 0.96
@export_range(0.8, 1.2, 0.01) var pitch_max: float = 1.04

@export_group("Audio Streams")
@export var hit_streams: Array[AudioStream] = [
	preload("res://assets/audio/sword_hit.mp3"),
	preload("res://assets/audio/sword_hit2.mp3")
]
@export var miss_streams: Array[AudioStream] = [
	preload("res://assets/audio/sword_miss.mp3")
]
@export var crit_streams: Array[AudioStream] = [
	preload("res://assets/audio/crit.mp3"),
	preload("res://assets/audio/crit_2.mp3")
]

var _players: Array[AudioStreamPlayer] = []
var _round_robin_index: int = 0
var _last_hit_index: int = -1
var _last_crit_index: int = -1
var _last_miss_index: int = -1

func _init() -> void:
	_init_pool()

func _enter_tree() -> void:
	if instance == null:
		instance = self
	if _players.is_empty():
		_init_pool()

func _exit_tree() -> void:
	if instance == self:
		instance = null

func _ready() -> void:
	if _players.is_empty():
		_init_pool()
	_connect_combat_events()

## Factory / singleton accessor allowing decoupled lookup anywhere in the codebase.
static func get_manager(context: Node = null) -> CombatAudioManager:
	if context != null:
		var local = context.get_node_or_null("CombatAudio") as CombatAudioManager
		if local != null:
			return local
		if context.is_inside_tree():
			var node = context.get_node_or_null("/root/CombatAudio") as CombatAudioManager
			if node != null:
				return node
	var tree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var node = tree.root.get_node_or_null("CombatAudio") as CombatAudioManager
		if node != null:
			return node
	return instance

## Pre-allocates a pool of AudioStreamPlayers to prevent audio clipping during rapid / AoE hits.
func _init_pool() -> void:
	# Clean existing if re-initializing
	for p in _players:
		if is_instance_valid(p):
			p.queue_free()
	_players.clear()

	for i in range(pool_size):
		var player = AudioStreamPlayer.new()
		player.name = "CombatSFXPlayer_%d" % i
		player.bus = audio_bus
		add_child(player)
		_players.append(player)

## Connects to the global CombatEventsBus for automatic attack audio handling.
func _connect_combat_events() -> void:
	var events: CombatEventsBus = null
	if has_node("/root/CombatEvents"):
		events = get_node("/root/CombatEvents") as CombatEventsBus
	elif CombatEventsBus != null:
		events = CombatEventsBus.get_bus(self)

	if events != null:
		connect_events(events)

## Explicitly connects to a CombatEventsBus instance (e.g. In custom scenes or tests).
func connect_events(events: CombatEventsBus) -> void:
	if events == null:
		return
	if not events.attack_hit.is_connected(_on_combat_attack_hit):
		events.attack_hit.connect(_on_combat_attack_hit)
	if not events.critical_hit.is_connected(_on_combat_critical_hit):
		events.critical_hit.connect(_on_combat_critical_hit)
	if not events.attack_missed.is_connected(_on_combat_attack_missed):
		events.attack_missed.connect(_on_combat_attack_missed)

func _on_combat_attack_hit(result: AttackResult) -> void:
	# If this hit was a critical hit, let _on_combat_critical_hit handle it so it doesn't double-play
	if result != null and result.critical:
		return
	play_hit()

func _on_combat_critical_hit(_result: AttackResult) -> void:
	play_crit()

func _on_combat_attack_missed(_result: AttackResult) -> void:
	play_miss()

## Play a regular attack sword hit sound with smart variant rotation.
func play_hit(volume_offset_db: float = 0.0) -> AudioStreamPlayer:
	if hit_streams.is_empty():
		return null
	var stream = _pick_variant(hit_streams, _last_hit_index)
	_last_hit_index = hit_streams.find(stream)
	return play_sfx(stream, hit_volume_db + volume_offset_db)

## Play a critical strike sound with smart variant rotation.
func play_crit(volume_offset_db: float = 0.0) -> AudioStreamPlayer:
	if crit_streams.is_empty():
		return null
	var stream = _pick_variant(crit_streams, _last_crit_index)
	_last_crit_index = crit_streams.find(stream)
	return play_sfx(stream, crit_volume_db + volume_offset_db)

## Play an attack miss / whiff sound.
func play_miss(volume_offset_db: float = 0.0) -> AudioStreamPlayer:
	if miss_streams.is_empty():
		return null
	var stream = _pick_variant(miss_streams, _last_miss_index)
	_last_miss_index = miss_streams.find(stream)
	return play_sfx(stream, miss_volume_db + volume_offset_db)

## Plays an AudioStream using an available AudioStreamPlayer from the pool.
func play_sfx(stream: AudioStream, volume_db: float = 0.0, apply_pitch_variance: bool = true) -> AudioStreamPlayer:
	if not enabled or stream == null:
		return null

	var player = _get_available_player()
	if player == null:
		return null

	player.stream = stream
	player.volume_db = volume_db
	player.bus = audio_bus

	if enable_pitch_variance and apply_pitch_variance:
		player.pitch_scale = randf_range(pitch_min, pitch_max)
	else:
		player.pitch_scale = 1.0

	if player.is_inside_tree():
		player.play()
	return player

## Retrieves an idle player from the pool, or steals using round-robin if all are busy.
func _get_available_player() -> AudioStreamPlayer:
	if _players.is_empty():
		_init_pool()
	if _players.is_empty():
		return null

	for p in _players:
		if not p.playing:
			return p

	# All busy: recycle via round robin
	var player = _players[_round_robin_index % _players.size()]
	_round_robin_index = (_round_robin_index + 1) % _players.size()
	return player

## Chooses a variant, avoiding consecutive repeats when 2 or more options exist.
func _pick_variant(stream_list: Array[AudioStream], last_index: int) -> AudioStream:
	var count = stream_list.size()
	if count == 0:
		return null
	if count == 1:
		return stream_list[0]

	var new_index = randi() % count
	if new_index == last_index:
		new_index = (new_index + 1 + randi() % (count - 1)) % count

	return stream_list[new_index]
