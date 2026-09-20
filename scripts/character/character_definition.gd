class_name CharacterDefinition
extends Resource

enum Team {
	PLAYER,
	ENEMY
}

enum Archetype {
	NONE,
	BRAWLER,
	STRIKER,
	SPECIALIST
}

@export var codename: String = "HERO"
@export var display_name: String = "Hero"
@export var team: Team = Team.PLAYER
@export var archetype: Archetype = Archetype.NONE
@export var portrait: Texture2D
@export var banner: Texture2D
@export var model_scene: PackedScene

# Base Stats
@export var max_hp: int = 500
@export var max_mp: int = 50
@export var attack: int = 35
@export var defense: int = 15
@export var agility: int = 18
@export var accuracy: int = 90
@export var evasion: int = 10

# Skills and Perks
@export var skills: Array[Resource] = [] # Array[SkillDefinition]
@export var perks: Array[Resource] = []  # Array[PerkDefinition]

# Visual/Chibi Accent Color (for PSX anime palette)
@export var accent_color: Color = Color(0.2, 0.6, 1.0)
