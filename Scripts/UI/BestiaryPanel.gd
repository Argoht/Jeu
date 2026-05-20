extends Control

const MONSTERS = [
	{"key": "bat", "name": "Chauve-souris", "path": "res://Assets/Monsters/Bestiary/bat_fly.png", "frames": 11},
	{"key": "mimic", "name": "Mimic", "path": "res://Assets/Monsters/Bestiary/mimic_idle.png", "frames": 9},
	{"key": "rat", "name": "Rat", "path": "res://Assets/Monsters/Bestiary/rat_idle.png", "frames": 10},
	{"key": "slime", "name": "Slime", "path": "res://Assets/Monsters/Bestiary/slime_idle.png", "frames": 14},
	{"key": "flying_eye", "name": "Oeil volant", "path": "res://Assets/Monsters/Bestiary/flying_eye_flight.png", "frames": 8},
	{"key": "goblin", "name": "Gobelin", "path": "res://Assets/Monsters/Bestiary/goblin_idle.png", "frames": 4},
	{"key": "mushroom", "name": "Champignon", "path": "res://Assets/Monsters/Bestiary/mushroom_idle.png", "frames": 4},
	{"key": "skeleton", "name": "Squelette", "path": "res://Assets/Monsters/Bestiary/skeleton_idle.png", "frames": 4},
	{"key": "rat_savage", "name": "Rat sauvage", "path": "res://Assets/Monsters/Bestiary/rat_savage_idle.png", "frames": 6},
	{"key": "golem_blue", "name": "Golem bleu", "path": "res://Assets/Monsters/Bestiary/golem_blue_idle.png", "frames": 9, "frame_width": 80, "frame_height": 64},
	{"key": "golem_orange", "name": "Golem orange", "path": "res://Assets/Monsters/Bestiary/golem_orange_idle.png", "frames": 9, "frame_width": 80, "frame_height": 64},
	{"key": "demon_sword", "name": "Epee demoniaque", "path": "res://Assets/Monsters/Bestiary/demon_sword_idle.png", "frame_rects": [
		Rect2(0, 0, 64, 64),
		Rect2(128, 0, 64, 64),
		Rect2(256, 0, 64, 64),
		Rect2(384, 0, 64, 64),
		Rect2(512, 0, 64, 64),
		Rect2(640, 0, 64, 64),
		Rect2(768, 0, 64, 64),
	]},
	{"key": "minotaur", "name": "Minotaure", "path": "res://Assets/Monsters/Bestiary/minotaur_idle.png", "frames": 16, "frame_width": 288, "frame_height": 160},
	{"key": "demon_slime", "name": "Demon slime", "path": "res://Assets/Monsters/Bestiary/demon_slime_idle.png", "frames": 6, "frame_width": 288, "frame_height": 160},
	{"key": "knight", "name": "Chevalier", "path": "res://Assets/Monsters/Bestiary/knight_idle.png", "frames": 15},
]

var _monster_dialog: Control = null
var _monster_preview: TextureRect = null
var _monster_title: Label = null
var _animation_timer: Timer = null
var _current_monster: Dictionary = {}
var _current_frame := 0
var _scroll: ScrollContainer = null
var _content_margin: MarginContainer = null
var _monster_grid: GridContainer = null
var _close_wide_button: Button = null

func _ready() -> void:
	name = "Bestiaire"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build()
	_build_monster_dialog()
	if GlobalEngine.has_signal("language_changed"):
		GlobalEngine.language_changed.connect(func(_locale: String): _refresh_locale())

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_sync_content_width")

func _build() -> void:
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)

	_content_margin = MarginContainer.new()
	_content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_margin.add_theme_constant_override("margin_left", 6)
	_content_margin.add_theme_constant_override("margin_top", 8)
	_content_margin.add_theme_constant_override("margin_right", 6)
	_content_margin.add_theme_constant_override("margin_bottom", 8)
	_scroll.add_child(_content_margin)

	_monster_grid = GridContainer.new()
	_monster_grid.columns = 2
	_monster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_monster_grid.add_theme_constant_override("h_separation", 10)
	_monster_grid.add_theme_constant_override("v_separation", 10)
	_content_margin.add_child(_monster_grid)

	for monster in MONSTERS:
		_monster_grid.add_child(_make_monster_card(monster))
	call_deferred("_sync_content_width")

func _refresh_locale() -> void:
	if is_instance_valid(_monster_grid):
		for child in _monster_grid.get_children():
			_monster_grid.remove_child(child)
			child.queue_free()
		for monster in MONSTERS:
			_monster_grid.add_child(_make_monster_card(monster))
	if is_instance_valid(_close_wide_button):
		_close_wide_button.text = GlobalEngine.loc("popup.close")
	if is_instance_valid(_monster_title) and not _current_monster.is_empty():
		_monster_title.text = _localized_monster_name(_current_monster).to_upper()

