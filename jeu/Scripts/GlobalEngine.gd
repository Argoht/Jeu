extends Node

signal stats_updated
signal leveled_up(new_level)
signal xp_gained(amount)
signal mission_completed(xp_amount, stat_name, stat_amount)
signal mission_failed(hp_lost)
signal missions_changed

const SAVE_PATH = "user://save_game.dat"

# --- DONNÉES JOUEUR ---
var player_name: String = "Joueur"
var hp: int = 100
var max_hp: int = 100
var end: int = 100
var max_end: int = 100
var xp: int = 0
var lvl: int = 1
var stat_points: int = 0

var atk: int = 12
var def: int = 6

var inventory: Array = []
var items_per_page: int = 45

# --- CYCLES DU SYSTÈME ---
var reset_duration: float = 14400.0 # 4 heures
var time_until_reset: float = reset_duration

var weekly_reset_duration: float = 604800.0 # 7 jours
var time_until_weekly_reset: float = weekly_reset_duration

var auto_save_timer: float = 0.0

# --- RÉGÉNÉRATION ---
const HP_REGEN_RATE: float = 5.0 / 3600.0  # +5 HP par heure
const END_REGEN_RATE: float = 10.0 / 3600.0 # +10 END par heure (END se dépense plus vite)
var _hp_regen_acc: float = 0.0
var _end_regen_acc: float = 0.0

var stats: Dictionary = {
	"str": 1, "dex": 1, "vit": 1, "int": 1,
	"wis": 1, "per": 1, "cha": 1, "wil": 1,
	"spd": 100, "lck": 1
}

var all_missions: Dictionary = {}
var available_missions: Array = []
var available_weekly_missions: Array = []

func _ready():
	randomize()
	load_all_missions()
	load_game()
	update_derived_stats()
	if available_missions.is_empty(): generate_missions()

func _process(delta):
	if time_until_reset > 0:
		time_until_reset -= delta
	else:
		reset_daily_missions()

	if time_until_weekly_reset > 0:
		time_until_weekly_reset -= delta
	else:
		reset_weekly_missions()

	auto_save_timer += delta
	if auto_save_timer >= 30.0:
		auto_save_timer = 0.0
		save_game()

	if hp < max_hp:
		_hp_regen_acc += delta * HP_REGEN_RATE
		if _hp_regen_acc >= 1.0:
			var gain = int(_hp_regen_acc)
			hp = min(max_hp, hp + gain)
			_hp_regen_acc -= gain
			stats_updated.emit()
	else:
		_hp_regen_acc = 0.0

	if end < max_end:
		_end_regen_acc += delta * END_REGEN_RATE
		if _end_regen_acc >= 1.0:
			var gain = int(_end_regen_acc)
			end = min(max_end, end + gain)
			_end_regen_acc -= gain
			stats_updated.emit()
	else:
		_end_regen_acc = 0.0

func load_all_missions() -> void:
	var path = "res://Data/Missions/"
	if not DirAccess.dir_exists_absolute(path): return
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var mission = load(path + file_name) as MissionData
				if mission: all_missions[mission.id] = mission
			file_name = dir.get_next()

func update_derived_stats():
	atk = 10 + (int(stats.get("str", 1)) * 2)
	def = int(5 + (float(stats.get("vit", 1)) * 1.5))

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var save_data = {
			"player_name": player_name,
			"hp": hp, "max_hp": max_hp, "lvl": lvl, "xp": xp, "stat_points": stat_points,
			"end": end, "max_end": max_end,
			"stats": stats, "inventory": inventory,
			"available_missions": available_missions,
			"available_weekly_missions": available_weekly_missions,
			"time_until_reset": time_until_reset,
			"time_until_weekly_reset": time_until_weekly_reset,
			"last_save_time": Time.get_unix_time_from_system()
		}
		file.store_string(JSON.stringify(save_data))

func load_game():
	if not FileAccess.file_exists(SAVE_PATH): return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var save_data = JSON.parse_string(file.get_as_text())
	if typeof(save_data) == TYPE_DICTIONARY:
		player_name = save_data.get("player_name", "Joueur")
		lvl = int(save_data.get("lvl", 1))
		hp = int(save_data.get("hp", 100))
		max_hp = int(save_data.get("max_hp", 100))
		xp = int(save_data.get("xp", 0))
		stat_points = int(save_data.get("stat_points", 0))
		end = int(save_data.get("end", 100))
		max_end = int(save_data.get("max_end", 100))
		stats = save_data.get("stats", stats)
		inventory = save_data.get("inventory", [])
		available_missions = save_data.get("available_missions", [])
		available_weekly_missions = save_data.get("available_weekly_missions", [])

		var current_time = Time.get_unix_time_from_system()
		var elapsed = current_time - float(save_data.get("last_save_time", current_time))
		time_until_reset = max(0, float(save_data.get("time_until_reset", reset_duration)) - elapsed)
		time_until_weekly_reset = max(0, float(save_data.get("time_until_weekly_reset", weekly_reset_duration)) - elapsed)
		# Régén hors-ligne : applique les HP/END gagnés pendant l'absence
		hp = min(max_hp, hp + int(elapsed * HP_REGEN_RATE))
		end = min(max_end, end + int(elapsed * END_REGEN_RATE))

