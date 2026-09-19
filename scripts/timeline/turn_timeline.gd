class_name TurnTimeline
extends RefCounted

## Manages the continuous two-stage Grandia / Child of Light style turn timeline.
## Stage 1: START (0.0) -> COM (100.0) where combatants race to command selection.
## Stage 2: COM (100.0) -> EXECUTION (100.0 + action_delay) where combatants race to execute chosen actions.

signal actor_reached_com(actor: BattleCharacter)
signal action_ready_to_execute(actor: BattleCharacter, action: BattleAction)
signal combatant_added(actor: BattleCharacter)
signal combatant_removed(actor: BattleCharacter)
signal combatant_evicted(actor: BattleCharacter)
signal action_canceled(actor: BattleCharacter, pushback: float)
signal action_line_reached(actor: BattleCharacter) # Legacy signal compatibility

const START_LINE: float = 0.0
const COM_LINE: float = 100.0
const ACTION_LINE: float = 100.0 # Legacy alias for COM line
const MAX_ACTION_DELAY: float = 60.0 # Upper bound for action delay visualization

var timeline_speed: float = 10.0 # Base timeline speed multiplier (tuned for readable pacing)
var combatants: Array = [] # Array[BattleCharacter]
var formation_system: FormationSystem = null

func initialize(characters: Array) -> void:
	combatants.clear()
	for c in characters:
		if c != null and is_instance_valid(c) and not c.is_dead:
			combatants.append(c)
			c.pending_action = null
			c.execution_position = 0.0
			c.timeline_state = BattleCharacter.TimelineState.MOVING_TO_COM
			# Stagger initial positions slightly based on agility
			var agi = c.get_stat("agility")
			c.timeline_position = clamp(float(agi) * 0.7 + randf_range(0.0, 8.0), 0.0, 30.0)

func add_combatant(c: BattleCharacter) -> void:
	if c == null or not is_instance_valid(c) or c.is_dead:
		return
	if c not in combatants:
		combatants.append(c)
		c.timeline_state = BattleCharacter.TimelineState.MOVING_TO_COM
		var agi = c.get_stat("agility")
		c.timeline_position = clamp(float(agi) * 0.5, 0.0, 15.0)
		combatant_added.emit(c)

func remove_combatant(c: BattleCharacter) -> void:
	if c in combatants:
		combatants.erase(c)
		combatant_removed.emit(c)
		combatant_evicted.emit(c)

## Cancels a combatant's action and throws them back behind the command tick (COM_LINE)
## with a pushback amount determined by the disruptor's attack.
func cancel_combatant_action(actor: BattleCharacter, pushback: float) -> void:
	if actor == null or not is_instance_valid(actor) or actor.is_dead:
		return
		
	actor.pending_action = null
	actor.execution_position = 0.0
	actor.timeline_state = BattleCharacter.TimelineState.MOVING_TO_COM
	# Throw back from COM_LINE into WAIT region
	actor.timeline_position = clamp(COM_LINE - pushback, START_LINE, COM_LINE)
	action_canceled.emit(actor, pushback)


## Advances timeline continuously. Returns a Dictionary containing:
## "ready_to_execute": Array[BattleCharacter]
## "reached_com": Array[BattleCharacter]
func advance_timeline(delta: float) -> Dictionary:
	var result = {
		"ready_to_execute": [],
		"reached_com": []
	}
	
	if combatants.is_empty():
		return result
		
	var reached_com: Array = []
	var ready_to_execute: Array = []
	var prev_positions: Dictionary = {}
	
	# Record previous positions to detect passing
	for c in combatants:
		if c != null and is_instance_valid(c) and not c.is_dead:
			prev_positions[c] = c.timeline_position
			StatusSystem.process_timeline_delta(c, delta)
	
	for c in combatants:
		if c == null or not is_instance_valid(c) or c.is_dead:
			continue
			
		var agi = float(c.get_stat("agility"))
		var base_rate = (agi / 18.0) * timeline_speed
		
		# Apply status timeline modifiers
		if StatusSystem.is_stunned(c) or StatusSystem.is_sleeping(c):
			base_rate = 0.0 # Completely halted
		elif StatusSystem.is_flinched(c):
			base_rate *= 0.25 # Heavily slowed down
		
		match c.timeline_state:
			BattleCharacter.TimelineState.MOVING_TO_COM:
				var form_mult = formation_system.get_timeline_speed_multiplier(c, c.timeline_state) if formation_system != null else 1.0
				var rate = base_rate * form_mult
				c.timeline_position += rate * delta
				if c.timeline_position >= COM_LINE:
					c.timeline_position = COM_LINE
					c.timeline_state = BattleCharacter.TimelineState.COMMAND_SELECTION
					reached_com.append(c)
					actor_reached_com.emit(c)
					action_line_reached.emit(c)
					
			BattleCharacter.TimelineState.COMMAND_SELECTION:
				c.timeline_position = COM_LINE
				
			BattleCharacter.TimelineState.MOVING_TO_EXECUTION:
				var form_mult = formation_system.get_timeline_speed_multiplier(c, c.timeline_state) if formation_system != null else 1.0
				var rate = base_rate * form_mult
				c.timeline_position += rate * delta
				if c.timeline_position >= c.execution_position:
					c.timeline_position = c.execution_position
					ready_to_execute.append(c)
					action_ready_to_execute.emit(c, c.pending_action)
					
			BattleCharacter.TimelineState.EXECUTING_ACTION:
				pass
				
	# Check Sleep wake-up condition: wake if passed by any ally
	for c in combatants:
		if c != null and is_instance_valid(c) and not c.is_dead and StatusSystem.is_sleeping(c):
			for ally in combatants:
				if ally != null and is_instance_valid(ally) and ally != c and ally.team == c.team and not ally.is_dead:
					var p_prev = prev_positions.get(ally, 0.0)
					if p_prev < c.timeline_position and ally.timeline_position >= c.timeline_position:
						StatusSystem.wake_from_sleep(c)
						break
				
	# Sort multiple arrivals by agility or overflow distance
	if reached_com.size() > 1:
		reached_com.sort_custom(func(a, b):
			return a.get_stat("agility") > b.get_stat("agility")
		)
		
	if ready_to_execute.size() > 1:
		ready_to_execute.sort_custom(func(a, b):
			var a_overflow = a.timeline_position - a.execution_position
			var b_overflow = b.timeline_position - b.execution_position
			if is_equal_approx(a_overflow, b_overflow):
				return a.get_stat("agility") > b.get_stat("agility")
			return a_overflow > b_overflow
		)
		
	result["ready_to_execute"] = ready_to_execute
	result["reached_com"] = reached_com
	return result

