class_name SaveSystem
extends Node

## Handles serialization, deserialization, and corruption protection.
## Uses duck typing for PlayerData/MissionManager/InventorySystem to avoid
## class_name circular deps at autoload compile time.

const SAVE_PATH = "user://save_game.dat"
const SAVE_VERSION = 8
const BACKUP_PATH = "user://save_game.backup.dat"
const TEMP_PATH = "user://save_game.tmp"

var writes_allowed := true
var _loaded_commerce: Dictionary = {}
var _loaded_regen: Dictionary = {}
var _loaded_journey: Dictionary = {}
var _loaded_vitals: Dictionary = {}
var _loaded_metrics: Dictionary = {}

var _pending_offline_elapsed: float = 0.0
var _loaded_language: String = "en"

# ── Public API ────────────────────────────────────────────────────────────────

func save_game(player_data, mission_manager, inventory_system, dungeon_system = null, base_manager = null, settings: Dictionary = {}) -> bool:
	if not writes_allowed:
		return false
	if base_manager is Dictionary and settings.is_empty():
		settings = base_manager
		base_manager = null

	var save_data := {
		"version": SAVE_VERSION,
		"language": String(settings.get("language", _loaded_language)),
		"commerce": settings.get("commerce", {}),
		"journey": settings.get("journey", {}),
		"metrics": settings.get("metrics", {}),
		"regen": player_data.get_regen_state(),
		"player_name": player_data.player_name,
		"hp": player_data.hp,
		"max_hp": player_data.max_hp,
		"stamina": player_data.stamina,
		"max_stamina": player_data.max_stamina,
		"lvl": player_data.lvl,
		"xp": player_data.xp,
		"stat_points": player_data.stat_points,
		"base_stats": player_data.base_stats,
		"inventory": inventory_system.to_dict(),
		"available_missions": mission_manager.available_missions,
		"available_weekly_missions": mission_manager.available_weekly_missions,
		"mission_history": mission_manager.mission_history,
		"time_until_reset": mission_manager.time_until_reset,
		"time_until_weekly_reset": mission_manager.time_until_weekly_reset,
		"last_save_time": Time.get_unix_time_from_system()
	}
	if dungeon_system != null:
		save_data["dungeon"] = dungeon_system.to_dict()
	if base_manager != null:
		save_data["base"] = base_manager.to_dict()
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: unable to write temporary save.")
		return false
	file.store_string(JSON.stringify(save_data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK or _read_save(TEMP_PATH).is_empty():
		push_error("SaveSystem: temporary save validation failed.")
		return false
	# Keep the last readable save if the process stops during replacement.
	if not _read_save(SAVE_PATH).is_empty():
		if DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH) != OK:
			push_error("SaveSystem: backup failed; original save preserved.")
			return false
	var result := DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if result != OK:
		push_error("SaveSystem: save replacement failed: %s" % error_string(result))
	return result == OK

func load_game(player_data, mission_manager, inventory_system, dungeon_system = null, base_manager = null) -> bool:
	writes_allowed = true
	_loaded_commerce = {}
	_loaded_regen = {}
	_loaded_journey = {}
	_loaded_vitals = {}
	_loaded_metrics = {}
	_pending_offline_elapsed = 0.0
	_loaded_language = "en"
	var primary := _read_json(SAVE_PATH)
	if _is_newer_save(primary):
		writes_allowed = false
		push_warning("SaveSystem: newer primary save preserved; automatic writes disabled.")
		return false
	var save_data := _read_save(SAVE_PATH)
	if save_data.is_empty():
		save_data = _read_save(BACKUP_PATH)
	if save_data.is_empty():
		if FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH):
			writes_allowed = false
			push_warning("SaveSystem: unreadable or newer saves preserved; automatic writes disabled.")
		return false

	_load_player(player_data, save_data)
	_load_missions(mission_manager, save_data)
	_load_inventory(inventory_system, save_data)
	_load_dungeon(dungeon_system, save_data)
	_load_base(base_manager, save_data)
	_capture_offline_time(save_data)
	_loaded_language = String(save_data.get("language", "en"))
	_loaded_commerce = save_data.get("commerce", {})
	_loaded_regen = save_data.get("regen", {})
	_loaded_journey = save_data.get("journey", {})
	_loaded_metrics = save_data.get("metrics", {})
	player_data.load_regen_state(_loaded_regen)
	return true

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	var result := parser.parse(file.get_as_text())
	file.close()
	if result != OK or not parser.data is Dictionary:
		return {}
	return parser.data

func _is_newer_save(data: Dictionary) -> bool:
	var version = data.get("version", 1)
	return (version is int or version is float) and int(version) > SAVE_VERSION

