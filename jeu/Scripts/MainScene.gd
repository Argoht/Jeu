extends Control

const MISSIONS_SCENE = preload("res://Scenes/MissionsUI.tscn")

@onready var barre_hp     = $VBox/VitalsSection/VBox/Vitals/HP/BarreHP
@onready var label_hp_num = $VBox/VitalsSection/VBox/Vitals/HP/Margin/HBox/Val
@onready var barre_end     = $VBox/VitalsSection/VBox/Vitals/END/BarreEnd
@onready var label_end_num = $VBox/VitalsSection/VBox/Vitals/END/Margin/HBox/Val
@onready var barre_xp  = $VBox/VitalsSection/VBox/XPLine/BarreXP
@onready var label_lvl = $VBox/VitalsSection/VBox/XPLine/LabelLvl
@onready var game_zone_vbox = $VBox/GameZone/VBox
@onready var hero_frame  = $VBox/GameZone/VBox/HeroFrame
@onready var stats_frame = $VBox/GameZone/VBox/StatsFrame
@onready var inv_panel   = $VBox/GameZone/VBox/InvPanel
@onready var label_pseudo = $VBox/GameZone/VBox/HeroFrame/Margin/HeroLayout/AvatarCenter/HeaderInfo/Pseudo
@onready var inv_grid    = $VBox/GameZone/VBox/InvPanel/Margin/VBox/GridZone/Grille
@onready var page_label  = $VBox/GameZone/VBox/InvPanel/Margin/VBox/Header/PageLabel
@onready var btn_prev    = $VBox/GameZone/VBox/InvPanel/Margin/VBox/Header/BtnPrev
@onready var btn_next    = $VBox/GameZone/VBox/InvPanel/Margin/VBox/Header/BtnNext

var current_page: int = 0
var total_pages:  int = 5

# Popups
var _lvl_popup:      Control = null
var _mission_popup:  Control = null
var _fail_popup:     Control = null
var _rename_popup:   Control = null
var _rename_input:   LineEdit = null
var _lvl_num_label:    Label = null
var _miss_xp_label:    Label = null
var _miss_stat_label:  Label = null
var _fail_hp_label:    Label = null

# Bug corrigé : "wis" retiré (pas de nœud dédié dans la scène)
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

func _ready():
	$VBox/Nav/NavVBox/Row1/Button1.pressed.connect(_on_nav_pressed.bind("Personnage"))
	$VBox/Nav/NavVBox/Row1/Button3.pressed.connect(_on_nav_pressed.bind("Missions"))
	btn_prev.pressed.connect(_change_page.bind(-1))
	btn_next.pressed.connect(_change_page.bind(1))

	_lvl_popup     = _build_level_up_popup()
	_mission_popup = _build_mission_popup()
	_fail_popup    = _build_fail_popup()
	add_child(_lvl_popup)
	add_child(_mission_popup)
	add_child(_fail_popup)

	_rename_popup = _build_rename_popup()
	add_child(_rename_popup)
	_add_rename_button()

	if is_instance_valid(GlobalEngine):
		GlobalEngine.stats_updated.connect(update_ui)
		GlobalEngine.leveled_up.connect(_show_level_up)
		GlobalEngine.mission_completed.connect(_show_mission_complete)
		GlobalEngine.mission_failed.connect(_show_mission_fail)
		update_ui()

	_build_debug_bar()

# ---------------------------------------------------------------------------
# Debug
# ---------------------------------------------------------------------------

