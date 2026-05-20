extends PanelContainer

var _debug_toggle_button: Button = null
var _mute_button: Button = null
var _music_slider: HSlider = null
var _sfx_slider: HSlider = null
var _music_value_label: Label = null
var _sfx_value_label: Label = null
var _language_title_label: Label = null
var _audio_title_label: Label = null
var _english_button: Button = null
var _french_button: Button = null
var _music_label: Label = null
var _sfx_label: Label = null
var _placeholder_title_label: Label = null
var _placeholder_body_label: Label = null

func configure(tab_name: String, debug_callback: Callable) -> void:
	name = tab_name + "Panel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _make_panel_style())

	if tab_name == "Options":
		_build_options(debug_callback)
	elif tab_name == "Grimoire":
		_build_grimoire()
	elif tab_name == "Donjon":
		_build_safe_dungeon_placeholder()

func set_debug_enabled(enabled: bool) -> void:
	if is_instance_valid(_debug_toggle_button):
		_debug_toggle_button.text = GlobalEngine.loc("option.debug_on") if enabled else GlobalEngine.loc("option.debug_off")

func refresh_locale() -> void:
	if is_instance_valid(_language_title_label):
		_language_title_label.text = GlobalEngine.loc("option.language")
	if is_instance_valid(_english_button):
		_english_button.text = GlobalEngine.loc("option.english")
		_english_button.button_pressed = GlobalEngine.get_language() == "en"
	if is_instance_valid(_french_button):
		_french_button.text = GlobalEngine.loc("option.french")
		_french_button.button_pressed = GlobalEngine.get_language() == "fr"
	if is_instance_valid(_music_label):
		_music_label.text = GlobalEngine.loc("option.music")
	if is_instance_valid(_sfx_label):
		_sfx_label.text = GlobalEngine.loc("option.sfx")
	if is_instance_valid(_audio_title_label):
		_audio_title_label.text = GlobalEngine.loc("option.audio")
	if is_instance_valid(_placeholder_title_label):
		_placeholder_title_label.text = GlobalEngine.loc("placeholder.dungeon_title")
	if is_instance_valid(_placeholder_body_label):
		_placeholder_body_label.text = GlobalEngine.loc("placeholder.dungeon_safe")
	_update_mute_button_text()

func _build_options(debug_callback: Callable) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var options_box := VBoxContainer.new()
	options_box.name = "Options"
	options_box.add_theme_constant_override("separation", 10)
	margin.add_child(options_box)

	if GlobalEngine.debug_tools_available():
		_debug_toggle_button = Button.new()
		_debug_toggle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_debug_toggle_button.custom_minimum_size = Vector2(0, 56)
		_debug_toggle_button.add_theme_font_size_override("font_size", 12)
		_debug_toggle_button.add_theme_stylebox_override("normal", _button_style())
		_debug_toggle_button.add_theme_color_override("font_color", Color("#00f2ff"))
		_debug_toggle_button.pressed.connect(debug_callback)
		options_box.add_child(_debug_toggle_button)
		options_box.add_child(_make_separator())
	_add_language_options(options_box)
	options_box.add_child(_make_separator())
	_add_audio_options(options_box)

func _add_language_options(parent: VBoxContainer) -> void:
	_language_title_label = Label.new()
	_language_title_label.text = GlobalEngine.loc("option.language")
	_language_title_label.add_theme_font_size_override("font_size", 15)
	_language_title_label.add_theme_color_override("font_color", Color("#00f2ff"))
	parent.add_child(_language_title_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	_english_button = _make_da_button(GlobalEngine.loc("option.english"))
	_english_button.toggle_mode = true
	_english_button.button_pressed = GlobalEngine.get_language() == "en"
	_english_button.pressed.connect(func():
		GlobalEngine.set_language("en")
		refresh_locale()
	)
	row.add_child(_english_button)

	_french_button = _make_da_button(GlobalEngine.loc("option.french"))
	_french_button.toggle_mode = true
	_french_button.button_pressed = GlobalEngine.get_language() == "fr"
	_french_button.pressed.connect(func():
		GlobalEngine.set_language("fr")
		refresh_locale()
	)
	row.add_child(_french_button)

func _build_grimoire() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var bestiary_script = load("res://Scripts/UI/BestiaryPanel.gd")
	if bestiary_script != null:
		var bestiary = bestiary_script.new()
		bestiary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bestiary.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_child(bestiary)

func _build_safe_dungeon_placeholder() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	var title := Label.new()
	_placeholder_title_label = title
	title.text = GlobalEngine.loc("placeholder.dungeon_title")
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("#00f2ff"))
	box.add_child(title)

	var text := Label.new()
	_placeholder_body_label = text
	text.text = GlobalEngine.loc("placeholder.dungeon_safe")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	text.add_theme_font_size_override("font_size", 13)
	text.add_theme_color_override("font_color", Color("#d9f7ff"))
	box.add_child(text)

