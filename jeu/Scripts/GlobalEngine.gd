extends Node

## Thin orchestrator — creates subsystems, wires their signals and exposes a
## backward-compatible surface so existing UI scripts need no changes.
##
## Subsystem responsibilities:
##   PlayerData     — stats, XP, level, HP, stamina, regen
##   MissionManager — mission state, timers, generation, results
##   SaveSystem     — serialization, corruption protection, offline recovery

# ── Signals (re-emitted from subsystems for backward compat) ──────────────────

signal stats_updated
signal leveled_up(new_level: int)
signal xp_gained(amount: int)
signal mission_completed(xp_amount: int, stat_name: String, stat_amount: int)
signal mission_failed(hp_lost: int)
signal missions_changed

# ── Subsystems (accessible directly from UI if needed) ────────────────────────

var player_data: PlayerData
var mission_manager: MissionManager
var save_system: SaveSystem

# ── Inventory (will move to InventorySystem in a later step) ──────────────────

var inventory: Array = []
var items_per_page: int = 45

# ── Auto-save ─────────────────────────────────────────────────────────────────

var _auto_save_timer: float = 0.0

# ── Backward-compatible computed properties ───────────────────────────────────
# These let existing UI code (GlobalEngine.hp, GlobalEngine.stats, etc.)
# work unchanged while data now lives in PlayerData / MissionManager.

var player_name: String:
	get: return player_data.player_name
	set(v): player_data.player_name = v

var hp: int:
	get: return player_data.hp
	set(v): player_data.hp = v

var max_hp: int:
	get: return player_data.max_hp
	set(v): player_data.max_hp = v

# "end" maps to player_data.stamina (renamed for clarity)
var end: int:
	get: return player_data.stamina
	set(v): player_data.stamina = v

var max_end: int:
	get: return player_data.max_stamina
	set(v): player_data.max_stamina = v

var xp: int:
	get: return player_data.xp
	set(v): player_data.xp = v

var lvl: int:
	get: return player_data.lvl
	set(v): player_data.lvl = v

var stat_points: int:
	get: return player_data.stat_points
	set(v): player_data.stat_points = v

var atk: int:
	get: return player_data.atk

var def: int:
	get: return player_data.def

# Dictionary is a reference type — modifications go straight to PlayerData.
var stats: Dictionary:
	get: return player_data.base_stats
	set(v): player_data.base_stats = v

var all_missions: Dictionary:
	get: return mission_manager.all_missions

var available_missions: Array:
	get: return mission_manager.available_missions

var available_weekly_missions: Array:
	get: return mission_manager.available_weekly_missions

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	player_data     = PlayerData.new()
	mission_manager = MissionManager.new()
	save_system     = SaveSystem.new()

	add_child(player_data)
	add_child(mission_manager)
	add_child(save_system)

	mission_manager.initialize(player_data)

	randomize()
	mission_manager.load_all_missions()
	save_system.load_game(player_data, mission_manager)
	player_data.update_derived_stats()

	if mission_manager.available_missions.is_empty():
		mission_manager.generate_missions()

	_connect_signals()

func _process(delta: float) -> void:
	_auto_save_timer += delta
	if _auto_save_timer >= 30.0:
		_auto_save_timer = 0.0
		save_game()

# ── Signal wiring ─────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	player_data.stats_updated.connect(func(): stats_updated.emit())
	player_data.xp_gained.connect(func(a: int): xp_gained.emit(a))
	player_data.leveled_up.connect(func(l: int): leveled_up.emit(l))

	mission_manager.mission_completed.connect(
		func(xp_r: int, s: String, a: int): mission_completed.emit(xp_r, s, a)
	)
	mission_manager.mission_failed.connect(func(h: int): mission_failed.emit(h))
	mission_manager.missions_changed.connect(func(): missions_changed.emit())

# ── Delegated public API (backward compat) ────────────────────────────────────

func save_game() -> void:
	save_system.save_game(player_data, mission_manager)

func add_stat(stat_name: String) -> void:
	player_data.add_stat(stat_name)
	save_game()

func accept_mission(mission_dict: Dictionary) -> bool:
	var ok := mission_manager.accept_mission(mission_dict)
	if ok: save_game()
	return ok

func process_mission_result(mission_dict: Dictionary, success: bool) -> void:
	mission_manager.process_result(mission_dict, success)
	save_game()

func get_time_string() -> String:
	return mission_manager.get_time_string()

func get_weekly_time_string() -> String:
	return mission_manager.get_weekly_time_string()

func get_xp_for_level(l: int) -> int:
	return player_data.get_xp_for_level(l)

func get_rank_index(l: int) -> int:
	return player_data.get_rank_index(l)

func get_rank_by_level(l: int) -> String:
	return player_data.get_rank_by_level(l)

func update_derived_stats() -> void:
	player_data.update_derived_stats()

# ── Debug helpers ─────────────────────────────────────────────────────────────

func debug_reset_daily() -> void:
	mission_manager.debug_reset_daily()

func debug_reset_weekly() -> void:
	mission_manager.debug_reset_weekly()

func debug_add_level() -> void:
	player_data.lvl += 1
	player_data.stat_points += 3
	player_data.update_derived_stats()
	player_data.leveled_up.emit(player_data.lvl)
	player_data.stats_updated.emit()
	save_game()
