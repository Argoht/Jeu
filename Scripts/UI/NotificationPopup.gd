extends Control

const MOBILE_TOUCH_TARGET := 56.0

var _level_label: Label
var _sub_label: Label
var _close_button: Button

func _ready():
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	_build()
	if GlobalEngine.has_signal("language_changed"):
		GlobalEngine.language_changed.connect(func(_locale: String): _refresh_locale())
	_refresh_locale()
	hide()

func _build():
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.65)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.14, 1)
	style.border_width_left = 2; style.border_width_top = 2
	style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = Color("#ffd700")
	style.corner_radius_top_left = 12; style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12; style.corner_radius_bottom_right = 12
	style.shadow_color = Color(1, 0.84, 0, 0.25)
	style.shadow_size = 10

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 50)
	margin.add_theme_constant_override("margin_right", 50)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	_level_label = Label.new()
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.add_theme_color_override("font_color", Color("#ffd700"))
	_level_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(_level_label)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var sub = Label.new()
	_sub_label = sub
	sub.text = GlobalEngine.loc("popup.stat_points")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub.add_theme_color_override("font_color", Color("#00f2ff"))
	sub.add_theme_font_size_override("font_size", 16)
	vbox.add_child(sub)

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.08, 0.12, 0.2)
	btn_style.border_width_left = 1; btn_style.border_width_top = 1
	btn_style.border_width_right = 1; btn_style.border_width_bottom = 2
	btn_style.border_color = Color("#ffd700")
	btn_style.corner_radius_top_left = 6; btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6; btn_style.corner_radius_bottom_right = 6
	btn_style.content_margin_left = 30; btn_style.content_margin_right = 30
	btn_style.content_margin_top = 10; btn_style.content_margin_bottom = 10

	var btn = Button.new()
	_close_button = btn
	btn.text = GlobalEngine.loc("popup.close")
	btn.custom_minimum_size = Vector2(0, MOBILE_TOUCH_TARGET)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.pressed.connect(hide)
	vbox.add_child(btn)

func notify_level_up(new_level: int):
	_level_label.text = "%s\n%s" % [GlobalEngine.loc("popup.level_up"), GlobalEngine.loc("popup.level", [new_level])]
	show()

func _refresh_locale() -> void:
	if is_instance_valid(_sub_label):
		_sub_label.text = GlobalEngine.loc("popup.stat_points")
	if is_instance_valid(_close_button):
		_close_button.text = GlobalEngine.loc("popup.close")