func generate_missions():
	var rank_int = get_rank_index(lvl)
	if available_missions.is_empty():
		var daily_pool = all_missions.values().filter(func(m): return m.type == 0 and m.rank <= rank_int)
		daily_pool.shuffle()
		for i in range(min(5, daily_pool.size())):
			available_missions.append({"id": daily_pool[i].id, "status": "available", "end_cost": 15})

	if available_weekly_missions.is_empty():
		var weekly_pool = all_missions.values().filter(func(m): return m.type == 1 and m.rank <= rank_int)
		if weekly_pool.size() > 0:
			weekly_pool.shuffle()
			available_weekly_missions.append({"id": weekly_pool[0].id, "status": "available", "end_cost": 40})
	stats_updated.emit()

func accept_mission(mission_dict: Dictionary) -> bool:
	var m_data = all_missions.get(mission_dict.id)
	if not m_data: return false
	if hp <= 0: return false
	if end < mission_dict.end_cost: return false

	# req_end dans MissionData correspond à la stat "vit" (vitalité/endurance)
	var req_map = {
		"str": m_data.req_str, "dex": m_data.req_dex, "vit": m_data.req_end,
		"int": m_data.req_int, "wis": m_data.req_wis, "cha": m_data.req_cha,
		"per": m_data.req_per, "wil": m_data.req_wil
	}
	for stat_key in req_map:
		if stats.get(stat_key, 0) < req_map[stat_key]:
			return false

	end -= mission_dict.end_cost
	mission_dict["status"] = "in_progress"
	stats_updated.emit()
	save_game()
	return true

func process_mission_result(mission_dict: Dictionary, success: bool):
	var m_data = all_missions.get(mission_dict.id)
	if success:
		xp += m_data.base_xp
		xp_gained.emit(m_data.base_xp)
		var stat_name   = ""
		var stat_amount = 0
		if m_data.reward_stat != 0:
			var stat_keys = ["", "str", "dex", "vit", "int", "wis", "cha", "per", "wil"]
			stat_name   = stat_keys[m_data.reward_stat]
			stat_amount = m_data.reward_stat_amount
			stats[stat_name] += stat_amount
			update_derived_stats()
		mission_completed.emit(m_data.base_xp, stat_name, stat_amount)
		mission_dict["status"] = "completed"
		check_level_up()
	else:
		hp = max(0, hp - 20)
		mission_dict["status"] = "failed"
		mission_failed.emit(20)
	stats_updated.emit()
	save_game()

func reset_daily_missions():
	time_until_reset = reset_duration
	available_missions.clear()
	generate_missions()
	missions_changed.emit()

func reset_weekly_missions():
	time_until_weekly_reset = weekly_reset_duration
	available_weekly_missions.clear()
	generate_missions()
	missions_changed.emit()

func get_time_string() -> String:
	var ts = int(time_until_reset)
	return "%02d:%02d:%02d" % [ts / 3600, (ts % 3600) / 60, ts % 60]

func get_weekly_time_string() -> String:
	var ts = int(time_until_weekly_reset)
	var days = ts / 86400
	var hours = (ts % 86400) / 3600
	var mins = (ts % 3600) / 60
	var secs = ts % 60
	return "%d Jours - %02d:%02d:%02d" % [days, hours, mins, secs]

func get_rank_index(l):
	if l <= 10: return 0
	elif l <= 25: return 1
	elif l <= 40: return 2
	elif l <= 55: return 3
	elif l <= 70: return 4
	elif l <= 85: return 5
	else: return 6

func get_rank_by_level(l):
	return ["F", "E", "D", "C", "B", "A", "S"][get_rank_index(l)]

const XP_TABLE: Array = [
	100, 120, 140, 160, 180, 200, 230, 260, 300, 350,
	400, 450, 500, 560, 620, 680, 750, 820, 900, 980,
	1060, 1150, 1240, 1340, 1450, 1560, 1680, 1810, 1950, 2100,
	2260, 2430, 2610, 2800, 3000, 3210, 3430, 3660, 3900, 4150,
	4410, 4680, 4960, 5250, 5550, 5860, 6180, 6510, 6850, 7200,
	7560, 7930, 8310, 8700, 9100, 9510, 9930, 10360, 10800, 11250,
	11710, 12180, 12660, 13150, 13650, 14160, 14680, 15210, 15750, 16300,
	16860, 17430, 18010, 18600, 19200, 19810, 20430, 21060, 21700, 22350,
	23010, 23680, 24360, 25050, 25750, 26460, 27180, 27910, 28650, 29400,
	30160, 30930, 31710, 32500, 33300, 34110, 34930, 35760, 36600
]

func get_xp_for_level(l: int) -> int:
	if l >= 100: return 999999
	return XP_TABLE[clampi(l - 1, 0, 98)]

func check_level_up():
	while lvl < 100 and xp >= get_xp_for_level(lvl):
		xp -= get_xp_for_level(lvl)
		lvl += 1
		stat_points += 3
		leveled_up.emit(lvl)

# --- DEBUG ---
func debug_reset_daily():
	time_until_reset = 0.0

func debug_reset_weekly():
	time_until_weekly_reset = 0.0

func debug_add_level():
	lvl += 1
	stat_points += 3
	update_derived_stats()
	leveled_up.emit(lvl)
	save_game()
	stats_updated.emit()

func add_stat(stat_name: String):
	if stat_points > 0 and stats.has(stat_name):
		stats[stat_name] += 1
		stat_points -= 1
		update_derived_stats()
		save_game()
		stats_updated.emit()
