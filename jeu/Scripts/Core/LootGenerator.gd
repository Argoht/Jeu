extends RefCounted

## Stateless loot factory. Rolls rarity by weighted draw, then scales base power
## and stat bonuses according to rarity and player level.
##
## Output format is a plain Dictionary (JSON-friendly for SaveSystem) :
##   { id, name, rarity, type, base_power, stat_bonuses: { stat_key: amount } }

# ── Rarity tables ─────────────────────────────────────────────────────────────

const RARITY_NAMES: Array[String] = ["common", "rare", "epic", "legendary", "mythic"]
const RARITY_WEIGHTS: Array[int]  = [60, 25, 10, 4, 1]    # sum = 100
const RARITY_MULTS: Array[float]  = [1.0, 1.8, 3.0, 5.0, 8.0]

# ── Naming ────────────────────────────────────────────────────────────────────

const TYPES: Array[String] = ["weapon", "armor", "accessory"]

const NAMES_BY_TYPE: Dictionary = {
	"weapon":    ["Lame", "Épée", "Dague", "Hache", "Lance", "Marteau"],
	"armor":     ["Tunique", "Armure", "Cuirasse", "Robe", "Cotte"],
	"accessory": ["Anneau", "Amulette", "Bracelet", "Talisman"]
}

const RARITY_SUFFIX: Dictionary = {
	"common":    "",
	"rare":      "fin",
	"epic":      "magique",
	"legendary": "légendaire",
	"mythic":    "mythique"
}

# Stats éligibles selon le type d'objet
const STATS_BY_TYPE: Dictionary = {
	"weapon":    ["str", "dex"],
	"armor":     ["vit", "wil"],
	"accessory": ["int", "wis", "per", "cha", "lck"]
}

# ── Public API ────────────────────────────────────────────────────────────────

## Generates a random item Dictionary scaled to the player's level.
static func generate(player_level: int) -> Dictionary:
	var rarity: String   = _roll_rarity()
	var item_type: String = TYPES.pick_random()
	var rarity_idx: int  = RARITY_NAMES.find(rarity)
	var mult: float      = RARITY_MULTS[rarity_idx]

	return {
		"id": "loot_%d" % randi(),
		"name": _make_name(item_type, rarity),
		"rarity": rarity,
		"type": item_type,
		"base_power": int(float(player_level) * 2.0 * mult) + 1,
		"stat_bonuses": _roll_bonuses(item_type, rarity_idx, player_level, mult)
	}

# ── Private ───────────────────────────────────────────────────────────────────

static func _roll_rarity() -> String:
	var total: int = 0
	for w in RARITY_WEIGHTS: total += w
	var roll: int = randi() % total
	var cumul: int = 0
	for i in range(RARITY_WEIGHTS.size()):
		cumul += RARITY_WEIGHTS[i]
		if roll < cumul: return RARITY_NAMES[i]
	return "common"

static func _make_name(item_type: String, rarity: String) -> String:
	var base: String = (NAMES_BY_TYPE[item_type] as Array).pick_random()
	var suffix: String = RARITY_SUFFIX[rarity]
	return base if suffix == "" else "%s %s" % [base, suffix]

static func _roll_bonuses(item_type: String, rarity_idx: int, player_level: int, mult: float) -> Dictionary:
	# common = 1 stat, mythic = up to 5
	var num_stats: int = 1 + rarity_idx
	var pool: Array = (STATS_BY_TYPE[item_type] as Array).duplicate()
	pool.shuffle()

	var bonuses: Dictionary = {}
	for i in range(mini(num_stats, pool.size())):
		var amount: int = int(float(player_level) * 0.3 * mult) + randi_range(1, 3)
		bonuses[pool[i]] = amount
	return bonuses
