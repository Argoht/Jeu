extends PanelContainer

const MAX_DUNGEON_FLOOR := 100
const FALLBACK_DUNGEON_BACKGROUND_PATH := "res://Assets/Dungeons/Backgrounds/dungeon_global_ambience.png"

var _scroll: ScrollContainer
var _rank_select: OptionButton
var _title_label: Label
var _status_label: Label
var _checkpoint_label: Label
var _enemy_label: Label
var _enemy_hp_bar: ProgressBar
var _background_rect: TextureRect
var _enemy_sprite: TextureRect
var _fx_layer: Control
var _drop_popup: PanelContainer
var _drop_rarity_label: Label
var _drop_label: Label
var _drop_line: ColorRect
var _drop_popup_timer: Timer
var _current_background_path := ""
var _current_enemy_key := ""
var _last_combat_fx_seq := 0
var _combat_fx_ready := false
var _last_drop_key := ""
var _texture_cache: Dictionary = {}
var _enemy_arrival_tween: Tween
var _energy_label: Label
var _energy_bar: ProgressBar
var _event_panel: PanelContainer
var _event_title_label: Label
var _event_text_label: Label
var _choice_box: VBoxContainer
var _log_label: Label
var _start_button: Button
var _forfeit_button: Button
var _auto_button: Button
var _special_button: Button
var _heal_button: Button
var _shield_button: Button
var _next_button: Button

func _ready() -> void:
	name = "DonjonPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _panel_style())
	_build()
	if GlobalEngine.has_signal("dungeon_changed"):
		GlobalEngine.dungeon_changed.connect(_refresh)
	if GlobalEngine.has_signal("stats_updated"):
		GlobalEngine.stats_updated.connect(_refresh)
	if GlobalEngine.has_signal("language_changed"):
		GlobalEngine.language_changed.connect(func(_locale: String): _refresh())
	call_deferred("_refresh")

