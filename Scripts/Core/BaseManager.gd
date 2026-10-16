class_name BaseManager
extends Node

signal base_changed
signal materials_gained(gains: Dictionary)

const MATERIAL_DUNGEON_STONE := "dungeon_stone"
const MATERIAL_PORTAL_WOOD := "portal_wood"
const MATERIAL_SHADOW_CRYSTAL := "shadow_crystal"
const MATERIAL_KEYS: Array[String] = [MATERIAL_DUNGEON_STONE, MATERIAL_PORTAL_WOOD, MATERIAL_SHADOW_CRYSTAL]
const RANK_LABELS: Array[String] = ["F", "E", "D", "C", "B", "A", "S"]
const DEFAULT_MAX_BUILDING_LEVEL := 3

const BUILDINGS: Array[Dictionary] = [
	{
		"id": "training",
		"max_level": 3,
		"name_key": "base.building.training.name",
		"description_key": "base.building.training.desc",
		"effect_key": "base.building.training.effect",
		"costs": [
			{"dungeon_stone": 10},
			{"dungeon_stone": 25, "portal_wood": 8},
			{"dungeon_stone": 55, "shadow_crystal": 12},
		],
		"rank_gates": [0, 1, 2],
	},
	{
		"id": "archives",
		"max_level": 3,
		"name_key": "base.building.archives.name",
		"description_key": "base.building.archives.desc",
		"effect_key": "base.building.archives.effect",
		"costs": [
			{"portal_wood": 10},
			{"portal_wood": 28, "dungeon_stone": 8},
			{"portal_wood": 60, "shadow_crystal": 10},
		],
		"rank_gates": [0, 1, 2],
	},
	{
		"id": "sanctuary",
		"max_level": 3,
		"name_key": "base.building.sanctuary.name",
		"description_key": "base.building.sanctuary.desc",
		"effect_key": "base.building.sanctuary.effect",
		"costs": [
			{"shadow_crystal": 8, "dungeon_stone": 4},
			{"shadow_crystal": 22, "portal_wood": 10},
			{"shadow_crystal": 48, "dungeon_stone": 22},
		],
		"rank_gates": [0, 1, 2],
	},
	{
		"id": "workshop",
		"max_level": 5,
		"name_key": "base.building.workshop.name",
		"description_key": "base.building.workshop.desc",
		"effect_key": "base.building.workshop.effect",
		"costs": [
			{"portal_wood": 8, "shadow_crystal": 4},
			{"portal_wood": 24, "dungeon_stone": 12},
			{"portal_wood": 52, "shadow_crystal": 18},
			{"portal_wood": 90, "dungeon_stone": 38, "shadow_crystal": 30},
			{"portal_wood": 145, "dungeon_stone": 65, "shadow_crystal": 52},
		],
		"rank_gates": [0, 1, 2, 3, 4],
	},
	{
		"id": "vault",
		"max_level": 3,
		"name_key": "base.building.vault.name",
		"description_key": "base.building.vault.desc",
		"effect_key": "base.building.vault.effect",
		"costs": [
			{"dungeon_stone": 8, "portal_wood": 6},
			{"dungeon_stone": 22, "portal_wood": 18},
			{"dungeon_stone": 48, "shadow_crystal": 16},
		],
		"rank_gates": [0, 1, 2],
	},
]

var materials: Dictionary = {}
var building_levels: Dictionary = {}

func _init() -> void:
	_reset_defaults()

func _reset_defaults() -> void:
	materials = {
		MATERIAL_DUNGEON_STONE: 0,
		MATERIAL_PORTAL_WOOD: 0,
		MATERIAL_SHADOW_CRYSTAL: 0,
	}
	building_levels = {}
	for building in BUILDINGS:
		building_levels[String(building.get("id", ""))] = 0

func award_mission_materials(stat_key: String, rank_index: int) -> Dictionary:
	var gains := preview_mission_materials(stat_key, rank_index)
	add_materials(gains)
	return gains

func preview_mission_materials(stat_key: String, rank_index: int) -> Dictionary:
	if stat_key.is_empty():
		stat_key = "STR"

	var primary := _material_for_stat(stat_key)
	var rank_bonus := clampi(rank_index, 0, RANK_LABELS.size() - 1)
	var gains := {}
	gains[primary] = 3 + rank_bonus
	if primary != MATERIAL_DUNGEON_STONE:
		gains[MATERIAL_DUNGEON_STONE] = int(gains.get(MATERIAL_DUNGEON_STONE, 0)) + 1
	if rank_bonus >= 2 and primary != MATERIAL_SHADOW_CRYSTAL:
		gains[MATERIAL_SHADOW_CRYSTAL] = int(gains.get(MATERIAL_SHADOW_CRYSTAL, 0)) + 1

	return gains

func add_materials(gains: Dictionary) -> void:
	var cleaned := {}
	for key in MATERIAL_KEYS:
		var amount := int(gains.get(key, 0))
		if amount <= 0:
			continue
		materials[key] = int(materials.get(key, 0)) + amount
		cleaned[key] = amount
	if cleaned.is_empty():
		return
	materials_gained.emit(cleaned)
	base_changed.emit()

