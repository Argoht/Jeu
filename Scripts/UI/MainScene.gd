extends Control

const MISSIONS_SCENE = preload("res://Scenes/UI/missions_ui.tscn")
const EmptyTabPanel = preload("res://Scripts/UI/EmptyTabPanel.gd")
const INVENTORY_BACKGROUND_PATH := "res://Assets/UI/Backgrounds/inventory_background.png"
const CORE_STAT_KEYS: Array[String] = ["STR", "INT", "WIL", "AGI", "HP", "STAMINA"]
const DEBUG_BAR_DEFAULT_VISIBLE := false
const BASE_SCREEN_MARGIN := 15.0
const MOBILE_SAFE_TOP_FALLBACK := 76.0
const MOBILE_SAFE_BOTTOM_FALLBACK := 72.0
const MOBILE_TOUCH_TARGET := 56.0
const MOBILE_NAV_HEIGHT := 58.0
const MOBILE_INVENTORY_COLUMNS := 7
const MOBILE_INVENTORY_ROWS := 5
const MOBILE_INVENTORY_SLOT_SIZE := 78.0
const MOBILE_INVENTORY_SLOT_MIN := 64.0
const MOBILE_GRID_GAP := 8
const MOBILE_STATS_CARD_HEIGHT := 56.0
const MOBILE_SECTION_GAP := 14
const TOUCH_SCROLL_DEADZONE := 10.0
const TEXTURE_RECT_STRETCH_COVERED := 6
const EMPTY_TAB_NAMES: Array[String] = ["Campement", "Grimoire", "Social", "Donjon", "Boutique", "Options"]
const TAB_LABEL_KEYS := {
	"Personnage": "tab.character",
	"Campement": "tab.camp",
	"Missions": "tab.missions",
	"Grimoire": "tab.grimoire",
	"Social": "tab.social",
	"Donjon": "tab.dungeon",
	"Boutique": "tab.shop",
	"Options": "tab.options",
}
const DEFAULT_ARMOR_TEMPLATE_ID := "chemise_delavee"
const EQUIPMENT_SLOT_BY_TYPE := {
	"armor": "Torse",
	"legs": "Jambes",
	"feet": "Pieds",
	"weapon": "Mains",
	"accessory": "Anneau1",
}

# ── Nœuds de la scène ──

@onready var root_vbox     = $VBox
@onready var barre_hp      = $VBox/VitalsSection/VBox/Vitals/HP/BarreHP
@onready var label_hp_num  = $VBox/VitalsSection/VBox/Vitals/HP/Margin/HBox/Val
@onready var barre_end     = $VBox/VitalsSection/VBox/Vitals/END/BarreEnd
@onready var label_end_num = $VBox/VitalsSection/VBox/Vitals/END/Margin/HBox/Val
@onready var barre_xp      = $VBox/VitalsSection/VBox/XPLine/BarreXP
@onready var label_xp_num  = $VBox/VitalsSection/VBox/XPLine/BarreXP/XPText
@onready var label_lvl     = $VBox/VitalsSection/VBox/XPLine/LabelLvl

@onready var nav_section    = $VBox/Nav
@onready var vitals_section = $VBox/VitalsSection
@onready var game_zone      = $VBox/GameZone
@onready var hero_frame     = $VBox/GameZone/VBox/HeroFrame
@onready var avatar_view    = $VBox/GameZone/VBox/HeroFrame/Margin/HeroLayout/AvatarCenter/AvatarView
@onready var stats_frame    = $VBox/GameZone/VBox/StatsFrame
@onready var inv_panel      = $VBox/GameZone/VBox/InvPanel

@onready var btn_personnage = $VBox/Nav/NavVBox/Row1/Button1
@onready var btn_campement  = $VBox/Nav/NavVBox/Row1/Button2
@onready var btn_missions   = $VBox/Nav/NavVBox/Row1/Button3
@onready var btn_grimoire   = $VBox/Nav/NavVBox/Row1/Button4
@onready var btn_social     = $VBox/Nav/NavVBox/Row2/Button5
@onready var btn_donjon     = $VBox/Nav/NavVBox/Row2/Button6
@onready var btn_boutique   = $VBox/Nav/NavVBox/Row2/Button7
@onready var btn_options    = $VBox/Nav/NavVBox/Row2/Button8

@onready var label_pseudo = $VBox/GameZone/VBox/HeroFrame/Margin/HeroLayout/AvatarCenter/HeaderCard/HeaderInfo/Pseudo
@onready var inv_grid     = $VBox/GameZone/VBox/InvPanel/Margin/VBox/GridZone/Grille
@onready var page_label   = $VBox/GameZone/VBox/InvPanel/Margin/VBox/Header/PageLabel
@onready var btn_prev     = $VBox/GameZone/VBox/InvPanel/Margin/VBox/Header/BtnPrev
@onready var btn_next     = $VBox/GameZone/VBox/InvPanel/Margin/VBox/Header/BtnNext

@onready var stats_labels = {
	"STR": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Str/Val"),
	"AGI": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Dex/Val"),
	"INT": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Int/Val"),
	"HP": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Vit/Val"),
	"WIL": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Wil/Val"),
	"STAMINA": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Per/Val"),
	"atk": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Atk/Val"),
	"def": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Def/Val"),
	"spd": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Spd/Val"),
	"crit": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Crit/Val")
}

# ── État local ────────────────────────────────────────────────────────────────

var current_page: int = 0
var total_pages:  int = 5

var _missions_panel: Control = null
var _empty_tab_panels: Dictionary = {}
var _options_panel = null
var _debug_bar: Control = null
var _debug_invincible_button: Button = null
var _debug_mode_enabled: bool = DEBUG_BAR_DEFAULT_VISIBLE
var _popup_manager  = null   # PopupManager (preloaded)
var _safe_left_offset := BASE_SCREEN_MARGIN
var _safe_right_offset := BASE_SCREEN_MARGIN
var _safe_bottom_offset := BASE_SCREEN_MARGIN
var _active_tab_name := "Personnage"
var _touch_scroll_target: ScrollContainer = null
var _touch_scroll_start_position := Vector2.ZERO
var _touch_scroll_start_value := 0
var _touch_scroll_active_index := -1
var _inventory_background: TextureRect = null
var _inventory_scrim: ColorRect = null
var _inventory_resource_label: Label = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_apply_mobile_layout")

