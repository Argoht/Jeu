class_name MissionManager
extends Node

## Owns mission state, generation, timers and result processing.
## Uses duck typing for PlayerData to avoid class_name circular dependencies.

# ── Signals ───────────────────────────────────────────────────────────────────

signal mission_completed(xp_reward: int, stat_name: String, stat_amount: int)
signal mission_failed(hp_lost: int)
signal missions_changed

# ── State ─────────────────────────────────────────────────────────────────────

var all_missions: Dictionary = {}
var available_missions: Array = []
var available_weekly_missions: Array = []
var mission_history: Dictionary = {
	"completed_total": 0,
	"failed_total": 0,
	"current_streak": 0,
	"best_streak": 0,
	"last_success_day": -1,
	"entries": [],
	"by_mission": {},
}

const DAILY_MISSION_TARGET := 5
const WEEKLY_MISSION_TARGET := 1
const HISTORY_LIMIT := 50
const DAILY_FULL_REWARD_LIMIT := 10
const DAILY_AD_REWARD_LIMIT := 2
const REQUIRED_MISSIONS: Array[MissionData] = [
	preload("res://Data/Missions/F/f_reveil.tres"),
	preload("res://Data/Missions/F/f_meditation.tres"),
	preload("res://Data/Missions/F/f_respiration.tres"),
	preload("res://Data/Missions/F/f_marche.tres"),
	preload("res://Data/Missions/F/f_lecture_base.tres"),
	preload("res://Data/Missions/F/f_hebdo_fondation.tres"),
]

# ── Timers ────────────────────────────────────────────────────────────────────

var reset_duration: float = 14400.0          # 4 heures
var time_until_reset: float = reset_duration

var weekly_reset_duration: float = 604800.0  # 7 jours
var time_until_weekly_reset: float = weekly_reset_duration

# ── Internal reference (duck-typed PlayerData) ────────────────────────────────

var _player = null

# ── Setup ─────────────────────────────────────────────────────────────────────

func initialize(player_data) -> void:
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
	all_missions.clear()
	_register_required_missions()
	_load_missions_from_dir(path)

func sanitize_available_missions() -> void:
	_sanitize_mission_list(available_missions, 15)
	_sanitize_mission_list(available_weekly_missions, 40)
	_normalize_history()

func _sanitize_mission_list(list: Array, default_end_cost: int) -> void:
	for i in range(list.size() - 1, -1, -1):
		var mission = list[i]
		if typeof(mission) != TYPE_DICTIONARY:
			list.remove_at(i)
			continue

		var mission_id := String(mission.get("id", ""))
		if mission_id.is_empty() or not all_missions.has(mission_id):
			list.remove_at(i)
			continue

		if not mission.has("status"):
			mission["status"] = "available"
		if not mission.has("end_cost"):
			mission["end_cost"] = default_end_cost
		_sanitize_session_fields(mission)

func _sanitize_session_fields(mission: Dictionary) -> void:
	var status := String(mission.get("status", "available"))
	if status != "in_progress":
		return
	if not mission.has("started_at"):
		mission["started_at"] = Time.get_unix_time_from_system()
	if not mission.has("progress_amount"):
		mission["progress_amount"] = 0
	if not mission.has("proof_text"):
		mission["proof_text"] = ""

func _load_missions_from_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if not dir: return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				_load_missions_from_dir(path.path_join(file_name))
		elif file_name.ends_with(".tres"):
			var mission := load(path.path_join(file_name)) as MissionData
			if mission:
				all_missions[mission.id] = mission
		file_name = dir.get_next()

# ── Mission generation ────────────────────────────────────────────────────────

func generate_missions() -> void:
	if not _player: return
	if all_missions.is_empty():
		load_all_missions()
	sanitize_available_missions()
	var rank_int: int = _player.get_rank_index(_player.lvl)

	if _needs_fresh_missions(available_missions):
		available_missions.clear()
	_fill_mission_slots(available_missions, 0, rank_int, DAILY_MISSION_TARGET, 15)

	if _needs_fresh_missions(available_weekly_missions):
		available_weekly_missions.clear()
	_fill_mission_slots(available_weekly_missions, 1, rank_int, WEEKLY_MISSION_TARGET, 40)