func _build() -> void:
	_scroll = ScrollContainer.new()
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(_scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	_scroll.add_child(margin)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override("separation", 8)
	root.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	_title_label = _make_label(GlobalEngine.loc("placeholder.dungeon_title"), 18, Color("#00f2ff"))
	title_box.add_child(_title_label)

	_status_label = _make_label("", 12, Color(0.78, 0.84, 0.9))
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_box.add_child(_status_label)

	_rank_select = OptionButton.new()
	_rank_select.custom_minimum_size = Vector2(104, 48)
	_rank_select.item_selected.connect(func(_index: int): _refresh())
	header.add_child(_rank_select)

	_checkpoint_label = _make_label("", 12, Color("#ffd166"))
	_checkpoint_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(_checkpoint_label)

	var scene_panel := PanelContainer.new()
	scene_panel.custom_minimum_size = Vector2(0, 360)
	scene_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene_panel.add_theme_stylebox_override("panel", _scene_style())
	root.add_child(scene_panel)

	var combat_stack := Control.new()
	combat_stack.clip_contents = true
	combat_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combat_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene_panel.add_child(combat_stack)

	_background_rect = TextureRect.new()
	_background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_background_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_background_rect.modulate = Color(0.82, 0.94, 1.0, 0.92)
	_background_rect.texture = load(FALLBACK_DUNGEON_BACKGROUND_PATH)
	combat_stack.add_child(_background_rect)
	_background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

	var scrim := ColorRect.new()
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.color = Color(0.006, 0.011, 0.019, 0.18)
	combat_stack.add_child(scrim)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)

	_enemy_sprite = TextureRect.new()
	_enemy_sprite.visible = false
	_enemy_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_enemy_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_enemy_sprite.modulate = Color(1, 1, 1, 0.88)
	combat_stack.add_child(_enemy_sprite)
	_enemy_sprite.anchor_left = 0.30
	_enemy_sprite.anchor_top = 0.14
	_enemy_sprite.anchor_right = 0.70
	_enemy_sprite.anchor_bottom = 0.86
	_enemy_sprite.offset_left = 0
	_enemy_sprite.offset_top = 0
	_enemy_sprite.offset_right = 0
	_enemy_sprite.offset_bottom = 0

	_fx_layer = Control.new()
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_stack.add_child(_fx_layer)
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)

	_build_drop_popup(combat_stack)

	_event_panel = PanelContainer.new()
	_event_panel.visible = false
	_event_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_event_panel.add_theme_stylebox_override("panel", _event_style())
	combat_stack.add_child(_event_panel)
	_event_panel.anchor_left = 0.06
	_event_panel.anchor_top = 0.26
	_event_panel.anchor_right = 0.94
	_event_panel.anchor_bottom = 0.94
	_event_panel.offset_left = 0
	_event_panel.offset_top = 0
	_event_panel.offset_right = 0
	_event_panel.offset_bottom = 0

	var event_margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		event_margin.add_theme_constant_override(side, 10)
	_event_panel.add_child(event_margin)

	var event_box := VBoxContainer.new()
	event_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_box.add_theme_constant_override("separation", 5)
	event_margin.add_child(event_box)

	_event_title_label = _make_label("", 15, Color("#ffd166"))
	_event_title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.012, 0.025, 1.0))
	_event_title_label.add_theme_constant_override("outline_size", 2)
	event_box.add_child(_event_title_label)

	_event_text_label = _make_label("", 12, Color(0.86, 0.91, 0.95))
	_event_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_event_text_label.max_lines_visible = 2
	_event_text_label.add_theme_color_override("font_outline_color", Color(0.0, 0.012, 0.025, 1.0))
	_event_text_label.add_theme_constant_override("outline_size", 1)
	event_box.add_child(_event_text_label)

	_choice_box = VBoxContainer.new()
	_choice_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choice_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_choice_box.add_theme_constant_override("separation", 5)
	event_box.add_child(_choice_box)

	_enemy_label = _make_label(GlobalEngine.loc("dungeon.no_enemy"), 14, Color("#f5f7fb"))
	_enemy_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_enemy_label.add_theme_color_override("font_outline_color", Color(0.0, 0.012, 0.025, 1.0))
	_enemy_label.add_theme_constant_override("outline_size", 1)
	root.add_child(_enemy_label)

	_enemy_hp_bar = ProgressBar.new()
	_enemy_hp_bar.custom_minimum_size = Vector2(0, 18)
	_enemy_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_hp_bar.show_percentage = false
	root.add_child(_enemy_hp_bar)

	var combat_box := VBoxContainer.new()
	combat_box.add_theme_constant_override("separation", 8)
	combat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(combat_box)

	_energy_label = _make_label("", 12, Color("#8be9fd"))
	_energy_label.add_theme_color_override("font_outline_color", Color(0.0, 0.012, 0.025, 1.0))
	_energy_label.add_theme_constant_override("outline_size", 1)
	combat_box.add_child(_energy_label)

	_energy_bar = ProgressBar.new()
	_energy_bar.custom_minimum_size = Vector2(0, 18)
	_energy_bar.max_value = 100
	_energy_bar.show_percentage = false
	combat_box.add_child(_energy_bar)

	_log_label = _make_label("", 12, Color(0.86, 0.9, 0.95))
	_log_label.custom_minimum_size = Vector2(0, 96)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_log_label.add_theme_stylebox_override("normal", _log_style())
	root.add_child(_log_label)

	var button_grid := GridContainer.new()
	button_grid.columns = 2
	button_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button_grid.add_theme_constant_override("h_separation", 8)
	button_grid.add_theme_constant_override("v_separation", 8)
	root.add_child(button_grid)

	_auto_button = _make_button(GlobalEngine.loc("dungeon.auto"), Callable(self, "_on_auto_pressed"))
	_special_button = _make_button(GlobalEngine.loc("dungeon.special"), Callable(self, "_on_special_pressed"))
	_heal_button = _make_button(GlobalEngine.loc("dungeon.heal"), Callable(self, "_on_heal_pressed"))
	_shield_button = _make_button(GlobalEngine.loc("dungeon.shield"), Callable(self, "_on_shield_pressed"))
	button_grid.add_child(_auto_button)
	button_grid.add_child(_special_button)
	button_grid.add_child(_heal_button)
	button_grid.add_child(_shield_button)

	_next_button = _make_button(GlobalEngine.loc("dungeon.next"), Callable(self, "_on_next_pressed"))
	root.add_child(_next_button)

	_start_button = _make_button(GlobalEngine.loc("dungeon.enter", [GlobalEngine.dungeon_system.get_entry_cost("F")]), Callable(self, "_on_start_pressed"))
	root.add_child(_start_button)

	_forfeit_button = _make_button(GlobalEngine.loc("dungeon.leave"), Callable(self, "_on_forfeit_pressed"))
	root.add_child(_forfeit_button)

