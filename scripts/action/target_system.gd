class_name TargetSystem
extends RefCounted

## Resolves valid targets based on TargetType and the actor's team.

static func get_valid_targets(target_type: ActionDefinition.TargetType, actor: Node, all_combatants: Array) -> Array:
	var valid: Array = []
	if actor == null:
		return valid
		
	var actor_team: int = actor.team
	
	for c in all_combatants:
		if c == null or not is_instance_valid(c) or c.is_dead:
			continue

			
		match target_type:
			ActionDefinition.TargetType.SELF:
				if c == actor:
					valid.append(c)
			ActionDefinition.TargetType.SINGLE_ALLY:
				if c.team == actor_team:
					valid.append(c)
			ActionDefinition.TargetType.ALL_ALLIES:
				if c.team == actor_team:
					valid.append(c)
			ActionDefinition.TargetType.SINGLE_ENEMY:
				if c.team != actor_team:
					valid.append(c)
			ActionDefinition.TargetType.ALL_ENEMIES:
				if c.team != actor_team:
					valid.append(c)
					
	return valid

static func is_aoe(target_type: ActionDefinition.TargetType) -> bool:
	return target_type == ActionDefinition.TargetType.ALL_ALLIES or target_type == ActionDefinition.TargetType.ALL_ENEMIES