func _add_audio_options(parent: VBoxContainer) -> void:
	var title := Label.new()
	title.text = GlobalEngine.loc("option.audio")
	_audio_title_label = title
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color("#00f2ff"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(title)

	_mute_button = _make_da_button("")
	_mute_button.toggle_mode = true
	_mute_button.button_pressed = GlobalEngine.is_audio_muted()
	_mute_button.toggled.connect(_on_mute_toggled)
	parent.add_child(_mute_button)
	_update_mute_button_text()

	_music_value_label = Label.new()
	_music_slider = _make_volume_slider(GlobalEngine.get_music_volume())
	parent.add_child(_make_slider_row("option.music", _music_slider, _music_value_label))
	_music_slider.value_changed.connect(_on_music_volume_changed)

	_sfx_value_label = Label.new()
	_sfx_slider = _make_volume_slider(GlobalEngine.get_sfx_volume())
	parent.add_child(_make_slider_row("option.sfx", _sfx_slider, _sfx_value_label))
	_sfx_slider.value_changed.connect(_on_sfx_volume_changed)

	_refresh_audio_labels()

func _make_slider_row(label_key: String, slider: HSlider, value_label: Label) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _audio_row_style())
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(0, 52)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	frame.add_child(row)

	var label := Label.new()
	label.text = GlobalEngine.loc(label_key)
	label.custom_minimum_size = Vector2(72, 0)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("#d9f7ff"))
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	if label_key == "option.music":
		_music_label = label
	elif label_key == "option.sfx":
		_sfx_label = label

	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)

	value_label.custom_minimum_size = Vector2(42, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", Color("#00f2ff"))
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value_label)

	return frame

func _make_volume_slider(value: float) -> HSlider:
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(0, 36)
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = roundi(clampf(value, 0.0, 1.0) * 100.0)
	slider.add_theme_stylebox_override("slider", _slider_track_style(Color(0.025, 0.033, 0.045, 1)))
	slider.add_theme_stylebox_override("grabber_area", _slider_track_style(Color(0.0, 0.63, 1.0, 0.85)))
	slider.add_theme_stylebox_override("grabber_area_highlight", _slider_track_style(Color("#00f2ff")))
	return slider

func _on_mute_toggled(enabled: bool) -> void:
	GlobalEngine.set_audio_muted(enabled)
	_update_mute_button_text()

func _update_mute_button_text() -> void:
	if not is_instance_valid(_mute_button):
		return
	_mute_button.text = GlobalEngine.loc("option.sound_off") if GlobalEngine.is_audio_muted() else GlobalEngine.loc("option.sound_on")
	_mute_button.add_theme_color_override("font_color", Color("#ff4444") if GlobalEngine.is_audio_muted() else Color("#00f2ff"))

func _on_music_volume_changed(value: float) -> void:
	GlobalEngine.set_music_volume(value / 100.0)
	_refresh_audio_labels()

func _on_sfx_volume_changed(value: float) -> void:
	GlobalEngine.set_sfx_volume(value / 100.0)
	_refresh_audio_labels()

func _refresh_audio_labels() -> void:
	if is_instance_valid(_music_value_label):
		_music_value_label.text = "%d%%" % roundi(GlobalEngine.get_music_volume() * 100.0)
	if is_instance_valid(_sfx_value_label):
		_sfx_value_label.text = "%d%%" % roundi(GlobalEngine.get_sfx_volume() * 100.0)

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.12, 0.18, 0.24))
	return sep

func _make_da_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _button_style())
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.08, 0.04, 0.05, 1), Color("#ff4444")))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.06, 0.12, 0.19, 1), Color("#00f2ff")))
	button.add_theme_color_override("font_color", Color("#00f2ff"))
	return button

func _audio_row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 10
	style.content_margin_top = 10
	style.content_margin_right = 10
	style.content_margin_bottom = 10
	style.bg_color = Color(0.025, 0.033, 0.045, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.0, 0.63, 1.0, 0.35)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _button_style(bg: Color = Color(0.05, 0.10, 0.16, 1), border: Color = Color(0, 0.63, 1, 0.85)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 10
	style.content_margin_top = 10
	style.content_margin_right = 10
	style.content_margin_bottom = 10
	style.bg_color = bg
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _slider_track_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.0, 0.63, 1.0, 0.45)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	return style

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.043, 0.047, 0.059, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.149, 0.173, 0.212, 1)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
