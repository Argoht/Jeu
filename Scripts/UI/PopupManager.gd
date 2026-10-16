class_name PopupManager
extends CanvasLayer

## Manages all game popups (level-up, mission result, rename, item details).
##
## Extends CanvasLayer so that popup overlays use viewport-space coordinates
## directly — guarantees they fill the screen and center correctly regardless
## of where MainScene puts the PopupManager in the scene tree.
##
## Add as a child of any node. Connects to GlobalEngine signals automatically
## in _ready() so MainScene needs zero popup logic.

# ── Signals ───────────────────────────────────────────────────────────────────

## Emitted after a rename is confirmed, so listeners can refresh their UI.
signal player_renamed(new_name: String)

# ── Internal nodes ────────────────────────────────────────────────────────────

var _lvl_popup:     Control
var _mission_popup: Control
var _fail_popup:    Control
var _rename_popup:  Control
var _item_popup:    Control
var _fx_layer:      Control

var _lvl_num_label:   Label
var _lvl_title_label: Label
var _lvl_points_label: Label
var _miss_xp_label:   Label
var _miss_stat_label: Label
var _miss_title_label: Label
var _fail_hp_label:   Label
var _fail_title_label: Label
var _fail_msg_label: Label
var _rename_input:    LineEdit
var _rename_title_label: Label
var _lvl_close_button: Button
var _miss_continue_button: Button
var _fail_close_button: Button
var _rename_cancel_button: Button
var _rename_confirm_button: Button
var _item_close_button: Button

var _item_name_label:   Label
var _item_type_label:   Label
var _item_rarity_label: Label
var _item_power_label:  Label
var _item_stats_vbox:   VBoxContainer
var _item_action_button: Button
var _item_secondary_action_button: Button
var _item_tertiary_action_button: Button
var _item_action_callback := Callable()
var _item_secondary_action_callback := Callable()
var _item_tertiary_action_callback := Callable()
var _item_border_style: StyleBoxFlat   # change de couleur selon la rareté

const MOBILE_TOUCH_TARGET := 96.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	# Couche élevée → s'affiche au-dessus de toute l'UI du jeu.
	layer = 100

	_lvl_popup     = _build_level_up_popup()
	_mission_popup = _build_mission_popup()
	_fail_popup    = _build_fail_popup()
	_rename_popup  = _build_rename_popup()
	_item_popup    = _build_item_details_popup()

	add_child(_lvl_popup)
	add_child(_mission_popup)
	add_child(_fail_popup)
	add_child(_rename_popup)
	add_child(_item_popup)
	_fx_layer = Control.new()
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx_layer)

	GlobalEngine.leveled_up.connect(show_level_up)
	GlobalEngine.mission_completed.connect(show_mission_complete)
	GlobalEngine.mission_failed.connect(show_mission_fail)
	GlobalEngine.language_changed.connect(func(_locale: String): _refresh_locale())
	_refresh_locale()

# ── Public API ────────────────────────────────────────────────────────────────

func has_active_popup() -> bool:
	for popup in [_item_popup, _rename_popup, _fail_popup, _mission_popup, _lvl_popup]:
		if is_instance_valid(popup) and popup.visible:
			return true
	return false

func dismiss_top_popup() -> bool:
	for popup in [_item_popup, _rename_popup, _fail_popup, _mission_popup, _lvl_popup]:
		if is_instance_valid(popup) and popup.visible:
			popup.hide()
			return true
	return false

func show_level_up(new_level: int) -> void:
	_lvl_num_label.text = GlobalEngine.loc("popup.level", [new_level])
	_lvl_popup.show()
	GlobalEngine.play_level_up_additive()
	_play_level_up_impact(_lvl_popup)

func show_mission_complete(xp_amount: int, stat_name: String, stat_amount: int) -> void:
	var journal_only := false
	if xp_amount <= 0 and stat_name == "" and stat_amount <= 0:
		journal_only = true
		_miss_xp_label.text = GlobalEngine.loc("popup.journal_only")
		_miss_stat_label.text = GlobalEngine.loc("popup.daily_limit")
		_miss_stat_label.show()
	elif stat_name != "":
		_miss_xp_label.text = "+ %d XP" % xp_amount
		_miss_stat_label.text = "+ %d %s" % [stat_amount, stat_name.to_upper()]
		_miss_stat_label.show()
	else:
		_miss_xp_label.text = "+ %d XP" % xp_amount
		_miss_stat_label.hide()
	_mission_popup.show()
	if journal_only:
		GlobalEngine.play_ui_select(-11.0)
		_play_popup_impact(_mission_popup, Color("#8be9fd"), 2, "")
	else:
		GlobalEngine.play_loot_drop("rare")
		_play_popup_impact(_mission_popup, Color("#00ff99"), 4, "+%d XP" % xp_amount)

