extends MarginContainer

var _main_vbox: VBoxContainer
var _daily_list_vbox: VBoxContainer
var _weekly_vbox: VBoxContainer
var _daily_scroll: ScrollContainer
var _timer_acc: float = 0.0
var _touch_dragging: bool = false
var _touch_start_position := Vector2.ZERO
var _touch_scroll_start: int = 0
var _touch_active_index: int = -1
var _validation_widgets: Array = []
var _journal_expanded: bool = false

const TOUCH_DRAG_DEADZONE := 8.0
const MOBILE_TOUCH_TARGET := 68.0
const MOBILE_TIMER_HEIGHT := 38.0
const MOBILE_TIMER_FONT_SIZE := 15
const MOBILE_SECTION_FONT_SIZE := 18
const MOBILE_SMALL_FONT_SIZE := 14
const MOBILE_BODY_FONT_SIZE := 16
const MOBILE_TITLE_FONT_SIZE := 20
const JOURNAL_RECENT_LIMIT := 50
const JOURNAL_MAX_HEIGHT := 280.0
const JOURNAL_BUTTON_WIDTH := 118.0

func _ready() -> void:
	add_theme_constant_override("margin_left", 0)
	add_theme_constant_override("margin_right", 0)
	add_theme_constant_override("margin_top", 0)
	add_theme_constant_override("margin_bottom", 0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.043, 0.047, 0.059, 1)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.149, 0.173, 0.212, 1)
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_right = 4
	panel_style.corner_radius_bottom_left = 4

	var bg := PanelContainer.new()
	bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bg.add_theme_stylebox_override("panel", panel_style)
	add_child(bg)

	var inner := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		inner.add_theme_constant_override(side, 12)
	bg.add_child(inner)

	_main_vbox = VBoxContainer.new()
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_vbox.add_theme_constant_override("separation", 16)
	inner.add_child(_main_vbox)

	if GlobalEngine.has_method("ensure_missions_available"):
		GlobalEngine.ensure_missions_available()
	if not GlobalEngine.missions_changed.is_connected(_build_static_ui):
		GlobalEngine.missions_changed.connect(_build_static_ui)
	_build_static_ui()

func refresh() -> void:
	if GlobalEngine.has_method("ensure_missions_available"):
		GlobalEngine.ensure_missions_available()
	_build_static_ui()

func _build_static_ui() -> void:
	_build_static_ui_compact()
	return
	_clear_children(_main_vbox)

	var t_daily := Label.new()
	t_daily.name = "TimerDaily"
	t_daily.text = "↻ Quotidien : " + GlobalEngine.get_time_string()
	_style_timer_label(t_daily, Color("#00f2ff"))
	_main_vbox.add_child(t_daily)

	var t_weekly := Label.new()
	t_weekly.name = "TimerWeekly"
	t_weekly.text = "↻ Hebdo : " + GlobalEngine.get_weekly_time_string()
	_style_timer_label(t_weekly, Color("#d15cff"))
	_main_vbox.add_child(t_weekly)

	var history := Label.new()
	history.name = "HistorySummary"
	history.text = _history_summary_text()
	history.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	history.autowrap_mode = TextServer.AUTOWRAP_WORD
	history.add_theme_font_size_override("font_size", MOBILE_BODY_FONT_SIZE)
	history.add_theme_color_override("font_color", Color("#ffd166"))
	_main_vbox.add_child(history)

	var journal_button := Button.new()
	journal_button.name = "JournalToggle"
	journal_button.text = "JOURNAL ▲" if _journal_expanded else "JOURNAL ▼"
	journal_button.custom_minimum_size = Vector2(0, MOBILE_TOUCH_TARGET)
	journal_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal_button.add_theme_font_size_override("font_size", MOBILE_BODY_FONT_SIZE)
	journal_button.add_theme_color_override("font_color", Color("#8be9fd"))
	journal_button.pressed.connect(func():
		_journal_expanded = not _journal_expanded
		_build_static_ui()
	)
	_main_vbox.add_child(journal_button)

	if _journal_expanded:
		_main_vbox.add_child(_create_journal_panel())

	_add_section_header(GlobalEngine.loc("mission.daily_section"), Color("#00f2ff"), _main_vbox)

	_daily_scroll = ScrollContainer.new()
	_daily_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_daily_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_daily_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_daily_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_daily_scroll.gui_input.connect(_on_daily_scroll_gui_input)
	_main_vbox.add_child(_daily_scroll)

	_daily_list_vbox = VBoxContainer.new()
	_daily_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_daily_list_vbox.add_theme_constant_override("separation", 16)
	_daily_scroll.add_child(_daily_list_vbox)

	_add_section_header("MISSION HEBDOMADAIRE", Color("#d15cff"), _main_vbox)

	_weekly_vbox = VBoxContainer.new()
	_weekly_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weekly_vbox.add_theme_constant_override("separation", 14)
	_main_vbox.add_child(_weekly_vbox)

	_refresh_mission_cards()