func _input(event: InputEvent) -> void:
	if _is_popup_active():
		_reset_touch_scroll()
		return

	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_touch_scroll_target = _get_active_scroll_container_at(touch.position)
			_touch_scroll_active_index = touch.index
			_touch_scroll_start_position = touch.position
			_touch_scroll_start_value = 0
			if is_instance_valid(_touch_scroll_target):
				_touch_scroll_start_value = _touch_scroll_target.scroll_vertical
		elif touch.index == _touch_scroll_active_index:
			_reset_touch_scroll()
		return

	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _touch_scroll_active_index or not is_instance_valid(_touch_scroll_target):
			return

		var delta_y := drag.position.y - _touch_scroll_start_position.y
		if absf(delta_y) < TOUCH_SCROLL_DEADZONE:
			return

		_touch_scroll_target.scroll_vertical = maxi(0, _touch_scroll_start_value - int(delta_y))
		get_viewport().set_input_as_handled()

func _apply_canonical_stat_labels() -> void:
	var label_paths := {
		"Str": "STR",
		"Dex": "AGI",
		"Int": "INT",
		"Vit": "HP",
		"Wil": "WIL",
		"Per": "STAMINA",
		"Atk": "ATK",
		"Def": "DEF",
	}
	for node_name in label_paths.keys():
		var lab = get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/%s/Lab" % node_name)
		if is_instance_valid(lab):
			lab.text = label_paths[node_name]

	for old_node_name in ["Cha", "Lck"]:
		var old_node = get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/%s" % old_node_name)
		if is_instance_valid(old_node):
			old_node.hide()

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_apply_canonical_stat_labels()
	_apply_mobile_layout()

	# Navigation
	_connect_navigation()
	btn_prev.pressed.connect(_change_page.bind(-1))
	btn_next.pressed.connect(_change_page.bind(1))
	if game_zone is ScrollContainer:
		game_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		game_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$VBox/GameZone/VBox.mouse_filter = Control.MOUSE_FILTER_PASS

	# PopupManager — gère level-up, mission result et rename
	_popup_manager = preload("res://Scripts/UI/PopupManager.gd").new()
	add_child(_popup_manager)

	# Bouton renommage pseudo
	_add_rename_button()

	# Ecran missions : enfant direct de la racine UI, pour ne pas heriter
	# des marges/contraintes de GameZone.
	_missions_panel = MISSIONS_SCENE.instantiate()
	add_child(_missions_panel)
	move_child(_missions_panel, _popup_manager.get_index())
	_missions_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_missions_panel.offset_left = 0
	_missions_panel.offset_top = 0
	_missions_panel.offset_right = 0
	_missions_panel.offset_bottom = 0
	_missions_panel.hide()
	_build_empty_tab_panels()

	# Signaux GlobalEngine
	GlobalEngine.stats_updated.connect(update_ui)
	GlobalEngine.inventory_changed.connect(_on_inventory_changed)
	GlobalEngine.language_changed.connect(_on_language_changed)
	_apply_localized_texts()
	update_ui()

	_set_debug_mode(DEBUG_BAR_DEFAULT_VISIBLE)
	_sync_tab_music("Personnage")

# ── Navigation ────────────────────────────────────────────────────────────────

func _connect_navigation() -> void:
	var bindings := [
		[btn_personnage, "Personnage"],
		[btn_campement, "Campement"],
		[btn_missions, "Missions"],
		[btn_grimoire, "Grimoire"],
		[btn_social, "Social"],
		[btn_donjon, "Donjon"],
		[btn_boutique, "Boutique"],
		[btn_options, "Options"],
	]

	for binding in bindings:
		var button: Button = binding[0]
		var tab_name: String = binding[1]
		button.pressed.connect(_on_nav_pressed.bind(tab_name))

func _on_language_changed(_locale: String) -> void:
	_apply_localized_texts()
	update_ui()
	_update_debug_toggle_button()
	_update_debug_invincible_button()
	if is_instance_valid(_missions_panel) and _missions_panel.has_method("refresh"):
		_missions_panel.refresh()
	for panel in _empty_tab_panels.values():
		if is_instance_valid(panel) and panel.has_method("refresh_locale"):
			panel.refresh_locale()

func _apply_localized_texts() -> void:
	var bindings := [
		[btn_personnage, "Personnage"],
		[btn_campement, "Campement"],
		[btn_missions, "Missions"],
		[btn_grimoire, "Grimoire"],
		[btn_social, "Social"],
		[btn_donjon, "Donjon"],
		[btn_boutique, "Boutique"],
		[btn_options, "Options"],
	]
	for binding in bindings:
		var button: Button = binding[0]
		var tab_name: String = binding[1]
		if is_instance_valid(button):
			button.text = GlobalEngine.loc(String(TAB_LABEL_KEYS.get(tab_name, tab_name)))

	var hp_label = get_node_or_null("VBox/VitalsSection/VBox/Vitals/HP/Margin/HBox/Label")
	if is_instance_valid(hp_label):
		hp_label.text = GlobalEngine.loc("vital.health")
	var end_label = get_node_or_null("VBox/VitalsSection/VBox/Vitals/END/Margin/HBox/Label")
	if is_instance_valid(end_label):
		end_label.text = GlobalEngine.loc("vital.endurance")
	var inventory_label = get_node_or_null("VBox/GameZone/VBox/InvPanel/Margin/VBox/Header/L")
	if is_instance_valid(inventory_label):
		inventory_label.text = GlobalEngine.loc("inventory.title")
	var header_card = get_node_or_null("VBox/GameZone/VBox/HeroFrame/Margin/HeroLayout/AvatarCenter/HeaderCard")
	if is_instance_valid(header_card):
		header_card.tooltip_text = GlobalEngine.loc("tooltip.rename")