func show_mission_fail(hp_lost: int) -> void:
	_fail_hp_label.text = "- %d HP" % hp_lost
	_fail_popup.show()
	_play_damage_impact(_fail_popup, Color("#ff3333"), "-%d HP" % hp_lost)

func show_rename() -> void:
	_rename_input.text = GlobalEngine.player_name
	_rename_input.select_all()
	_rename_popup.show()
	_rename_input.grab_focus()

## Displays full info for an item: name, rarity, type, power, stat bonuses.
func show_item_details(
	item: Dictionary,
	action_text: String = "",
	action_callback: Callable = Callable(),
	secondary_action_text: String = "",
	secondary_action_callback: Callable = Callable(),
	tertiary_action_text: String = "",
	tertiary_action_callback: Callable = Callable()
) -> void:
	var rarity: String = item.get("rarity", "common")
	var rarity_color: Color = _rarity_color(rarity)

	_item_border_style.border_color = rarity_color
	_item_border_style.shadow_color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.35)

	_item_name_label.text = GlobalEngine.localize_item_name(item).to_upper()
	_item_name_label.add_theme_color_override("font_color", rarity_color)

	_item_type_label.text = _type_label(item.get("type", ""))

	_item_rarity_label.text = _rarity_label(rarity)
	_item_rarity_label.add_theme_color_override("font_color", rarity_color)

	_item_power_label.text = GlobalEngine.loc("item.power", [int(item.get("base_power", 0))])

	# Reconstruit la liste des stat bonuses
	for c in _item_stats_vbox.get_children(): c.queue_free()
	var bonuses: Dictionary = item.get("stat_bonuses", {})
	if bonuses.is_empty():
		var empty_line := Label.new()
		empty_line.text = GlobalEngine.loc("item.no_bonus")
		empty_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_line.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		empty_line.add_theme_font_size_override("font_size", 24)
		_item_stats_vbox.add_child(empty_line)
	else:
		for stat_key in bonuses:
			var line := Label.new()
			line.text = "+ %d %s" % [int(bonuses[stat_key]), String(stat_key).to_upper()]
			line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			line.add_theme_color_override("font_color", Color("#00ff88"))
			line.add_theme_font_size_override("font_size", 24)
			_item_stats_vbox.add_child(line)

	_item_action_callback = action_callback
	_item_secondary_action_callback = secondary_action_callback
	_item_tertiary_action_callback = tertiary_action_callback
	_configure_item_action_button(_item_action_button, action_text, action_callback)
	_configure_item_action_button(_item_secondary_action_button, secondary_action_text, secondary_action_callback)
	_configure_item_action_button(_item_tertiary_action_button, tertiary_action_text, tertiary_action_callback)

	_item_popup.show()
	_play_popup_impact(_item_popup, rarity_color, _rarity_intensity(rarity), _rarity_label(rarity).to_upper())

func _on_item_action_pressed() -> void:
	_run_item_action(_item_action_callback)

func _on_item_secondary_action_pressed() -> void:
	_run_item_action(_item_secondary_action_callback)

func _on_item_tertiary_action_pressed() -> void:
	_run_item_action(_item_tertiary_action_callback)