func _refresh() -> void:
	if not is_instance_valid(GlobalEngine) or GlobalEngine.dungeon_system == null:
		return

	var player_rank := GlobalEngine.get_rank_by_level(GlobalEngine.lvl)
	var state: Dictionary = GlobalEngine.dungeon_system.get_view_state(player_rank)
	_sync_rank_select(state.get("available_ranks", []), String(state.get("active_rank", player_rank)))

	var selected_rank := _selected_rank(player_rank)
	var rank_for_display := selected_rank
	if bool(state.get("in_run", false)):
		rank_for_display = String(state.get("active_rank", selected_rank))

	_refresh_background(String(state.get("background_path", "")))
	_title_label.text = GlobalEngine.loc("dungeon.rank_title", [GlobalEngine.dungeon_system.get_dungeon_name(rank_for_display).to_upper(), rank_for_display])
	_status_label.text = _status_text(state, rank_for_display)
	_checkpoint_label.text = _checkpoint_text(state, rank_for_display)
	_refresh_enemy(state)
	_refresh_combat_fx(state)
	_refresh_energy(state)
	_refresh_event(state)
	_refresh_log(state)
	_refresh_buttons(state, selected_rank, String(state.get("phase", "idle")))

func _sync_rank_select(ranks: Array, preferred_rank: String) -> void:
	var previous := _selected_rank(preferred_rank)
	_rank_select.clear()
	for rank in ranks:
		_rank_select.add_item(String(rank))
	if _rank_select.item_count == 0:
		_rank_select.add_item(preferred_rank)

	var target := preferred_rank
	if ranks.has(previous):
		target = previous
	for i in range(_rank_select.item_count):
		if _rank_select.get_item_text(i) == target:
			_rank_select.select(i)
			return
	_rank_select.select(0)

func _selected_rank(fallback: String) -> String:
	if not is_instance_valid(_rank_select) or _rank_select.item_count <= 0:
		return fallback
	return _rank_select.get_item_text(_rank_select.selected)

func _status_text(state: Dictionary, rank: String) -> String:
	if bool(state.get("in_run", false)):
		return GlobalEngine.loc("dungeon.floor_status", [int(state.get("current_floor", 1)), MAX_DUNGEON_FLOOR, _phase_label(String(state.get("phase", "idle")))])
	if String(state.get("phase", "idle")) == "dead":
		return GlobalEngine.loc("dungeon.dead")
	if String(state.get("phase", "idle")) == "completed":
		return GlobalEngine.loc("dungeon.completed")
	return GlobalEngine.loc("dungeon.entry_cost", [GlobalEngine.dungeon_system.get_entry_cost(rank)])

func _checkpoint_text(state: Dictionary, rank: String) -> String:
	var checkpoints: Dictionary = state.get("checkpoints", {})
	var bests: Dictionary = state.get("best_floors", {})
	return GlobalEngine.loc("dungeon.checkpoint", [
		int(checkpoints.get(rank, 1)),
		int(bests.get(rank, 1)),
		GlobalEngine.hp,
		GlobalEngine.max_hp,
		GlobalEngine.end,
		GlobalEngine.max_end,
	])

