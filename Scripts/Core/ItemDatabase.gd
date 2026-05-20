class_name ItemDatabase
extends Node

## Loads all ItemData templates from Data/Items/ and indexes them by id and type.
## A required preload set keeps starter equipment available in Android exports
## even if directory scanning returns nothing.

const ITEMS_PATH: String = "res://Data/Items/"
const REQUIRED_TEMPLATES: Array[ItemData] = [
	preload("res://Data/Items/massue.tres"),
	preload("res://Data/Items/chemise_delavee.tres"),
	preload("res://Data/Items/short_de_timp.tres"),
	preload("res://Data/Items/claquettes_de_boloss.tres"),
]

var _by_id: Dictionary = {}
var _by_type: Dictionary = { "weapon": [], "armor": [], "legs": [], "feet": [], "accessory": [] }

func load_all() -> void:
	_register_required_templates()

	var dir := DirAccess.open(ITEMS_PATH)
	if not dir:
		push_warning("ItemDatabase: dossier introuvable - " + ITEMS_PATH)
		return

	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			_try_load(ITEMS_PATH + fname)
		fname = dir.get_next()

func get_template(id: String) -> ItemData:
	return _by_id.get(id, null)

func get_random_by_type(type_str: String) -> ItemData:
	var pool: Array = _by_type.get(type_str, [])
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]

func has_templates_for_type(type_str: String) -> bool:
	var pool: Array = _by_type.get(type_str, [])
	return not pool.is_empty()

func template_count() -> int:
	return _by_id.size()

func _try_load(path: String) -> void:
	var res = load(path)
	if res is ItemData:
		_register_template(res as ItemData)

func _register_required_templates() -> void:
	for template in REQUIRED_TEMPLATES:
		_register_template(template)

func _register_template(tmpl: ItemData) -> void:
	if tmpl == null:
		return
	if _by_id.has(tmpl.id):
		return

	_by_id[tmpl.id] = tmpl
	var type_key: String = ItemData.type_string(tmpl.item_type)
	if _by_type.has(type_key):
		_by_type[type_key].append(tmpl)