func _run_item_action(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()
	_item_popup.hide()

func _configure_item_action_button(button: Button, text: String, callback: Callable) -> void:
	if not is_instance_valid(button):
		return
	if text.is_empty() or not callback.is_valid():
		button.hide()
		return
	button.text = text
	button.show()

# ── Helpers ───────────────────────────────────────────────────────────────────

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"common":    return Color("#aaaaaa")
		"rare":      return Color("#00f2ff")
		"epic":      return Color("#cc44ff")
		"legendary": return Color("#ffd700")
		"mythic":    return Color("#ff4444")
	return Color("#aaaaaa")

func _rarity_label(rarity: String) -> String:
	match rarity:
		"common":    return GlobalEngine.loc("item.rarity.common")
		"rare":      return GlobalEngine.loc("item.rarity.rare")
		"epic":      return GlobalEngine.loc("item.rarity.epic")
		"legendary": return GlobalEngine.loc("item.rarity.legendary")
		"mythic":    return GlobalEngine.loc("item.rarity.mythic")
	return rarity.capitalize()

func _type_label(item_type: String) -> String:
	match item_type:
		"weapon":    return GlobalEngine.loc("item.type.weapon")
		"armor":     return GlobalEngine.loc("item.type.armor")
		"legs":      return GlobalEngine.loc("item.type.legs")
		"feet":      return GlobalEngine.loc("item.type.feet")
		"accessory": return GlobalEngine.loc("item.type.accessory")
	return item_type.capitalize()

func _rarity_intensity(rarity: String) -> int:
	match rarity:
		"rare":
			return 2
		"epic":
			return 3
		"legendary":
			return 4
		"mythic":
			return 5
	return 1

func _play_popup_impact(overlay: Control, accent: Color, intensity: int, floating_text: String = "") -> void:
	if not is_instance_valid(overlay):
		return
	overlay.pivot_offset = overlay.size * 0.5
	overlay.scale = Vector2(0.96, 0.96)
	var tween := create_tween()
	tween.tween_property(overlay, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_screen_flash(Color(accent.r, accent.g, accent.b, 0.16 + float(intensity) * 0.025), 0.34)
	_spawn_reward_burst(accent, intensity)
	if not floating_text.is_empty():
		_spawn_floating_text(floating_text, accent, 30 + intensity * 2, Vector2(0, -28))

func _play_level_up_impact(overlay: Control) -> void:
	if not is_instance_valid(overlay):
		return
	var gold := Color("#ffd700")
	_play_popup_impact(overlay, gold, 5, GlobalEngine.loc("popup.level_up"))
	_spawn_level_up_rings(gold)
	_spawn_level_up_rays(gold)
	_spawn_level_up_sparkles()

func _play_damage_impact(overlay: Control, accent: Color, floating_text: String) -> void:
	if not is_instance_valid(overlay):
		return
	GlobalEngine.play_creepy_stinger()
	_spawn_screen_flash(Color(accent.r, accent.g, accent.b, 0.24), 0.30)
	_spawn_reward_burst(accent, 2)
	_spawn_floating_text(floating_text, accent, 32, Vector2(0, -20))
	overlay.rotation = 0.0
	var tween := create_tween()
	tween.tween_property(overlay, "rotation", deg_to_rad(0.7), 0.04)
	tween.tween_property(overlay, "rotation", deg_to_rad(-0.7), 0.04)
	tween.tween_property(overlay, "rotation", 0.0, 0.06)

func _spawn_screen_flash(color: Color, duration: float) -> void:
	if not is_instance_valid(_fx_layer):
		return
	var flash := ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = color
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_queue_free_fx.bind(flash))

func _spawn_reward_burst(accent: Color, intensity: int) -> void:
	if not is_instance_valid(_fx_layer):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var count := 18 + intensity * 10
	for i in range(count):
		var particle := ColorRect.new()
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		particle.color = Color(accent.r, accent.g, accent.b, randf_range(0.58, 0.95))
		_fx_layer.add_child(particle)
		var size_px := randf_range(3.0, 6.0 + float(intensity))
		particle.size = Vector2(size_px, size_px)
		particle.position = center + Vector2(randf_range(-24.0, 24.0), randf_range(-12.0, 12.0))
		var angle := randf() * TAU
		var distance := randf_range(80.0, 140.0 + float(intensity) * 28.0)
		var target := center + Vector2(cos(angle), sin(angle)) * distance
		var tween := create_tween()
		tween.set_parallel(true)
		var duration := randf_range(0.42, 0.72 + float(intensity) * 0.05)
		tween.tween_property(particle, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "rotation", randf_range(-3.0, 3.0), duration)
		tween.tween_property(particle, "modulate:a", 0.0, duration).set_delay(0.08)
		tween.chain().tween_callback(_queue_free_fx.bind(particle))

func _spawn_level_up_rings(accent: Color) -> void:
	if not is_instance_valid(_fx_layer):
		return
	var center := get_viewport().get_visible_rect().size * 0.5
	for i in range(3):
		var ring := Panel.new()
		ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var size_px := 92.0 + float(i) * 44.0
		ring.size = Vector2(size_px, size_px)
		ring.position = center - ring.size * 0.5
		ring.pivot_offset = ring.size * 0.5
		ring.scale = Vector2(0.36, 0.36)
		ring.modulate = Color(1.0, 1.0, 1.0, 0.85)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(accent.r, accent.g, accent.b, 0.0)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(accent.r, accent.g, accent.b, 0.62 - float(i) * 0.12)
		style.corner_radius_top_left = 999
		style.corner_radius_top_right = 999
		style.corner_radius_bottom_left = 999
		style.corner_radius_bottom_right = 999
		ring.add_theme_stylebox_override("panel", style)
		_fx_layer.add_child(ring)
		var delay := float(i) * 0.08
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(ring, "scale", Vector2(1.45 + float(i) * 0.18, 1.45 + float(i) * 0.18), 0.74).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(ring, "modulate:a", 0.0, 0.74).set_delay(delay + 0.08)
		tween.chain().tween_callback(_queue_free_fx.bind(ring))

func _spawn_level_up_rays(accent: Color) -> void:
	if not is_instance_valid(_fx_layer):
		return
	var center := get_viewport().get_visible_rect().size * 0.5
	for i in range(18):
		var ray := ColorRect.new()
		ray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ray.color = Color(accent.r, accent.g, accent.b, randf_range(0.22, 0.42))
		var length := randf_range(34.0, 74.0)
		ray.size = Vector2(randf_range(2.0, 4.0), length)
		ray.pivot_offset = Vector2(ray.size.x * 0.5, ray.size.y)
		var angle := (TAU / 18.0) * float(i) + randf_range(-0.08, 0.08)
		ray.rotation = angle + PI * 0.5
		ray.position = center + Vector2(cos(angle), sin(angle)) * randf_range(22.0, 36.0)
		_fx_layer.add_child(ray)
		var target := center + Vector2(cos(angle), sin(angle)) * randf_range(132.0, 210.0)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(ray, "position", target, randf_range(0.44, 0.64)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(ray, "modulate:a", 0.0, 0.52).set_delay(0.06)
		tween.chain().tween_callback(_queue_free_fx.bind(ray))

func _spawn_level_up_sparkles() -> void:
	if not is_instance_valid(_fx_layer):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size * 0.5
	var palette := [Color("#fff1a8"), Color("#ffd700"), Color("#ffffff"), Color("#8be9fd")]
	for i in range(52):
		var sparkle := ColorRect.new()
		sparkle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var color = palette.pick_random()
		sparkle.color = Color(color.r, color.g, color.b, randf_range(0.62, 0.95))
		_fx_layer.add_child(sparkle)
		var size_px := randf_range(3.0, 8.0)
		sparkle.size = Vector2(size_px, size_px)
		sparkle.pivot_offset = sparkle.size * 0.5
		sparkle.position = center + Vector2(randf_range(-72.0, 72.0), randf_range(-18.0, 54.0))
		var drift := Vector2(randf_range(-96.0, 96.0), randf_range(-180.0, -72.0))
		var tween := create_tween()
		tween.set_parallel(true)
		var duration := randf_range(0.58, 0.96)
		tween.tween_property(sparkle, "position", sparkle.position + drift, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(sparkle, "scale", Vector2(randf_range(0.25, 0.6), randf_range(0.25, 0.6)), duration)
		tween.tween_property(sparkle, "rotation", randf_range(-4.0, 4.0), duration)
		tween.tween_property(sparkle, "modulate:a", 0.0, duration).set_delay(0.18)
		tween.chain().tween_callback(_queue_free_fx.bind(sparkle))

func _spawn_floating_text(text: String, color: Color, font_size: int, offset: Vector2) -> void:
	if not is_instance_valid(_fx_layer):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("outline_size", 3)
	label.size = Vector2(viewport_size.x, 60)
	label.position = Vector2(0, viewport_size.y * 0.36) + offset
	_fx_layer.add_child(label)
	label.scale = Vector2(0.88, 0.88)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0, -42), 0.76).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.76).set_delay(0.18)
	tween.chain().tween_callback(_queue_free_fx.bind(label))