func _refresh_enemy(state: Dictionary) -> void:
	var enemy: Dictionary = state.get("enemy", {})
	if enemy.is_empty():
		var phase := String(state.get("phase", "idle"))
		if phase == "event":
			_enemy_label.hide()
		elif phase == "floor_cleared":
			_enemy_label.text = GlobalEngine.loc("dungeon.floor_clear")
			_enemy_label.show()
		else:
			_enemy_label.text = GlobalEngine.loc("dungeon.no_enemy")
			_enemy_label.show()
		_enemy_hp_bar.max_value = 1
		_enemy_hp_bar.value = 0
		_enemy_hp_bar.hide()
		_hide_enemy_sprite()
		return

	_enemy_hp_bar.show()
	_enemy_label.show()
	_enemy_label.text = "%s [%s]  HP %d/%d  ATK %d  DEF %d  SPD %d" % [
		String(enemy.get("name", "Ennemi")),
		_localized_enemy_type(String(enemy.get("type", "?"))),
		int(enemy.get("hp", 0)),
		int(enemy.get("max_hp", 1)),
		int(enemy.get("atk", 0)),
		int(enemy.get("def", 0)),
		int(enemy.get("spd", 0)),
	]
	_enemy_hp_bar.max_value = maxi(1, int(enemy.get("max_hp", 1)))
	_enemy_hp_bar.value = int(enemy.get("hp", 0))
	_refresh_enemy_sprite(enemy)

func _refresh_background(path: String) -> void:
	if not is_instance_valid(_background_rect):
		return
	if path.is_empty():
		path = FALLBACK_DUNGEON_BACKGROUND_PATH
	if path == _current_background_path:
		return
	_current_background_path = path
	var texture = load(path)
	if texture is Texture2D:
		_background_rect.texture = texture

func _refresh_enemy_sprite(enemy: Dictionary) -> void:
	if not is_instance_valid(_enemy_sprite):
		return
	var visual = enemy.get("visual", {})
	if not (visual is Dictionary) or visual.is_empty():
		_hide_enemy_sprite()
		return

	var enemy_key := String(enemy.get("spawn_key", enemy.get("name", "")))
	if enemy_key == _current_enemy_key and _enemy_sprite.texture != null:
		return
	_current_enemy_key = enemy_key
	_enemy_sprite.texture = _make_enemy_texture(visual)
	_enemy_sprite.visible = _enemy_sprite.texture != null
	if _enemy_sprite.visible:
		_play_enemy_arrival()

func _hide_enemy_sprite() -> void:
	_current_enemy_key = ""
	if _enemy_arrival_tween != null:
		_enemy_arrival_tween.kill()
		_enemy_arrival_tween = null
	if is_instance_valid(_enemy_sprite):
		_enemy_sprite.hide()
		_enemy_sprite.texture = null
		_enemy_sprite.modulate = Color(1, 1, 1, 0.88)
		_enemy_sprite.scale = Vector2.ONE

