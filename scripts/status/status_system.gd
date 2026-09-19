class_name StatusSystem
extends RefCounted

## Manages status application, tick processing, and cleanup.

static func apply_status(character: Node, status_def: StatusDefinition, source: String = "") -> StatusInstance:
	if character == null or character.is_dead or status_def == null:
		return null
		
	# Check if already has status
	for active in character.active_statuses:
		if active.definition.status_id == status_def.status_id:
			# Refresh duration and handle stacks
			active.duration = status_def.duration_turns
			if active.stacks < status_def.max_stacks:
				active.stacks += 1
			return active
			
	var instance = StatusInstance.new(status_def, character, source)
	
	# Apply stat modifier if defined
	if status_def.stat_name != "" and (status_def.modifier_percent != 0.0 or status_def.modifier_flat != 0.0):
		var mod_type = StatModifier.Type.PERCENT if status_def.modifier_percent != 0.0 else StatModifier.Type.FLAT
		var mod_val = status_def.modifier_percent if status_def.modifier_percent != 0.0 else status_def.modifier_flat
		var mod = StatModifier.new(status_def.stat_name, mod_type, mod_val, "status_" + status_def.status_id)
		character.add_stat_modifier(mod)
		instance.modifier_ref = mod
		
	character.active_statuses.append(instance)
	
	if character.has_method("refresh_overhead_status"):
		character.refresh_overhead_status()
		
	var events = CombatEventsBus.get_bus(character)
	if events:
		events.status_applied.emit(character, instance)
		
	return instance

static func remove_status(character: Node, instance: StatusInstance) -> void:
	if character == null or instance == null:
		return
		
	if instance.modifier_ref != null:
		character.remove_stat_modifier(instance.modifier_ref)
		instance.modifier_ref = null
		
	character.active_statuses.erase(instance)
	
	if character.has_method("refresh_overhead_status"):
		character.refresh_overhead_status()
		
	var events = CombatEventsBus.get_bus(character)
	if events:
		events.status_removed.emit(character, instance)

## Advances real-time durations (e.g. Stun and Flinch) along the continuous timeline
static func process_timeline_delta(character: Node, delta: float) -> void:
	if character == null or character.is_dead:
		return
		
	var to_remove: Array = []
	for instance in character.active_statuses:
		if instance.definition.real_time_duration > 0.0:
			instance.time_remaining -= delta
			if instance.time_remaining <= 0.0:
				to_remove.append(instance)
				
	for rem in to_remove:
		remove_status(character, rem)

## Decrements COM visit charges (e.g. Silence, Disarm) when character reaches COM
static func process_com_reached(character: Node) -> void:
	if character == null or character.is_dead:
		return
		
	var to_remove: Array = []
	for instance in character.active_statuses:
		if instance.is_silence() or instance.is_disarm():
			instance.com_charges -= 1
			if instance.com_charges <= 0:
				to_remove.append(instance)
				
	for rem in to_remove:
		remove_status(character, rem)

## Wakes up sleeping character (called on ally pass or taking damage)
static func wake_from_sleep(character: Node) -> void:
	if character == null:
		return
	var to_remove: Array = []
	for instance in character.active_statuses:
		if instance.is_sleep():
			to_remove.append(instance)
	for rem in to_remove:
		remove_status(character, rem)

# --- Status Type Queries ---

static func is_stunned(character: Node) -> bool:
	if character == null or character.is_dead:
		return false
	for instance in character.active_statuses:
		if instance.is_stun():
			return true
	return false

static func is_sleeping(character: Node) -> bool:
	if character == null or character.is_dead:
		return false
	for instance in character.active_statuses:
		if instance.is_sleep():
			return true
	return false

static func is_flinched(character: Node) -> bool:
	if character == null or character.is_dead:
		return false
	for instance in character.active_statuses:
		if instance.is_flinch():
			return true
	return false

static func is_silenced(character: Node) -> bool:
	if character == null or character.is_dead:
		return false
	for instance in character.active_statuses:
		if instance.is_silence():
			return true
	return false

static func is_disarmed(character: Node) -> bool:
	if character == null or character.is_dead:
		return false
	for instance in character.active_statuses:
		if instance.is_disarm():
			return true
	return false

static func has_status_id(character: Node, status_id: String) -> bool:
	if character == null or character.is_dead:
		return false
	for instance in character.active_statuses:
		if instance.definition.status_id == status_id:
			return true
	return false

static func process_turn_start(character: Node) -> Array:
	var logs: Array = []
	if character == null or character.is_dead:
		return logs
		
	var to_remove: Array = []
	
	for instance in character.active_statuses:
		var sdef: StatusDefinition = instance.definition
		
		# Process DoT (Bleed / Poison)
		var dot_amount: int = 0
		if sdef.dot_flat_damage > 0:
			dot_amount += sdef.dot_flat_damage * instance.stacks
		if sdef.dot_percent_max_hp > 0.0:
			var max_hp = character.get_stat("max_hp")
			dot_amount += int(max_hp * sdef.dot_percent_max_hp * instance.stacks)
			
		if dot_amount > 0:
			var dmg_taken = character.take_damage(dot_amount, sdef.status_name)
			logs.append({"type": "dot", "name": sdef.status_name, "damage": dmg_taken})
			
		# Decrement turn duration for standard turn-based statuses
		if sdef.status_type == StatusDefinition.StatusType.STANDARD:
			instance.duration -= 1
			if instance.duration <= 0:
				to_remove.append(instance)
			
	for rem in to_remove:
		remove_status(character, rem)
		logs.append({"type": "expire", "name": rem.definition.status_name})
		
	return logs

static func clear_all(character: Node) -> void:
	if character == null:
		return
	var list_copy = character.active_statuses.duplicate()
	for instance in list_copy:
		remove_status(character, instance)
	if character.has_method("refresh_overhead_status"):
		character.refresh_overhead_status()
