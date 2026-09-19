class_name PerkDefinition
extends Resource

enum ActivationType {
	ONE_SHOT,
	TEMPORARY,
	PERMANENT,
	COOLDOWN
}

@export var perk_id: String = "perk"
@export var perk_name: String = "Perk"
@export var description: String = ""
@export var icon: Texture2D
@export var activation_type: ActivationType = ActivationType.ONE_SHOT
@export var duration_turns: int = 0
@export var cooldown_turns: int = 0

# Configurable parameters for conditions and effects
@export var params: Dictionary = {}
