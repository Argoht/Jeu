extends Node

## Manages the player's items, equipment slots and computed equipment bonuses.
## Items are stored as JSON-friendly Dictionaries — see LootGenerator.gd.
## Emits inventory_changed whenever the items list or equipment is mutated.

const LootGen  = preload("res://Scripts/Core/LootGenerator.gd")
const ItemDB   = preload("res://Scripts/Core/ItemDatabase.gd")

# ── Signals ───────────────────────────────────────────────────────────────────

signal inventory_changed
signal item_added(item: Dictionary)
signal item_equipped(slot: String, item: Dictionary)

# ── Constants ─────────────────────────────────────────────────────────────────

## 5 pages × 45 slots in the current UI grid.
const MAX_SLOTS: int = 225
const DEFAULT_ARMOR_TEMPLATE_ID := "chemise_delavee"
const DEFAULT_LEGS_TEMPLATE_ID := "short_de_timp"
const DEFAULT_FEET_TEMPLATE_ID := "claquettes_de_boloss"
const DEFAULT_WEAPON_TEMPLATE_ID := "massue"
const VITAL_STAT_MIN_BONUS := 10
const REMOVED_TEMPLATE_IDS := [
	"amulette_sagesse",
	"anneau_force",
	"armure_acier",
	"bracelet_agilite",
	"cotte_mailles",
	"dague_rapide",
	"epee_fer",
	"hache_guerre",
	"lance_ombre",
	"robe_mage",
	"talisman_chance",
	"tunique_cuir",
]

const EQUIP_SLOTS: Array[String] = ["weapon", "armor", "legs", "feet", "accessory"]

# ── State ─────────────────────────────────────────────────────────────────────

var items: Array = []
var equipment: Dictionary = {
	"weapon": null, "armor": null, "legs": null, "feet": null, "accessory": null
}
var gold: int = 0

var _item_db = null  # ItemDatabase node

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func load_database() -> void:
	_item_db = ItemDB.new()
	add_child(_item_db)
	_item_db.load_all()

func ensure_default_equipment() -> void:
	_remove_deleted_templates()
	_normalize_item_instances()
	_normalize_default_instances()
	_normalize_default_shirt_stats()
	_ensure_default_slot("weapon", DEFAULT_WEAPON_TEMPLATE_ID, "rare", {"STR": 3, "HP": 10}, "Masse rare")
	_ensure_default_slot("armor", DEFAULT_ARMOR_TEMPLATE_ID, "common", {"HP": 10})
	_ensure_default_slot("legs", DEFAULT_LEGS_TEMPLATE_ID, "common", {"AGI": 1})
	_ensure_default_slot("feet", DEFAULT_FEET_TEMPLATE_ID, "common", {"STAMINA": 10})

func _ensure_default_slot(slot: String, template_id: String, rarity: String, stat_bonuses: Dictionary, display_name: String = "") -> void:
	var equipped = equipment.get(slot, null)
	if typeof(equipped) == TYPE_DICTIONARY and not String(equipped.get("template_id", "")).is_empty():
		return

	var existing_default := _take_default_item_from_inventory(template_id)
	if not existing_default.is_empty():
		equipment[slot] = existing_default
		return

	if _has_equipped_template(template_id):
		return

	var template = null
	if _item_db != null:
		template = _item_db.get_template(template_id)
	if template == null:
		equipment[slot] = _make_fallback_default_item(slot, template_id, rarity, stat_bonuses, display_name)
		return

	var item_name: String = display_name
	if item_name.is_empty():
		item_name = template.item_name

	equipment[slot] = {
		"id": "default_%s" % template_id,
		"name": item_name,
		"rarity": rarity,
		"type": slot,
		"base_power": maxi(1, int(round(float(template.base_power) * _rarity_power_multiplier(rarity)))),
		"stat_bonuses": stat_bonuses,
		"template_id": template.id
	}

func _make_fallback_default_item(slot: String, template_id: String, rarity: String, stat_bonuses: Dictionary, display_name: String) -> Dictionary:
	var item_name := display_name
	if item_name.is_empty():
		match template_id:
			DEFAULT_ARMOR_TEMPLATE_ID:
				item_name = "Haut commun"
			DEFAULT_LEGS_TEMPLATE_ID:
				item_name = "Pantalon commun"
			DEFAULT_FEET_TEMPLATE_ID:
				item_name = "Claquettes communes"
			DEFAULT_WEAPON_TEMPLATE_ID:
				item_name = "Masse rare"
			_:
				item_name = "Equipement"

	return {
		"id": "default_%s" % template_id,
		"name": item_name,
		"rarity": rarity,
		"type": slot,
		"base_power": 1,
		"stat_bonuses": stat_bonuses,
		"template_id": template_id
	}

