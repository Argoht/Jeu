extends Control

const MATERIAL_ORDER: Array[String] = ["dungeon_stone", "portal_wood", "shadow_crystal"]
const BACKGROUND_PATH := "res://Assets/Base/base_background_vertical.png"
const FIRE_GLOW_PATH := "res://Assets/Base/fire_glow.png"
const TEXTURE_RECT_STRETCH_COVERED := 6
const BUILDING_DISPLAY_ORDER: Array[String] = ["sanctuary", "workshop"]
const BUILDING_VISUALS := {
	"sanctuary": [
		"res://Assets/Base/Campfire/campfire_lvl1.png",
		"res://Assets/Base/Campfire/campfire_lvl2.png",
		"res://Assets/Base/Campfire/campfire_lvl3.png",
	],
	"workshop": [
		"res://Assets/Base/Forge/forge_lvl1.png",
		"res://Assets/Base/Forge/forge_lvl2.png",
		"res://Assets/Base/Forge/forge_lvl3.png",
	],
}
const BUILDING_LAYOUT := {
	"sanctuary": {"position": Vector2(0.22, 0.78), "size": Vector2(205, 190)},
	"workshop": {"position": Vector2(0.74, 0.67), "size": Vector2(318, 300)},
}

class BirdLayer:
	extends Control

	var birds: Array = []
	var elapsed := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in range(12):
			birds.append({
				"offset": Vector2(randf(), randf() * 0.26 + 0.06),
				"speed": randf_range(0.014, 0.032),
				"size": randf_range(5.5, 11.0),
				"phase": randf() * TAU,
			})
		visibility_changed.connect(func(): set_process(is_visible_in_tree()))
		set_process(is_visible_in_tree())

	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()

	func _draw() -> void:
		var area := size
		if area.x <= 1.0 or area.y <= 1.0:
			return
		var color := Color(0.08, 0.11, 0.15, 0.50)
		for bird in birds:
			var offset: Vector2 = bird["offset"]
			var speed: float = bird["speed"]
			var wing: float = sin((elapsed * 5.2) + float(bird["phase"])) * 2.2
			var x := fposmod((offset.x + elapsed * speed) * area.x, area.x + 90.0) - 45.0
			var y := offset.y * area.y + sin((elapsed * 1.3) + float(bird["phase"])) * 5.0
			var s: float = bird["size"]
			draw_line(Vector2(x, y), Vector2(x - s, y + s * 0.42 + wing), color, 1.7)
			draw_line(Vector2(x, y), Vector2(x + s, y + s * 0.42 - wing), color, 1.7)

class AtmosphereLayer:
	extends Control

	var elapsed := 0.0
	var motes: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in range(26):
			motes.append({
				"offset": Vector2(randf(), randf_range(0.40, 0.94)),
				"speed": randf_range(0.006, 0.018),
				"size": randf_range(0.9, 2.2),
				"phase": randf() * TAU,
			})
		visibility_changed.connect(func(): set_process(is_visible_in_tree()))
		set_process(is_visible_in_tree())

	func _process(delta: float) -> void:
		elapsed += delta
		queue_redraw()

	func _draw() -> void:
		var area := size
		if area.x <= 1.0 or area.y <= 1.0:
			return
		for mote in motes:
			var offset: Vector2 = mote["offset"]
			var drift := float(mote["speed"]) * elapsed
			var x := fposmod((offset.x + drift) * area.x, area.x + 24.0) - 12.0
			var y := offset.y * area.y + sin(elapsed * 1.4 + float(mote["phase"])) * 9.0
			var alpha := 0.10 + sin(elapsed * 1.8 + float(mote["phase"])) * 0.06
			draw_circle(Vector2(x, y), float(mote["size"]), Color(1.0, 0.80, 0.36, alpha))

var _scene_layer: Control = null
var _bird_layer: Control = null
var _atmosphere_layer: Control = null
var _detail_panel: PanelContainer = null
var _detail_title: Label = null
var _detail_description: Label = null
var _detail_effect: Label = null
var _detail_cost: Label = null
var _detail_materials: Label = null
var _upgrade_button: Button = null
var _asset_buttons: Dictionary = {}
var _asset_textures: Dictionary = {}
var _asset_base_positions: Dictionary = {}
var _asset_glows: Dictionary = {}
var _building_views: Dictionary = {}
var _selected_building_id := ""
var _fx_time := 0.0
var _stock_label: Label

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		call_deferred("_layout_assets")
	elif what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready():
		set_process(is_visible_in_tree())

func _process(delta: float) -> void:
	_fx_time += delta
	_update_scene_fx()