func _play_enemy_arrival() -> void:
	if not is_instance_valid(_enemy_sprite) or not is_visible_in_tree():
		return
	if _enemy_arrival_tween != null:
		_enemy_arrival_tween.kill()
	_enemy_sprite.pivot_offset = _enemy_sprite.size * 0.5
	_enemy_sprite.modulate = Color(0.70, 0.95, 1.0, 0.0)
	_enemy_sprite.scale = Vector2(0.86, 0.86)
	_enemy_arrival_tween = create_tween()
	_enemy_arrival_tween.set_parallel(true)
	_enemy_arrival_tween.tween_property(_enemy_sprite, "modulate", Color(1, 1, 1, 0.88), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_enemy_arrival_tween.tween_property(_enemy_sprite, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _refresh_combat_fx(state: Dictionary) -> void:
	var fx_seq := int(state.get("combat_fx_seq", 0))
	if not _combat_fx_ready:
		_combat_fx_ready = true
		_last_combat_fx_seq = fx_seq
		_refresh_drop_popup(state)
		return

	if fx_seq <= 0 or fx_seq == _last_combat_fx_seq:
		_refresh_drop_popup(state)
		return

	_last_combat_fx_seq = fx_seq
	var fx = state.get("combat_fx", {})
	if not (fx is Dictionary):
		return

	match String(fx.get("kind", "")):
		"slash":
			_play_slash_fx(int(fx.get("damage", 0)), false)
		"burst":
			_play_slash_fx(int(fx.get("damage", 0)), true)
		"death":
			_play_death_fx()
			_refresh_drop_popup(state, true)

func _play_slash_fx(damage: int, heavy: bool) -> void:
	if not is_instance_valid(_fx_layer) or not is_visible_in_tree():
		return
	var center := _effect_center()
	var count := 2 if heavy else 1
	for i in range(count):
		var slash := ColorRect.new()
		slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slash.color = Color(0.75, 0.96, 1.0, 0.92) if not heavy else Color(0.0, 0.88, 1.0, 0.95)
		_fx_layer.add_child(slash)
		var w := 96.0 if not heavy else 126.0
		var h := 6.0 if not heavy else 9.0
		slash.size = Vector2(w, h)
		slash.position = center + Vector2(-w * 0.5, -h * 0.5 + float(i * 18 - 7))
		slash.rotation = deg_to_rad(-24.0 if i == 0 else 24.0)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(slash, "position", slash.position + Vector2(22, -14), 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(slash, "modulate:a", 0.0, 0.20)
		tween.chain().tween_callback(_queue_free_fx.bind(slash))

	if damage > 0:
		_play_damage_label(damage, heavy)

func _play_damage_label(damage: int, heavy: bool) -> void:
	if not is_instance_valid(_fx_layer):
		return
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "-%d" % damage
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22 if not heavy else 28)
	label.add_theme_color_override("font_color", Color("#f5f7fb") if not heavy else Color("#00f2ff"))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.012, 0.025, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	_fx_layer.add_child(label)
	label.size = Vector2(92, 36)
	label.position = _effect_center() + Vector2(-46, -78)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", label.position + Vector2(0, -30), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.42).set_delay(0.08)
	tween.chain().tween_callback(_queue_free_fx.bind(label))

func _play_death_fx() -> void:
	if not is_instance_valid(_fx_layer) or not is_visible_in_tree():
		return
	var center := _effect_center()
	for i in range(14):
		var particle := ColorRect.new()
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		particle.color = [Color("#00f2ff"), Color("#8be9fd"), Color("#f5f7fb"), Color("#5b6f86")].pick_random()
		_fx_layer.add_child(particle)
		var size_px := randf_range(4.0, 7.0)
		particle.size = Vector2(size_px, size_px)
		particle.position = center
		var angle := randf() * TAU
		var distance := randf_range(32.0, 88.0)
		var target := center + Vector2(cos(angle), sin(angle)) * distance
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "modulate:a", 0.0, 0.42).set_delay(0.08)
		tween.chain().tween_callback(_queue_free_fx.bind(particle))

func _effect_center() -> Vector2:
	if is_instance_valid(_enemy_sprite) and _enemy_sprite.visible:
		return _enemy_sprite.position + _enemy_sprite.size * 0.5
	if is_instance_valid(_fx_layer):
		return _fx_layer.size * Vector2(0.5, 0.48)
	return Vector2(180, 140)

func _queue_free_fx(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()

func _build_drop_popup(parent: Control) -> void:
	_drop_popup = PanelContainer.new()
	_drop_popup.visible = false
	_drop_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_popup.add_theme_stylebox_override("panel", _drop_popup_style())
	parent.add_child(_drop_popup)
	_drop_popup.anchor_left = 0.08
	_drop_popup.anchor_top = 0.68
	_drop_popup.anchor_right = 0.92
	_drop_popup.anchor_bottom = 0.68
	_drop_popup.offset_bottom = 82

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	_drop_popup.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)

	_drop_rarity_label = Label.new()
	_drop_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drop_rarity_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_drop_rarity_label.add_theme_font_size_override("font_size", 10)
	_drop_rarity_label.add_theme_color_override("font_outline_color", Color(0.0, 0.012, 0.025, 1.0))
	_drop_rarity_label.add_theme_constant_override("outline_size", 1)
	box.add_child(_drop_rarity_label)

	_drop_label = Label.new()
	_drop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drop_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_drop_label.add_theme_font_size_override("font_size", 16)
	_drop_label.add_theme_color_override("font_outline_color", Color(0.0, 0.012, 0.025, 1.0))
	_drop_label.add_theme_constant_override("outline_size", 2)
	box.add_child(_drop_label)

	_drop_line = ColorRect.new()
	_drop_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_line.custom_minimum_size = Vector2(0, 2)
	box.add_child(_drop_line)

	_drop_popup_timer = Timer.new()
	_drop_popup_timer.one_shot = true
	_drop_popup_timer.wait_time = 2.6
	_drop_popup_timer.timeout.connect(_hide_drop_popup)
	add_child(_drop_popup_timer)

func _refresh_drop_popup(state: Dictionary, force_show: bool = false) -> void:
	var drop = state.get("last_drop", {})
	if not (drop is Dictionary) or drop.is_empty():
		return
	var drop_key := "%s:%s:%s" % [
		str(drop.get("floor", "")),
		str(drop.get("name", "")),
		str(drop.get("rarity", "")),
	]
	if not force_show and drop_key == _last_drop_key:
		return
	_last_drop_key = drop_key
	_show_drop_popup(drop)

func _show_drop_popup(drop: Dictionary) -> void:
	if not is_instance_valid(_drop_popup) or not is_instance_valid(_drop_label) or not is_visible_in_tree():
		return
	var rarity := str(drop.get("rarity", "common"))
	var rarity_color := _rarity_color(rarity)
	var rarity_name := _rarity_label(rarity)
	_drop_rarity_label.text = GlobalEngine.loc("dungeon.loot", [rarity_name])
	_drop_rarity_label.add_theme_color_override("font_color", rarity_color)
	_drop_label.text = GlobalEngine.localize_item_name(drop).to_upper()
	_drop_label.add_theme_color_override("font_color", rarity_color)
	if is_instance_valid(_drop_line):
		_drop_line.color = Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.85)
	_drop_popup.add_theme_stylebox_override("panel", _drop_popup_style(rarity_color))
	_drop_popup.show()
	_drop_popup.modulate = Color(1, 1, 1, 0)
	_drop_popup.scale = Vector2(0.90, 0.90)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_drop_popup, "modulate:a", 1.0, 0.16)
	tween.tween_property(_drop_popup, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_spawn_drop_sparks(rarity_color)
	if is_instance_valid(_drop_popup_timer):
		_drop_popup_timer.start()

func _hide_drop_popup() -> void:
	if is_instance_valid(_drop_popup):
		_drop_popup.hide()

func _spawn_drop_sparks(color: Color) -> void:
	if not is_instance_valid(_fx_layer) or not is_instance_valid(_drop_popup):
		return
	var rect := _drop_popup.get_rect()
	var center := rect.position + rect.size * 0.5
	for i in range(16):
		var spark := ColorRect.new()
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.color = Color(color.r, color.g, color.b, 0.88)
		_fx_layer.add_child(spark)
		var size_px := 3.0 + float(i % 3)
		spark.size = Vector2(size_px, size_px)
		var start_x := randf_range(rect.position.x + 16.0, rect.position.x + maxf(18.0, rect.size.x - 16.0))
		var start_y := randf_range(rect.position.y + 6.0, rect.position.y + rect.size.y - 6.0)
		spark.position = Vector2(start_x, start_y)
		var angle := randf() * TAU
		var distance := randf_range(22.0, 70.0)
		var target := center + Vector2(cos(angle), sin(angle)) * distance
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(spark, "position", target, 0.44).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.44).set_delay(0.08)
		tween.chain().tween_callback(_queue_free_fx.bind(spark))