func _on_nav_pressed(tab_name: String) -> void:
	_active_tab_name = tab_name
	_sync_tab_music(tab_name)
	vitals_section.show()
	_hide_root_tab_panels()

	if tab_name == "Personnage":
		_show_personnage_content(true)
		update_ui()
		return

	_show_personnage_content(false)
	if tab_name == "Missions":
		if _missions_panel.has_method("refresh"):
			_missions_panel.refresh()
		_missions_panel.show()
		_missions_panel.move_to_front()
	else:
		var panel = _empty_tab_panels.get(tab_name, null)
		if is_instance_valid(panel):
			panel.show()
			panel.move_to_front()

	if is_instance_valid(_popup_manager):
		move_child(_popup_manager, get_child_count() - 1)

	call_deferred("_sync_content_panels_layout")

func _sync_tab_music(tab_name: String) -> void:
	if tab_name == "Donjon":
		GlobalEngine.stop_music()
		GlobalEngine.play_dungeon_ambience()
	else:
		GlobalEngine.stop_ambience()
		GlobalEngine.play_camp_music()

func _show_personnage_content(is_visible: bool) -> void:
	hero_frame.visible = is_visible
	stats_frame.visible = is_visible
	inv_panel.visible = is_visible

func _hide_root_tab_panels() -> void:
	if is_instance_valid(_missions_panel):
		_missions_panel.hide()

	for panel in _empty_tab_panels.values():
		if is_instance_valid(panel):
			panel.hide()

func _toggle_debug_mode() -> void:
	if not GlobalEngine.debug_tools_available():
		return
	_set_debug_mode(not _debug_mode_enabled)

func _set_debug_mode(enabled: bool) -> void:
	if not GlobalEngine.debug_tools_available():
		enabled = false
	_debug_mode_enabled = enabled

	if enabled and not is_instance_valid(_debug_bar):
		_build_debug_bar()

	if is_instance_valid(_debug_bar):
		_debug_bar.visible = enabled

	_update_debug_toggle_button()
	_update_debug_invincible_button()

	call_deferred("_sync_content_panels_layout")

func _toggle_debug_invincible() -> void:
	if not GlobalEngine.debug_tools_available():
		return
	GlobalEngine.debug_toggle_invincible()
	_update_debug_invincible_button()
	update_ui()

func _update_debug_invincible_button() -> void:
	if not is_instance_valid(_debug_invincible_button):
		return
	var enabled = GlobalEngine.is_debug_invincible()
	if enabled:
		_debug_invincible_button.text = GlobalEngine.loc("debug.invincible_on")
	else:
		_debug_invincible_button.text = GlobalEngine.loc("debug.invincible_off")

func _sync_missions_layout() -> void:
	_sync_content_panels_layout()

func _sync_content_panels_layout() -> void:
	if not is_instance_valid(_missions_panel):
		return
	var content_top: float = vitals_section.global_position.y + vitals_section.size.y - global_position.y + 8.0

	var panels := [_missions_panel]
	panels.append_array(_empty_tab_panels.values())
	for panel in panels:
		if not is_instance_valid(panel):
			continue
		panel.offset_top = content_top
		panel.offset_left = _safe_left_offset
		panel.offset_right = -_safe_right_offset
		panel.offset_bottom = -_safe_bottom_offset

func _build_empty_tab_panels() -> void:
	for tab_name in EMPTY_TAB_NAMES:
		var panel: Control = _create_empty_tab_panel(tab_name)
		_empty_tab_panels[tab_name] = panel
		add_child(panel)
		move_child(panel, _popup_manager.get_index())
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		panel.offset_left = 0
		panel.offset_top = 0
		panel.offset_right = 0
		panel.offset_bottom = 0
		panel.hide()

func _create_empty_tab_panel(tab_name: String) -> Control:
	if tab_name == "Donjon":
		var dungeon_script = load("res://Scripts/UI/DungeonPanel.gd")
		if dungeon_script != null:
			var dungeon_panel = dungeon_script.new()
			if dungeon_panel is Control:
				return dungeon_panel

	var panel = EmptyTabPanel.new()
	panel.configure(tab_name, Callable(self, "_toggle_debug_mode"))
	if tab_name == "Options":
		_options_panel = panel
		_update_debug_toggle_button()
	return panel

func _update_debug_toggle_button() -> void:
	if is_instance_valid(_options_panel):
		_options_panel.set_debug_enabled(_debug_mode_enabled)

func _change_page(step: int) -> void:
	current_page = clampi(current_page + step, 0, total_pages - 1)
	update_inventory_display()
	update_equipment_display()

func _on_inventory_changed() -> void:
	update_inventory_display()
	update_equipment_display()
	update_ui()

# ── UI update ─────────────────────────────────────────────────────────────────

func update_ui() -> void:
	if not is_instance_valid(GlobalEngine): return

	barre_hp.value    = GlobalEngine.hp
	label_hp_num.text = "%d / %d" % [GlobalEngine.hp, GlobalEngine.max_hp]
	barre_end.value    = GlobalEngine.end
	label_end_num.text = "%d / %d" % [GlobalEngine.end, GlobalEngine.max_end]
	barre_xp.max_value = GlobalEngine.get_xp_for_level(GlobalEngine.lvl)
	barre_xp.value     = GlobalEngine.xp
	label_xp_num.text  = "%d / %d XP" % [GlobalEngine.xp, GlobalEngine.get_xp_for_level(GlobalEngine.lvl)]
	label_lvl.text     = GlobalEngine.loc("vital.level", [GlobalEngine.lvl])

	if is_instance_valid(label_pseudo):
		label_pseudo.text = GlobalEngine.player_name.to_upper()
	if is_instance_valid(avatar_view):
		avatar_view.set_avatar_state(GlobalEngine.lvl, GlobalEngine.get_rank_by_level(GlobalEngine.lvl), GlobalEngine.inventory_system.equipment)

	for s_key in stats_labels.keys():
		var label = stats_labels[s_key]
		if not is_instance_valid(label): continue

		if s_key == "atk":
			label.text = str(GlobalEngine.atk)
		elif s_key == "def":
			label.text = str(GlobalEngine.def)
		elif s_key == "spd":
			label.text = str(GlobalEngine.spd)
		elif s_key == "crit":
			label.text = "%d%%" % GlobalEngine.crit
		elif s_key in CORE_STAT_KEYS:
			label.text = str(GlobalEngine.get_final_stat(s_key))
		elif GlobalEngine.stats.has(s_key):
			label.text = str(GlobalEngine.stats[s_key])

		var parent   = label.get_parent()
		var btn_name = "AddBtn_" + s_key
		var btn      = parent.get_node_or_null(btn_name)

		if GlobalEngine.stat_points > 0 and s_key not in ["atk", "def", "spd", "crit"]:
			if not btn:
				btn = Button.new()
				btn.name = btn_name
				btn.text = "+"
				btn.custom_minimum_size = Vector2(MOBILE_TOUCH_TARGET, MOBILE_TOUCH_TARGET)
				btn.add_theme_font_size_override("font_size", 18)
				btn.pressed.connect(Callable(GlobalEngine, "add_stat").bind(s_key))
				parent.add_child(btn)
			btn.show()
		elif btn:
			btn.hide()

	update_inventory_display()
	update_equipment_display()

