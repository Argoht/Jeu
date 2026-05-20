class_name DungeonSystem
extends Node

signal dungeon_changed
signal run_failed(rank, floor)
signal run_completed(rank)

const MAX_FLOOR = 100
const CHECKPOINT_STEP = 10
const ENERGY_MAX = 100
const DROP_CHANCE_BASE = 42
const DROP_CHANCE_RANK_STEP = 3
const DROP_CHANCE_MINOR_BONUS = 18
const RANKS = ["F", "E", "D", "C", "B", "A", "S"]

const ENTRY_COSTS = {
	"F": 10,
	"E": 15,
	"D": 22,
	"C": 30,
	"B": 40,
	"A": 52,
	"S": 65,
}

const DUNGEON_NAMES = {
	"F": "Bois fendu",
	"E": "Caves de rouille",
	"D": "Cryptes affamees",
	"C": "Tour des echos",
	"B": "Fosse des rois",
	"A": "Citadelle noire",
	"S": "Abime final",
}

const DUNGEON_BACKGROUNDS = {
	"F": [
		"res://Assets/Dungeons/Backgrounds/rank_f_01.png",
		"res://Assets/Dungeons/Backgrounds/rank_f_02.png",
		"res://Assets/Dungeons/Backgrounds/rank_f_03.png",
		"res://Assets/Dungeons/Backgrounds/rank_f_04.png",
	],
}

const AMBIENCE_MESSAGES = [
	"L'air devient plus lourd. Le donjon se referme autour de toi.",
	"L'ambiance se degrade. Les ombres semblent suivre chacun de tes pas.",
	"Le donjon s'enfonce dans quelque chose de mauvais. Reste vigilant.",
	"Tout ici respire la fin. Le coeur du donjon est proche.",
]

const TYPE_DATA = {
	"Brute": {"hp": 1.35, "atk": 1.12, "def": 1.2, "spd": 0.72},
	"Assassin": {"hp": 0.85, "atk": 1.05, "def": 0.8, "spd": 1.45},
	"Mage": {"hp": 0.95, "atk": 1.28, "def": 0.72, "spd": 1.0},
}

const MONSTER_VISUALS = {
	"bat": {"path": "res://Assets/Monsters/Bestiary/bat_fly.png", "frames": 11, "scale": 0.88},
	"rat": {"path": "res://Assets/Monsters/Bestiary/rat_idle.png", "frames": 10, "scale": 0.82},
	"slime": {"path": "res://Assets/Monsters/Bestiary/slime_idle.png", "frames": 14, "scale": 0.78},
	"goblin": {"path": "res://Assets/Monsters/Bestiary/goblin_idle.png", "frames": 4, "scale": 1.0},
	"mushroom": {"path": "res://Assets/Monsters/Bestiary/mushroom_idle.png", "frames": 4, "scale": 0.92},
	"skeleton": {"path": "res://Assets/Monsters/Bestiary/skeleton_idle.png", "frames": 4, "scale": 1.05},
	"mimic": {"path": "res://Assets/Monsters/Bestiary/mimic_idle.png", "frames": 9, "scale": 0.95},
	"flying_eye": {"path": "res://Assets/Monsters/Bestiary/flying_eye_flight.png", "frames": 8, "scale": 0.9},
	"rat_savage": {"path": "res://Assets/Monsters/Bestiary/rat_savage_idle.png", "frames": 6, "scale": 0.95},
	"golem_blue": {"path": "res://Assets/Monsters/Bestiary/golem_blue_idle.png", "frames": 9, "frame_width": 80, "frame_height": 64, "scale": 1.18},
	"golem_orange": {"path": "res://Assets/Monsters/Bestiary/golem_orange_idle.png", "frames": 9, "frame_width": 80, "frame_height": 64, "scale": 1.18},
	"demon_sword": {"path": "res://Assets/Monsters/Bestiary/demon_sword_idle.png", "frame_rects": [
		Rect2(0, 0, 64, 64),
		Rect2(128, 0, 64, 64),
		Rect2(256, 0, 64, 64),
		Rect2(384, 0, 64, 64),
		Rect2(512, 0, 64, 64),
		Rect2(640, 0, 64, 64),
		Rect2(768, 0, 64, 64),
	], "scale": 1.08},
	"minotaur": {"path": "res://Assets/Monsters/Bestiary/minotaur_idle.png", "frames": 16, "frame_width": 288, "frame_height": 160, "scale": 1.35},
	"demon_slime": {"path": "res://Assets/Monsters/Bestiary/demon_slime_idle.png", "frames": 6, "frame_width": 288, "frame_height": 160, "scale": 1.25},
	"knight": {"path": "res://Assets/Monsters/Bestiary/knight_idle.png", "frames": 15, "scale": 1.12},
}