func _make_enemy_texture(visual: Dictionary) -> Texture2D:
	var path := String(visual.get("path", ""))
	if path.is_empty():
		return null
	var atlas = _texture_cache.get(path, null)
	if not atlas is Texture2D:
		atlas = load(path)
		if not atlas is Texture2D:
			return null
		_texture_cache[path] = atlas

	var texture := AtlasTexture.new()
	texture.atlas = atlas
	texture.region = _first_frame_region(visual, atlas)
	return texture

func _first_frame_region(visual: Dictionary, atlas: Texture2D) -> Rect2:
	if visual.has("frame_rects"):
		var rects: Array = visual["frame_rects"]
		if not rects.is_empty() and rects[0] is Rect2:
			return rects[0]

	var frame_width := float(atlas.get_width())
	var frame_height := float(atlas.get_height())
	if visual.has("frame_width") and visual.has("frame_height"):
		frame_width = float(visual["frame_width"])
		frame_height = float(visual["frame_height"])
	else:
		var frames := maxi(1, int(visual.get("frames", 1)))
		frame_width = frame_width / float(frames)
	return Rect2(0, 0, frame_width, frame_height)

func _refresh_energy(state: Dictionary) -> void:
	var energy := int(state.get("player_energy", 0))
	_energy_label.text = GlobalEngine.loc("dungeon.energy", [energy])
	_energy_bar.value = energy

