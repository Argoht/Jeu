class_name SaveSystem
extends Node

## Handles serialization, deserialization, and corruption protection.
## Uses duck typing for PlayerData/MissionManager/InventorySystem to avoid
## class_name circular deps at autoload compile time.

const SAVE_PATH = "user://save_game.dat"
const SAVE_VERSION = 4

var _pending_offline_elapsed: float = 0.0
var _loaded_language: String = "en"

# ── Public API ────────────────────────────────────────────────────────────────

func save_game(player_data, mission_manager, inventory_system, dungeon_system = null, settings: Dictionary = {}) -> void:
	var save_data := {
		"version": SAVE_VERSION,
		"language": String(settings.get("language", _loaded_language)),
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
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))

func load_game(player_data, mission_manager, inventory_system, dungeon_system = null) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return false

	var save_data = JSON.parse_string(file.get_as_text())
	if typeof(save_data) != TYPE_DICTIONARY:
		push_error("SaveSystem: fichier de sauvegarde corrompu, partie fraîche lancée.")
		return false

	_load_player(player_data, save_data)
	_load_missions(mission_manager, save_data)
	_load_inventory(inventory_system, save_data)
	_load_dungeon(dungeon_system, save_data)
	_capture_offline_time(save_data)
	_loaded_language = String(save_data.get("language", "en"))
	return true

func apply_pending_offline_time(player_data, mission_manager) -> void:
	if _pending_offline_elapsed <= 0.0:
		return

	mission_manager.time_until_reset = maxf(0.0, mission_manager.time_until_reset - _pending_offline_elapsed)
	mission_manager.time_until_weekly_reset = maxf(0.0, mission_manager.time_until_weekly_reset - _pending_offline_elapsed)
	player_data.apply_offline_regen(_pending_offline_elapsed)
	_pending_offline_elapsed = 0.0

func get_loaded_language() -> String:
	return _loaded_language

# ── Private ───────────────────────────────────────────────────────────────────

func _load_player(pd, data: Dictionary) -> void:
	pd.player_name = data.get("player_name", "Player")
	pd.lvl         = int(data.get("lvl", 1))
	pd.hp          = int(data.get("hp", 100))
	pd.max_hp      = int(data.get("max_hp", 100))
	pd.xp          = int(data.get("xp", 0))
	pd.stat_points = int(data.get("stat_points", 0))

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

func _capture_offline_time(data: Dictionary) -> void:
	var now     := Time.get_unix_time_from_system()
	var elapsed := now - float(data.get("last_save_time", now))
	_pending_offline_elapsed = maxf(0.0, elapsed)