var in_run = false
var active_rank = "F"
var current_floor = 1
var checkpoint_floor = 1
var phase = "idle"
var player_energy = 0
var shield_turns = 0
var temp_atk_bonus = 0
var temp_def_bonus = 0
var temp_agi_bonus = 0
var enemy: Dictionary = {}
var event_data: Dictionary = {}
var battle_log: Array = []
var checkpoints: Dictionary = {}
var best_floors: Dictionary = {}
var combat_fx_seq: int = 0
var combat_fx: Dictionary = {}
var pending_drop_floor: int = 0
var last_drop: Dictionary = {}

func _ready() -> void:
	_ensure_rank_data()

func start_run(rank: String, player_rank: String, player_data) -> bool:
	_ensure_rank_data()
	if in_run:
		return false
	if not _rank_available(rank, player_rank):
		_set_log([GlobalEngine.loc("dungeon.unavailable_rank")])
		_emit_changed()
		return false

	var cost = get_entry_cost(rank)
	if not player_data.can_spend_stamina(cost):
		_set_log([GlobalEngine.loc("dungeon.not_enough_end")])
		_emit_changed()
		return false
	if player_data.hp <= 0:
		_set_log([GlobalEngine.loc("dungeon.not_enough_hp")])
		_emit_changed()
		return false

	player_data.spend_stamina(cost)
	active_rank = rank
	checkpoint_floor = int(checkpoints.get(rank, 1))
	current_floor = checkpoint_floor
	in_run = true
	player_energy = 15
	shield_turns = 0
	temp_atk_bonus = 0
	temp_def_bonus = 0
	temp_agi_bonus = 0
	_set_log([GlobalEngine.loc("dungeon.enter_log", [get_dungeon_name(rank), checkpoint_floor])])
	_start_combat()
	return true

func resolve_auto_exchange(player_data) -> bool:
	if phase != "combat" or enemy.is_empty():
		return false

	_add_energy(18)
	var player_first = _player_speed(player_data) >= int(enemy.get("spd", 1))
	if player_first:
		_player_basic_attack(player_data)
		if _enemy_dead():
			_clear_floor()
			return true
		_enemy_attack(player_data)
	else:
		_enemy_attack(player_data)
		if _player_dead(player_data):
			_fail_run(player_data)
			return true
		_player_basic_attack(player_data)

	if _enemy_dead():
		_clear_floor()
	elif _player_dead(player_data):
		_fail_run(player_data)
	else:
		_tick_shield()
		_emit_changed()
	return true

