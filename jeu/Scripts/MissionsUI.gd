extends MarginContainer

var _vbox: VBoxContainer
var _timer_acc: float = 0.0


func _ready():
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("margin_left", 12)
	add_theme_constant_override("margin_right", 12)
	add_theme_constant_override("margin_bottom", 20)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(_vbox)

	_display_missions_list()

func _display_missions_list():
	for child in _vbox.get_children(): child.queue_free()

	var t_daily = Label.new()
	t_daily.name = "TimerDaily"
	t_daily.text = "↻ Quotidien : " + GlobalEngine.get_time_string()
	t_daily.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_daily.add_theme_color_override("font_color", Color("#00f2ff"))
	t_daily.add_theme_font_size_override("font_size", 13)
	_vbox.add_child(t_daily)

	var t_weekly = Label.new()
	t_weekly.name = "TimerWeekly"
	t_weekly.text = "↻ Hebdo : " + GlobalEngine.get_weekly_time_string()
	t_weekly.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_weekly.add_theme_color_override("font_color", Color("#d15cff"))
	t_weekly.add_theme_font_size_override("font_size", 13)
	_vbox.add_child(t_weekly)

	_add_section_header("MISSIONS QUOTIDIENNES", Color("#00f2ff"))
	if GlobalEngine.available_missions.is_empty():
		var empty = Label.new()
		empty.text = "Missions épuisées."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color("#555555"))
		_vbox.add_child(empty)
	else:
		for m in GlobalEngine.available_missions:
			_vbox.add_child(_create_card(m, false, 0))

	_add_section_header("MISSION HEBDOMADAIRE", Color("#d15cff"))
	if GlobalEngine.available_weekly_missions.is_empty():
		var empty = Label.new()
		empty.text = "Aucun défi cette semaine."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", Color("#555555"))
		_vbox.add_child(empty)
	else:
		for m in GlobalEngine.available_weekly_missions:
			_vbox.add_child(_create_card(m, true, 0))


func _add_section_header(text: String, color: Color):
	_vbox.add_child(HSeparator.new())
	var l = Label.new()
	l.text = "— " + text + " —"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", 13)
	_vbox.add_child(l)

func _create_card(m_dict: Dictionary, is_weekly: bool, card_width: int) -> PanelContainer:
	var m_data = GlobalEngine.all_missions.get(m_dict.id)
	var card = PanelContainer.new()
	if card_width > 0:
		card.custom_minimum_size = Vector2(card_width, 0)
	else:
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
				b.pressed.connect(func(): if GlobalEngine.accept_mission(m_dict): _display_missions_list())
				btns.add_child(b)
		"in_progress":
			var f = Button.new()
			f.text = "ÉCHEC"
			f.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			f.add_theme_color_override("font_color", Color("#ff4444"))
			f.pressed.connect(func(): GlobalEngine.process_mission_result(m_dict, false); _display_missions_list())
			var r = Button.new()
			r.text = "RÉUSSITE"
			r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			r.add_theme_color_override("font_color", Color("#00ff88"))
			r.pressed.connect(func(): GlobalEngine.process_mission_result(m_dict, true); _display_missions_list())
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
	var d = _vbox.get_node_or_null("TimerDaily")
	if d: d.text = "↻ Quotidien : " + GlobalEngine.get_time_string()
	var w = _vbox.get_node_or_null("TimerWeekly")
	if w: w.text = "↻ Hebdo : " + GlobalEngine.get_weekly_time_string()
