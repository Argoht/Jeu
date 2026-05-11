extends Control

const MISSIONS_SCENE = preload("res://Scenes/MissionsUI.tscn")

# ── Nœuds de la scène (chemins conservés — refactor UI complet à l'étape 3) ──

@onready var barre_hp      = $VBox/VitalsSection/VBox/Vitals/HP/BarreHP
@onready var label_hp_num  = $VBox/VitalsSection/VBox/Vitals/HP/Margin/HBox/Val
@onready var barre_end     = $VBox/VitalsSection/VBox/Vitals/END/BarreEnd
@onready var label_end_num = $VBox/VitalsSection/VBox/Vitals/END/Margin/HBox/Val
@onready var barre_xp      = $VBox/VitalsSection/VBox/XPLine/BarreXP
@onready var label_lvl     = $VBox/VitalsSection/VBox/XPLine/LabelLvl

@onready var game_zone_vbox = $VBox/GameZone/VBox
@onready var hero_frame     = $VBox/GameZone/VBox/HeroFrame
@onready var stats_frame    = $VBox/GameZone/VBox/StatsFrame
@onready var inv_panel      = $VBox/GameZone/VBox/InvPanel

@onready var label_pseudo = $VBox/GameZone/VBox/HeroFrame/Margin/HeroLayout/AvatarCenter/HeaderInfo/Pseudo
@onready var inv_grid     = $VBox/GameZone/VBox/InvPanel/Margin/VBox/GridZone/Grille
@onready var page_label   = $VBox/GameZone/VBox/InvPanel/Margin/VBox/Header/PageLabel
@onready var btn_prev     = $VBox/GameZone/VBox/InvPanel/Margin/VBox/Header/BtnPrev
@onready var btn_next     = $VBox/GameZone/VBox/InvPanel/Margin/VBox/Header/BtnNext

@onready var stats_labels = {
	"str": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Str/Val"),
	"dex": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Dex/Val"),
	"int": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Int/Val"),
	"vit": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Vit/Val"),
	"wil": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Wil/Val"),
	"per": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Per/Val"),
	"cha": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Cha/Val"),
	"atk": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Atk/Val"),
	"def": get_node_or_null("VBox/GameZone/VBox/StatsFrame/Margin/StatsGrid/Def/Val")
}

# ── État local ────────────────────────────────────────────────────────────────

var current_page: int = 0
var total_pages:  int = 5

var _missions_panel: Control = null
var _popup_manager  = null   # PopupManager (preloaded)

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Navigation
	$VBox/Nav/NavVBox/Row1/Button1.pressed.connect(_on_nav_pressed.bind("Personnage"))
	$VBox/Nav/NavVBox/Row1/Button3.pressed.connect(_on_nav_pressed.bind("Missions"))
	btn_prev.pressed.connect(_change_page.bind(-1))
	btn_next.pressed.connect(_change_page.bind(1))

	# PopupManager — gère level-up, mission result et rename
	_popup_manager = preload("res://Scripts/UI/PopupManager.gd").new()
	add_child(_popup_manager)

	# Bouton renommage pseudo
	_add_rename_button()

	# Panel missions (permanent, affiché/caché comme les autres panels)
	_missions_panel = MISSIONS_SCENE.instantiate()
	_missions_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_missions_panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	game_zone_vbox.add_child(_missions_panel)
	_missions_panel.hide()

	# Signaux GlobalEngine
	GlobalEngine.stats_updated.connect(update_ui)
	GlobalEngine.inventory_changed.connect(update_inventory_display)
	update_ui()

	_build_debug_bar()

# ── Navigation ────────────────────────────────────────────────────────────────

func _on_nav_pressed(tab_name: String) -> void:
	if tab_name == "Missions":
		hero_frame.hide(); stats_frame.hide(); inv_panel.hide()
		_missions_panel.show()
	else:
		_missions_panel.hide()
		hero_frame.show(); stats_frame.show(); inv_panel.show()
		update_ui()

func _change_page(step: int) -> void:
	current_page = clampi(current_page + step, 0, total_pages - 1)
	update_inventory_display()

# ── UI update ─────────────────────────────────────────────────────────────────