func _build_static_ui_compact() -> void:
	_clear_children(_main_vbox)
	_main_vbox.add_child(_create_header_panel())

	if _journal_expanded:
		_main_vbox.add_child(_create_journal_panel())

	_add_section_header(GlobalEngine.loc("mission.daily_section"), Color("#00f2ff"), _main_vbox)

	_daily_scroll = ScrollContainer.new()
	_daily_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_daily_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_daily_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_daily_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_daily_scroll.gui_input.connect(_on_daily_scroll_gui_input)
	_main_vbox.add_child(_daily_scroll)

	_daily_list_vbox = VBoxContainer.new()
	_daily_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_daily_list_vbox.add_theme_constant_override("separation", 16)
	_daily_scroll.add_child(_daily_list_vbox)

	_add_section_header(GlobalEngine.loc("mission.weekly_section"), Color("#d15cff"), _main_vbox)

	_weekly_vbox = VBoxContainer.new()
	_weekly_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weekly_vbox.add_theme_constant_override("separation", 14)
	_main_vbox.add_child(_weekly_vbox)

	_refresh_mission_cards()

func _create_header_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _header_panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 5)
	margin.add_child(box)

	var timer_row := HBoxContainer.new()
	timer_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_row.add_theme_constant_override("separation", 6)
	box.add_child(timer_row)

	var t_daily := Label.new()
	t_daily.name = "TimerDaily"
	t_daily.text = GlobalEngine.loc("mission.daily_timer", [GlobalEngine.get_time_string()])
	_style_timer_label(t_daily, Color("#00f2ff"))
	timer_row.add_child(_wrap_header_label(t_daily, Color("#00f2ff")))

	var t_weekly := Label.new()
	t_weekly.name = "TimerWeekly"
	t_weekly.text = GlobalEngine.loc("mission.weekly_timer", [_short_weekly_time(GlobalEngine.get_weekly_time_string())])
	_style_timer_label(t_weekly, Color("#d15cff"))
	timer_row.add_child(_wrap_header_label(t_weekly, Color("#d15cff")))

	var summary_row := HBoxContainer.new()
	summary_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_row.add_theme_constant_override("separation", 8)
	box.add_child(summary_row)

	var history := Label.new()
	history.name = "HistorySummary"
	history.text = _history_summary_text()
	history.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	history.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	history.autowrap_mode = TextServer.AUTOWRAP_OFF
	history.clip_text = true
	history.add_theme_font_size_override("font_size", MOBILE_SMALL_FONT_SIZE)
	history.add_theme_color_override("font_color", Color("#ffd166"))
	summary_row.add_child(history)

	var reward_cap := Label.new()
	reward_cap.name = "RewardCapSummary"
	reward_cap.text = _reward_cap_text()
	reward_cap.custom_minimum_size = Vector2(176, 40)
	reward_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_cap.autowrap_mode = TextServer.AUTOWRAP_OFF
	reward_cap.clip_text = true
	reward_cap.add_theme_font_size_override("font_size", 12)
	reward_cap.add_theme_color_override("font_color", Color("#8be9fd"))
	summary_row.add_child(reward_cap)

	var journal_button := Button.new()
	journal_button.name = "JournalToggle"
	journal_button.text = GlobalEngine.loc("mission.journal")
	journal_button.custom_minimum_size = Vector2(82, 40)
	journal_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	journal_button.add_theme_font_size_override("font_size", MOBILE_SMALL_FONT_SIZE)
	journal_button.add_theme_color_override("font_color", Color("#8be9fd"))
	journal_button.add_theme_stylebox_override("normal", _journal_toggle_style())
	journal_button.add_theme_stylebox_override("pressed", _journal_toggle_style(Color(0.03, 0.09, 0.13, 1)))
	journal_button.pressed.connect(func():
		_journal_expanded = not _journal_expanded
		_build_static_ui()
	)
	summary_row.add_child(journal_button)
	return panel