func update_inventory_display() -> void:
	_apply_inventory_layout()
	page_label.text = "%d / %d" % [current_page + 1, total_pages]
	var slots     := inv_grid.get_children()
	var start_idx := current_page * GlobalEngine.items_per_page

	for i in range(slots.size()):
		var slot = slots[i]
		_clear_slot(slot)
		if not slot.visible:
			continue

		var item_idx := start_idx + i
		if item_idx < GlobalEngine.inventory.size():
			var item: Dictionary = GlobalEngine.inventory[item_idx]
			var accent := _rarity_color(item.get("rarity", "common"))
			_apply_inventory_slot_style(slot, true, accent)
			_add_inventory_slot_effects(slot, true, accent)
			var btn := Button.new()
			_configure_item_button(btn, item)
			btn.pressed.connect(_on_inventory_item_pressed.bind(item_idx, item))
			slot.add_child(btn)
			# Fait remplir le slot après add_child (sinon les ancres n'ont pas de parent)
			btn.set_anchors_preset(Control.PRESET_FULL_RECT)
			btn.offset_left = 0; btn.offset_top = 0
			btn.offset_right = 0; btn.offset_bottom = 0
		else:
			_apply_inventory_slot_style(slot, false)
			_add_inventory_slot_effects(slot, false)

## Couleur d'affichage par rareté (aligné sur ItemData.get_rarity_color).
func update_equipment_display() -> void:
	_prepare_equipment_slots()
	for slot_type in EQUIPMENT_SLOT_BY_TYPE.keys():
		var panel := _get_equipment_slot_panel(slot_type)
		if not is_instance_valid(panel):
			continue

		var item = GlobalEngine.inventory_system.equipment.get(slot_type, null)
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var accent := _rarity_color(item.get("rarity", "common"))
		_clear_slot(panel)
		_apply_inventory_slot_style(panel, true, accent)
		_add_inventory_slot_effects(panel, true, accent)
		var btn := Button.new()
		_configure_item_button(btn, item)
		btn.pressed.connect(_on_equipment_slot_pressed.bind(slot_type))
		panel.add_child(btn)
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.offset_left = 0; btn.offset_top = 0
		btn.offset_right = 0; btn.offset_bottom = 0

func _prepare_equipment_slots() -> void:
	for column_path in [
		"VBox/GameZone/VBox/HeroFrame/Margin/HeroLayout/LeftCol",
		"VBox/GameZone/VBox/HeroFrame/Margin/HeroLayout/RightCol"
	]:
		var column = get_node_or_null(column_path)
		if not is_instance_valid(column):
			continue
		for slot in column.get_children():
			if not (slot is Panel):
				continue
			_clear_slot(slot)
			slot.custom_minimum_size = Vector2(MOBILE_TOUCH_TARGET, MOBILE_TOUCH_TARGET)
			_apply_inventory_slot_style(slot, false)
			_add_inventory_slot_effects(slot, false)

func _on_inventory_item_pressed(item_idx: int, item: Dictionary) -> void:
	var sell_text := GlobalEngine.loc("item.action.sell", [GlobalEngine.get_item_sell_value(item)])
	if _can_equip_item(item):
		_popup_manager.show_item_details(
			item,
			GlobalEngine.loc("item.action.equip"),
			Callable(self, "_equip_inventory_item_from_popup").bind(item_idx),
			sell_text,
			Callable(self, "_sell_inventory_item_from_popup").bind(item_idx)
		)
	else:
		_popup_manager.show_item_details(
			item,
			sell_text,
			Callable(self, "_sell_inventory_item_from_popup").bind(item_idx)
		)

func _on_equipment_slot_pressed(slot_type: String) -> void:
	var item = GlobalEngine.inventory_system.equipment.get(slot_type, null)
	if typeof(item) != TYPE_DICTIONARY:
		return

	_popup_manager.show_item_details(item, GlobalEngine.loc("item.action.unequip"), Callable(self, "_unequip_item_from_popup").bind(slot_type))

func _equip_inventory_item_from_popup(item_idx: int) -> void:
	GlobalEngine.equip_inventory_item(item_idx)

func _sell_inventory_item_from_popup(item_idx: int) -> void:
	GlobalEngine.sell_inventory_item(item_idx)

func _unequip_item_from_popup(slot_type: String) -> void:
	GlobalEngine.unequip_item(slot_type)

func _can_equip_item(item: Dictionary) -> bool:
	return GlobalEngine.inventory_system.equipment.has(item.get("type", ""))

func _is_default_shirt(item: Dictionary) -> bool:
	return item.get("type", "") == "armor" and item.get("template_id", "") == DEFAULT_ARMOR_TEMPLATE_ID

func _get_equipment_slot_panel(slot_type: String) -> Node:
	var node_name: String = EQUIPMENT_SLOT_BY_TYPE.get(slot_type, "")
	if node_name.is_empty():
		return null

	var left_panel = get_node_or_null("VBox/GameZone/VBox/HeroFrame/Margin/HeroLayout/LeftCol/%s" % node_name)
	if is_instance_valid(left_panel):
		return left_panel

	return get_node_or_null("VBox/GameZone/VBox/HeroFrame/Margin/HeroLayout/RightCol/%s" % node_name)