func _refresh_event(state: Dictionary) -> void:
	for child in _choice_box.get_children():
		child.queue_free()

	var event: Dictionary = state.get("event", {})
	if String(state.get("phase", "")) != "event" or event.is_empty():
		_event_panel.hide()
		_event_title_label.hide()
		_event_text_label.hide()
		return

	_event_title_label.text = String(event.get("title", GlobalEngine.loc("dungeon.phase.event"))).to_upper()
	_event_text_label.text = String(event.get("text", ""))
	_event_panel.show()
	_event_title_label.show()
	_event_text_label.show()

	var choices: Array = event.get("choices", [])
	for i in range(choices.size()):
		var button := _make_button(String(choices[i]), Callable(self, "_on_choice_pressed").bind(i))
		button.custom_minimum_size = Vector2(0, 44)
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_color_override("font_color", Color("#f5f7fb"))
		button.add_theme_color_override("font_pressed_color", Color("#ffd166"))
		button.add_theme_color_override("font_hover_color", Color("#8be9fd"))
		button.add_theme_stylebox_override("normal", _event_choice_style())
		button.add_theme_stylebox_override("hover", _event_choice_style(Color(0.060, 0.145, 0.215, 0.98), Color(0.0, 0.78, 1.0, 0.92)))
		button.add_theme_stylebox_override("pressed", _event_choice_style(Color(0.085, 0.072, 0.030, 1.0), Color(1.0, 0.82, 0.32, 0.95)))
		_choice_box.add_child(button)

func _refresh_log(state: Dictionary) -> void:
	var lines: Array = state.get("log", [])
	var text := ""
	for line in lines:
		text += String(line) + "\n"
	_log_label.text = text.strip_edges()

func _refresh_buttons(state: Dictionary, selected_rank: String, phase: String) -> void:
	var in_run := bool(state.get("in_run", false))
	var energy := int(state.get("player_energy", 0))
	var is_combat := phase == "combat"
	var is_clear := phase == "floor_cleared"

	_rank_select.disabled = in_run
	_auto_button.text = GlobalEngine.loc("dungeon.auto")
	_special_button.text = GlobalEngine.loc("dungeon.special")
	_heal_button.text = GlobalEngine.loc("dungeon.heal")
	_shield_button.text = GlobalEngine.loc("dungeon.shield")
	_next_button.text = GlobalEngine.loc("dungeon.next")
	_forfeit_button.text = GlobalEngine.loc("dungeon.leave")
	_start_button.visible = not in_run
	_start_button.text = GlobalEngine.loc("dungeon.enter", [GlobalEngine.dungeon_system.get_entry_cost(selected_rank)])
	_start_button.disabled = (not GlobalEngine.is_debug_invincible() and GlobalEngine.end < GlobalEngine.dungeon_system.get_entry_cost(selected_rank)) or GlobalEngine.hp <= 0

	_forfeit_button.visible = in_run
	_auto_button.visible = is_combat
	_special_button.visible = is_combat
	_heal_button.visible = is_combat
	_shield_button.visible = is_combat
	_next_button.visible = is_clear

	_auto_button.disabled = not is_combat
	_special_button.disabled = energy < 50
	_heal_button.disabled = energy < 45
	_shield_button.disabled = energy < 35
	_next_button.disabled = not is_clear