func _wrap_header_label(label: Label, accent: Color) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", _timer_chip_style(accent))
	frame.add_child(label)
	return frame

func _short_weekly_time(text: String) -> String:
	return text.replace(" Jours - ", "%s " % GlobalEngine.loc("time.day_short"))

func _refresh_mission_cards() -> void:
	if not is_instance_valid(_daily_list_vbox) or not is_instance_valid(_weekly_vbox):
		return

	if GlobalEngine.has_method("ensure_missions_available"):
		GlobalEngine.ensure_missions_available()

	_validation_widgets.clear()
	_clear_children(_daily_list_vbox)
	_clear_children(_weekly_vbox)

	if GlobalEngine.available_missions.is_empty():
		var empty := Label.new()
		empty.text = GlobalEngine.loc("mission.exhausted")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", MOBILE_BODY_FONT_SIZE)
		empty.add_theme_color_override("font_color", Color("#707070"))
		_daily_list_vbox.add_child(empty)
	else:
		for mission in GlobalEngine.available_missions:
			_daily_list_vbox.add_child(_create_card(mission, false))

	if GlobalEngine.available_weekly_missions.is_empty():
		var empty_weekly := Label.new()
		empty_weekly.text = GlobalEngine.loc("mission.no_weekly")
		empty_weekly.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_weekly.add_theme_font_size_override("font_size", MOBILE_BODY_FONT_SIZE)
		empty_weekly.add_theme_color_override("font_color", Color("#707070"))
		_weekly_vbox.add_child(empty_weekly)
	else:
		for mission in GlobalEngine.available_weekly_missions:
			_weekly_vbox.add_child(_create_card(mission, true))

func _on_daily_scroll_gui_input(event: InputEvent) -> void:
	if not is_instance_valid(_daily_scroll):
		return

	if event is InputEventScreenTouch:
		var touch_event: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_event.pressed:
			_touch_dragging = true
			_touch_active_index = touch_event.index
			_touch_start_position = touch_event.position
			_touch_scroll_start = _daily_scroll.scroll_vertical
		elif touch_event.index == _touch_active_index:
			_touch_dragging = false
			_touch_active_index = -1
		return

	if event is InputEventScreenDrag:
		var drag_event: InputEventScreenDrag = event as InputEventScreenDrag
		if not _touch_dragging:
			return
		if drag_event.index != _touch_active_index:
			return

		var delta_y: float = drag_event.position.y - _touch_start_position.y
		if abs(delta_y) < TOUCH_DRAG_DEADZONE:
			return

		_daily_scroll.scroll_vertical = max(0, _touch_scroll_start - int(delta_y))
		accept_event()

func _add_section_header(text: String, color: Color, parent: VBoxContainer) -> void:
	parent.add_child(HSeparator.new())

	var label := Label.new()
	label.text = "— " + text + " —"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", MOBILE_SECTION_FONT_SIZE)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)