func _configure_item_button(btn: Button, item: Dictionary) -> void:
	btn.custom_minimum_size = Vector2(MOBILE_TOUCH_TARGET, MOBILE_TOUCH_TARGET)
	var accent := _rarity_color(item.get("rarity", "common"))
	var icon_tex = GlobalEngine.get_item_icon(item)
	if icon_tex != null:
		btn.icon = icon_tex
		btn.expand_icon = true
	else:
		btn.text = _type_icon(item.get("type", ""))
		btn.add_theme_font_size_override("font_size", 22)
	btn.flat = false
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_color_override("font_color", accent)
	btn.add_theme_stylebox_override("normal", _inventory_item_button_style(Color(accent.r, accent.g, accent.b, 0.055), Color(accent.r, accent.g, accent.b, 0.32), 1))
	btn.add_theme_stylebox_override("hover", _inventory_item_button_style(Color(accent.r, accent.g, accent.b, 0.12), Color(accent.r, accent.g, accent.b, 0.52), 1))
	btn.add_theme_stylebox_override("pressed", _inventory_item_button_style(Color(accent.r, accent.g, accent.b, 0.20), Color(accent.r, accent.g, accent.b, 0.85), 2))
	btn.add_theme_stylebox_override("focus", _inventory_item_button_style(Color(0, 0, 0, 0), Color(accent.r, accent.g, accent.b, 0.65), 1))

func _clear_slot(slot: Node) -> void:
	for c in slot.get_children():
		c.queue_free()

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"common":    return Color("#aaaaaa")
		"rare":      return Color("#00f2ff")
		"epic":      return Color("#cc44ff")
		"legendary": return Color("#ffd700")
		"mythic":    return Color("#ff4444")
	return Color("#aaaaaa")

## Glyphe Unicode représentant le type d'objet (placeholder en attendant les sprites).
func _type_icon(item_type: String) -> String:
	match item_type:
		"weapon":    return "⚔"
		"armor":     return "🛡"
		"legs":      return "◩"
		"feet":      return "◨"
		"accessory": return "💍"
	return "◆"

# ── Rename button ─────────────────────────────────────────────────────────────

func _add_rename_button() -> void:
	var header_card = get_node_or_null("VBox/GameZone/VBox/HeroFrame/Margin/HeroLayout/AvatarCenter/HeaderCard")
	var header_info = get_node_or_null("VBox/GameZone/VBox/HeroFrame/Margin/HeroLayout/AvatarCenter/HeaderCard/HeaderInfo")
	if not is_instance_valid(header_card) or not is_instance_valid(header_info):
		return

	header_card.mouse_filter = Control.MOUSE_FILTER_STOP
	header_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	header_card.tooltip_text = GlobalEngine.loc("tooltip.rename")
	if not header_card.gui_input.is_connected(_on_name_header_input):
		header_card.gui_input.connect(_on_name_header_input)

	header_info.add_theme_constant_override("separation", 1)
	header_info.mouse_filter = Control.MOUSE_FILTER_IGNORE

	label_pseudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_pseudo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_pseudo.clip_text = true
	label_pseudo.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_label = header_info.get_node_or_null("Titre")
	if is_instance_valid(title_label):
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_name_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_popup_manager.show_rename()
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_popup_manager.show_rename()
		accept_event()

func _apply_mobile_navigation_targets() -> void:
	for button in [btn_personnage, btn_campement, btn_missions, btn_grimoire, btn_social, btn_donjon, btn_boutique, btn_options]:
		if is_instance_valid(button):
			button.custom_minimum_size = Vector2(0, MOBILE_NAV_HEIGHT)

func _apply_mobile_layout() -> void:
	_apply_mobile_safe_area()
	_configure_game_scroll()
	_apply_content_spacing()
	_apply_mobile_navigation_targets()
	_apply_stats_layout()
	_apply_inventory_layout()
	call_deferred("_sync_content_panels_layout")
	if is_node_ready():
		call_deferred("update_inventory_display")

func _apply_mobile_safe_area() -> void:
	if not is_instance_valid(root_vbox):
		return

	var left := BASE_SCREEN_MARGIN
	var top := BASE_SCREEN_MARGIN
	var right := BASE_SCREEN_MARGIN
	var bottom := BASE_SCREEN_MARGIN

	if _is_mobile_runtime():
		var safe_padding := _get_safe_area_padding()
		left += safe_padding.x
		top += maxf(safe_padding.y, MOBILE_SAFE_TOP_FALLBACK)
		right += safe_padding.z
		bottom += maxf(safe_padding.w, MOBILE_SAFE_BOTTOM_FALLBACK)

	_safe_left_offset = left
	_safe_right_offset = right
	_safe_bottom_offset = bottom

	root_vbox.offset_left = left
	root_vbox.offset_top = top
	root_vbox.offset_right = -right
	root_vbox.offset_bottom = -bottom

func _get_safe_area_padding() -> Vector4:
	var viewport_size := get_viewport_rect().size
	var screen_size_i := DisplayServer.screen_get_size()
	var screen_size := Vector2(float(screen_size_i.x), float(screen_size_i.y))
	var safe_area := DisplayServer.get_display_safe_area()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or screen_size.x <= 0.0 or screen_size.y <= 0.0 or safe_area.size.x <= 0:
		return Vector4.ZERO

	var scale_x := viewport_size.x / screen_size.x
	var scale_y := viewport_size.y / screen_size.y
	var left := maxf(0.0, float(safe_area.position.x) * scale_x)
	var top := maxf(0.0, float(safe_area.position.y) * scale_y)
	var right := maxf(0.0, float(screen_size.x - safe_area.position.x - safe_area.size.x) * scale_x)
	var bottom := maxf(0.0, float(screen_size.y - safe_area.position.y - safe_area.size.y) * scale_y)
	return Vector4(left, top, right, bottom)