func _ready() -> void:
	name = "BasePanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _empty_style())
	_build_ui()
	if GlobalEngine.has_signal("base_changed"):
		GlobalEngine.base_changed.connect(_on_base_changed)
	if GlobalEngine.has_signal("stats_updated"):
		GlobalEngine.stats_updated.connect(_on_progress_changed)
	if GlobalEngine.has_signal("leveled_up"):
		GlobalEngine.leveled_up.connect(func(_new_level: int): _on_progress_changed())
	refresh()
	set_process(is_visible_in_tree())
	call_deferred("_layout_assets")

func refresh_locale() -> void:
	refresh()

func refresh() -> void:
	if not is_instance_valid(_scene_layer):
		return
	_refresh_buildings()
	_stock_label.text = _format_materials()
	if not _selected_building_id.is_empty():
		_show_details(_selected_building_id)

func _on_base_changed() -> void:
	if is_visible_in_tree():
		refresh()

func _on_progress_changed() -> void:
	if is_visible_in_tree():
		refresh()

func _build_ui() -> void:
	var background := TextureRect.new()
	background.name = "Background"
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.texture = load(BACKGROUND_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TEXTURE_RECT_STRETCH_COVERED
	add_child(background)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.offset_left = 0
	background.offset_top = 0
	background.offset_right = 0
	background.offset_bottom = 0

	var scrim := ColorRect.new()
	scrim.name = "BottomScrim"
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.color = Color(0.0, 0.0, 0.0, 0.10)
	add_child(scrim)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.offset_left = 0
	scrim.offset_top = 0
	scrim.offset_right = 0
	scrim.offset_bottom = 0

	_bird_layer = BirdLayer.new()
	_bird_layer.name = "BirdLayer"
	_bird_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bird_layer)
	_bird_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bird_layer.offset_left = 0
	_bird_layer.offset_top = 0
	_bird_layer.offset_right = 0
	_bird_layer.offset_bottom = 0

	_atmosphere_layer = AtmosphereLayer.new()
	_atmosphere_layer.name = "AtmosphereLayer"
	_atmosphere_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_atmosphere_layer)
	_atmosphere_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_atmosphere_layer.offset_left = 0
	_atmosphere_layer.offset_top = 0
	_atmosphere_layer.offset_right = 0
	_atmosphere_layer.offset_bottom = 0

	_scene_layer = Control.new()
	_scene_layer.name = "SceneLayer"
	_scene_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scene_layer)
	_scene_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scene_layer.offset_left = 0
	_scene_layer.offset_top = 0
	_scene_layer.offset_right = 0
	_scene_layer.offset_bottom = 0

	for building_id in BUILDING_DISPLAY_ORDER:
		_create_asset_button(building_id)

	var stock_band := PanelContainer.new()
	stock_band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	stock_band.offset_bottom = 96
	stock_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stock_style := StyleBoxFlat.new()
	stock_style.bg_color = Color(0.02, 0.04, 0.06, 0.88)
	stock_style.content_margin_left = 16
	stock_style.content_margin_right = 16
	stock_style.content_margin_top = 12
	stock_style.content_margin_bottom = 12
	stock_band.add_theme_stylebox_override("panel", stock_style)
	add_child(stock_band)
	_stock_label = Label.new()
	_stock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stock_label.add_theme_font_size_override("font_size", 28)
	_stock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stock_band.add_child(_stock_label)

	_build_detail_panel()

func _create_asset_button(building_id: String) -> void:
	var button := Button.new()
	button.name = "%sAsset" % building_id
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.add_theme_stylebox_override("normal", _empty_style())
	button.add_theme_stylebox_override("pressed", _empty_style())
	button.add_theme_stylebox_override("hover", _empty_style())
	button.add_theme_stylebox_override("focus", _empty_style())
	button.button_down.connect(func(): GlobalEngine.play_ui_select(-14.0))
	button.pressed.connect(func(): _show_details(building_id))
	_scene_layer.add_child(button)
	_asset_buttons[building_id] = button

	var glow := TextureRect.new()
	glow.name = "Glow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.texture = load(FIRE_GLOW_PATH)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glow.modulate = Color(1.0, 0.67, 0.22, 0.0)
	button.add_child(glow)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.offset_left = -28
	glow.offset_top = -18
	glow.offset_right = 28
	glow.offset_bottom = 34
	_asset_glows[building_id] = glow

	var texture := TextureRect.new()
	texture.name = "Texture"
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	button.add_child(texture)
	texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture.offset_left = 0
	texture.offset_top = 0
	texture.offset_right = 0
	texture.offset_bottom = 0
	_asset_textures[building_id] = texture

