class_name FormationSystem
extends RefCounted

## Manages the 3 x 4 formation grid (12 slots per side), column-based timeline modifiers,
## archetype movement rules, and spot-targeted evasion checks.

enum ColumnType {
	REAR,
	MIDDLE,
	FRONT
}

const ROWS: int = 4
const COLS: int = 3
const TOTAL_SLOTS: int = 12

# Timeline multipliers
const FRONT_COM_SPEED_MULT: float = 1.30
const REAR_ACT_SPEED_MULT: float = 1.35

# Slot positions arrays: index = col * 4 + row
var player_slots_pos: Array[Vector2] = []
var enemy_slots_pos: Array[Vector2] = []

# Occupancy tracking: index -> BattleCharacter (or null)
var player_occupancy: Array = []
var enemy_occupancy: Array = []

func _init() -> void:
	_init_slots()

func _init_slots() -> void:
	player_slots_pos.clear()
	enemy_slots_pos.clear()
	player_occupancy.clear()
	enemy_occupancy.clear()
	
	player_occupancy.resize(TOTAL_SLOTS)
	player_occupancy.fill(null)
	enemy_occupancy.resize(TOTAL_SLOTS)
	enemy_occupancy.fill(null)
	
	# Player Side (Flipped horizontally):
	# Col 0 (Rear, x=192), Col 1 (Mid, x=332), Col 2 (Front, x=472)
	# Slant: dx = -42, dy = 46
	var player_base_x = [192.0, 332.0, 472.0]
	for col in range(COLS):
		for row in range(ROWS):
			var pos = Vector2(
				player_base_x[col] - float(row) * 42.0,
				280.0 + float(row) * 46.0
			)
			player_slots_pos.append(pos)
			
	# Enemy Side:
	# Col 0 (Front, x=680), Col 1 (Mid, x=820), Col 2 (Rear, x=960)
	# Slant: dx = +42, dy = 46
	var enemy_base_x = [680.0, 820.0, 960.0]
	for col in range(COLS):
		for row in range(ROWS):
			var pos = Vector2(
				enemy_base_x[col] + float(row) * 42.0,
				280.0 + float(row) * 46.0
			)
			enemy_slots_pos.append(pos)

func get_slot_position(team: int, slot_index: int) -> Vector2:
	if slot_index < 0 or slot_index >= TOTAL_SLOTS:
		return Vector2.ZERO
	if team == 0:
		return player_slots_pos[slot_index]
	else:
		return enemy_slots_pos[slot_index]

func get_column_type(team: int, slot_index: int) -> ColumnType:
	var col = slot_index / ROWS
	if team == 0:
		# Player: Col 0 = REAR, Col 1 = MIDDLE, Col 2 = FRONT
		match col:
			2: return ColumnType.FRONT
			1: return ColumnType.MIDDLE
			_: return ColumnType.REAR
	else:
		# Enemy: Col 0 = FRONT, Col 1 = MIDDLE, Col 2 = REAR
		match col:
			0: return ColumnType.FRONT
			1: return ColumnType.MIDDLE
			_: return ColumnType.REAR

func get_timeline_speed_multiplier(character: BattleCharacter, state: BattleCharacter.TimelineState) -> float:
	if character == null or character.formation_slot < 0:
		return 1.0
		
	var col_type = get_column_type(character.team, character.formation_slot)
	match col_type:
		ColumnType.FRONT:
			if state == BattleCharacter.TimelineState.MOVING_TO_COM:
				return FRONT_COM_SPEED_MULT
		ColumnType.REAR:
			if state == BattleCharacter.TimelineState.MOVING_TO_EXECUTION:
				return REAR_ACT_SPEED_MULT
		ColumnType.MIDDLE:
			return 1.0
			
	return 1.0

func occupy_slot(character: BattleCharacter, slot_index: int) -> bool:
	if character == null or slot_index < 0 or slot_index >= TOTAL_SLOTS:
		return false
		
	var occupancy = player_occupancy if character.team == 0 else enemy_occupancy
	
	# Vacate previous slot if any
	vacate_character(character)
	
	occupancy[slot_index] = character
	character.formation_slot = slot_index
	character.global_position = get_slot_position(character.team, slot_index)
	character.position = character.global_position
	character.initial_position = character.global_position
	return true

func vacate_character(character: BattleCharacter) -> void:
	if character == null:
		return
	var occupancy = player_occupancy if character.team == 0 else enemy_occupancy
	for i in range(occupancy.size()):
		if occupancy[i] == character:
			occupancy[i] = null
			break
	character.formation_slot = -1

func is_slot_occupied(team: int, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= TOTAL_SLOTS:
		return true
	var occupancy = player_occupancy if team == 0 else enemy_occupancy
	var occupant = occupancy[slot_index]
	return occupant != null and is_instance_valid(occupant) and not occupant.is_dead

func get_character_at_slot(team: int, slot_index: int) -> BattleCharacter:
	if slot_index < 0 or slot_index >= TOTAL_SLOTS:
		return null
	var occupancy = player_occupancy if team == 0 else enemy_occupancy
	var occupant = occupancy[slot_index]
	if occupant != null and is_instance_valid(occupant) and not occupant.is_dead:
		return occupant
	return null

func get_first_open_slot(team: int) -> int:
	for i in range(TOTAL_SLOTS):
		if not is_slot_occupied(team, i):
			return i
	return -1

## Validates and returns all valid destination slot indices for an actor's Move command.
func get_valid_moves(character: BattleCharacter) -> Array[int]:
	var valid: Array[int] = []
	if character == null or character.formation_slot < 0:
		return valid
		
	var cur_slot = character.formation_slot
	var cur_col = cur_slot / ROWS
	var cur_row = cur_slot % ROWS
	var archetype = character.archetype
	
	for slot_idx in range(TOTAL_SLOTS):
		if slot_idx == cur_slot:
			continue
		if is_slot_occupied(character.team, slot_idx):
			continue
			
		var col = slot_idx / ROWS
		var row = slot_idx % ROWS
		
		match archetype:
			CharacterDefinition.Archetype.BRAWLER:
				# Brawler can only move one tile (Manhattan distance == 1)
				var manhattan = abs(col - cur_col) + abs(row - cur_row)
				if manhattan == 1:
					valid.append(slot_idx)
			_:
				# Striker, Specialist, and other archetypes can move to any unoccupied tile
				valid.append(slot_idx)
				
	return valid

## Checks whether a combatant is still occupying the specified spot.
## Used for defensive evasion / whiff detection when an action arrives.
func is_target_still_at_spot(character: BattleCharacter, expected_slot: int) -> bool:
	if character == null or not is_instance_valid(character) or character.is_dead:
		return false
	return character.formation_slot == expected_slot