func _is_mobile_runtime() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios")

func _configure_game_scroll() -> void:
	if game_zone is ScrollContainer:
		game_zone.mouse_filter = Control.MOUSE_FILTER_STOP
		game_zone.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		game_zone.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		var content = game_zone.get_node_or_null("VBox")
		if content is Control:
			content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			content.custom_minimum_size.x = maxf(game_zone.size.x, content.custom_minimum_size.x)

func _apply_content_spacing() -> void:
	var content = get_node_or_null("VBox/GameZone/VBox")
	if content is VBoxContainer:
		content.add_theme_constant_override("separation", MOBILE_SECTION_GAP)

func _apply_stats_layout() -> void:
	if is_instance_valid(stats_frame):
		stats_frame.custom_minimum_size = Vector2(0, 268)
		stats_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if stats_frame is PanelContainer:
			stats_frame.add_theme_stylebox_override("panel", _stats_frame_style())

	var margin = get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin")
	if margin is MarginContainer:
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 12)

	var grid = get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid")
	if not (grid is GridContainer):
		return

	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)

	for card in grid.get_children():
		if not (card is PanelContainer):
			continue
		card.custom_minimum_size = Vector2(0, MOBILE_STATS_CARD_HEIGHT)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var accent := _stat_accent(card.name)
		card.add_theme_stylebox_override("panel", _stat_card_style(accent))

		var lab = card.get_node_or_null("Lab")
		if lab is Label:
			lab.add_theme_font_size_override("font_size", 16)
			lab.add_theme_color_override("font_color", accent)
			lab.add_theme_color_override("font_outline_color", Color(0.0, 0.012, 0.025, 1.0))
			lab.add_theme_color_override("font_shadow_color", Color(accent.r, accent.g, accent.b, 0.30))
			lab.add_theme_constant_override("outline_size", 1)
			lab.add_theme_constant_override("shadow_offset_y", 1)
			lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var val = card.get_node_or_null("Val")
		if val is Label:
			val.add_theme_font_size_override("font_size", 23)
			val.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 1.0))
			val.add_theme_color_override("font_outline_color", Color(0.0, 0.012, 0.025, 1.0))
			val.add_theme_color_override("font_shadow_color", Color(0.0, 0.42, 0.80, 0.30))
			val.add_theme_constant_override("outline_size", 1)
			val.add_theme_constant_override("shadow_offset_y", 1)
			val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _apply_inventory_layout() -> void:
	if not is_instance_valid(inv_grid):
		return

	var visible_slots := mini(inv_grid.get_child_count(), MOBILE_INVENTORY_COLUMNS * MOBILE_INVENTORY_ROWS)
	if visible_slots <= 0:
		return
	GlobalEngine.items_per_page = visible_slots
	total_pages = maxi(5, int(ceil(float(maxi(GlobalEngine.inventory.size(), visible_slots)) / float(visible_slots))))
	current_page = clampi(current_page, 0, total_pages - 1)

	inv_grid.columns = MOBILE_INVENTORY_COLUMNS
	inv_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inv_grid.add_theme_constant_override("h_separation", MOBILE_GRID_GAP)
	inv_grid.add_theme_constant_override("v_separation", MOBILE_GRID_GAP)
	_apply_inventory_panel_style()

	if is_instance_valid(btn_prev):
		btn_prev.custom_minimum_size = Vector2(MOBILE_TOUCH_TARGET, MOBILE_TOUCH_TARGET)
		btn_prev.add_theme_font_size_override("font_size", 18)
		btn_prev.add_theme_stylebox_override("normal", _inventory_nav_button_style())
		btn_prev.add_theme_stylebox_override("pressed", _inventory_nav_button_style(Color(0.025, 0.055, 0.080, 1), Color(0.0, 0.63, 1.0, 0.85)))
	if is_instance_valid(btn_next):
		btn_next.custom_minimum_size = Vector2(MOBILE_TOUCH_TARGET, MOBILE_TOUCH_TARGET)
		btn_next.add_theme_font_size_override("font_size", 18)
		btn_next.add_theme_stylebox_override("normal", _inventory_nav_button_style())
		btn_next.add_theme_stylebox_override("pressed", _inventory_nav_button_style(Color(0.025, 0.055, 0.080, 1), Color(0.0, 0.63, 1.0, 0.85)))
	if is_instance_valid(page_label):
		page_label.custom_minimum_size = Vector2(70, MOBILE_TOUCH_TARGET)
		page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		page_label.add_theme_font_size_override("font_size", 16)
		page_label.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0, 1.0))
		page_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.30, 0.55, 0.80))
		page_label.add_theme_constant_override("shadow_offset_x", 0)
		page_label.add_theme_constant_override("shadow_offset_y", 1)

	var slot_size := _get_inventory_slot_size()
	var slots := inv_grid.get_children()
	for i in range(slots.size()):
		var slot = slots[i]
		if slot is Control:
			slot.visible = i < visible_slots
			slot.custom_minimum_size = Vector2(slot_size, slot_size)
			slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_apply_inventory_slot_style(slot, false)

# ── Debug bar ─────────────────────────────────────────────────────────────────

func _get_inventory_slot_size() -> float:
	var panel_width := 0.0
	if is_instance_valid(inv_panel):
		panel_width = inv_panel.size.x
	if panel_width <= 1.0:
		panel_width = get_viewport_rect().size.x - (_safe_left_offset + _safe_right_offset + 44.0)
	var usable_width = maxf(1.0, panel_width - 52.0)
	var gaps = float(MOBILE_INVENTORY_COLUMNS - 1) * float(MOBILE_GRID_GAP)
	var computed_size = floorf((usable_width - gaps) / float(MOBILE_INVENTORY_COLUMNS))
	return clampf(computed_size, MOBILE_INVENTORY_SLOT_MIN, MOBILE_INVENTORY_SLOT_SIZE)