# ── Public API: items ─────────────────────────────────────────────────────────

func _rarity_power_multiplier(rarity: String) -> float:
	match rarity:
		"rare":
			return 1.8
		"epic":
			return 3.0
		"legendary":
			return 5.0
		"mythic":
			return 8.0
	return 1.0

func add_item(item: Dictionary) -> bool:
	if items.size() >= MAX_SLOTS:
		return false
	items.append(item)
	item_added.emit(item)
	inventory_changed.emit()
	return true

func can_add_item() -> bool:
	return items.size() < MAX_SLOTS

func remove_item_at(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}
	var removed: Dictionary = items[index]
	items.remove_at(index)
	inventory_changed.emit()
	return removed

func generate_loot(player_level: int) -> Dictionary:
	if not can_add_item():
		return {}
	var item: Dictionary = LootGen.generate(player_level, _item_db)
	if add_item(item):
		return item
	return {}

func sell_at(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}
	var item: Dictionary = items[index]
	var value := get_item_sell_value(item)
	items.remove_at(index)
	gold += value
	inventory_changed.emit()
	return {
		"item": item,
		"gold": value,
	}

func get_item_sell_value(item: Dictionary) -> int:
	var base_power := maxi(1, int(item.get("base_power", 1)))
	return maxi(1, base_power * _rarity_economy_multiplier(str(item.get("rarity", "common"))))

func _rarity_economy_multiplier(rarity: String) -> int:
	match rarity:
		"rare":
			return 4
		"epic":
			return 9
		"legendary":
			return 20
		"mythic":
			return 45
	return 2

# ── Public API: equipment ─────────────────────────────────────────────────────

## Equip the item at `index` to its matching slot, swapping any current piece
## back into the inventory. Returns true on success.
func equip_at(index: int) -> bool:
	if index < 0 or index >= items.size(): return false
	var item: Dictionary = items[index]
	var slot: String = item.get("type", "")
	if not equipment.has(slot): return false

	if equipment[slot] != null:
		items.append(equipment[slot])
	items.remove_at(index)
	equipment[slot] = item

	item_equipped.emit(slot, item)
	inventory_changed.emit()
	return true

## Unequip the item in `slot` and move it back to inventory.
func unequip(slot: String) -> bool:
	if not equipment.has(slot) or equipment[slot] == null: return false
	if items.size() >= MAX_SLOTS: return false
	items.append(equipment[slot])
	equipment[slot] = null
	inventory_changed.emit()
	return true

func _has_template_anywhere(template_id: String) -> bool:
	for slot in EQUIP_SLOTS:
		var equipped = equipment.get(slot)
		if typeof(equipped) == TYPE_DICTIONARY and equipped.get("template_id", "") == template_id:
			return true

	for item in items:
		if typeof(item) == TYPE_DICTIONARY and item.get("template_id", "") == template_id:
			return true

	return false

func _has_equipped_template(template_id: String) -> bool:
	for slot in EQUIP_SLOTS:
		var equipped = equipment.get(slot)
		if typeof(equipped) == TYPE_DICTIONARY and equipped.get("template_id", "") == template_id:
			return true
	return false

func _take_default_item_from_inventory(template_id: String) -> Dictionary:
	for i in range(items.size()):
		var item = items[i]
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var instance_id := String(item.get("id", ""))
		if instance_id.begins_with("default_") and item.get("template_id", "") == template_id:
			items.remove_at(i)
			return item
	return {}

func _normalize_default_shirt_stats() -> void:
	var armor = equipment.get("armor", null)
	if typeof(armor) == TYPE_DICTIONARY and armor.get("template_id", "") == DEFAULT_ARMOR_TEMPLATE_ID:
		var bonuses = armor.get("stat_bonuses", {})
		if typeof(bonuses) != TYPE_DICTIONARY or bonuses.is_empty():
			armor["stat_bonuses"] = {"HP": 10}
		else:
			_enforce_vital_bonus_minimums(armor)

func _normalize_item_instances() -> void:
	for slot in EQUIP_SLOTS:
		_normalize_item_instance(equipment.get(slot, null))

	for item in items:
		_normalize_item_instance(item)

func _normalize_item_instance(item) -> void:
	if typeof(item) != TYPE_DICTIONARY:
		return

	var template_id := String(item.get("template_id", ""))
	if not template_id.is_empty() and _item_db != null:
		var template = _item_db.get_template(template_id)
		if template != null:
			item["name"] = template.item_name

	_enforce_vital_bonus_minimums(item)