func ensure_missions_available() -> bool:
	var before_daily := _mission_list_signature(available_missions)
	var before_weekly := _mission_list_signature(available_weekly_missions)
	var before_all := all_missions.size()
	if all_missions.is_empty():
		load_all_missions()
	generate_missions()
	var changed := before_daily != _mission_list_signature(available_missions) or before_weekly != _mission_list_signature(available_weekly_missions) or before_all != all_missions.size()
	if changed:
		missions_changed.emit()
	return changed

# ── Mission actions ───────────────────────────────────────────────────────────

func accept_mission(mission_dict: Dictionary) -> bool:
	var m_data: MissionData = all_missions.get(String(mission_dict.get("id", ""))) as MissionData
	if not m_data: return false
	if _player.hp <= 0: return false
	var end_cost := int(mission_dict.get("end_cost", 0))
	if not _player.can_spend_stamina(end_cost): return false

	var req_map := m_data.get_requirement_map()
	for stat_key in req_map:
		if _player.get_final_stat(stat_key) < req_map[stat_key]:
			return false

	if not _player.spend_stamina(end_cost):
		return false

	mission_dict["status"] = "in_progress"
	mission_dict["started_at"] = Time.get_unix_time_from_system()
	mission_dict["progress_amount"] = 0
	mission_dict["proof_text"] = ""
	mission_dict["completed_at"] = 0
	missions_changed.emit()
	return true

func process_result(mission_dict: Dictionary, success: bool) -> bool:
	var m_data: MissionData = all_missions.get(String(mission_dict.get("id", ""))) as MissionData
	if not m_data:
		return false

	if success:
		var validation := get_validation_state(mission_dict)
		if not bool(validation.get("can_validate", false)):
			return false
		var reward_state := get_daily_reward_state()
		var rewards_enabled := int(m_data.type) != MissionData.MissionType.QUOTIDIENNE or bool(reward_state.get("can_reward_daily", true))
		var stat_name := m_data.get_reward_stat_key()
		var stat_amount := 0
		var xp_reward := m_data.get_base_xp_reward()
		if not rewards_enabled:
			stat_name = ""
			xp_reward = 0
		if rewards_enabled and not stat_name.is_empty():
			stat_amount = m_data.reward_stat_amount
		mission_dict["status"] = "completed"
		mission_dict["completed_at"] = Time.get_unix_time_from_system()
		mission_dict["rewarded"] = rewards_enabled
		_register_history(m_data, true, mission_dict, rewards_enabled)
		mission_completed.emit(xp_reward, stat_name, stat_amount)
	else:
		mission_dict["status"] = "failed"
		mission_dict["completed_at"] = Time.get_unix_time_from_system()
		mission_dict["rewarded"] = false
		_register_history(m_data, false, mission_dict, false)
		mission_failed.emit(m_data.get_failure_penalty_hp())

	missions_changed.emit()
	return true

func update_mission_progress(mission_dict: Dictionary, delta: int) -> bool:
	if String(mission_dict.get("status", "")) != "in_progress":
		return false
	var validation := get_validation_state(mission_dict)
	var target := int(validation.get("target_amount", 0))
	if target <= 0:
		return false
	var current := int(mission_dict.get("progress_amount", 0))
	mission_dict["progress_amount"] = clampi(current + delta, 0, target)
	return true

func update_mission_proof(mission_dict: Dictionary, proof_text: String) -> bool:
	if String(mission_dict.get("status", "")) != "in_progress":
		return false
	mission_dict["proof_text"] = proof_text.strip_edges()
	return true