func _apply_inventory_panel_style() -> void:
	_ensure_inventory_background()
	if inv_panel is PanelContainer:
		inv_panel.add_theme_stylebox_override("panel", _inventory_panel_style())

	var margin = get_node_or_null("VBox/GameZone/VBox/InvPanel/Margin")
	if margin is MarginContainer:
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_bottom", 14)

	var title = get_node_or_null("VBox/GameZone/VBox/InvPanel/Margin/VBox/Header/L")
	if title is Label:
		title.custom_minimum_size = Vector2(168, MOBILE_TOUCH_TARGET)
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 20)
		title.add_theme_color_override("font_color", Color(0.45, 0.93, 1.0, 1.0))
		title.add_theme_color_override("font_shadow_color", Color(0.0, 0.40, 0.80, 0.85))
		title.add_theme_color_override("font_outline_color", Color(0.0, 0.015, 0.035, 1.0))
		title.add_theme_constant_override("outline_size", 2)
		title.add_theme_constant_override("shadow_offset_x", 0)
		title.add_theme_constant_override("shadow_offset_y", 2)

	var header = get_node_or_null("VBox/GameZone/VBox/InvPanel/Margin/VBox/Header")
	if header is HBoxContainer:
		header.add_theme_constant_override("separation", 8)
		_ensure_inventory_resource_label(header)

func _ensure_inventory_resource_label(header: HBoxContainer) -> void:
	if not is_instance_valid(_inventory_resource_label):
		_inventory_resource_label = Label.new()
		_inventory_resource_label.name = "ResourceLabel"
		header.add_child(_inventory_resource_label)
		var spacer := header.get_node_or_null("Spacer")
		if is_instance_valid(spacer):
			header.move_child(_inventory_resource_label, spacer.get_index())
	_inventory_resource_label.custom_minimum_size = Vector2(76, MOBILE_TOUCH_TARGET)
	_inventory_resource_label.clip_text = true
	_inventory_resource_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_inventory_resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inventory_resource_label.add_theme_font_size_override("font_size", 15)
	_inventory_resource_label.add_theme_color_override("font_color", Color("#ffd166"))
	_inventory_resource_label.add_theme_color_override("font_shadow_color", Color(0.72, 0.42, 0.03, 0.95))
	_inventory_resource_label.add_theme_color_override("font_outline_color", Color(0.0, 0.012, 0.025, 1.0))
	_inventory_resource_label.add_theme_constant_override("outline_size", 1)
	_inventory_resource_label.add_theme_constant_override("shadow_offset_x", 0)
	_inventory_resource_label.add_theme_constant_override("shadow_offset_y", 2)
	_inventory_resource_label.add_theme_stylebox_override("normal", _gold_badge_style())
	_update_inventory_resource_label()

func _update_inventory_resource_label() -> void:
	if is_instance_valid(_inventory_resource_label):
		_inventory_resource_label.text = "🪙 %s" % _format_gold_amount(GlobalEngine.gold)

func _format_gold_amount(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (float(value) / 1000000.0)
	if value >= 1000:
		return "%.1fK" % (float(value) / 1000.0)
	return str(value)

func _ensure_inventory_background() -> void:
	if not is_instance_valid(inv_panel):
		return

	if not is_instance_valid(_inventory_background):
		_inventory_background = TextureRect.new()
		_inventory_background.name = "InventoryBackground"
		var background_texture = load(INVENTORY_BACKGROUND_PATH)
		if background_texture != null:
			_inventory_background.texture = background_texture
		_inventory_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inventory_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_inventory_background.stretch_mode = TEXTURE_RECT_STRETCH_COVERED
		_inventory_background.modulate = Color(0.74, 0.90, 1.0, 0.58)
		inv_panel.add_child(_inventory_background)
		_inventory_background.set_anchors_preset(Control.PRESET_FULL_RECT)
		_inventory_background.offset_left = 0
		_inventory_background.offset_top = 0
		_inventory_background.offset_right = 0
		_inventory_background.offset_bottom = 0
		inv_panel.move_child(_inventory_background, 0)

	if not is_instance_valid(_inventory_scrim):
		_inventory_scrim = ColorRect.new()
		_inventory_scrim.name = "InventoryScrim"
		_inventory_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_inventory_scrim.color = Color(0.004, 0.010, 0.018, 0.62)
		inv_panel.add_child(_inventory_scrim)
		_inventory_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_inventory_scrim.offset_left = 0
		_inventory_scrim.offset_top = 0
		_inventory_scrim.offset_right = 0
		_inventory_scrim.offset_bottom = 0
		inv_panel.move_child(_inventory_scrim, 1)

	var margin = get_node_or_null("VBox/GameZone/VBox/InvPanel/Margin")
	if is_instance_valid(margin) and margin.get_parent() == inv_panel:
		inv_panel.move_child(margin, inv_panel.get_child_count() - 1)

func _apply_inventory_slot_style(slot: Node, occupied: bool, accent: Color = Color(0.0, 0.63, 1.0, 1.0)) -> void:
	if slot is Panel:
		slot.add_theme_stylebox_override("panel", _inventory_slot_style(occupied, accent))

func _inventory_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.004, 0.010, 0.018, 0.72)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.58, 0.92, 0.46)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.shadow_color = Color(0.0, 0.36, 0.70, 0.18)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 2)
	return style

func _gold_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.050, 0.035, 0.014, 0.86)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 0.70, 0.22, 0.58)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 7
	style.content_margin_top = 4
	style.content_margin_right = 7
	style.content_margin_bottom = 4
	style.shadow_color = Color(1.0, 0.58, 0.08, 0.12)
	style.shadow_size = 4
	return style

func _stats_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.013, 0.018, 0.027, 0.98)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.40, 0.66, 0.32)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.shadow_color = Color(0.0, 0.28, 0.54, 0.12)
	style.shadow_size = 6
	return style

func _stat_card_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.020, 0.026, 0.038, 0.96)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.42)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 14
	style.content_margin_top = 8
	style.content_margin_right = 14
	style.content_margin_bottom = 8
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.10)
	style.shadow_size = 4
	return style