func _build_debug_bar():
	var bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.0, 0.0, 0.85)
	style.border_width_bottom = 1
	style.border_color = Color("#ff3333")

	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	for side in ["margin_left","margin_right","margin_top","margin_bottom"]:
		margin.add_theme_constant_override(side, 6)
	panel.add_child(margin)
	margin.add_child(bar)

	var lbl = Label.new()
	lbl.text = "⚙ DEBUG"
	lbl.add_theme_color_override("font_color", Color("#ff3333"))
	lbl.add_theme_font_size_override("font_size", 11)
	bar.add_child(lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	for btn_data in [
		["Reset Quotidien", func(): GlobalEngine.debug_reset_daily()],
		["Reset Hebdo",     func(): GlobalEngine.debug_reset_weekly()],
		["+ Niveau",        func(): GlobalEngine.debug_add_level()],
	]:
		var b = Button.new()
		b.text = btn_data[0]
		b.add_theme_font_size_override("font_size", 11)
		b.pressed.connect(btn_data[1])
		bar.add_child(b)

	$VBox.add_child(panel)
	$VBox.move_child(panel, 0)

# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------

func _change_page(step: int):
	current_page = clampi(current_page + step, 0, total_pages - 1)
	update_inventory_display()

func _on_nav_pressed(tab_name: String):
	for child in game_zone_vbox.get_children():
		if child.name not in ["HeroFrame", "StatsFrame", "InvPanel"]:
			child.queue_free()

	if tab_name == "Missions":
		hero_frame.hide(); stats_frame.hide(); inv_panel.hide()
		game_zone_vbox.add_child(MISSIONS_SCENE.instantiate())
	else:
		hero_frame.show(); stats_frame.show(); inv_panel.show()
		update_ui()

# ---------------------------------------------------------------------------
# UI update
# ---------------------------------------------------------------------------

func update_inventory_display():
	page_label.text = str(current_page + 1) + " / " + str(total_pages)
	var slots     = inv_grid.get_children()
	var start_idx = current_page * GlobalEngine.items_per_page

	for i in range(slots.size()):
		var slot = slots[i]
		for c in slot.get_children(): c.queue_free()

		var item_idx = start_idx + i
		if item_idx < GlobalEngine.inventory.size():
			var item = GlobalEngine.inventory[item_idx]
			var lbl  = Label.new()
			lbl.text = item["name"].substr(0, 5)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 10)
			var color = Color("#00f2ff")
			if item["rarity"] == "rare": color = Color("#ffff00")
			elif item["rarity"] == "epic": color = Color("#ff00ff")
			lbl.add_theme_color_override("font_color", color)
			slot.add_child(lbl)

func update_ui():
	if not is_instance_valid(GlobalEngine): return

	barre_hp.value    = GlobalEngine.hp
	label_hp_num.text = str(GlobalEngine.hp) + " / " + str(GlobalEngine.max_hp)
	barre_end.value    = GlobalEngine.end
	label_end_num.text = str(GlobalEngine.end) + " / " + str(GlobalEngine.max_end)
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

# ---------------------------------------------------------------------------
# Popups
# ---------------------------------------------------------------------------

func _show_level_up(new_level: int):
	_lvl_num_label.text = "Niveau %d" % new_level
	_lvl_popup.show()

func _show_mission_fail(hp_lost: int):
	_fail_hp_label.text = "- %d HP" % hp_lost
	_fail_popup.show()

func _show_mission_complete(xp_amount: int, stat_name: String, stat_amount: int):
	_miss_xp_label.text = "+ %d XP" % xp_amount
	if stat_name != "":
		_miss_stat_label.text = "+ %d %s" % [stat_amount, stat_name.to_upper()]
		_miss_stat_label.show()
	else:
		_miss_stat_label.hide()
	_mission_popup.show()

func _make_popup_base(border_color: Color) -> Array:
	var overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.72)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.14)
	style.border_width_left = 2; style.border_width_top = 2
	style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = 12; style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12; style.corner_radius_bottom_right = 12
	style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.35)
	style.shadow_size = 10

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.06, 0.10, 0.18)
	btn_style.border_width_left = 1; btn_style.border_width_top = 1
	btn_style.border_width_right = 1; btn_style.border_width_bottom = 2
	btn_style.border_color = border_color
	btn_style.corner_radius_top_left = 6; btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6; btn_style.corner_radius_bottom_right = 6
	btn_style.content_margin_left = 30; btn_style.content_margin_right = 30
	btn_style.content_margin_top = 10;  btn_style.content_margin_bottom = 10

	return [overlay, vbox, btn_style]

func _build_level_up_popup() -> Control:
	var parts      = _make_popup_base(Color("#ffd700"))
	var overlay    = parts[0] as Control
	var vbox       = parts[1] as VBoxContainer
	var btn_style  = parts[2] as StyleBoxFlat

	var title = Label.new()
	title.text = "LEVEL UP !"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#ffd700"))
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)

	_lvl_num_label = Label.new()
	_lvl_num_label.text = "Niveau 1"
	_lvl_num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lvl_num_label.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	_lvl_num_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_lvl_num_label)

	vbox.add_child(HSeparator.new())

	var pts = Label.new()
	pts.text = "+ 3 Points de Stats disponibles !"
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pts.add_theme_color_override("font_color", Color("#00f2ff"))
	pts.add_theme_font_size_override("font_size", 14)
	pts.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(pts)

	var btn = Button.new()
	btn.text = "FERMER"
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.pressed.connect(overlay.hide)
	vbox.add_child(btn)

	overlay.hide()
	return overlay

