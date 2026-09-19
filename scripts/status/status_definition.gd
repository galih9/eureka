class_name StatusDefinition
extends Resource

enum StatusType {
	STANDARD,
	STUN,
	SLEEP,
	FLINCH,
	SILENCE,
	DISARM
}

@export var status_id: String = "status"
@export var status_name: String = "Status Effect"
@export var description: String = ""
@export var icon: Texture2D
@export var is_debuff: bool = false
@export var status_type: StatusType = StatusType.STANDARD
@export var duration_turns: int = 3
@export var max_stacks: int = 1
@export var real_time_duration: float = 0.0 # Real-time duration (seconds) for Stun, Flinch
@export var com_charge_count: int = 1       # Number of COM command visits blocked (Silence, Disarm)

# DoT damage (e.g. Bleed, Poison)
@export var dot_flat_damage: int = 0
@export var dot_percent_max_hp: float = 0.0 # e.g. 0.08 = 8% max HP damage per turn

# Stat modifiers
@export var stat_name: String = ""
@export var modifier_percent: float = 0.0 # e.g. 0.20 for +20%
@export var modifier_flat: float = 0.0