func _queue_free_fx(node) -> void:
	if is_instance_valid(node):
		node.queue_free()

func _refresh_locale() -> void:
	if is_instance_valid(_lvl_title_label):
		_lvl_title_label.text = GlobalEngine.loc("popup.level_up")
	if is_instance_valid(_lvl_num_label):
		_lvl_num_label.text = GlobalEngine.loc("popup.level", [GlobalEngine.lvl])
	if is_instance_valid(_lvl_points_label):
		_lvl_points_label.text = GlobalEngine.loc("popup.stat_points")
	if is_instance_valid(_miss_title_label):
		_miss_title_label.text = GlobalEngine.loc("popup.mission_complete")
	if is_instance_valid(_fail_title_label):
		_fail_title_label.text = GlobalEngine.loc("popup.mission_failed")
	if is_instance_valid(_fail_msg_label):
		_fail_msg_label.text = GlobalEngine.loc("popup.mission_injury")
	if is_instance_valid(_rename_title_label):
		_rename_title_label.text = GlobalEngine.loc("popup.rename")
	if is_instance_valid(_rename_input):
		_rename_input.placeholder_text = GlobalEngine.loc("popup.name_placeholder")
	if is_instance_valid(_lvl_close_button):
		_lvl_close_button.text = GlobalEngine.loc("popup.close")
	if is_instance_valid(_miss_continue_button):
		_miss_continue_button.text = GlobalEngine.loc("popup.continue")
	if is_instance_valid(_fail_close_button):
		_fail_close_button.text = GlobalEngine.loc("popup.understood")
	if is_instance_valid(_rename_cancel_button):
		_rename_cancel_button.text = GlobalEngine.loc("popup.cancel")
	if is_instance_valid(_rename_confirm_button):
		_rename_confirm_button.text = GlobalEngine.loc("popup.confirm")
	if is_instance_valid(_item_close_button):
		_item_close_button.text = GlobalEngine.loc("popup.close")