func get_validation_state(mission_dict: Dictionary) -> Dictionary:
	var mission_id := String(mission_dict.get("id", ""))
	var m_data: MissionData = all_missions.get(mission_id) as MissionData
	if not m_data:
		return {"can_validate": false, "blockers": [GlobalEngine.loc("mission.blocker.not_found")]}

	var rules := m_data.get_validation_rules()
	var started_at := float(mission_dict.get("started_at", 0.0))
	var elapsed := 0
	if started_at > 0.0:
		elapsed = maxi(0, int(Time.get_unix_time_from_system() - started_at))

	var min_duration := int(rules.get("min_duration_seconds", 0))
	var target := int(rules.get("target_amount", 0))
	var progress := int(mission_dict.get("progress_amount", 0))
	var proof_text := String(mission_dict.get("proof_text", "")).strip_edges()
	var blockers: Array[String] = []

	if String(mission_dict.get("status", "")) != "in_progress":
		blockers.append(GlobalEngine.loc("mission.blocker.not_started"))
	if min_duration > 0 and elapsed < min_duration:
		blockers.append(GlobalEngine.loc("mission.blocker.time", [_format_duration(elapsed), _format_duration(min_duration)]))
	if target > 0 and progress < target:
		blockers.append(GlobalEngine.loc("mission.blocker.objective", [progress, target, _localized_amount_label(String(rules.get("amount_label", "")))]))
	if bool(rules.get("proof_required", false)) and proof_text.length() < 3:
		blockers.append(GlobalEngine.loc("mission.blocker.note"))

	return {
		"can_validate": blockers.is_empty(),
		"blockers": blockers,
		"rules": rules,
		"elapsed": elapsed,
		"min_duration_seconds": min_duration,
		"target_amount": target,
		"progress_amount": progress,
		"amount_label": String(rules.get("amount_label", "")),
		"amount_step": int(rules.get("amount_step", 1)),
		"proof_required": bool(rules.get("proof_required", false)),
		"proof_text": proof_text,
	}

func _localized_amount_label(label: String) -> String:
	if label.is_empty():
		return label
	var key := "mission.amount_label.%s" % label
	if GlobalEngine.has_loc(key):
		return GlobalEngine.loc(key)
	return label

func load_history(data) -> void:
	mission_history = data if data is Dictionary else {}
	_normalize_history()

func get_history_summary() -> Dictionary:
	_normalize_history()
	return {
		"completed_total": int(mission_history.get("completed_total", 0)),
		"failed_total": int(mission_history.get("failed_total", 0)),
		"current_streak": int(mission_history.get("current_streak", 0)),
		"best_streak": int(mission_history.get("best_streak", 0)),
	}

func get_history_view(limit: int = 5) -> Dictionary:
	_normalize_history()
	var view := get_history_summary()
	var entries: Array = mission_history.get("entries", [])
	var recent: Array = []
	var today := _today_day_index()
	var today_completed := 0
	var today_failed := 0

	for entry in entries:
		if not (entry is Dictionary):
			continue
		var entry_day := int(floor(float(entry.get("timestamp", 0.0)) / 86400.0))
		if entry_day == today:
			if bool(entry.get("success", false)):
				today_completed += 1
			else:
				today_failed += 1

	for i in range(entries.size() - 1, -1, -1):
		if recent.size() >= limit:
			break
		var entry = entries[i]
		if entry is Dictionary:
			recent.append(entry.duplicate(true))

	view["today_completed"] = today_completed
	view["today_failed"] = today_failed
	view["recent"] = recent
	return view

