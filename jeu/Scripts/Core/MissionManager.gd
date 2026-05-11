class_name MissionManager
extends Node

## Owns mission state, generation, timers and result processing.
## Communicates results to PlayerData through signals caught by GlobalEngine.

# ── Signals ───────────────────────────────────────────────────────────────────

signal mission_completed(xp_reward: int, stat_name: String, stat_amount: int)
signal mission_failed(hp_lost: int)
signal missions_changed

# ── State ─────────────────────────────────────────────────────────────────────

var all_missions: Dictionary = {}
var available_missions: Array = []
var available_weekly_missions: Array = []

# ── Timers ────────────────────────────────────────────────────────────────────

var reset_duration: float = 14400.0          # 4 heures
var time_until_reset: float = reset_duration

var weekly_reset_duration: float = 604800.0  # 7 jours
var time_until_weekly_reset: float = weekly_reset_duration

# ── Internal reference ────────────────────────────────────────────────────────

var _player: PlayerData = null

# ── Setup ─────────────────────────────────────────────────────────────────────

## Must be called by GlobalEngine before any other method.
func initialize(player_data: PlayerData) -> void:
	_player = player_data

# ── Godot lifecycle ───────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if time_until_reset > 0.0:
		time_until_reset -= delta
	else:
		_reset_daily()

	if time_until_weekly_reset > 0.0:
		time_until_weekly_reset -= delta
	else:
		_reset_weekly()

# ── Mission loading ───────────────────────────────────────────────────────────

func load_all_missions() -> void:
	var path := "res://Data/Missions/"
	if not DirAccess.dir_exists_absolute(path): return
	var dir := DirAccess.open(path)
	if not dir: return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var mission := load(path + file_name) as MissionData
			if mission: all_missions[mission.id] = mission
		file_name = dir.get_next()

# ── Mission generation ────────────────────────────────────────────────────────

func generate_missions() -> void:
	if not _player: return
	var rank_int := _player.get_rank_index(_player.lvl)

	if available_missions.is_empty():
		var daily_pool: Array = all_missions.values().filter(
			func(m): return m.type == 0 and m.rank <= rank_int
		)
		daily_pool.shuffle()
		for i in range(mini(5, daily_pool.size())):
			available_missions.append({
				"id": daily_pool[i].id,
				"status": "available",
				"end_cost": 15
			})

	if available_weekly_missions.is_empty():
		var weekly_pool: Array = all_missions.values().filter(
			func(m): return m.type == 1 and m.rank <= rank_int
		)
		if not weekly_pool.is_empty():
			weekly_pool.shuffle()
			available_weekly_missions.append({
				"id": weekly_pool[0].id,
				"status": "available",
				"end_cost": 40
			})

# ── Mission actions ───────────────────────────────────────────────────────────

func accept_mission(mission_dict: Dictionary) -> bool:
	var m_data: MissionData = all_missions.get(mission_dict.id)
	if not m_data: return false
	if _player.hp <= 0: return false
	if _player.stamina < mission_dict.end_cost: return false

	# Vérifie les pré-requis de stats
	var req_map := {
		"str": m_data.req_str, "dex": m_data.req_dex, "vit": m_data.req_end,
		"int": m_data.req_int, "wis": m_data.req_wis, "cha": m_data.req_cha,
		"per": m_data.req_per, "wil": m_data.req_wil
	}
	for stat_key in req_map:
		if _player.get_final_stat(stat_key) < req_map[stat_key]:
			return false

	_player.stamina -= mission_dict.end_cost
	mission_dict["status"] = "in_progress"
	_player.stats_updated.emit()
	return true

func process_result(mission_dict: Dictionary, success: bool) -> void:
	var m_data: MissionData = all_missions.get(mission_dict.id)
	if not m_data: return

	if success:
		var stat_name := ""
		var stat_amount := 0
		if m_data.reward_stat != 0:
			var stat_keys := ["", "str", "dex", "vit", "int", "wis", "cha", "per", "wil"]
			stat_name   = stat_keys[m_data.reward_stat]
			stat_amount = m_data.reward_stat_amount
			_player.base_stats[stat_name] += stat_amount
			_player.update_derived_stats()
		_player.add_xp(m_data.base_xp)
		mission_completed.emit(m_data.base_xp, stat_name, stat_amount)
		mission_dict["status"] = "completed"
	else:
		_player.take_damage(20)
		mission_dict["status"] = "failed"
		mission_failed.emit(20)

	_player.stats_updated.emit()

# ── Timer strings ─────────────────────────────────────────────────────────────

func get_time_string() -> String:
	var ts := int(time_until_reset)
	return "%02d:%02d:%02d" % [ts / 3600, (ts % 3600) / 60, ts % 60]

func get_weekly_time_string() -> String:
	var ts   := int(time_until_weekly_reset)
	var days := ts / 86400
	var hrs  := (ts % 86400) / 3600
	var mins := (ts % 3600) / 60
	var secs := ts % 60
	return "%d Jours - %02d:%02d:%02d" % [days, hrs, mins, secs]

# ── Debug ─────────────────────────────────────────────────────────────────────

func debug_reset_daily() -> void:
	time_until_reset = 0.0

func debug_reset_weekly() -> void:
	time_until_weekly_reset = 0.0

# ── Private ───────────────────────────────────────────────────────────────────

func _reset_daily() -> void:
	time_until_reset = reset_duration
	available_missions.clear()
	generate_missions()
	missions_changed.emit()

func _reset_weekly() -> void:
	time_until_weekly_reset = weekly_reset_duration
	available_weekly_missions.clear()
	generate_missions()
	missions_changed.emit()