## Assigns a selected action to actor and transitions them into Stage 2 (MOVING_TO_EXECUTION).
func schedule_action(actor: BattleCharacter, action: BattleAction) -> void:
	if actor == null:
		return
		
	action.actor = actor
	actor.pending_action = action
	var delay = action.timeline_cost
	actor.execution_position = COM_LINE + delay
	actor.timeline_state = BattleCharacter.TimelineState.MOVING_TO_EXECUTION

## Returns the actor to START_LINE after action execution completes.
func finish_action(actor: BattleCharacter) -> void:
	if actor == null:
		return
		
	actor.timeline_position = START_LINE
	actor.timeline_state = BattleCharacter.TimelineState.MOVING_TO_COM
	actor.pending_action = null
	actor.execution_position = 0.0

## Backwards compatibility helper for resetting actor position
func reset_actor_position(actor: BattleCharacter, _action_cost: float = 0.0) -> void:
	finish_action(actor)

func calculate_next_position(_action_cost: float) -> float:
	return START_LINE

# --- Timeline State Queries (Source of Truth) ---

func get_combatants_moving_to_com() -> Array:
	var list: Array = []
	for c in combatants:
		if c != null and is_instance_valid(c) and not c.is_dead and c.timeline_state == BattleCharacter.TimelineState.MOVING_TO_COM:
			list.append(c)
	return list

func get_combatants_at_com() -> Array:
	var list: Array = []
	for c in combatants:
		if c != null and is_instance_valid(c) and not c.is_dead and c.timeline_state == BattleCharacter.TimelineState.COMMAND_SELECTION:
			list.append(c)
	return list

func get_combatants_moving_to_execution() -> Array:
	var list: Array = []
	for c in combatants:
		if c != null and is_instance_valid(c) and not c.is_dead and c.timeline_state == BattleCharacter.TimelineState.MOVING_TO_EXECUTION:
			list.append(c)
	return list

func get_pending_actions() -> Array:
	var list: Array = []
	for c in combatants:
		if c != null and is_instance_valid(c) and not c.is_dead and c.pending_action != null:
			list.append(c.pending_action)
	return list

## Simulates upcoming action order (accounting for COM distance + average execution delay).
func simulate_upcoming_order(count: int = 10) -> Array:
	var result: Array = []
	if combatants.is_empty():
		return result
		
	var sim_states: Array = []
	for c in combatants:
		if c != null and is_instance_valid(c) and not c.is_dead:
			var target_pos = c.execution_position if c.timeline_state == BattleCharacter.TimelineState.MOVING_TO_EXECUTION else COM_LINE
			sim_states.append({
				"character": c,
				"position": c.timeline_position,
				"state": c.timeline_state,
				"target_position": target_pos,
				"agility": max(1.0, float(c.get_stat("agility"))),
				"pending_cost": c.pending_action.timeline_cost if c.pending_action != null else 35.0
			})
			
	if sim_states.is_empty():
		return result
		
	for _i in range(count):
		var min_time: float = 999999.0
		var next_idx: int = -1
		
		for idx in range(sim_states.size()):
			var s = sim_states[idx]
			var speed = (s["agility"] / 18.0) * timeline_speed
			var dist = s["target_position"] - s["position"]
			var time_needed = 0.0
			if dist > 0.0:
				time_needed = dist / speed
			else:
				time_needed = 0.0
				
			# If at COM, add time to complete execution
			if s["state"] == BattleCharacter.TimelineState.COMMAND_SELECTION or s["target_position"] == COM_LINE:
				time_needed += s["pending_cost"] / speed
				
			if time_needed < min_time:
				min_time = time_needed
				next_idx = idx
				
		if next_idx == -1:
			break
			
		var chosen_state = sim_states[next_idx]
		result.append(chosen_state["character"])
		
		# Advance others
		for s in sim_states:
			var speed = (s["agility"] / 18.0) * timeline_speed
			s["position"] += speed * min_time
			
		# Reset chosen combatant to start
		chosen_state["position"] = START_LINE
		chosen_state["state"] = BattleCharacter.TimelineState.MOVING_TO_COM
		chosen_state["target_position"] = COM_LINE
		chosen_state["pending_cost"] = 35.0
		
	return result