func get_daily_reward_state() -> Dictionary:
	_normalize_history()
	var today := _today_day_index()
	var rewarded_today := 0
	var consumed_today := 0
	var entries: Array = mission_history.get("entries", [])
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var entry_day := int(floor(float(entry.get("timestamp", 0.0)) / 86400.0))
		if entry_day != today:
			continue
		if int(entry.get("type", MissionData.MissionType.QUOTIDIENNE)) != MissionData.MissionType.QUOTIDIENNE:
			continue
		consumed_today += 1
		if not bool(entry.get("success", false)):
			continue
		if not bool(entry.get("rewarded", true)):
			continue
		rewarded_today += 1

	var ad_unlocked := 0 # Future hook: increment after rewarded ads.
	var max_rewarded := DAILY_FULL_REWARD_LIMIT + mini(ad_unlocked, DAILY_AD_REWARD_LIMIT)
	return {
		"rewarded_today": rewarded_today,
		"consumed_today": consumed_today,
		"full_limit": DAILY_FULL_REWARD_LIMIT,
		"ad_bonus_limit": DAILY_AD_REWARD_LIMIT,
		"ad_unlocked": ad_unlocked,
		"max_rewarded_today": max_rewarded,
		"remaining_full": maxi(0, DAILY_FULL_REWARD_LIMIT - consumed_today),
		"remaining_ad_locked": maxi(0, DAILY_AD_REWARD_LIMIT - ad_unlocked),
		"can_reward_daily": consumed_today < max_rewarded,
		"journal_only": consumed_today >= max_rewarded,
	}

# ── Timer strings ─────────────────────────────────────────────────────────────

func get_time_string() -> String:
	var ts := int(time_until_reset)
	return "%02d:%02d:%02d" % [floori(float(ts) / 3600.0), floori(float(ts % 3600) / 60.0), ts % 60]

func get_weekly_time_string() -> String:
	var ts   := int(time_until_weekly_reset)
	var days := floori(float(ts) / 86400.0)
	var hrs  := floori(float(ts % 86400) / 3600.0)
	var mins := floori(float(ts % 3600) / 60.0)
	var secs := ts % 60
	return "%d Jours - %02d:%02d:%02d" % [days, hrs, mins, secs]

# ── Debug ─────────────────────────────────────────────────────────────────────

func debug_reset_daily() -> void:
	time_until_reset = 0.0

func debug_reset_weekly() -> void:
	time_until_weekly_reset = 0.0

# ── Private ───────────────────────────────────────────────────────────────────

func _register_history(m_data: MissionData, success: bool, mission_dict: Dictionary, rewarded: bool) -> void:
	_normalize_history()
	var mission_id := m_data.id
	var by_mission: Dictionary = mission_history.get("by_mission", {})
	var per_mission: Dictionary = by_mission.get(mission_id, {"completed": 0, "failed": 0})
	var now := Time.get_unix_time_from_system()

	if success:
		mission_history["completed_total"] = int(mission_history.get("completed_total", 0)) + 1
		per_mission["completed"] = int(per_mission.get("completed", 0)) + 1
		_update_streak()
	else:
		mission_history["failed_total"] = int(mission_history.get("failed_total", 0)) + 1
		per_mission["failed"] = int(per_mission.get("failed", 0)) + 1

	by_mission[mission_id] = per_mission
	mission_history["by_mission"] = by_mission

	var entries: Array = mission_history.get("entries", [])
	entries.append({
		"id": mission_id,
		"title": m_data.title,
		"success": success,
		"rank": int(m_data.rank),
		"type": int(m_data.type),
		"timestamp": now,
		"elapsed": int(get_validation_state(mission_dict).get("elapsed", 0)),
		"progress": int(mission_dict.get("progress_amount", 0)),
		"rewarded": rewarded,
	})
	while entries.size() > HISTORY_LIMIT:
		entries.remove_at(0)
	mission_history["entries"] = entries

func _update_streak() -> void:
	var today := _today_day_index()
	var last_day := int(mission_history.get("last_success_day", -1))
	if last_day == today:
		return
	if last_day == today - 1:
		mission_history["current_streak"] = int(mission_history.get("current_streak", 0)) + 1
	else:
		mission_history["current_streak"] = 1
	mission_history["best_streak"] = maxi(
		int(mission_history.get("best_streak", 0)),
		int(mission_history.get("current_streak", 0))
	)
	mission_history["last_success_day"] = today

func _normalize_history() -> void:
	if not (mission_history is Dictionary):
		mission_history = {}
	for key in ["completed_total", "failed_total", "current_streak", "best_streak"]:
		mission_history[key] = maxi(0, int(mission_history.get(key, 0)))
	mission_history["last_success_day"] = int(mission_history.get("last_success_day", -1))
	if not (mission_history.get("entries", []) is Array):
		mission_history["entries"] = []
	if not (mission_history.get("by_mission", {}) is Dictionary):
		mission_history["by_mission"] = {}