func _apply_popup_button(button: Button, btn_style: StyleBoxFlat) -> void:
	button.custom_minimum_size = Vector2(0, MOBILE_TOUCH_TARGET)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 28)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_stylebox_override("normal", btn_style)

# ── Popup builders ────────────────────────────────────────────────────────────

func _make_popup_base(border_color: Color) -> Array:
	# Le parent (PopupManager) est un CanvasLayer → PRESET_FULL_RECT place
	# l'overlay aux coordonnées viewport, donc plein écran et bien centré.
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

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
	panel.custom_minimum_size = Vector2(640, 0)
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
	btn_style.content_margin_top   = 12; btn_style.content_margin_bottom = 12

	# 4e élément: le StyleBoxFlat du panneau, utile pour changer la bordure
	# dynamiquement (ex: popup détails item selon la rareté).
	return [overlay, vbox, btn_style, style]

func _build_level_up_popup() -> Control:
	var parts     := _make_popup_base(Color("#ffd700"))
	var overlay   := parts[0] as Control
	var vbox      := parts[1] as VBoxContainer
	var btn_style := parts[2] as StyleBoxFlat

	var title := Label.new()
	_lvl_title_label = title
	title.text = GlobalEngine.loc("popup.level_up")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#ffd700"))
	title.add_theme_font_size_override("font_size", 30)
	vbox.add_child(title)

	_lvl_num_label = Label.new()
	_lvl_num_label.text = GlobalEngine.loc("popup.level", [1])
	_lvl_num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lvl_num_label.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	_lvl_num_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(_lvl_num_label)

	vbox.add_child(HSeparator.new())

	var pts := Label.new()
	_lvl_points_label = pts
	pts.text = GlobalEngine.loc("popup.stat_points")
	pts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pts.add_theme_color_override("font_color", Color("#00f2ff"))
	pts.add_theme_font_size_override("font_size", 14)
	pts.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(pts)

	var btn := Button.new()
	_lvl_close_button = btn
	btn.text = GlobalEngine.loc("popup.close")
	_apply_popup_button(btn, btn_style)
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
	_miss_title_label = title
	title.text = GlobalEngine.loc("popup.mission_complete")
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
	_miss_continue_button = btn
	btn.text = GlobalEngine.loc("popup.continue")
	_apply_popup_button(btn, btn_style)
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
	_fail_title_label = title
	title.text = GlobalEngine.loc("popup.mission_failed")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#ff3333"))
	title.add_theme_font_size_override("font_size", 22)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var msg := Label.new()
	_fail_msg_label = msg
	msg.text = GlobalEngine.loc("popup.mission_injury")
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
	_fail_close_button = btn
	btn.text = GlobalEngine.loc("popup.understood")
	_apply_popup_button(btn, btn_style)
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
	_rename_title_label = title
	title.text = GlobalEngine.loc("popup.rename")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#00f2ff"))
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	_rename_input = LineEdit.new()
	_rename_input.max_length = 20
	_rename_input.placeholder_text = GlobalEngine.loc("popup.name_placeholder")
	_rename_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rename_input.custom_minimum_size = Vector2(0, MOBILE_TOUCH_TARGET)
	_rename_input.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_rename_input)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	vbox.add_child(btns)

	var btn_cancel := Button.new()
	_rename_cancel_button = btn_cancel
	btn_cancel.text = GlobalEngine.loc("popup.cancel")
	_apply_popup_button(btn_cancel, btn_style)
	btn_cancel.add_theme_color_override("font_color", Color("#888888"))
	btn_cancel.pressed.connect(overlay.hide)
	btns.add_child(btn_cancel)

	var btn_confirm := Button.new()
	_rename_confirm_button = btn_confirm
	btn_confirm.text = GlobalEngine.loc("popup.confirm")
	_apply_popup_button(btn_confirm, btn_style)
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