func _sync_content_width() -> void:
	if not is_instance_valid(_scroll) or not is_instance_valid(_content_margin):
		return
	var target_width = maxf(0.0, _scroll.size.x)
	if target_width <= 1.0:
		target_width = maxf(0.0, get_viewport_rect().size.x - 24.0)
	if absf(_content_margin.custom_minimum_size.x - target_width) > 0.5:
		_content_margin.custom_minimum_size = Vector2(target_width, 0.0)
	if is_instance_valid(_monster_grid):
		var usable_width = maxf(1.0, target_width - 12.0)
		var columns := 2
		if usable_width >= 1240.0:
			columns = 4
		elif usable_width >= 900.0:
			columns = 3
		_monster_grid.columns = columns

func _make_monster_card(monster: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 146)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(_on_monster_card_input.bind(monster))
	card.tooltip_text = GlobalEngine.loc("bestiary.view_large")
	card.add_theme_stylebox_override("panel", _card_style())

	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(116, 88)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _make_frame_texture(monster, 0)
	box.add_child(icon)

	var label = Label.new()
	label.text = _localized_monster_name(monster).to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("#d9f7ff"))
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)

	var tap_button = Button.new()
	tap_button.text = ""
	tap_button.flat = true
	tap_button.focus_mode = Control.FOCUS_NONE
	tap_button.mouse_filter = Control.MOUSE_FILTER_STOP
	tap_button.tooltip_text = GlobalEngine.loc("bestiary.view_large")
	for state in ["normal", "hover", "pressed", "focus"]:
		tap_button.add_theme_stylebox_override(state, _transparent_button_style())
	tap_button.pressed.connect(_show_monster.bind(monster))
	card.add_child(tap_button)
	tap_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	tap_button.offset_left = 0
	tap_button.offset_top = 0
	tap_button.offset_right = 0
	tap_button.offset_bottom = 0

	return card

func _on_monster_card_input(event: InputEvent, monster: Dictionary) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_show_monster(monster)
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_show_monster(monster)
		accept_event()

func _build_monster_dialog() -> void:
	_monster_dialog = Control.new()
	_monster_dialog.name = "MonsterPopup"
	_monster_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
	_monster_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	_monster_dialog.hide()
	add_child(_monster_dialog)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.gui_input.connect(_on_dialog_background_input)
	_monster_dialog.add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monster_dialog.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _dialog_panel_style())
	center.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var header = HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	_monster_title = Label.new()
	_monster_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_monster_title.add_theme_font_size_override("font_size", 18)
	_monster_title.add_theme_color_override("font_color", Color("#00f2ff"))
	header.add_child(_monster_title)

	var close_button = Button.new()
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(56, 56)
	close_button.add_theme_font_size_override("font_size", 16)
	close_button.add_theme_color_override("font_color", Color("#ff4444"))
	close_button.add_theme_stylebox_override("normal", _dialog_button_style(Color(0.05, 0.08, 0.13), Color("#ff4444")))
	close_button.add_theme_stylebox_override("hover", _dialog_button_style(Color(0.10, 0.04, 0.05), Color("#ff6666")))
	close_button.add_theme_stylebox_override("pressed", _dialog_button_style(Color(0.14, 0.02, 0.03), Color("#ff4444")))
	close_button.pressed.connect(_hide_monster_dialog)
	header.add_child(close_button)

	_monster_preview = TextureRect.new()
	_monster_preview.custom_minimum_size = Vector2(260, 190)
	_monster_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_monster_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_monster_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	box.add_child(_monster_preview)

	var close_wide = Button.new()
	_close_wide_button = close_wide
	close_wide.text = GlobalEngine.loc("popup.close")
	close_wide.custom_minimum_size = Vector2(0, 56)
	close_wide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_wide.add_theme_font_size_override("font_size", 13)
	close_wide.add_theme_color_override("font_color", Color("#00f2ff"))
	close_wide.add_theme_stylebox_override("normal", _dialog_button_style())
	close_wide.add_theme_stylebox_override("hover", _dialog_button_style(Color(0.06, 0.12, 0.19), Color("#00f2ff")))
	close_wide.add_theme_stylebox_override("pressed", _dialog_button_style(Color(0.03, 0.07, 0.12), Color("#00aaff")))
	close_wide.pressed.connect(_hide_monster_dialog)
	box.add_child(close_wide)

	_animation_timer = Timer.new()
	_animation_timer.wait_time = 0.12
	_animation_timer.timeout.connect(_advance_monster_animation)
	add_child(_animation_timer)