func _build_detail_panel() -> void:
	_detail_panel = PanelContainer.new()
	_detail_panel.name = "Details"
	_detail_panel.visible = false
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_panel.add_theme_stylebox_override("panel", _detail_style())
	add_child(_detail_panel)
	_detail_panel.anchor_left = 0.0
	_detail_panel.anchor_top = 1.0
	_detail_panel.anchor_right = 1.0
	_detail_panel.anchor_bottom = 1.0
	_detail_panel.offset_left = 14
	_detail_panel.offset_top = -640
	_detail_panel.offset_right = -14
	_detail_panel.offset_bottom = -14

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	_detail_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)

	_detail_title = Label.new()
	_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_title.add_theme_font_size_override("font_size", 30)
	_detail_title.add_theme_color_override("font_color", Color("#edf7ff"))
	header.add_child(_detail_title)

	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(96, 96)
	close.focus_mode = Control.FOCUS_NONE
	close.add_theme_font_size_override("font_size", 28)
	close.add_theme_stylebox_override("normal", _small_button_style())
	close.add_theme_stylebox_override("pressed", _small_button_style(Color(0.08, 0.04, 0.05, 1), Color("#ff6b6b")))
	close.pressed.connect(_hide_details)
	header.add_child(close)

	_detail_description = _make_detail_label(Color("#b8c7d6"), 26)
	box.add_child(_detail_description)

	_detail_effect = _make_detail_label(Color("#67e8f9"), 26)
	box.add_child(_detail_effect)

	_detail_materials = _make_detail_label(Color("#d7dde8"), 24)
	box.add_child(_detail_materials)

	_detail_cost = _make_detail_label(Color("#ffd166"), 24)
	box.add_child(_detail_cost)

	_upgrade_button = Button.new()
	_upgrade_button.custom_minimum_size = Vector2(0, 96)
	_upgrade_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_upgrade_button.focus_mode = Control.FOCUS_NONE
	_upgrade_button.add_theme_font_size_override("font_size", 26)
	_upgrade_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_upgrade_button.add_theme_stylebox_override("normal", _upgrade_button_style())
	_upgrade_button.add_theme_stylebox_override("pressed", _upgrade_button_style(Color(0.030, 0.075, 0.086, 1), Color("#67e8f9")))
	_upgrade_button.add_theme_stylebox_override("disabled", _upgrade_button_style(Color(0.035, 0.038, 0.046, 0.78), Color(0.25, 0.29, 0.33, 0.7)))
	_upgrade_button.button_down.connect(func(): GlobalEngine.play_ui_select(-14.0))
	_upgrade_button.pressed.connect(_upgrade_selected_building)
	box.add_child(_upgrade_button)

func _refresh_buildings() -> void:
	_building_views.clear()
	for building in GlobalEngine.get_base_buildings_view():
		var building_id := String(building.get("id", ""))
		if not BUILDING_VISUALS.has(building_id):
			continue
		_building_views[building_id] = building
		var texture_rect = _asset_textures.get(building_id, null)
		if texture_rect is TextureRect:
			var level := maxi(1, int(building.get("level", 0)))
			texture_rect.texture = _building_texture(building_id, level)
	_layout_assets()

func _layout_assets() -> void:
	if not is_instance_valid(_scene_layer):
		return
	var viewport_size := _scene_layer.size
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		return
	var scale := clampf(viewport_size.x / 720.0, 0.72, 1.18)
	for building_id in _asset_buttons.keys():
		var button = _asset_buttons[building_id]
		if not (button is Control):
			continue
		var layout: Dictionary = BUILDING_LAYOUT.get(building_id, {})
		var normalized: Vector2 = layout.get("position", Vector2(0.5, 0.5))
		var base_size: Vector2 = layout.get("size", Vector2(180, 180))
		var size := base_size * scale
		button.size = size
		var position := Vector2(viewport_size.x * normalized.x, viewport_size.y * normalized.y) - (size * 0.5)
		_asset_base_positions[building_id] = position
		button.position = position
		button.pivot_offset = size * 0.5

func _update_scene_fx() -> void:
	for building_id in _asset_buttons.keys():
		var button = _asset_buttons[building_id]
		if not (button is Control):
			continue
		var phase := 0.0 if building_id == "sanctuary" else 1.7
		button.position = _asset_base_positions.get(building_id, button.position)
		button.scale = Vector2.ONE
		var glow = _asset_glows.get(building_id, null)
		if glow is TextureRect:
			var alpha := 0.22 + (sin(_fx_time * 2.6 + phase) * 0.06)
			if building_id == "workshop":
				alpha *= 0.62
			glow.modulate = Color(1.0, 0.62, 0.20, alpha)

