class_name ItemData
extends Resource

## Represents an equippable item with rarity, type and stat bonuses.
## Use ResourceSaver to persist items as .tres files.

# ── Enums ──────────────────────────────────────────────────────────────────────

enum Rarity  { COMMON, RARE, EPIC, LEGENDARY, MYTHIC }
enum ItemType { WEAPON, ARMOR, ACCESSORY }

# ── Export fields (editable in the Godot Inspector) ───────────────────────────

@export_category("Informations")
@export var id: String = "item_001"
@export var item_name: String = "Nouvel Objet"
@export_multiline var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var item_type: ItemType = ItemType.WEAPON

@export_category("Statistiques")
@export var base_power: int = 0
## Keys must match PlayerData.STAT_KEYS (ex: "str", "dex", "wil"…)
@export var stat_bonuses: Dictionary = {}

# ── Helpers ───────────────────────────────────────────────────────────────────

func get_rarity_color() -> Color:
	match rarity:
		Rarity.COMMON:    return Color("#aaaaaa")
		Rarity.RARE:      return Color("#00f2ff")
		Rarity.EPIC:      return Color("#cc44ff")
		Rarity.LEGENDARY: return Color("#ffd700")
		Rarity.MYTHIC:    return Color("#ff4444")
	return Color.WHITE

func get_rarity_name() -> String:
	return ["Commun", "Rare", "Épique", "Légendaire", "Mythique"][rarity]
