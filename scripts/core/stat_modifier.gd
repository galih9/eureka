class_name StatModifier
extends RefCounted

enum Type {
	FLAT,
	PERCENT
}

var stat_name: String = ""
var type: Type = Type.FLAT
var value: float = 0.0
var source_id: String = ""

func _init(p_stat_name: String = "", p_type: Type = Type.FLAT, p_value: float = 0.0, p_source_id: String = "") -> void:
	stat_name = p_stat_name
	type = p_type
	value = p_value
	source_id = p_source_id