func _style_timer_label(label: Label, color: Color) -> void:
	label.custom_minimum_size = Vector2(0, MOBILE_TIMER_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", MOBILE_TIMER_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 0)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 0)

func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _localized_mission_text(m_data, field: String, fallback: String) -> String:
	if m_data == null:
		return fallback
	var key := "mission_data.%s.%s" % [String(m_data.id), field]
	if not GlobalEngine.has_loc(key):
		return fallback
	return GlobalEngine.loc(key)

func _create_card(m_dict: Dictionary, is_weekly: bool) -> PanelContainer:
	var mission_id := String(m_dict.get("id", ""))
	var m_data = GlobalEngine.all_missions.get(mission_id)
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if not m_data:
		card.add_theme_stylebox_override("panel", _missing_mission_style())
		var missing := Label.new()
		missing.text = GlobalEngine.loc("mission.not_found")
		missing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		missing.add_theme_font_size_override("font_size", MOBILE_BODY_FONT_SIZE)
		missing.add_theme_color_override("font_color", Color("#ff6262"))
		card.add_child(missing)
		return card

	var style := StyleBoxFlat.new()
	style.bg_color = Color("#0a1018")
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10

	var mission_status := String(m_dict.get("status", "available"))
	var end_cost := int(m_dict.get("end_cost", 15))

	if mission_status == "in_progress":
		style.border_color = Color("#ffaa00")
		style.shadow_color = Color(1.0, 0.67, 0.0, 0.25)
		style.shadow_size = 6
	elif mission_status in ["completed", "failed"]:
		style.border_color = Color("#2a2a2a")
	else:
		var border_color := Color("#00f2ff") if not is_weekly else Color("#d15cff")
		style.border_color = border_color
		style.shadow_color = Color(border_color.r, border_color.g, border_color.b, 0.18)
		style.shadow_size = 5

	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 9)

	var title := Label.new()
	title.text = _localized_mission_text(m_data, "title", m_data.title).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", MOBILE_TITLE_FONT_SIZE)
	title.add_theme_color_override("font_color", Color("#00f2ff") if not is_weekly else Color("#d15cff"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.add_child(title)

	var desc := Label.new()
	desc.text = _localized_mission_text(m_data, "description", m_data.description)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", MOBILE_BODY_FONT_SIZE)
	desc.add_theme_color_override("font_color", Color(0.74, 0.74, 0.74))
	content.add_child(desc)

	var reward_text := "+" + str(m_data.get_base_xp_reward()) + " XP"
	var reward_stat_key: String = m_data.get_reward_stat_key()
	if not reward_stat_key.is_empty():
		reward_text += "  +" + str(m_data.reward_stat_amount) + " " + reward_stat_key

	var reward := Label.new()
	reward.text = reward_text
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.add_theme_font_size_override("font_size", MOBILE_BODY_FONT_SIZE)
	reward.add_theme_color_override("font_color", Color("#00ff88"))
	content.add_child(reward)

	var validation_preview := _validation_preview_text(m_data)
	if not validation_preview.is_empty() and mission_status == "available":
		var validation_label := Label.new()
		validation_label.text = validation_preview
		validation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		validation_label.add_theme_font_size_override("font_size", MOBILE_BODY_FONT_SIZE)
		validation_label.add_theme_color_override("font_color", Color("#8be9fd"))
		content.add_child(validation_label)

	if mission_status == "available" and _daily_rewards_exhausted_for(m_data):
		var journal_only := Label.new()
		journal_only.text = GlobalEngine.loc("mission.journal_only_cap")
		journal_only.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		journal_only.autowrap_mode = TextServer.AUTOWRAP_WORD
		journal_only.add_theme_font_size_override("font_size", MOBILE_SMALL_FONT_SIZE)
		journal_only.add_theme_color_override("font_color", Color("#ffb347"))
		content.add_child(journal_only)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)

	match mission_status:
		"available":
			var blockers := _get_launch_blockers(m_dict, m_data)
			if not blockers.is_empty():
				var reason := Label.new()
				reason.text = GlobalEngine.loc("mission.missing", [" | ".join(blockers)])
				reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				reason.autowrap_mode = TextServer.AUTOWRAP_WORD
				reason.add_theme_font_size_override("font_size", MOBILE_SMALL_FONT_SIZE)
				reason.add_theme_color_override("font_color", Color("#ffb347"))
				buttons.add_child(reason)

				var disabled_button := Button.new()
				disabled_button.text = GlobalEngine.loc("mission.blocked")
				disabled_button.disabled = true
				disabled_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				disabled_button.custom_minimum_size = Vector2(0, MOBILE_TOUCH_TARGET)
				disabled_button.add_theme_font_size_override("font_size", MOBILE_BODY_FONT_SIZE)
				buttons.add_child(disabled_button)
			else:
				var accept_button := Button.new()
				accept_button.text = GlobalEngine.loc("mission.launch", [end_cost])
				accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				accept_button.custom_minimum_size = Vector2(0, MOBILE_TOUCH_TARGET)
				accept_button.add_theme_font_size_override("font_size", MOBILE_BODY_FONT_SIZE)
				accept_button.pressed.connect(func(): if GlobalEngine.accept_mission(m_dict): _refresh_mission_cards())
				buttons.add_child(accept_button)
		"in_progress":
			_build_in_progress_controls(buttons, m_dict)
		_:
			var status_label := Label.new()
			status_label.text = "◉ " + mission_status.to_upper()
			status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			status_label.add_theme_font_size_override("font_size", MOBILE_BODY_FONT_SIZE)
			status_label.add_theme_color_override("font_color", Color("#707070"))
			buttons.add_child(status_label)

	content.add_child(buttons)
	margin.add_child(content)
	card.add_child(margin)
	return card

func _build_in_progress_controls(parent: VBoxContainer, m_dict: Dictionary) -> void:
	var state := GlobalEngine.get_mission_validation_state(m_dict)

	var state_label := Label.new()
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	state_label.add_theme_font_size_override("font_size", MOBILE_BODY_FONT_SIZE)
	state_label.add_theme_color_override("font_color", Color("#ffd166"))
	parent.add_child(state_label)

	var progress_label: Label = null
	if int(state.get("target_amount", 0)) > 0:
		var progress_row := HBoxContainer.new()
		progress_row.add_theme_constant_override("separation", 6)
		parent.add_child(progress_row)

		var step := maxi(1, int(state.get("amount_step", 1)))
		var minus_button := _make_validation_button("-%d" % step, Color("#ff6262"))
		minus_button.custom_minimum_size = Vector2(72, MOBILE_TOUCH_TARGET)
		minus_button.pressed.connect(func():
			if GlobalEngine.update_mission_progress(m_dict, -step):
				_refresh_validation_widgets()
		)
		progress_row.add_child(minus_button)

		progress_label = Label.new()
		progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		progress_label.add_theme_font_size_override("font_size", MOBILE_BODY_FONT_SIZE)
		progress_label.add_theme_color_override("font_color", Color("#d9f7ff"))
		progress_row.add_child(progress_label)

		var plus_button := _make_validation_button("+%d" % step, Color("#00ff88"))
		plus_button.custom_minimum_size = Vector2(72, MOBILE_TOUCH_TARGET)
		plus_button.pressed.connect(func():
			if GlobalEngine.update_mission_progress(m_dict, step):
				_refresh_validation_widgets()
		)
		progress_row.add_child(plus_button)

	if bool(state.get("proof_required", false)):
		var proof_edit := LineEdit.new()
		proof_edit.text = String(m_dict.get("proof_text", ""))
		proof_edit.placeholder_text = GlobalEngine.loc("mission.note_placeholder")
		proof_edit.custom_minimum_size = Vector2(0, MOBILE_TOUCH_TARGET)
		proof_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		proof_edit.max_length = 120
		proof_edit.add_theme_font_size_override("font_size", MOBILE_BODY_FONT_SIZE)
		proof_edit.text_changed.connect(func(new_text: String):
			m_dict["proof_text"] = new_text
		)
		proof_edit.text_submitted.connect(func(new_text: String):
			GlobalEngine.update_mission_proof(m_dict, new_text)
			_refresh_validation_widgets()
		)
		proof_edit.focus_exited.connect(func():
			GlobalEngine.update_mission_proof(m_dict, proof_edit.text)
			_refresh_validation_widgets()
		)
		parent.add_child(proof_edit)

	var blockers_label := Label.new()
	blockers_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blockers_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	blockers_label.add_theme_font_size_override("font_size", MOBILE_BODY_FONT_SIZE)
	parent.add_child(blockers_label)

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	parent.add_child(action_row)

	var fail_button := _make_validation_button(GlobalEngine.loc("mission.abandon"), Color("#ff6262"))
	fail_button.pressed.connect(func():
		if GlobalEngine.process_mission_result(m_dict, false):
			_refresh_mission_cards()
	)
	action_row.add_child(fail_button)

	var validate_button := _make_validation_button(GlobalEngine.loc("mission.validate"), Color("#00ff88"))
	validate_button.pressed.connect(func():
		if GlobalEngine.process_mission_result(m_dict, true):
			_refresh_mission_cards()
	)
	action_row.add_child(validate_button)

	var widget := {
		"mission": m_dict,
		"state_label": state_label,
		"progress_label": progress_label,
		"blockers_label": blockers_label,
		"validate_button": validate_button,
	}
	_validation_widgets.append(widget)
	_sync_validation_widget(widget)

func _make_validation_button(text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, MOBILE_TOUCH_TARGET)
	button.add_theme_font_size_override("font_size", MOBILE_BODY_FONT_SIZE)
	button.add_theme_color_override("font_color", color)
	return button

func _refresh_validation_widgets() -> void:
	for widget in _validation_widgets:
		if widget is Dictionary:
			_sync_validation_widget(widget)

func _sync_validation_widget(widget: Dictionary) -> void:
	var mission: Dictionary = widget.get("mission", {})
	var state := GlobalEngine.get_mission_validation_state(mission)

	var state_label = widget.get("state_label", null)
	if is_instance_valid(state_label):
		state_label.text = _validation_state_text(state)

	var progress_label = widget.get("progress_label", null)
	if is_instance_valid(progress_label):
		progress_label.text = _progress_text(state)

	var blockers_label = widget.get("blockers_label", null)
	if is_instance_valid(blockers_label):
		var can_validate := bool(state.get("can_validate", false))
		var blocker_parts: Array[String] = []
		for blocker in state.get("blockers", []):
			blocker_parts.append(String(blocker))
		blockers_label.text = GlobalEngine.loc("mission.ready") if can_validate else GlobalEngine.loc("mission.remaining", [" | ".join(blocker_parts)])
		blockers_label.add_theme_color_override("font_color", Color("#00ff88") if can_validate else Color("#ffb347"))

	var validate_button = widget.get("validate_button", null)
	if is_instance_valid(validate_button):
		var ready := bool(state.get("can_validate", false))
		validate_button.disabled = not ready
		validate_button.text = GlobalEngine.loc("mission.validate") if ready else GlobalEngine.loc("mission.locked")

func _validation_state_text(state: Dictionary) -> String:
	var parts: Array[String] = []
	var min_duration := int(state.get("min_duration_seconds", 0))
	if min_duration > 0:
		parts.append(GlobalEngine.loc("mission.validation_time", [_format_duration_ui(int(state.get("elapsed", 0))), _format_duration_ui(min_duration)]))
	if int(state.get("target_amount", 0)) > 0:
		parts.append(GlobalEngine.loc("mission.validation_objective", [_progress_text(state)]))
	if bool(state.get("proof_required", false)):
		parts.append(GlobalEngine.loc("mission.validation_note"))
	if parts.is_empty():
		return GlobalEngine.loc("mission.validation_free")
	return GlobalEngine.loc("mission.validation", [" | ".join(parts)])

func _progress_text(state: Dictionary) -> String:
	var target := int(state.get("target_amount", 0))
	if target <= 0:
		return ""
	var label := String(state.get("amount_label", ""))
	label = _localized_amount_label(label)
	return "%d/%d %s" % [int(state.get("progress_amount", 0)), target, label]

func _validation_preview_text(m_data) -> String:
	if not m_data.has_method("get_validation_rules"):
		return ""
	var rules: Dictionary = m_data.get_validation_rules()
	var parts: Array[String] = []
	var duration := int(rules.get("min_duration_seconds", 0))
	var target := int(rules.get("target_amount", 0))
	if duration > 0:
		parts.append(_format_duration_ui(duration))
	if target > 0:
		parts.append("%d %s" % [target, _localized_amount_label(String(rules.get("amount_label", "")))])
	if bool(rules.get("proof_required", false)):
		parts.append(GlobalEngine.loc("mission.validation_note"))
	if parts.is_empty():
		return ""
	return GlobalEngine.loc("mission.validation", [" | ".join(parts)])

func _localized_amount_label(label: String) -> String:
	if label.is_empty():
		return label
	var key := "mission.amount_label.%s" % label
	if GlobalEngine.has_loc(key):
		return GlobalEngine.loc(key)
	return label

func _format_duration_ui(seconds: int) -> String:
	var safe_seconds := maxi(0, seconds)
	var hours := int(float(safe_seconds) / 3600.0)
	var minutes := int(float(safe_seconds % 3600) / 60.0)
	var secs := safe_seconds % 60
	if hours > 0:
		return "%d:%02d:%02d" % [hours, minutes, secs]
	return "%02d:%02d" % [minutes, secs]

func _history_summary_text() -> String:
	if not GlobalEngine.has_method("get_mission_history_summary"):
		return ""
	var history: Dictionary = GlobalEngine.get_mission_history_summary()
	return GlobalEngine.loc("mission.history", [
		int(history.get("current_streak", 0)),
		int(history.get("completed_total", 0)),
		int(history.get("failed_total", 0)),
	])

func _header_summary_text() -> String:
	var history_text := _history_summary_text()
	var reward_text := _reward_cap_text()
	if history_text.is_empty():
		return reward_text
	if reward_text.is_empty():
		return history_text
	return "%s | %s" % [history_text, reward_text]

func _reward_cap_text() -> String:
	var state := _daily_reward_state()
	var consumed := int(state.get("consumed_today", state.get("rewarded_today", 0)))
	var full_limit := int(state.get("full_limit", 10))
	return GlobalEngine.loc("mission.daily_quests", [consumed, full_limit])

func _daily_reward_state() -> Dictionary:
	if not GlobalEngine.has_method("get_daily_mission_reward_state"):
		return {}
	return GlobalEngine.get_daily_mission_reward_state()

func _daily_rewards_exhausted_for(m_data) -> bool:
	if m_data == null:
		return false
	if int(m_data.type) != MissionData.MissionType.QUOTIDIENNE:
		return false
	return bool(_daily_reward_state().get("journal_only", false))

func _create_journal_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _journal_panel_style())

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var history := _history_view()
	var today := Label.new()
	today.text = GlobalEngine.loc("journal.today", [
		int(history.get("today_completed", 0)),
		int(history.get("today_failed", 0)),
	])
	today.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	today.add_theme_font_size_override("font_size", MOBILE_BODY_FONT_SIZE)
	today.add_theme_color_override("font_color", Color("#ffd166"))
	box.add_child(today)

	var recent: Array = history.get("recent", [])
	if recent.is_empty():
		var empty := Label.new()
		empty.text = GlobalEngine.loc("journal.empty")
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD
		empty.add_theme_font_size_override("font_size", MOBILE_SMALL_FONT_SIZE)
		empty.add_theme_color_override("font_color", Color(0.70, 0.74, 0.80))
		box.add_child(empty)
		return panel

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, minf(JOURNAL_MAX_HEIGHT, maxf(96.0, float(recent.size()) * 52.0)))
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(scroll)

	var entries_box := VBoxContainer.new()
	entries_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries_box.add_theme_constant_override("separation", 6)
	scroll.add_child(entries_box)

	for entry in recent:
		if entry is Dictionary:
			entries_box.add_child(_create_journal_entry(entry))

	return panel