func _build_mission_popup() -> Control:
	var parts     = _make_popup_base(Color("#00ff99"))
	var overlay   = parts[0] as Control
	var vbox      = parts[1] as VBoxContainer
	var btn_style = parts[2] as StyleBoxFlat

	var title = Label.new()
	title.text = "MISSION ACCOMPLIE !"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#00ff99"))
	title.add_theme_font_size_override("font_size", 22)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	_miss_xp_label = Label.new()
	_miss_xp_label.text = "+ 0 XP"
	_miss_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_miss_xp_label.add_theme_color_override("font_color", Color("#00f2ff"))
	_miss_xp_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_miss_xp_label)

	_miss_stat_label = Label.new()
	_miss_stat_label.text = ""
	_miss_stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_miss_stat_label.add_theme_color_override("font_color", Color("#ffd700"))
	_miss_stat_label.add_theme_font_size_override("font_size", 18)
	_miss_stat_label.hide()
	vbox.add_child(_miss_stat_label)

	var btn = Button.new()
	btn.text = "CONTINUER"
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.pressed.connect(overlay.hide)
	vbox.add_child(btn)

	overlay.hide()
	return overlay

func _build_fail_popup() -> Control:
	var parts     = _make_popup_base(Color("#ff3333"))
	var overlay   = parts[0] as Control
	var vbox      = parts[1] as VBoxContainer
	var btn_style = parts[2] as StyleBoxFlat

	var title = Label.new()
	title.text = "MISSION ÉCHOUÉE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#ff3333"))
	title.add_theme_font_size_override("font_size", 22)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var msg = Label.new()
	msg.text = "Tu as été blessé durant ta mission."
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	msg.add_theme_font_size_override("font_size", 14)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(msg)

	_fail_hp_label = Label.new()
	_fail_hp_label.text = "- 20 HP"
	_fail_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fail_hp_label.add_theme_color_override("font_color", Color("#ff4444"))
	_fail_hp_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_fail_hp_label)

	var btn2 = Button.new()
	btn2.text = "COMPRIS"
	btn2.add_theme_stylebox_override("normal", btn_style)
	btn2.pressed.connect(overlay.hide)
	vbox.add_child(btn2)

	overlay.hide()
	return overlay

# ---------------------------------------------------------------------------
# Pseudo / Renommage
# ---------------------------------------------------------------------------

func _add_rename_button():
	var header_info = $VBox/GameZone/VBox/HeroFrame/Margin/HeroLayout/AvatarCenter/HeaderInfo
	var btn = Button.new()
	btn.text = "✎"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 10)
	btn.add_theme_color_override("font_color", Color("#00f2ff"))
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = Color(0, 0, 0, 0)
	s.content_margin_left = 4; s.content_margin_right = 4
	s.content_margin_top = 1; s.content_margin_bottom = 1
	btn.add_theme_stylebox_override("normal", s)
	btn.pressed.connect(_open_rename_popup)
	header_info.add_child(btn)

func _build_rename_popup() -> Control:
	var parts     = _make_popup_base(Color("#00f2ff"))
	var overlay   = parts[0] as Control
	var vbox      = parts[1] as VBoxContainer

	var title = Label.new()
	title.text = "CHANGER DE PSEUDO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#00f2ff"))
	title.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title)

	_rename_input = LineEdit.new()
	_rename_input.max_length = 20
	_rename_input.placeholder_text = "Ton pseudo..."
	_rename_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rename_input.add_theme_font_size_override("font_size", 18)
	vbox.add_child(_rename_input)

	var btns = HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	vbox.add_child(btns)

	var btn_style = parts[2] as StyleBoxFlat

	var btn_cancel = Button.new()
	btn_cancel.text = "ANNULER"
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cancel.add_theme_stylebox_override("normal", btn_style)
	btn_cancel.add_theme_color_override("font_color", Color("#888888"))
	btn_cancel.pressed.connect(func(): overlay.hide())
	btns.add_child(btn_cancel)

	var btn_confirm = Button.new()
	btn_confirm.text = "CONFIRMER"
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.add_theme_stylebox_override("normal", btn_style)
	btn_confirm.add_theme_color_override("font_color", Color("#00f2ff"))
	btn_confirm.pressed.connect(_confirm_rename)
	btns.add_child(btn_confirm)

	_rename_input.text_submitted.connect(func(_t): _confirm_rename())

	overlay.hide()
	return overlay

func _open_rename_popup():
	_rename_input.text = GlobalEngine.player_name
	_rename_input.select_all()
	_rename_popup.show()
	_rename_input.grab_focus()

func _confirm_rename():
	var new_name = _rename_input.text.strip_edges()
	if new_name.length() > 0:
		GlobalEngine.player_name = new_name
		GlobalEngine.save_game()
		if is_instance_valid(label_pseudo):
			label_pseudo.text = new_name.to_upper()
	_rename_popup.hide()