func _read_save(path: String) -> Dictionary:
	var parsed := _read_json(path)
	if parsed.is_empty() or not parsed.has("lvl") or not parsed.has("inventory") or _is_newer_save(parsed):
		return {}
	for key in ["version", "lvl", "hp", "max_hp", "stamina", "max_stamina", "end", "max_end", "xp", "stat_points", "time_until_reset", "time_until_weekly_reset", "last_save_time"]:
		if parsed.has(key) and not _is_number(parsed[key]):
			return {}
	for key in ["base_stats", "stats", "mission_history", "dungeon", "base", "commerce", "regen", "journey", "metrics"]:
		if parsed.has(key) and not parsed[key] is Dictionary:
			return {}
	for key in ["available_missions", "available_weekly_missions"]:
		if parsed.has(key) and not parsed[key] is Array:
			return {}
	for key in ["player_name", "language"]:
		if parsed.has(key) and not parsed[key] is String:
			return {}
	if not parsed["inventory"] is Array and not parsed["inventory"] is Dictionary:
		return {}
	var raw_inventory = parsed["inventory"]
	var items = raw_inventory if raw_inventory is Array else raw_inventory.get("items", [])
	if not items is Array:
		return {}
	for item in items:
		if not item is Dictionary:
			return {}
	if raw_inventory is Dictionary and not raw_inventory.get("equipment", {}) is Dictionary:
		return {}
	for section in ["base_stats", "stats", "regen"]:
		for value in parsed.get(section, {}).values():
			if not _is_number(value):
				return {}
	var commerce: Dictionary = parsed.get("commerce", {})
	for key in ["tokens", "day", "ads_today", "mission_tokens_today", "last_ad_at"]:
		if commerce.has(key) and not _is_number(commerce[key]):
			return {}
	if commerce.has("owned") and not commerce["owned"] is Array:
		return {}
	if commerce.has("selected") and not commerce["selected"] is String:
		return {}
	var journey: Dictionary = parsed.get("journey", {})
	for key in ["day", "steps", "next_step_at", "pending_tokens"]:
		if journey.has(key) and not _is_number(journey[key]):
			return {}
	if journey.has("seen_floors") and not journey["seen_floors"] is Array:
		return {}
	return parsed

func _is_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func get_loaded_commerce() -> Dictionary:
	return _loaded_commerce.duplicate(true)

func get_loaded_metrics() -> Dictionary:
	return _loaded_metrics.duplicate(true)

func get_loaded_journey() -> Dictionary:
	return _loaded_journey.duplicate(true)

func apply_pending_offline_time(player_data, mission_manager) -> void:
	# Restore current values only after equipment and base maxima are calculated.
	if not _loaded_vitals.is_empty():
		player_data.hp = clampi(int(_loaded_vitals["hp"]), 0, player_data.max_hp)
		player_data.stamina = clampi(int(_loaded_vitals["stamina"]), 0, player_data.max_stamina)
		_loaded_vitals = {}
	if _pending_offline_elapsed <= 0.0:
		return

	mission_manager.advance_time(_pending_offline_elapsed)
	player_data.apply_offline_regen(_pending_offline_elapsed)
	_pending_offline_elapsed = 0.0

func get_loaded_language() -> String:
	return _loaded_language

# ── Private ───────────────────────────────────────────────────────────────────

func _load_player(pd, data: Dictionary) -> void:
	_loaded_vitals = {
		"hp": int(data.get("hp", 100)),
		"stamina": int(data.get("stamina", data.get("end", 100))),
	}
	pd.player_name = data.get("player_name", "Player")
	pd.lvl         = clampi(int(data.get("lvl", 1)), 1, 100)
	pd.hp          = int(data.get("hp", 100))
	pd.max_hp      = int(data.get("max_hp", 100))
	pd.xp          = maxi(0, int(data.get("xp", 0)))
	pd.stat_points = maxi(0, int(data.get("stat_points", 0)))

	# Compat: anciens saves utilisaient "end" / "max_end"
	pd.stamina     = int(data.get("stamina", data.get("end", 100)))
	pd.max_stamina = int(data.get("max_stamina", data.get("max_end", 100)))

	# Compat: anciens saves utilisaient "stats" au lieu de "base_stats".
	pd.set_base_stats(data.get("base_stats", data.get("stats", pd.base_stats)))

func _load_missions(mm, data: Dictionary) -> void:
	mm.available_missions        = data.get("available_missions", [])
	mm.available_weekly_missions = data.get("available_weekly_missions", [])
	mm.time_until_reset          = maxf(0.0, float(data.get("time_until_reset", mm.reset_duration)))
	mm.time_until_weekly_reset   = maxf(0.0, float(data.get("time_until_weekly_reset", mm.weekly_reset_duration)))
	if mm.has_method("load_history"):
		mm.load_history(data.get("mission_history", {}))

func _load_inventory(inv, data: Dictionary) -> void:
	# Compat: saves v1/v2 avaient "inventory" comme Array plat (pas de Dictionary {items, equipment})
	var raw = data.get("inventory", null)
	if raw == null:
		return
	if raw is Array:
		inv.from_dict({"items": raw, "equipment": {}})
	elif raw is Dictionary:
		inv.from_dict(raw)

func _load_dungeon(dungeon_system, data: Dictionary) -> void:
	if dungeon_system == null:
		return
	var raw = data.get("dungeon", null)
	if raw is Dictionary:
		dungeon_system.from_dict(raw)

func _load_base(base_manager, data: Dictionary) -> void:
	if base_manager == null:
		return
	var raw = data.get("base", null)
	if raw is Dictionary and base_manager.has_method("from_dict"):
		base_manager.from_dict(raw)

func _capture_offline_time(data: Dictionary) -> void:
	var now     := Time.get_unix_time_from_system()
	var elapsed := now - float(data.get("last_save_time", now))
	_pending_offline_elapsed = maxf(0.0, elapsed)