func _create_journal_entry(entry: Dictionary) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.add_theme_stylebox_override("panel", _journal_entry_style(bool(entry.get("success", false))))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	frame.add_child(margin)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	var status := Label.new()
	status.text = "OK" if bool(entry.get("success", false)) else "KO"
	status.custom_minimum_size = Vector2(44, 0)
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", MOBILE_SMALL_FONT_SIZE)
	status.add_theme_color_override("font_color", Color("#00ff88") if bool(entry.get("success", false)) else Color("#ff6262"))
	row.add_child(status)

	var text := Label.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.autowrap_mode = TextServer.AUTOWRAP_WORD
	text.add_theme_font_size_override("font_size", MOBILE_SMALL_FONT_SIZE)
	text.add_theme_color_override("font_color", Color("#d9f7ff"))
	text.text = "%s  %s" % [_localized_journal_title(entry).to_upper(), _journal_entry_meta(entry)]
	row.add_child(text)

	return frame

func _localized_journal_title(entry: Dictionary) -> String:
	var mission_id := String(entry.get("id", ""))
	if not mission_id.is_empty():
		var key := "mission_data.%s.title" % mission_id
		if GlobalEngine.has_loc(key):
			return GlobalEngine.loc(key)
	return String(entry.get("title", "Mission"))

