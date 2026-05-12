extends Node

## Manages the player's items, equipment slots and computed equipment bonuses.
## Items are stored as JSON-friendly Dictionaries — see LootGenerator.gd.
## Emits inventory_changed whenever the items list or equipment is mutated.

const LootGen  = preload("res://Scripts/Core/LootGenerator.gd")
const ItemDB   = preload("res://Scripts/Core/ItemDatabase.gd")
const StatTypes = preload("res://Scripts/Core/StatTypes.gd")

# ── Signals ───────────────────────────────────────────────────────────────────

signal inventory_changed
signal item_added(item: Dictionary)
signal item_equipped(slot: String, item: Dictionary)

# ── Constants ─────────────────────────────────────────────────────────────────

## 5 pages × 45 slots in the current UI grid.
const MAX_SLOTS: int = 225

const EQUIP_SLOTS: Array[String] = ["weapon", "armor", "accessory"]

# ── State ─────────────────────────────────────────────────────────────────────

var items: Array = []
var equipment: Dictionary = {
	"weapon": null, "armor": null, "accessory": null
}

var _item_db = null  # ItemDatabase node

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func load_database() -> void:
	_item_db = ItemDB.new()
	add_child(_item_db)
	_item_db.load_all()

# ── Public API: items ─────────────────────────────────────────────────────────

func add_item(item: Dictionary) -> bool:
	if items.size() >= MAX_SLOTS:
		return false
	items.append(item)
	item_added.emit(item)
	inventory_changed.emit()
	return true

func remove_item_at(index: int) -> Dictionary:
	if index < 0 or index >= items.size():
		return {}
	var removed: Dictionary = items[index]
	items.remove_at(index)
	inventory_changed.emit()
	return removed

func generate_loot(player_level: int) -> Dictionary:
	var item: Dictionary = LootGen.generate(player_level, _item_db)
	add_item(item)
	return item

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
		"equipment": equipment
	}

func from_dict(data: Dictionary) -> void:
	items = data.get("items", [])
	equipment = data.get("equipment", {})
	# Forward-compat: garantit que tous les slots existent
	for slot in EQUIP_SLOTS:
		if not equipment.has(slot):
			equipment[slot] = null
	inventory_changed.emit()