func use_skill(skill: String, player_data) -> bool:
	if phase != "combat" or enemy.is_empty():
		return false

	match skill:
		"special":
			if player_energy < 50:
				return false
			player_energy -= 50
			var damage = maxi(4, int(float(player_data.atk + temp_atk_bonus) * 1.75) + player_data.get_final_stat("INT") - int(enemy.get("def", 0) * 0.35))
			enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - damage)
			_set_combat_fx("burst", damage)
			_log(GlobalEngine.loc("dungeon.log.special", [damage]))
		"heal":
			if player_energy < 45:
				return false
			player_energy -= 45
			var heal = maxi(8, int(float(player_data.max_hp) * 0.18) + player_data.get_final_stat("WIL"))
			player_data.hp = mini(player_data.max_hp, player_data.hp + heal)
			player_data.stats_updated.emit()
			_log(GlobalEngine.loc("dungeon.log.heal", [heal]))
		"shield":
			if player_energy < 35:
				return false
			player_energy -= 35
			shield_turns = maxi(shield_turns, 2)
			_log(GlobalEngine.loc("dungeon.log.shield"))
		_:
			return false

	if _enemy_dead():
		_clear_floor()
		return true

	_enemy_attack(player_data)
	if _player_dead(player_data):
		_fail_run(player_data)
	else:
		_tick_shield()
		_emit_changed()
	return true

func advance_floor() -> bool:
	if phase != "floor_cleared":
		return false
	if current_floor >= MAX_FLOOR:
		_complete_run()
		return true
	current_floor += 1
	_start_combat()
	return true

func resolve_event(choice_index: int, player_data) -> bool:
	if phase != "event" or event_data.is_empty():
		return false

	var kind = String(event_data.get("kind", ""))
	var rank_i := _rank_index(active_rank)
	match kind:
		"altar":
			if choice_index == 0:
				var sacrifice = maxi(5, int(float(player_data.max_hp) * 0.12))
				player_data.take_damage(sacrifice)
				temp_atk_bonus += 3 + rank_i
				_log(GlobalEngine.loc("dungeon.log.altar_hp", [sacrifice]))
			elif choice_index == 1:
				var cost = mini(player_data.stamina, 8 + rank_i * 2)
				player_data.spend_stamina(cost)
				temp_def_bonus += 3 + rank_i
				_log(GlobalEngine.loc("dungeon.log.altar_end", [cost]))
			else:
				_log(GlobalEngine.loc("dungeon.log.altar_ignore"))
		"merchant":
			if choice_index == 0 and player_data.can_spend_stamina(8):
				player_data.spend_stamina(8)
				var heal = maxi(10, int(float(player_data.max_hp) * 0.22))
				player_data.hp = mini(player_data.max_hp, player_data.hp + heal)
				player_data.stats_updated.emit()
				_log(GlobalEngine.loc("dungeon.log.merchant_buy", [heal]))
			else:
				_log(GlobalEngine.loc("dungeon.log.pass"))
		"trap":
			var stat = "INT"
			if choice_index == 0:
				stat = "AGI"
			var score = player_data.get_final_stat(stat) + randi_range(1, 20)
			var difficulty = 10 + rank_i * 4 + int(float(current_floor) * 0.18)
			if rank_i == 0:
				difficulty = 8 + int(_floor_curve() * 7.0)
			if score >= difficulty:
				player_energy = mini(ENERGY_MAX, player_energy + 25)
				_log(GlobalEngine.loc("dungeon.log.test_success", [stat]))
			else:
				var damage = 6 + rank_i * 5 + int(float(current_floor) * 0.45)
				if rank_i == 0:
					damage = 5 + int(_floor_curve() * 12.0)
				damage = _round_combat_value(damage, 5)
				player_data.take_damage(damage)
				_log(GlobalEngine.loc("dungeon.log.test_fail", [stat, damage]))
		"dilemma":
			if choice_index == 0:
				var damage = 4 + rank_i * 4 + int(float(current_floor) * 0.35)
				if rank_i == 0:
					damage = 3 + int(_floor_curve() * 10.0)
				damage = _round_combat_value(damage, 5)
				player_data.take_damage(damage)
				current_floor = mini(MAX_FLOOR - 1, current_floor + 1)
				_log(GlobalEngine.loc("dungeon.log.short_path", [damage]))
			else:
				temp_def_bonus += 2
				_log(GlobalEngine.loc("dungeon.log.long_path"))

	event_data = {}
	if _player_dead(player_data):
		_fail_run(player_data)
	else:
		phase = "floor_cleared"
		_emit_changed()
	return true