func upgrade_building(building_id: String, rank_index: int) -> Dictionary:
	var view := get_building_view(building_id, rank_index)
	if view.is_empty():
		return {"ok": false, "reason": "unknown"}
	if bool(view.get("is_max", false)):
		return {"ok": false, "reason": "max"}
	if not bool(view.get("rank_unlocked", false)):
		return {"ok": false, "reason": "rank"}
	if not bool(view.get("can_afford", false)):
		return {"ok": false, "reason": "materials"}

	var cost: Dictionary = view.get("cost", {})
	for key in cost.keys():
		materials[key] = int(materials.get(key, 0)) - int(cost[key])

	building_levels[building_id] = int(building_levels.get(building_id, 0)) + 1
	base_changed.emit()
	return {"ok": true, "building_id": building_id, "level": int(building_levels[building_id])}

func get_materials() -> Dictionary:
	var view := {}
	for key in MATERIAL_KEYS:
		view[key] = int(materials.get(key, 0))
	return view

func get_buildings_view(rank_index: int) -> Array:
	var view := []
	for building in BUILDINGS:
		view.append(_make_building_view(building, rank_index))
	return view

func get_building_view(building_id: String, rank_index: int) -> Dictionary:
	for building in BUILDINGS:
		if String(building.get("id", "")) == building_id:
			return _make_building_view(building, rank_index)
	return {}

func get_passive_bonuses() -> Dictionary:
	var training := int(building_levels.get("training", 0))
	var archives := int(building_levels.get("archives", 0))
	var sanctuary := int(building_levels.get("sanctuary", 0))
	var workshop := int(building_levels.get("workshop", 0))
	var vault := int(building_levels.get("vault", 0))
	return {
		"STR": training,
		"AGI": training,
		"INT": archives,
		"WIL": sanctuary,
		"STAMINA": sanctuary * 5,
		"HP": workshop * 3 + vault * 5,
	}

func apply_to_player(player_data) -> void:
	if player_data != null and player_data.has_method("set_passive_bonuses"):
		player_data.set_passive_bonuses(get_passive_bonuses())

func to_dict() -> Dictionary:
	return {
		"materials": get_materials(),
		"building_levels": building_levels.duplicate(true),
	}

func from_dict(data: Dictionary) -> void:
	_reset_defaults()
	var raw_materials = data.get("materials", {})
	if raw_materials is Dictionary:
		for key in MATERIAL_KEYS:
			materials[key] = maxi(0, int(raw_materials.get(key, materials.get(key, 0))))

	var raw_levels = data.get("building_levels", {})
	if raw_levels is Dictionary:
		for building in BUILDINGS:
			var building_id := String(building.get("id", ""))
			building_levels[building_id] = clampi(int(raw_levels.get(building_id, building_levels.get(building_id, 0))), 0, _get_building_max_level(building))

func get_rank_label(rank_index: int) -> String:
	return RANK_LABELS[clampi(rank_index, 0, RANK_LABELS.size() - 1)]

func _make_building_view(building: Dictionary, rank_index: int) -> Dictionary:
	var building_id := String(building.get("id", ""))
	var max_level := _get_building_max_level(building)
	var level := clampi(int(building_levels.get(building_id, 0)), 0, max_level)
	var is_max := level >= max_level
	var costs: Array = building.get("costs", [])
	var gates: Array = building.get("rank_gates", [])
	var cost := {}
	var required_rank := 0
	if not is_max:
		var raw_cost = costs[level] if level < costs.size() else {}
		if raw_cost is Dictionary:
			cost = raw_cost.duplicate(true)
		required_rank = int(gates[level]) if level < gates.size() else 0
	var rank_unlocked := rank_index >= required_rank
	var can_afford := _can_afford(cost)
	return {
		"id": building_id,
		"name_key": String(building.get("name_key", "")),
		"description_key": String(building.get("description_key", "")),
		"effect_key": String(building.get("effect_key", "")),
		"level": level,
		"max_level": max_level,
		"cost": cost,
		"is_max": is_max,
		"required_rank": required_rank,
		"required_rank_label": get_rank_label(required_rank),
		"rank_unlocked": rank_unlocked,
		"can_afford": can_afford,
		"can_upgrade": (not is_max) and rank_unlocked and can_afford,
	}

func _can_afford(cost: Dictionary) -> bool:
	for key in cost.keys():
		if int(materials.get(key, 0)) < int(cost[key]):
			return false
	return true

func _get_building_max_level(building: Dictionary) -> int:
	return maxi(1, int(building.get("max_level", DEFAULT_MAX_BUILDING_LEVEL)))

func _material_for_stat(stat_key: String) -> String:
	match stat_key:
		"INT":
			return MATERIAL_PORTAL_WOOD
		"WIL":
			return MATERIAL_SHADOW_CRYSTAL
		_:
			return MATERIAL_DUNGEON_STONE