func _show_monster(monster: Dictionary) -> void:
	if _monster_dialog == null:
		return

	var monster_name = _localized_monster_name(monster)
	_current_monster = monster
	_current_frame = 0
	_monster_title.text = monster_name.to_upper()
	_monster_preview.texture = _make_frame_texture(monster, _current_frame)
	_monster_dialog.show()
	_monster_dialog.move_to_front()

	if _get_frame_count(monster) > 1:
		_animation_timer.start()
	else:
		_animation_timer.stop()

func _localized_monster_name(monster: Dictionary) -> String:
	var key := "bestiary.monster.%s" % String(monster.get("key", ""))
	if GlobalEngine.has_loc(key):
		return GlobalEngine.loc(key)
	return String(monster.get("name", "Monster"))

func _hide_monster_dialog() -> void:
	_stop_monster_animation()
	if is_instance_valid(_monster_dialog):
		_monster_dialog.hide()

func _on_dialog_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_hide_monster_dialog()
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_hide_monster_dialog()
		accept_event()

func _advance_monster_animation() -> void:
	if _current_monster.is_empty():
		_animation_timer.stop()
		return

	var frame_count = _get_frame_count(_current_monster)
	if frame_count <= 1:
		_animation_timer.stop()
		return

	_current_frame = (_current_frame + 1) % frame_count
	_monster_preview.texture = _make_frame_texture(_current_monster, _current_frame)

func _stop_monster_animation() -> void:
	if _animation_timer != null:
		_animation_timer.stop()
	_current_monster = {}
	_current_frame = 0

func _make_first_frame_texture(path: String) -> Texture2D:
	var atlas = load(path)
	if atlas is Texture2D:
		return _make_atlas_first_frame(atlas)

	var image = Image.new()
	var error = image.load(path)
	if error == OK:
		return _make_atlas_first_frame(ImageTexture.create_from_image(image))
	return null

func _make_atlas_first_frame(atlas: Texture2D) -> AtlasTexture:
	var frame_size = minf(atlas.get_width(), atlas.get_height())
	var texture = AtlasTexture.new()
	texture.atlas = atlas
	texture.region = Rect2(0, 0, frame_size, atlas.get_height())
	return texture

func _make_frame_texture(monster: Dictionary, frame: int) -> Texture2D:
	var path = String(monster.get("path", ""))
	var atlas = load(path)
	if not atlas is Texture2D:
		var image = Image.new()
		var error = image.load(path)
		if error != OK:
			return null
		atlas = ImageTexture.create_from_image(image)

	var texture = AtlasTexture.new()
	var frame_size = _get_frame_size(monster, atlas)
	texture.atlas = atlas
	if monster.has("frame_rects"):
		var rects: Array = monster["frame_rects"]
		texture.region = rects[frame % rects.size()]
	elif monster.has("frame_rect"):
		texture.region = monster["frame_rect"]
	else:
		texture.region = Rect2(frame_size.x * frame, 0, frame_size.x, frame_size.y)
	return texture

func _get_frame_count(monster: Dictionary) -> int:
	if monster.has("frame_rects"):
		return maxi(1, (monster["frame_rects"] as Array).size())
	if monster.has("frame_rect"):
		return 1
	return maxi(1, int(monster.get("frames", 1)))

func _get_frame_size(monster: Dictionary, atlas: Texture2D) -> Vector2:
	if monster.has("frame_width") and monster.has("frame_height"):
		return Vector2(float(monster["frame_width"]), float(monster["frame_height"]))

	var frame_count = _get_frame_count(monster)
	if frame_count > 1:
		return Vector2(atlas.get_width() / float(frame_count), atlas.get_height())

	return Vector2(atlas.get_width(), atlas.get_height())

func _card_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.033, 0.045, 0.94)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.0, 0.63, 1.0, 0.42)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_top = 10
	style.content_margin_right = 8
	style.content_margin_bottom = 10
	return style

func _dialog_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.033, 0.045, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color("#00aaff")
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.shadow_color = Color(0.0, 0.63, 1.0, 0.35)
	style.shadow_size = 12
	return style

func _dialog_button_style(bg: Color = Color(0.05, 0.10, 0.16, 1), border: Color = Color(0.0, 0.63, 1.0, 0.85)) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
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
	style.content_margin_left = 16
	style.content_margin_top = 10
	style.content_margin_right = 16
	style.content_margin_bottom = 10
	return style

func _transparent_button_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	return style