func forfeit_run() -> bool:
	if not in_run:
		return false
	in_run = false
	phase = "idle"
	current_floor = int(checkpoints.get(active_rank, 1))
	event_data = {}
	enemy = {}
	_log(GlobalEngine.loc("dungeon.log.leave"))
	_emit_changed()
	return true

func get_entry_cost(rank: String) -> int:
	return int(ENTRY_COSTS.get(rank, 10))

func get_dungeon_name(rank: String) -> String:
	var key := "dungeon.name.%s" % rank.to_lower()
	if GlobalEngine.has_loc(key):
		return GlobalEngine.loc(key)
	return String(DUNGEON_NAMES.get(rank, "Donjon"))

func get_dungeon_background_stage(floor: int) -> int:
	return clampi(int(float(maxi(1, floor) - 1) / 25.0), 0, 3)

func get_dungeon_background_path(rank: String, floor: int = 1) -> String:
	var backgrounds = DUNGEON_BACKGROUNDS.get(rank, [])
	if backgrounds is Array and not backgrounds.is_empty():
		return String(backgrounds[get_dungeon_background_stage(floor)])
	return ""

func get_ambience_message(stage: int) -> String:
	return String(AMBIENCE_MESSAGES[clampi(stage, 0, AMBIENCE_MESSAGES.size() - 1)])

func get_view_state(player_rank: String = "F") -> Dictionary:
	_ensure_rank_data()
	var available: Array = []
	for rank in RANKS:
		if _rank_available(rank, player_rank):
			available.append(rank)
	return {
		"in_run": in_run,
		"active_rank": active_rank,
		"current_floor": current_floor,
		"checkpoint_floor": checkpoint_floor,
		"phase": phase,
		"player_energy": player_energy,
		"shield_turns": shield_turns,
		"enemy": enemy,
		"event": event_data,
		"log": battle_log,
		"checkpoints": checkpoints,
		"best_floors": best_floors,
		"available_ranks": available,
		"background_stage": get_dungeon_background_stage(current_floor),
		"background_path": get_dungeon_background_path(active_rank, current_floor),
		"combat_fx_seq": combat_fx_seq,
		"combat_fx": combat_fx,
		"last_drop": last_drop,
	}

func to_dict() -> Dictionary:
	return {
		"in_run": in_run,
		"active_rank": active_rank,
		"current_floor": current_floor,
		"checkpoint_floor": checkpoint_floor,
		"phase": phase,
		"player_energy": player_energy,
		"shield_turns": shield_turns,
		"temp_atk_bonus": temp_atk_bonus,
		"temp_def_bonus": temp_def_bonus,
		"temp_agi_bonus": temp_agi_bonus,
		"enemy": _serializable_enemy(),
		"event_data": event_data,
		"battle_log": battle_log,
		"checkpoints": checkpoints,
		"best_floors": best_floors,
	}

func from_dict(data: Dictionary) -> void:
	_ensure_rank_data()
	in_run = bool(data.get("in_run", false))
	active_rank = String(data.get("active_rank", "F"))
	current_floor = int(data.get("current_floor", 1))
	checkpoint_floor = int(data.get("checkpoint_floor", checkpoints.get(active_rank, 1)))
	phase = String(data.get("phase", "idle"))
	player_energy = int(data.get("player_energy", 0))
	shield_turns = int(data.get("shield_turns", 0))
	temp_atk_bonus = int(data.get("temp_atk_bonus", 0))
	temp_def_bonus = int(data.get("temp_def_bonus", 0))
	temp_agi_bonus = int(data.get("temp_agi_bonus", 0))
	enemy = data.get("enemy", {})
	if not (enemy is Dictionary):
		enemy = {}
	if enemy is Dictionary and not enemy.is_empty():
		_ensure_enemy_visual()
	event_data = data.get("event_data", {})
	battle_log = []
	for line in data.get("battle_log", []):
		battle_log.append(String(line))
	checkpoints = data.get("checkpoints", checkpoints)
	best_floors = data.get("best_floors", best_floors)
	_ensure_rank_data()