func _stat_accent(card_name: String) -> Color:
	match card_name:
		"Atk":
			return Color("#ff6262")
		"Def":
			return Color("#579dff")
		"Spd":
			return Color("#42e07b")
		"Crit":
			return Color("#ffc43d")
		"Wil":
			return Color("#bd7cff")
		"Per":
			return Color("#b56cff")
		"Vit":
			return Color("#c4ccd8")
		"Str":
			return Color("#d7dde8")
		"Dex":
			return Color("#d7dde8")
		"Int":
			return Color("#9fa8b8")
	return Color("#00bfff")

func _inventory_slot_style(occupied: bool, accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if occupied:
		style.bg_color = Color(0.020, 0.028, 0.040, 0.92)
		style.border_color = Color(accent.r, accent.g, accent.b, 0.78)
		style.shadow_color = Color(accent.r, accent.g, accent.b, 0.22)
		style.shadow_size = 5
	else:
		style.bg_color = Color(0.006, 0.011, 0.019, 0.76)
		style.border_color = Color(0.0, 0.55, 0.86, 0.50)
		style.shadow_color = Color(0.0, 0.34, 0.58, 0.14)
		style.shadow_size = 3
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

func _add_inventory_slot_effects(slot: Node, occupied: bool, accent: Color = Color(0.0, 0.63, 1.0, 1.0)) -> void:
	if not (slot is Control):
		return

	var control := slot as Control
	control.mouse_filter = Control.MOUSE_FILTER_PASS

	var soft_alpha := 0.18
	var strong_alpha := 0.34
	if occupied:
		soft_alpha = 0.28
		strong_alpha = 0.56

	_add_inventory_slot_rect(control, "FxTopGleam", Color(accent.r, accent.g, accent.b, soft_alpha), 0.0, 0.0, 1.0, 0.0, 8, 5, -8, 7)
	_add_inventory_slot_rect(control, "FxLeftRail", Color(accent.r, accent.g, accent.b, strong_alpha), 0.0, 0.0, 0.0, 1.0, 5, 12, 7, -12)
	_add_inventory_slot_rect(control, "FxCornerA", Color(0.72, 0.94, 1.0, strong_alpha), 0.0, 0.0, 0.0, 0.0, 6, 6, 18, 8)
	_add_inventory_slot_rect(control, "FxCornerB", Color(accent.r, accent.g, accent.b, soft_alpha), 1.0, 1.0, 1.0, 1.0, -18, -8, -6, -6)
	if occupied:
		_add_inventory_slot_rect(control, "FxRarityDot", Color(accent.r, accent.g, accent.b, 0.82), 1.0, 0.0, 1.0, 0.0, -12, 7, -7, 12)

func _add_inventory_slot_rect(parent: Control, rect_name: String, color: Color, anchor_left: float, anchor_top: float, anchor_right: float, anchor_bottom: float, offset_left: float, offset_top: float, offset_right: float, offset_bottom: float) -> void:
	var rect := ColorRect.new()
	rect.name = rect_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = color
	parent.add_child(rect)
	rect.anchor_left = anchor_left
	rect.anchor_top = anchor_top
	rect.anchor_right = anchor_right
	rect.anchor_bottom = anchor_bottom
	rect.offset_left = offset_left
	rect.offset_top = offset_top
	rect.offset_right = offset_right
	rect.offset_bottom = offset_bottom

func _inventory_item_button_style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

func _inventory_nav_button_style(bg: Color = Color(0.028, 0.040, 0.055, 1), border: Color = Color(0.0, 0.50, 0.82, 0.55)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 12
	style.content_margin_top = 8
	style.content_margin_right = 12
	style.content_margin_bottom = 8
	return style

func _reset_touch_scroll() -> void:
	_touch_scroll_target = null
	_touch_scroll_active_index = -1
	_touch_scroll_start_position = Vector2.ZERO
	_touch_scroll_start_value = 0

func _is_popup_active() -> bool:
	if not is_instance_valid(_popup_manager):
		return false
	for child in _popup_manager.get_children():
		if child is Control and child.visible:
			return true
	return false

func _get_active_scroll_container_at(position: Vector2):
	var root: Node = null
	if _active_tab_name == "Personnage":
		root = game_zone
	elif _active_tab_name == "Missions":
		root = _missions_panel
	else:
		root = _empty_tab_panels.get(_active_tab_name, null)

	if not is_instance_valid(root):
		return null
	return _find_scroll_container_at(root, position)

func _find_scroll_container_at(node: Node, position: Vector2):
	if not (node is Control):
		return null

	var control := node as Control
	if not control.is_visible_in_tree():
		return null
	if not control.get_global_rect().has_point(position):
		return null

	for i in range(node.get_child_count() - 1, -1, -1):
		var found = _find_scroll_container_at(node.get_child(i), position)
		if found != null:
			return found

	if node is ScrollContainer:
		return node
	return null

func _build_debug_bar() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.0, 0.0, 0.85)
	style.border_width_bottom = 1
	style.border_color = Color("#ff3333")

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", style)
	_debug_bar = panel

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 6)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	scroll.add_child(bar)

	var lbl := Label.new()
	lbl.text = "⚙ DEBUG"
	lbl.add_theme_color_override("font_color", Color("#ff3333"))
	lbl.add_theme_font_size_override("font_size", 11)
	bar.add_child(lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	for btn_data in [
		[GlobalEngine.loc("debug.reset_daily"), func(): GlobalEngine.debug_reset_daily()],
		[GlobalEngine.loc("debug.reset_weekly"), func(): GlobalEngine.debug_reset_weekly()],
		[GlobalEngine.loc("debug.level_up"),     func(): GlobalEngine.debug_add_level()],
		[GlobalEngine.loc("debug.loot"),         func(): GlobalEngine.debug_add_loot()],
		[GlobalEngine.loc("debug.invincible_off"), func(): _toggle_debug_invincible()],
	]:
		var b := Button.new()
		b.text = btn_data[0]
		b.custom_minimum_size = Vector2(0, MOBILE_TOUCH_TARGET)
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(btn_data[1])
		bar.add_child(b)
		if btn_data[0] == GlobalEngine.loc("debug.invincible_off"):
			_debug_invincible_button = b

	_update_debug_invincible_button()

	$VBox.add_child(panel)
	$VBox.move_child(panel, 0)