func _today_day_index() -> int:
	return int(floor(Time.get_unix_time_from_system() / 86400.0))

func _format_duration(seconds: int) -> String:
	var safe_seconds := maxi(0, seconds)
	var hours := int(float(safe_seconds) / 3600.0)
	var minutes := int(float(safe_seconds % 3600) / 60.0)
	var secs := safe_seconds % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, secs]
	return "%02d:%02d" % [minutes, secs]

func _reset_daily() -> void:
	time_until_reset = reset_duration
	available_missions = _retain_in_progress(available_missions)
	generate_missions()
	missions_changed.emit()

func _reset_weekly() -> void:
	time_until_weekly_reset = weekly_reset_duration
	available_weekly_missions = _retain_in_progress(available_weekly_missions)
	generate_missions()
	missions_changed.emit()

func _fill_mission_slots(list: Array, mission_type: int, current_rank: int, target_count: int, end_cost: int) -> void:
	if list.size() >= target_count:
		return

	var pool: Array = _get_preferred_mission_pool(mission_type, current_rank, target_count)
	if pool.is_empty():
		pool = _get_mission_pool(mission_type, 999)
	pool.shuffle()

	var used_ids := {}
	for mission in list:
		if typeof(mission) == TYPE_DICTIONARY:
			used_ids[String(mission.get("id", ""))] = true

	for mission_data in pool:
		if list.size() >= target_count:
			return
		if mission_data == null or used_ids.has(mission_data.id):
			continue
		list.append({
			"id": mission_data.id,
			"status": "available",
			"end_cost": end_cost,
		})
		used_ids[mission_data.id] = true

func _retain_in_progress(list: Array) -> Array:
	var retained: Array = []
	for mission in list:
		if typeof(mission) == TYPE_DICTIONARY and String(mission.get("status", "")) == "in_progress":
			retained.append(mission)
	return retained

func _get_mission_pool(mission_type: int, max_rank: int) -> Array:
	var pool: Array = []
	for mission in all_missions.values():
		if mission == null:
			continue
		if int(mission.type) != mission_type:
			continue
		if int(mission.rank) > max_rank:
			continue
		pool.append(mission)
	return pool

func _get_preferred_mission_pool(mission_type: int, current_rank: int, desired_count: int) -> Array:
	var pool := _get_mission_pool_exact(mission_type, current_rank)
	if pool.size() >= desired_count:
		return pool

	if current_rank > 0:
		pool.append_array(_get_mission_pool_exact(mission_type, current_rank - 1))
	if pool.size() >= desired_count:
		return pool

	for rank in range(current_rank - 2, -1, -1):
		pool.append_array(_get_mission_pool_exact(mission_type, rank))
		if pool.size() >= desired_count:
			return pool
	return pool

func _get_mission_pool_exact(mission_type: int, rank_index: int) -> Array:
	var pool: Array = []
	for mission in all_missions.values():
		if mission == null:
			continue
		if int(mission.type) != mission_type:
			continue
		if int(mission.rank) != rank_index:
			continue
		pool.append(mission)
	return pool

func _register_required_missions() -> void:
	for mission in REQUIRED_MISSIONS:
		if mission != null and not mission.id.is_empty():
			all_missions[mission.id] = mission

func _needs_fresh_missions(list: Array) -> bool:
	if list.is_empty():
		return true

	for mission in list:
		if typeof(mission) != TYPE_DICTIONARY:
			continue
		if String(mission.get("status", "available")) in ["available", "in_progress", "completed", "failed"]:
			return false

	return true

func _mission_list_signature(list: Array) -> String:
	var parts: Array[String] = []
	for mission in list:
		if typeof(mission) != TYPE_DICTIONARY:
			parts.append("invalid")
			continue
		parts.append("%s:%s" % [String(mission.get("id", "")), String(mission.get("status", ""))])
	return "|".join(parts)