func has_pending_drop() -> bool:
	return pending_drop_floor > 0

func register_drop(item: Dictionary) -> void:
	if pending_drop_floor <= 0:
		return
	last_drop = {
		"floor": pending_drop_floor,
		"name": String(item.get("name", "Butin")),
		"rarity": String(item.get("rarity", "common")),
		"type": String(item.get("type", "")),
		"template_id": String(item.get("template_id", "")),
	}
	pending_drop_floor = 0
	_log(GlobalEngine.loc("dungeon.log.loot", [GlobalEngine.localize_item_name(last_drop)]))
	_emit_changed()

func register_drop_failed(message: String = "") -> void:
	if pending_drop_floor <= 0:
		return
	pending_drop_floor = 0
	last_drop = {}
	if message.is_empty():
		message = GlobalEngine.loc("dungeon.inventory_full")
	if not message.is_empty():
		_log(message)
	_emit_changed()

func _ensure_enemy_visual() -> void:
	var rank_i = _rank_index(active_rank)
	var type_name := String(enemy.get("type", "Brute"))
	enemy["visual"] = _pick_enemy_visual(rank_i, current_floor, type_name)
	if not enemy.has("spawn_key"):
		enemy["spawn_key"] = "%s_%d_saved" % [active_rank, current_floor]

func _start_combat() -> void:
	phase = "combat"
	event_data = {}
	enemy = _generate_enemy()
	_log(GlobalEngine.loc("dungeon.log.spawn", [current_floor, enemy.get("name", "Enemy")]))
	_emit_changed()

func _generate_enemy() -> Dictionary:
	var rank_i = _rank_index(active_rank)
	var enemy_types = TYPE_DATA.keys()
	var type_name = String(enemy_types.pick_random())
	var type_mod = TYPE_DATA[type_name]
	var visual := _pick_enemy_visual(rank_i, current_floor, type_name)
	var base_hp = 28 + current_floor * 5 + rank_i * 38
	var base_atk = 7 + current_floor * 2 + rank_i * 8
	var base_def = 3 + current_floor + rank_i * 3
	var base_spd = 92 + current_floor * 2 + rank_i * 14
	if rank_i == 0:
		var curve := _floor_curve()
		base_hp = 22 + int(round(curve * 76.0))
		base_atk = 6 + int(round(curve * 13.0))
		base_def = 3 + int(round(curve * 10.0))
		base_spd = 88 + int(round(curve * 30.0))
	return {
		"spawn_key": "%s_%d_%d" % [active_rank, current_floor, randi()],
		"name": _enemy_name(type_name),
		"type": type_name,
		"hp": _round_combat_value(int(float(base_hp) * float(type_mod["hp"])), 5),
		"max_hp": _round_combat_value(int(float(base_hp) * float(type_mod["hp"])), 5),
		"atk": _round_combat_value(int(float(base_atk) * float(type_mod["atk"])), 5),
		"def": _round_combat_value(int(float(base_def) * float(type_mod["def"])), 5),
		"spd": _round_combat_value(int(float(base_spd) * float(type_mod["spd"])), 5),
		"visual": visual,
	}

func _pick_enemy_visual(rank_i: int, floor: int, type_name: String) -> Dictionary:
	var pool: Array[String] = ["bat", "rat", "slime", "goblin", "mushroom", "skeleton"]
	if rank_i >= 1 or floor >= 12:
		pool.append_array(["mimic", "flying_eye", "rat_savage"])
	if rank_i >= 2 or floor >= 25:
		pool.append_array(["golem_blue", "knight"])
	if rank_i >= 4 or floor >= 55:
		pool.append_array(["golem_orange", "knight"])
	if rank_i >= 5 or floor >= 75:
		pool.append_array(["minotaur", "demon_slime"])

	if type_name == "Mage" and pool.has("flying_eye"):
		return MONSTER_VISUALS["flying_eye"].duplicate(true)
	if type_name == "Brute" and pool.has("golem_blue"):
		return MONSTER_VISUALS[["golem_blue", "golem_orange", "minotaur"].pick_random()].duplicate(true)
	if type_name == "Assassin" and pool.has("knight"):
		return MONSTER_VISUALS[["knight", "rat_savage"].pick_random()].duplicate(true)

	return MONSTER_VISUALS[pool.pick_random()].duplicate(true)

