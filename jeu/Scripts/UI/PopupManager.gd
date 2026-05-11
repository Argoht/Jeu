class_name PopupManager
extends Control

## Manages all game popups (level-up, mission result, rename).
## Add as a child of the root Control. Connects to GlobalEngine signals
## automatically in _ready() so MainScene needs zero popup logic.

# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted after a rename is confirmed, so listeners can refresh their UI.
signal player_renamed(new_name: String)

# ── Internal nodes ────────────────────────────────────────────────────────────

var _lvl_popup:     Control
var _mission_popup: Control
var _fail_popup:    Control
var _rename_popup:  Control

var _lvl_num_label:   Label
var _miss_xp_label:   Label
var _miss_stat_label: Label
var _fail_hp_label:   Label
var _rename_input:    LineEdit

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100

	_lvl_popup     = _build_level_up_popup()
	_mission_popup = _build_mission_popup()
	_fail_popup    = _build_fail_popup()
	_rename_popup  = _build_rename_popup()

	add_child(_lvl_popup)
	add_child(_mission_popup)
	add_child(_fail_popup)
	add_child(_rename_popup)

	GlobalEngine.leveled_up.connect(show_level_up)
	GlobalEngine.mission_completed.connect(show_mission_complete)
	GlobalEngine.mission_failed.connect(show_mission_fail)

# ── Public API ────────────────────────────────────────────────────────────────

func show_level_up(new_level: int) -> void:
	_lvl_num_label.text = "Niveau %d" % new_level
	_lvl_popup.show()

func show_mission_complete(xp_amount: int, stat_name: String, stat_amount: int) -> void:
	_miss_xp_label.text = "+ %d XP" % xp_amount
	if stat_name != "":
		_miss_stat_label.text = "+ %d %s" % [stat_amount, stat_name.to_upper()]
		_miss_stat_label.show()
	else:
		_miss_stat_label.hide()
	_mission_popup.show()

func show_mission_fail(hp_lost: int) -> void:
	_fail_hp_label.text = "- %d HP" % hp_lost
	_fail_popup.show()

func show_rename() -> void:
	_rename_input.text = GlobalEngine.player_name
	_rename_input.select_all()
	_rename_popup.show()
	_rename_input.grab_focus()

# ── Popup builders ────────────────────────────────────────────────────────────

func _make_popup_base(border_color: Color) -> Array:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 100

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.72)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.14)
	style.border_width_left   = 2; style.border_width_top    = 2
	style.border_width_right  = 2; style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left     = 12; style.corner_radius_top_right    = 12
	style.corner_radius_bottom_left  = 12; style.corner_radius_bottom_right = 12
	style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.35)
	style.shadow_size = 10

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 30 if side in ["margin_top", "margin_bottom"] else 36)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.06, 0.10, 0.18)
	btn_style.border_width_left   = 1; btn_style.border_width_top    = 1
	btn_style.border_width_right  = 1; btn_style.border_width_bottom = 2
	btn_style.border_color = border_color
	btn_style.corner_radius_top_left    = 6; btn_style.corner_radius_top_right   = 6
	btn_style.corner_radius_bottom_left = 6; btn_style.corner_radius_bottom_right = 6
	btn_style.content_margin_left  = 30; btn_style.content_margin_right = 30
	btn_style.content_margin_top   = 10; btn_style.content_margin_bottom = 10

	return [overlay, vbox, btn_style]

func _build_level_up_popup() -> Control:
	var parts     := _make_popup_base(Color("#ffd700"))
	var overlay   := parts[0] as Control
	var vbox      := parts[1] as VBoxContainer
	var btn_style := parts[2] as StyleBoxFlat

	var title := Label.new()
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

	var pts := Label.new()
	pts.text = "+ 3 Points de Stats disponibles !"
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pts.add_theme_color_override("font_color", Color("#00f2ff"))
	pts.add_theme_font_size_override("font_size", 14)
	pts.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(pts)

	var btn := Button.new()
	btn.text = "FERMER"
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.pressed.connect(overlay.hide)
	vbox.add_child(btn)

	overlay.hide()
	return overlay

func _build_mission_popup() -> Control:
	var parts     := _make_popup_base(Color("#00ff99"))
	var overlay   := parts[0] as Control
	var vbox      := parts[1] as VBoxContainer
	var btn_style := parts[2] as StyleBoxFlat

	var title := Label.new()
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
	_miss_stat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_miss_stat_label.add_theme_color_override("font_color", Color("#ffd700"))
	_miss_stat_label.add_theme_font_size_override("font_size", 18)
	_miss_stat_label.hide()
	vbox.add_child(_miss_stat_label)

	var btn := Button.new()
	btn.text = "CONTINUER"
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.pressed.connect(overlay.hide)
	vbox.add_child(btn)

	overlay.hide()
	return overlay

func _build_fail_popup() -> Control:
	var parts     := _make_popup_base(Color("#ff3333"))
	var overlay   := parts[0] as Control
	var vbox      := parts[1] as VBoxContainer
	var btn_style := parts[2] as StyleBoxFlat

	var title := Label.new()
	title.text = "MISSION ÉCHOUÉE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#ff3333"))
	title.add_theme_font_size_override("font_size", 22)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var msg := Label.new()
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

	var btn := Button.new()
	btn.text = "COMPRIS"
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.pressed.connect(overlay.hide)
	vbox.add_child(btn)

	overlay.hide()
	return overlay

func _build_rename_popup() -> Control:
	var parts     := _make_popup_base(Color("#00f2ff"))
	var overlay   := parts[0] as Control
	var vbox      := parts[1] as VBoxContainer
	var btn_style := parts[2] as StyleBoxFlat

	var title := Label.new()
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

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	vbox.add_child(btns)

	var btn_cancel := Button.new()
	btn_cancel.text = "ANNULER"
	btn_cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_cancel.add_theme_stylebox_override("normal", btn_style)
	btn_cancel.add_theme_color_override("font_color", Color("#888888"))
	btn_cancel.pressed.connect(overlay.hide)
	btns.add_child(btn_cancel)

	var btn_confirm := Button.new()
	btn_confirm.text = "CONFIRMER"
	btn_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_confirm.add_theme_stylebox_override("normal", btn_style)
	btn_confirm.add_theme_color_override("font_color", Color("#00f2ff"))
	btn_confirm.pressed.connect(_confirm_rename.bind(overlay))
	btns.add_child(btn_confirm)

	_rename_input.text_submitted.connect(func(_t): _confirm_rename(overlay))

	overlay.hide()
	return overlay

func _confirm_rename(overlay: Control) -> void:
	var new_name := _rename_input.text.strip_edges()
	if new_name.length() > 0:
		GlobalEngine.player_name = new_name
		GlobalEngine.save_game()
		GlobalEngine.stats_updated.emit()
		player_renamed.emit(new_name)
	overlay.hide()