func _phase_label(phase: String) -> String:
	match phase:
		"combat":
			return GlobalEngine.loc("dungeon.phase.combat")
		"event":
			return GlobalEngine.loc("dungeon.phase.event")
		"floor_cleared":
			return GlobalEngine.loc("dungeon.phase.clear")
		"dead":
			return GlobalEngine.loc("dungeon.phase.dead")
		"completed":
			return GlobalEngine.loc("dungeon.phase.completed")
	return GlobalEngine.loc("dungeon.phase.idle")

func _on_start_pressed() -> void:
	GlobalEngine.start_dungeon(_selected_rank(GlobalEngine.get_rank_by_level(GlobalEngine.lvl)))
	_refresh()

func _on_forfeit_pressed() -> void:
	GlobalEngine.forfeit_dungeon()
	_refresh()

func _on_auto_pressed() -> void:
	GlobalEngine.dungeon_auto_exchange()
	_refresh()

func _on_special_pressed() -> void:
	GlobalEngine.dungeon_use_skill("special")
	_refresh()

func _on_heal_pressed() -> void:
	GlobalEngine.dungeon_use_skill("heal")
	_refresh()

func _on_shield_pressed() -> void:
	GlobalEngine.dungeon_use_skill("shield")
	_refresh()

func _on_next_pressed() -> void:
	GlobalEngine.dungeon_advance_floor()
	_refresh()

func _on_choice_pressed(choice_index: int) -> void:
	GlobalEngine.dungeon_choose_event(choice_index)
	_refresh()

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _button_style())
	button.pressed.connect(callback)
	return button

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.024, 0.032, 0.96)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.0, 0.40, 0.66, 0.45)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.020, 0.026, 0.038, 0.96)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.63, 1.0, 0.42)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

func _event_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.010, 0.018, 0.028, 0.82)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.0, 0.56, 0.86, 0.62)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.shadow_color = Color(0.0, 0.28, 0.48, 0.18)
	style.shadow_size = 8
	return style

func _event_choice_style(bg: Color = Color(0.032, 0.076, 0.120, 0.94), border: Color = Color(0.0, 0.56, 0.86, 0.76)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 12
	style.content_margin_top = 7
	style.content_margin_right = 12
	style.content_margin_bottom = 7
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
	return style

func _drop_popup_style(accent: Color = Color("#00f2ff")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.025, 0.035, 0.94)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.border_color = Color(accent.r, accent.g, accent.b, 0.86)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.28)
	style.shadow_size = 12
	return style

func _rarity_color(rarity: String) -> Color:
	match rarity:
		"rare":
			return Color("#00f2ff")
		"epic":
			return Color("#cc44ff")
		"legendary":
			return Color("#ffd700")
		"mythic":
			return Color("#ff4444")
	return Color("#d7dde8")

func _rarity_label(rarity: String) -> String:
	match rarity:
		"rare":
			return GlobalEngine.loc("item.rarity.rare").to_upper()
		"epic":
			return GlobalEngine.loc("item.rarity.epic").to_upper()
		"legendary":
			return GlobalEngine.loc("item.rarity.legendary").to_upper()
		"mythic":
			return GlobalEngine.loc("item.rarity.mythic").to_upper()
	return GlobalEngine.loc("item.rarity.common").to_upper()

func _localized_enemy_type(type_name: String) -> String:
	var key := "dungeon.enemy_type.%s" % type_name
	if GlobalEngine.has_loc(key):
		return GlobalEngine.loc(key)
	return type_name

func _scene_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.035, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.63, 1.0, 0.85)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _log_style() -> StyleBoxFlat:
	var style := _frame_style()
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	return style

func _button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	style.bg_color = Color(0.05, 0.10, 0.16, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.63, 1.0, 0.85)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style