func _serializable_enemy() -> Dictionary:
	if not (enemy is Dictionary) or enemy.is_empty():
		return {}
	var clean := enemy.duplicate(true)
	clean.erase("visual")
	return clean

func _enemy_name(type_name: String) -> String:
	var rank_i = _rank_index(active_rank)
	var base_index := randi_range(0, 2)
	var base := GlobalEngine.loc("dungeon.enemy_base.%d.%d" % [clampi(rank_i, 0, 6), base_index])
	var type_label := GlobalEngine.loc("dungeon.enemy_type.%s" % type_name)
	return "%s %s" % [base, type_label]

func _player_basic_attack(player_data) -> void:
	var damage = _roll_damage(player_data.atk + temp_atk_bonus, int(enemy.get("def", 0)))
	var crit_roll := randi_range(1, 100) <= int(player_data.crit)
	if crit_roll:
		damage = maxi(1, int(round(float(damage) * 1.65)))
	enemy["hp"] = maxi(0, int(enemy.get("hp", 0)) - damage)
	_set_combat_fx("slash", damage)
	if crit_roll:
		_log(GlobalEngine.loc("dungeon.log.crit", [damage]))
	else:
		_log(GlobalEngine.loc("dungeon.log.player_hit", [damage]))

func _enemy_attack(player_data) -> void:
	var defense = player_data.def + temp_def_bonus
	var damage = _roll_damage(int(enemy.get("atk", 1)), defense)
	if shield_turns > 0:
		damage = maxi(1, int(float(damage) * 0.45))
	player_data.take_damage(damage)
	_log(GlobalEngine.loc("dungeon.log.enemy_hit", [enemy.get("name", "Enemy"), damage]))

func _roll_damage(atk: int, defense: int) -> int:
	return maxi(1, atk - int(float(defense) * 0.55) + randi_range(-2, 2))

func _floor_curve() -> float:
	var progress := clampf(float(current_floor - 1) / float(MAX_FLOOR - 1), 0.0, 1.0)
	return pow(progress, 1.08)

func _round_combat_value(value: int, step: int) -> int:
	if value <= 0:
		return 0
	if value < step * 2:
		return value
	return maxi(step, int(round(float(value) / float(step))) * step)

func _clear_floor() -> void:
	phase = "floor_cleared"
	pending_drop_floor = current_floor if _should_drop_loot() else 0
	last_drop = {}
	_set_combat_fx("death", 0)
	enemy = {}
	best_floors[active_rank] = maxi(int(best_floors.get(active_rank, 1)), current_floor)
	if current_floor % CHECKPOINT_STEP == 0:
		checkpoint_floor = current_floor
		checkpoints[active_rank] = checkpoint_floor
		_log(GlobalEngine.loc("dungeon.log.checkpoint", [checkpoint_floor]))

	if current_floor >= MAX_FLOOR:
		_complete_run()
		return

	if randi_range(1, 100) <= 28:
		_start_event()
	else:
		_log(GlobalEngine.loc("dungeon.log.floor_clear", [current_floor]))
		_emit_changed()