func _journal_entry_meta(entry: Dictionary) -> String:
	var parts: Array[String] = []
	var elapsed := int(entry.get("elapsed", 0))
	if elapsed > 0:
		parts.append(_format_duration_ui(elapsed))
	var progress := int(entry.get("progress", 0))
	if progress > 0:
		parts.append(str(progress))
	if parts.is_empty():
		return ""
	return "(" + " | ".join(parts) + ")"

func _history_view() -> Dictionary:
	if not GlobalEngine.has_method("get_mission_history_view"):
		return {}
	return GlobalEngine.get_mission_history_view(JOURNAL_RECENT_LIMIT)

func _journal_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.020, 0.030, 0.042, 0.96)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.border_color = Color(0.0, 0.63, 1.0, 0.40)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

func _header_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.014, 0.018, 0.026, 0.96)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.12, 0.18, 0.24, 0.85)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

func _timer_chip_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.022, 0.030, 0.040, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(accent.r, accent.g, accent.b, 0.40)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6
	style.content_margin_right = 6
	return style

func _journal_toggle_style(bg: Color = Color(0.022, 0.050, 0.070, 1.0)) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.0, 0.63, 1.0, 0.42)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 10
	style.content_margin_right = 10
	return style

func _journal_entry_style(success: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.010, 0.016, 0.026, 0.86)
	style.border_width_left = 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color("#00ff88") if success else Color("#ff6262")
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _get_launch_blockers(m_dict: Dictionary, m_data) -> Array[String]:
	var blockers: Array[String] = []

	if GlobalEngine.hp <= 0:
		blockers.append("HP")

	var end_cost := int(m_dict.get("end_cost", 0))
	if not GlobalEngine.is_debug_invincible() and GlobalEngine.end < end_cost:
		blockers.append("END %d/%d" % [GlobalEngine.end, end_cost])

	for stat_key in m_data.get_requirement_map().keys():
		var required := int(m_data.get_requirement_map()[stat_key])
		var current := int(GlobalEngine.get_final_stat(stat_key))
		if current < required:
			blockers.append("%s %d/%d" % [_format_stat_label(stat_key), current, required])

	return blockers

func _format_stat_label(stat_key: String) -> String:
	if stat_key == "STAMINA":
		return "END"
	return stat_key

func _missing_mission_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#14080a")
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color("#ff6262")
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_top = 12
	style.content_margin_right = 12
	style.content_margin_bottom = 12
	return style

func _process(delta: float) -> void:
	_timer_acc += delta
	if _timer_acc < 1.0:
		return

	_timer_acc = 0.0

	var daily := _main_vbox.find_child("TimerDaily", true, false)
	if daily:
		daily.text = GlobalEngine.loc("mission.daily_timer", [GlobalEngine.get_time_string()])

	var weekly := _main_vbox.find_child("TimerWeekly", true, false)
	if weekly:
		weekly.text = GlobalEngine.loc("mission.weekly_timer", [_short_weekly_time(GlobalEngine.get_weekly_time_string())])

	var history := _main_vbox.find_child("HistorySummary", true, false)
	if history:
		history.text = _history_summary_text()

	var reward_cap := _main_vbox.find_child("RewardCapSummary", true, false)
	if reward_cap:
		reward_cap.text = _reward_cap_text()

	_refresh_validation_widgets()