func _build_item_details_popup() -> Control:
	# La couleur de bordure initiale est neutre ; show_item_details la modifie
	# selon la rareté de l'item affiché.
	var parts := _make_popup_base(Color("#aaaaaa"))
	var overlay   := parts[0] as Control
	var vbox      := parts[1] as VBoxContainer
	var btn_style := parts[2] as StyleBoxFlat
	_item_border_style = parts[3] as StyleBoxFlat

	_item_name_label = Label.new()
	_item_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_name_label.add_theme_font_size_override("font_size", 28)
	_item_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_item_name_label)

	vbox.add_child(HSeparator.new())

	_item_type_label = Label.new()
	_item_type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_type_label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_item_type_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_item_type_label)

	_item_rarity_label = Label.new()
	_item_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_rarity_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_item_rarity_label)

	vbox.add_child(HSeparator.new())

	_item_power_label = Label.new()
	_item_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_power_label.add_theme_color_override("font_color", Color("#ffd700"))
	_item_power_label.add_theme_font_size_override("font_size", 26)
	vbox.add_child(_item_power_label)

	_item_stats_vbox = VBoxContainer.new()
	_item_stats_vbox.add_theme_constant_override("separation", 4)
	vbox.add_child(_item_stats_vbox)

	_item_action_button = Button.new()
	_apply_popup_button(_item_action_button, btn_style)
	_item_action_button.add_theme_color_override("font_color", Color("#00f2ff"))
	_item_action_button.button_down.connect(func(): GlobalEngine.play_ui_select(-12.0))
	_item_action_button.pressed.connect(_on_item_action_pressed)
	_item_action_button.hide()
	vbox.add_child(_item_action_button)

	_item_secondary_action_button = Button.new()
	_apply_popup_button(_item_secondary_action_button, btn_style)
	_item_secondary_action_button.add_theme_color_override("font_color", Color("#ffd166"))
	_item_secondary_action_button.button_down.connect(func(): GlobalEngine.play_ui_select(-12.0))
	_item_secondary_action_button.pressed.connect(_on_item_secondary_action_pressed)
	_item_secondary_action_button.hide()
	vbox.add_child(_item_secondary_action_button)

	_item_tertiary_action_button = Button.new()
	_apply_popup_button(_item_tertiary_action_button, btn_style)
	_item_tertiary_action_button.add_theme_color_override("font_color", Color("#8be9fd"))
	_item_tertiary_action_button.button_down.connect(func(): GlobalEngine.play_ui_select(-12.0))
	_item_tertiary_action_button.pressed.connect(_on_item_tertiary_action_pressed)
	_item_tertiary_action_button.hide()
	vbox.add_child(_item_tertiary_action_button)

	var btn := Button.new()
	_item_close_button = btn
	btn.text = GlobalEngine.loc("popup.close")
	_apply_popup_button(btn, btn_style)
	btn.button_down.connect(func(): GlobalEngine.play_ui_select(-13.0))
	btn.pressed.connect(overlay.hide)
	vbox.add_child(btn)

	overlay.hide()
	return overlay