func _start_event() -> void:
	phase = "event"
	var kind = ["altar", "merchant", "trap", "dilemma"].pick_random()
	match kind:
		"altar":
			event_data = {
				"kind": kind,
				"title": GlobalEngine.loc("dungeon.event.altar.title"),
				"text": GlobalEngine.loc("dungeon.event.altar.text"),
				"choices": [GlobalEngine.loc("dungeon.event.altar.choice_hp"), GlobalEngine.loc("dungeon.event.altar.choice_end"), GlobalEngine.loc("dungeon.event.altar.choice_ignore")],
			}
		"merchant":
			event_data = {
				"kind": kind,
				"title": GlobalEngine.loc("dungeon.event.merchant.title"),
				"text": GlobalEngine.loc("dungeon.event.merchant.text"),
				"choices": [GlobalEngine.loc("dungeon.event.merchant.choice_buy"), GlobalEngine.loc("dungeon.event.merchant.choice_pass")],
			}
		"trap":
			event_data = {
				"kind": kind,
				"title": GlobalEngine.loc("dungeon.event.trap.title"),
				"text": GlobalEngine.loc("dungeon.event.trap.text"),
				"choices": [GlobalEngine.loc("dungeon.event.trap.choice_agi"), GlobalEngine.loc("dungeon.event.trap.choice_int")],
			}
		"dilemma":
			event_data = {
				"kind": kind,
				"title": GlobalEngine.loc("dungeon.event.dilemma.title"),
				"text": GlobalEngine.loc("dungeon.event.dilemma.text"),
				"choices": [GlobalEngine.loc("dungeon.event.dilemma.choice_short"), GlobalEngine.loc("dungeon.event.dilemma.choice_long")],
			}
	_log(GlobalEngine.loc("dungeon.log.event", [event_data.get("title", "Choice")]))
	_emit_changed()

func _complete_run() -> void:
	in_run = false
	phase = "completed"
	checkpoints[active_rank] = MAX_FLOOR
	best_floors[active_rank] = MAX_FLOOR
	_log(GlobalEngine.loc("dungeon.log.complete", [get_dungeon_name(active_rank)]))
	run_completed.emit(active_rank)
	_emit_changed()

func _fail_run(player_data) -> void:
	in_run = false
	phase = "dead"
	current_floor = int(checkpoints.get(active_rank, 1))
	checkpoint_floor = current_floor
	enemy = {}
	event_data = {}
	_log(GlobalEngine.loc("dungeon.log.defeat", [checkpoint_floor]))
	run_failed.emit(active_rank, current_floor)
	_emit_changed()

func _player_speed(player_data) -> int:
	return maxi(1, int(player_data.spd) + temp_agi_bonus * 5)

func _should_drop_loot() -> bool:
	if current_floor % CHECKPOINT_STEP == 0:
		return true
	var chance := DROP_CHANCE_BASE + _rank_index(active_rank) * DROP_CHANCE_RANK_STEP
	if current_floor % 5 == 0:
		chance += DROP_CHANCE_MINOR_BONUS
	chance = clampi(chance, 25, 85)
	return randi_range(1, 100) <= chance

func _enemy_dead() -> bool:
	return int(enemy.get("hp", 0)) <= 0

func _player_dead(player_data) -> bool:
	return player_data.hp <= 0

func _tick_shield() -> void:
	if shield_turns > 0:
		shield_turns -= 1

func _add_energy(amount: int) -> void:
	player_energy = mini(ENERGY_MAX, player_energy + amount)

func _rank_available(rank: String, player_rank: String) -> bool:
	var wanted = RANKS.find(rank)
	var current = RANKS.find(player_rank)
	return wanted >= 0 and current >= 0 and wanted <= current

func _rank_index(rank: String) -> int:
	return maxi(0, RANKS.find(rank))

func _ensure_rank_data() -> void:
	for rank in RANKS:
		if not checkpoints.has(rank):
			checkpoints[rank] = 1
		if not best_floors.has(rank):
			best_floors[rank] = 1

func _set_log(lines: Array) -> void:
	battle_log = lines.duplicate()

func _log(line: String) -> void:
	battle_log.append(line)
	while battle_log.size() > 8:
		battle_log.remove_at(0)

func _emit_changed() -> void:
	dungeon_changed.emit()

func _set_combat_fx(kind: String, damage: int = 0) -> void:
	combat_fx_seq += 1
	combat_fx = {
		"kind": kind,
		"damage": damage,
	}
