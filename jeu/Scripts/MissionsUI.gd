extends MarginContainer

var _main_vbox: VBoxContainer
var _daily_vbox: VBoxContainer
var _timer_acc: float = 0.0

func _ready():
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("margin_left", 12)
	add_theme_constant_override("margin_right", 12)
	add_theme_constant_override("margin_bottom", 20)

	_main_vbox = VBoxContainer.new()
	_main_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_vbox.add_theme_constant_override("separation", 14)
	add_child(_main_vbox)

	GlobalEngine.missions_changed.connect(_build_static_ui)
	_build_static_ui()

func _build_static_ui():
	for child in _main_vbox.get_children(): child.queue_free()

	# Timers
	var t_daily = Label.new()
	t_daily.name = "TimerDaily"
	t_daily.text = "↻ Quotidien : " + GlobalEngine.get_time_string()
	t_daily.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_daily.add_theme_color_override("font_color", Color("#00f2ff"))
	t_daily.add_theme_font_size_override("font_size", 13)
	_main_vbox.add_child(t_daily)

	var t_weekly = Label.new()
	t_weekly.name = "TimerWeekly"
	t_weekly.text = "↻ Hebdo : " + GlobalEngine.get_weekly_time_string()
	t_weekly.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_weekly.add_theme_color_override("font_color", Color("#d15cff"))
	t_weekly.add_theme_font_size_override("font_size", 13)
	_main_vbox.add_child(t_weekly)

	# Section quotidienne avec son propre scroll
	_add_section_header("MISSIONS QUOTIDIENNES", Color("#00f2ff"))

	var daily_scroll = ScrollContainer.new()
	daily_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	daily_scroll.custom_minimum_size = Vector2(0, 390)
	daily_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_vbox.add_child(daily_scroll)

	_daily_vbox = VBoxContainer.new()
	_daily_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_daily_vbox.add_theme_constant_override("separation", 10)
	daily_scroll.add_child(_daily_vbox)

	_refresh_daily_cards()

	# Section hebdomadaire fixe en bas
	_add_section_header("MISSION HEBDOMADAIRE", Color("#d15cff"))

	if GlobalEngine.available_weekly_missions.is_empty():
		var empty = Label.new()
		empty.text = "Aucun défi cette semaine."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color("#555555"))
		_main_vbox.add_child(empty)
	else:
		for m in GlobalEngine.available_weekly_missions:
			_main_vbox.add_child(_create_card(m, true))

func _refresh_daily_cards():
	for child in _daily_vbox.get_children(): child.queue_free()

	if GlobalEngine.available_missions.is_empty():
		var empty = Label.new()
		empty.text = "Missions épuisées."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color("#555555"))
		_daily_vbox.add_child(empty)
	else:
		for m in GlobalEngine.available_missions:
			_daily_vbox.add_child(_create_card(m, false))

func _add_section_header(text: String, color: Color):
	_main_vbox.add_child(HSeparator.new())
	var l = Label.new()
	l.text = "— " + text + " —"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 13)
	_main_vbox.add_child(l)

func _create_card(m_dict: Dictionary, is_weekly: bool) -> PanelContainer:
	var m_data = GlobalEngine.all_missions.get(m_dict.id)
	var card = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if not m_data:
		return card

	var s = StyleBoxFlat.new()
	s.bg_color = Color("#0a1018")
	s.border_width_left = 2; s.border_width_top = 2
	s.border_width_right = 2; s.border_width_bottom = 2
	s.corner_radius_top_left = 10; s.corner_radius_top_right = 10
	s.corner_radius_bottom_left = 10; s.corner_radius_bottom_right = 10

	if m_dict.status == "in_progress":
		s.border_color = Color("#ffaa00")
		s.shadow_color = Color(1.0, 0.67, 0.0, 0.25)
		s.shadow_size = 6
	elif m_dict.status in ["completed", "failed"]:
		s.border_color = Color("#2a2a2a")
	else:
		var bc = Color("#00f2ff") if not is_weekly else Color("#d15cff")
		s.border_color = bc
		s.shadow_color = Color(bc.r, bc.g, bc.b, 0.18)
		s.shadow_size = 5

	card.add_theme_stylebox_override("panel", s)

	var mar = MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		mar.add_theme_constant_override(side, 12)

	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 7)

	var title = Label.new()
	title.text = m_data.title.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#00f2ff") if not is_weekly else Color("#d15cff"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(title)

	var desc = Label.new()
	desc.text = m_data.description
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.68, 0.68, 0.68))
	v.add_child(desc)

	var stat_names = ["", "STR", "DEX", "VIT", "INT", "WIS", "CHA", "PER", "WIL"]
	var rew_txt = "+" + str(m_data.base_xp) + " XP"
	if m_data.reward_stat != 0:
		rew_txt += "  +" + str(m_data.reward_stat_amount) + " " + stat_names[m_data.reward_stat]
	var rew = Label.new()
	rew.text = rew_txt
	rew.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rew.add_theme_font_size_override("font_size", 11)
	rew.add_theme_color_override("font_color", Color("#00ff88"))
	v.add_child(rew)

	var btns = VBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)

	match m_dict.status:
		"available":
			if GlobalEngine.hp <= 0:
				var b = Button.new()
				b.text = "TROP BLESSÉ"
				b.disabled = true
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.add_theme_color_override("font_color", Color("#ff4444"))
				btns.add_child(b)
			else:
				var b = Button.new()
				b.text = "LANCER — %d END" % m_dict.end_cost
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.pressed.connect(func(): if GlobalEngine.accept_mission(m_dict): _refresh_daily_cards())
				btns.add_child(b)
		"in_progress":
			var f = Button.new()
			f.text = "ÉCHEC"
			f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			f.add_theme_color_override("font_color", Color("#ff4444"))
			f.pressed.connect(func(): GlobalEngine.process_mission_result(m_dict, false); _refresh_daily_cards())
			var r = Button.new()
			r.text = "RÉUSSITE"
			r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_theme_color_override("font_color", Color("#00ff88"))
			r.pressed.connect(func(): GlobalEngine.process_mission_result(m_dict, true); _refresh_daily_cards())
			btns.add_child(f)
			btns.add_child(r)
		_:
			var lbl = Label.new()
			lbl.text = "◉ " + m_dict.status.to_upper()
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 12)
			lbl.add_theme_color_override("font_color", Color("#3a3a3a"))
			btns.add_child(lbl)

	v.add_child(btns)
	mar.add_child(v)
	card.add_child(mar)
	return card

func _process(delta):
	_timer_acc += delta
	if _timer_acc < 1.0: return
	_timer_acc = 0.0
	var d = _main_vbox.get_node_or_null("TimerDaily")
	if d: d.text = "↻ Quotidien : " + GlobalEngine.get_time_string()
	var w = _main_vbox.get_node_or_null("TimerWeekly")
	if w: w.text = "↻ Hebdo : " + GlobalEngine.get_weekly_time_string()
