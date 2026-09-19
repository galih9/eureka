class_name BattleState
extends RefCounted

enum State {
	INTRO,
	TIMELINE,
	PLAYER_ACTION,
	TARGET_SELECTION,
	ACTION_EXECUTION,
	ACTION_RESULT,
	PERK_RESOLUTION,
	STATUS_RESOLUTION,
	BATTLE_END
}

static func to_string_name(state: State) -> String:
	match state:
		State.INTRO: return "INTRO"
		State.TIMELINE: return "TIMELINE"
		State.PLAYER_ACTION: return "PLAYER_ACTION"
		State.TARGET_SELECTION: return "TARGET_SELECTION"
		State.ACTION_EXECUTION: return "ACTION_EXECUTION"
		State.ACTION_RESULT: return "ACTION_RESULT"
		State.PERK_RESOLUTION: return "PERK_RESOLUTION"
		State.STATUS_RESOLUTION: return "STATUS_RESOLUTION"
		State.BATTLE_END: return "BATTLE_END"
		_: return "UNKNOWN"