func update_ui() -> void:
	if not is_instance_valid(GlobalEngine): return

	barre_hp.value    = GlobalEngine.hp
	label_hp_num.text = "%d / %d" % [GlobalEngine.hp, GlobalEngine.max_hp]
	barre_end.value    = GlobalEngine.end
	label_end_num.text = "%d / %d" % [GlobalEngine.end, GlobalEngine.max_end]
	barre_xp.max_value = GlobalEngine.get_xp_for_level(GlobalEngine.lvl)
	barre_xp.value     = GlobalEngine.xp
	label_lvl.text     = "NIVEAU " + str(GlobalEngine.lvl)

	if is_instance_valid(label_pseudo):
		label_pseudo.text = GlobalEngine.player_name.to_upper()

	for s_key in stats_labels.keys():
		var label = stats_labels[s_key]
		if not is_instance_valid(label): continue

		if s_key == "atk":
			label.text = str(GlobalEngine.atk)
		elif s_key == "def":
			label.text = str(GlobalEngine.def)
		elif GlobalEngine.stats.has(s_key):
			label.text = str(GlobalEngine.stats[s_key])

		var parent   = label.get_parent()
		var btn_name = "AddBtn_" + s_key
		var btn      = parent.get_node_or_null(btn_name)

		if GlobalEngine.stat_points > 0 and s_key not in ["atk", "def"]:
			if not btn:
				btn = Button.new()
				btn.name = btn_name
				btn.text = "+"
				btn.pressed.connect(Callable(GlobalEngine, "add_stat").bind(s_key))
				parent.add_child(btn)
			btn.show()
		elif btn:
			btn.hide()

	update_inventory_display()

func update_inventory_display() -> void:
	page_label.text = "%d / %d" % [current_page + 1, total_pages]
	var slots     := inv_grid.get_children()
	var start_idx := current_page * GlobalEngine.items_per_page

	for i in range(slots.size()):
		var slot = slots[i]
		for c in slot.get_children(): c.queue_free()

		var item_idx := start_idx + i
		if item_idx < GlobalEngine.inventory.size():
			var item: Dictionary = GlobalEngine.inventory[item_idx]
			var lbl := Label.new()
			lbl.text = item["name"].substr(0, 5)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.add_theme_color_override("font_color", _rarity_color(item.get("rarity", "common")))
			slot.add_child(lbl)

## Couleur d'affichage par rareté (aligné sur ItemData.get_rarity_color).
func _rarity_color(rarity: String) -> Color:
	match rarity:
		"common":    return Color("#aaaaaa")
		"rare":      return Color("#00f2ff")
		"epic":      return Color("#cc44ff")
		"legendary": return Color("#ffd700")
		"mythic":    return Color("#ff4444")
	return Color("#aaaaaa")

# ── Rename button ─────────────────────────────────────────────────────────────

func _add_rename_button() -> void:
	var header_info = $VBox/GameZone/VBox/HeroFrame/Margin/HeroLayout/AvatarCenter/HeaderInfo

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	header_info.add_child(hbox)
	header_info.move_child(hbox, 0)

	label_pseudo.reparent(hbox)

	var btn := Button.new()
	btn.text = "✎"
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", Color("#00f2ff"))
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_width_left   = 1; s.border_width_top    = 1
	s.border_width_right  = 1; s.border_width_bottom = 1
	s.border_color = Color("#00f2ff")
	s.corner_radius_top_left    = 3; s.corner_radius_top_right   = 3
	s.corner_radius_bottom_left = 3; s.corner_radius_bottom_right = 3
	s.content_margin_left  = 4; s.content_margin_right = 4
	s.content_margin_top   = 1; s.content_margin_bottom = 1
	btn.add_theme_stylebox_override("normal", s)
	btn.pressed.connect(_popup_manager.show_rename)
	hbox.add_child(btn)

# ── Debug bar ─────────────────────────────────────────────────────────────────

func _build_debug_bar() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.0, 0.0, 0.85)
	style.border_width_bottom = 1
	style.border_color = Color("#ff3333")

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 6)
	panel.add_child(margin)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	margin.add_child(bar)

	var lbl := Label.new()
	lbl.text = "⚙ DEBUG"
	lbl.add_theme_color_override("font_color", Color("#ff3333"))
	lbl.add_theme_font_size_override("font_size", 11)
	bar.add_child(lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	for btn_data in [
		["Reset Quotidien", func(): GlobalEngine.debug_reset_daily()],
		["Reset Hebdo",     func(): GlobalEngine.debug_reset_weekly()],
		["+ Niveau",        func(): GlobalEngine.debug_add_level()],
		["+ Loot",          func(): GlobalEngine.debug_add_loot()],
	]:
		var b := Button.new()
		b.text = btn_data[0]
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(btn_data[1])
		bar.add_child(b)

	$VBox.add_child(panel)
	$VBox.move_child(panel, 0)