func _show_details(building_id: String) -> void:
	if not _building_views.has(building_id):
		return
	_selected_building_id = building_id
	var data: Dictionary = _building_views[building_id]
	var level := int(data.get("level", 0))
	var max_level := int(data.get("max_level", 3))
	_detail_title.text = "%s - %s %d/%d" % [
		GlobalEngine.loc(String(data.get("name_key", ""))),
		GlobalEngine.loc("base.level"),
		level,
		max_level,
	]
	_detail_description.text = GlobalEngine.loc(String(data.get("description_key", "")))
	_detail_effect.text = GlobalEngine.loc(String(data.get("effect_key", "")), _effect_args(building_id, level))
	_detail_materials.text = _format_materials()
	if bool(data.get("is_max", false)):
		_detail_cost.text = ""
		_upgrade_button.text = GlobalEngine.loc("base.maxed")
		_upgrade_button.disabled = true
	elif not bool(data.get("rank_unlocked", false)):
		_detail_cost.text = GlobalEngine.loc("base.cost", [_format_cost(data.get("cost", {}))])
		_upgrade_button.text = GlobalEngine.loc("base.locked_rank", [String(data.get("required_rank_label", "F"))])
		_upgrade_button.disabled = true
	elif not bool(data.get("can_afford", false)):
		_detail_cost.text = GlobalEngine.loc("base.cost", [_format_cost(data.get("cost", {}))])
		_upgrade_button.text = GlobalEngine.loc("base.missing_materials")
		_upgrade_button.disabled = true
	else:
		_detail_cost.text = GlobalEngine.loc("base.cost", [_format_cost(data.get("cost", {}))])
		_upgrade_button.text = GlobalEngine.loc("base.upgrade")
		_upgrade_button.disabled = false
	_detail_panel.show()

func _hide_details() -> void:
	_selected_building_id = ""
	_detail_panel.hide()

func dismiss_details() -> bool:
	if not _detail_panel.visible:
		return false
	_hide_details()
	return true

func _upgrade_selected_building() -> void:
	if _selected_building_id.is_empty():
		return
	GlobalEngine.upgrade_base_building(_selected_building_id)
	refresh()

func _format_materials() -> String:
	var materials := GlobalEngine.get_base_materials()
	var parts := []
	for material_key in MATERIAL_ORDER:
		parts.append("%s: %d" % [GlobalEngine.loc("base.material.short.%s" % material_key), int(materials.get(material_key, 0))])
	var text := String(parts[0]) if not parts.is_empty() else ""
	for i in range(1, parts.size()):
		text += " | " + String(parts[i])
	return text

func _format_cost(cost_value) -> String:
	if not (cost_value is Dictionary):
		return "-"
	var cost: Dictionary = cost_value
	var parts := []
	for material_key in MATERIAL_ORDER:
		var amount := int(cost.get(material_key, 0))
		if amount <= 0:
			continue
		parts.append("%d %s" % [amount, GlobalEngine.loc("base.material.short.%s" % material_key)])
	if parts.is_empty():
		return "-"
	var text := String(parts[0])
	for i in range(1, parts.size()):
		text += " / " + String(parts[i])
	return text

func _effect_args(building_id: String, level: int) -> Array:
	match building_id:
		"training":
			return [level, level]
		"sanctuary":
			return [level, level * 5]
		"workshop":
			return [level * 3]
		"vault":
			return [level * 5]
		_:
			return [level]

func _building_texture(building_id: String, level: int):
	if not BUILDING_VISUALS.has(building_id):
		return null
	var paths: Array = BUILDING_VISUALS[building_id]
	var index := clampi(level - 1, 0, paths.size() - 1)
	return load(String(paths[index]))

func _make_detail_label(color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _empty_style() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

func _asset_hover_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.95, 0.74, 0.08)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1.0, 0.83, 0.38, 0.28)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

func _detail_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.010, 0.014, 0.020, 0.90)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.border_color = Color(0.62, 0.78, 0.92, 0.34)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 12
	return style

func _small_button_style(bg: Color = Color(0.035, 0.046, 0.058, 1), border: Color = Color(0.58, 0.74, 0.88, 0.50)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _upgrade_button_style(bg: Color = Color(0.040, 0.075, 0.095, 1), border: Color = Color("#22d3ee")) -> StyleBoxFlat:
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
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style