func _enforce_vital_bonus_minimums(item: Dictionary) -> void:
	var bonuses = item.get("stat_bonuses", {})
	if typeof(bonuses) != TYPE_DICTIONARY:
		return
	for stat_key in [StatTypes.KEY_HP, StatTypes.KEY_STAMINA]:
		if bonuses.has(stat_key):
			bonuses[stat_key] = maxi(VITAL_STAT_MIN_BONUS, int(bonuses[stat_key]))
	item["stat_bonuses"] = bonuses

func _normalize_default_instances() -> void:
	for slot in EQUIP_SLOTS:
		_normalize_default_instance(equipment.get(slot, null))

	for item in items:
		_normalize_default_instance(item)

func _normalize_default_instance(item) -> void:
	if typeof(item) != TYPE_DICTIONARY:
		return
	var instance_id := String(item.get("id", ""))
	if not instance_id.begins_with("default_"):
		return

	var template_id := String(item.get("template_id", ""))
	if template_id == DEFAULT_WEAPON_TEMPLATE_ID:
		item["name"] = "Masse rare"
		item["rarity"] = "rare"
		item["type"] = "weapon"
		item["stat_bonuses"] = {"STR": 3, "HP": 10}
		item["base_power"] = _default_power(DEFAULT_WEAPON_TEMPLATE_ID, "rare")
	elif template_id == DEFAULT_ARMOR_TEMPLATE_ID:
		item["name"] = "Haut commun"
		item["rarity"] = "common"
		item["type"] = "armor"
		item["stat_bonuses"] = {"HP": 10}
		item["base_power"] = _default_power(DEFAULT_ARMOR_TEMPLATE_ID, "common")
	elif template_id == DEFAULT_LEGS_TEMPLATE_ID:
		item["name"] = "Pantalon commun"
		item["rarity"] = "common"
		item["type"] = "legs"
		item["stat_bonuses"] = {"AGI": 1}
		item["base_power"] = _default_power(DEFAULT_LEGS_TEMPLATE_ID, "common")
	elif template_id == DEFAULT_FEET_TEMPLATE_ID:
		item["name"] = "Claquettes communes"
		item["rarity"] = "common"
		item["type"] = "feet"
		item["stat_bonuses"] = {"STAMINA": 10}
		item["base_power"] = _default_power(DEFAULT_FEET_TEMPLATE_ID, "common")

func _default_power(template_id: String, rarity: String) -> int:
	if _item_db == null:
		return 1
	var template = _item_db.get_template(template_id)
	if template == null:
		return 1
	return maxi(1, int(round(float(template.base_power) * _rarity_power_multiplier(rarity))))

func _remove_deleted_templates() -> void:
	for slot in EQUIP_SLOTS:
		var equipped = equipment.get(slot)
		if typeof(equipped) == TYPE_DICTIONARY and REMOVED_TEMPLATE_IDS.has(equipped.get("template_id", "")):
			equipment[slot] = null

	for i in range(items.size() - 1, -1, -1):
		var item = items[i]
		if typeof(item) == TYPE_DICTIONARY and REMOVED_TEMPLATE_IDS.has(item.get("template_id", "")):
			items.remove_at(i)

## Sum stat bonuses from all equipped items — used by PlayerData.get_final_stat().
func get_equipment_bonuses() -> Dictionary:
	var total: Dictionary = {}
	for slot in EQUIP_SLOTS:
		var piece = equipment.get(slot)
		if piece == null: continue
		var bonuses := StatTypes.normalize_bonus_stats(piece.get("stat_bonuses", {}))
		for stat_key in bonuses:
			total[stat_key] = total.get(stat_key, 0) + int(bonuses[stat_key])
	return total

# ── Serialization ─────────────────────────────────────────────────────────────

func to_dict() -> Dictionary:
	return {
		"items": items,
		"equipment": equipment,
		"gold": gold,
	}

func from_dict(data: Dictionary) -> void:
	var loaded_items = data.get("items", [])
	items = loaded_items if loaded_items is Array else []

	var loaded_equipment = data.get("equipment", {})
	equipment = loaded_equipment if loaded_equipment is Dictionary else {}
	gold = maxi(0, int(data.get("gold", 0)))
	# Forward-compat: garantit que tous les slots existent
	for slot in EQUIP_SLOTS:
		if not equipment.has(slot):
			equipment[slot] = null
		elif typeof(equipment[slot]) != TYPE_DICTIONARY:
			equipment[slot] = null
	inventory_changed.emit()
