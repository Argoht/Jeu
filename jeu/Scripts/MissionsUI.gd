extends MarginContainer

@onready var mission_vbox = VBoxContainer.new()

func _ready():
	add_theme_constant_override("margin_left", 20)
	add_theme_constant_override("margin_right", 20)
	add_theme_constant_override("margin_bottom", 30)
	add_child(mission_vbox)
	mission_vbox.add_theme_constant_override("separation", 20)
	_display_missions_list()

func _display_missions_list():
	for child in mission_vbox.get_children(): child.queue_free()

	# --- TIMERS HARMONISÉS ---
	var t_daily = Label.new()
	t_daily.name = "TimerDaily"
	t_daily.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_daily.add_theme_color_override("font_color", Color("#00f2ff"))
	# Taille standardisée
	t_daily.add_theme_font_size_override("font_size", 14) 
	mission_vbox.add_child(t_daily)

	var t_weekly = Label.new()
	t_weekly.name = "TimerWeekly"
	t_weekly.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_weekly.add_theme_color_override("font_color", Color("#d15cff"))
	# MÊME TAILLE QUE LE QUOTIDIEN
	t_weekly.add_theme_font_size_override("font_size", 14) 
	mission_vbox.add_child(t_weekly)

	# --- SECTIONS ---
	_add_header("MISSIONS QUOTIDIENNES", Color("#00f2ff"))
	for m in GlobalEngine.available_missions:
		mission_vbox.add_child(_create_card(m, false))

	_add_header("MISSION HEBDOMADAIRE", Color("#d15cff"))
	if GlobalEngine.available_weekly_missions.is_empty():
		var empty = Label.new()
		empty.text = "Aucun défi cette semaine."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mission_vbox.add_child(empty)
	else:
		for m in GlobalEngine.available_weekly_missions:
			mission_vbox.add_child(_create_card(m, true))

func _add_header(t, c):
	var sep = HSeparator.new()
	mission_vbox.add_child(sep)
	var l = Label.new()
	l.text = "--- " + t + " ---"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", c)
	mission_vbox.add_child(l)

func _create_card(m_dict, is_weekly):
	var m_data = GlobalEngine.all_missions.get(m_dict.id)
	if not m_data: return Control.new()

	var card = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color("#0c1520")
	s.border_width_left = 2; s.border_width_top = 2; s.border_width_right = 2; s.border_width_bottom = 2
	s.corner_radius_top_left = 8; s.corner_radius_top_right = 8; s.corner_radius_bottom_left = 8; s.corner_radius_bottom_right = 8
	
	if m_dict.status == "in_progress": s.border_color = Color("#ffaa00")
	elif m_dict.status in ["completed", "failed"]: s.border_color = Color("#333333")
	else: s.border_color = Color("#00f2ff") if not is_weekly else Color("#d15cff")
	
	card.add_theme_stylebox_override("panel", s)

	var v = VBoxContainer.new()
	var mar = MarginContainer.new(); mar.add_theme_constant_override("margin_all", 15)
	
	var title = Label.new()
	title.text = m_data.title.to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#00f2ff") if not is_weekly else Color("#d15cff"))
	title.add_theme_font_size_override("font_size", 16)
	v.add_child(title)

	var desc = Label.new()
	desc.text = m_data.description
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(desc)

	var rew = Label.new()
	var stat_names = ["", "STR", "DEX", "VIT", "INT", "WIS", "CHA", "PER", "WIL"]
	var rew_txt = "[ +" + str(m_data.base_xp) + " XP"
	if m_data.reward_stat != 0: rew_txt += " | +" + str(m_data.reward_stat_amount) + " " + stat_names[m_data.reward_stat]
	rew.text = rew_txt + " ]"
	rew.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rew.add_theme_font_size_override("font_size", 11)
	rew.add_theme_color_override("font_color", Color("#00ff99"))
	v.add_child(rew)

	var btns = HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 20)
	
	if m_dict.status == "available":
		var b = Button.new(); b.text = "S'ENGAGER (" + str(m_dict.end_cost) + " END)"
		b.pressed.connect(func(): if GlobalEngine.accept_mission(m_dict): _display_missions_list())
		btns.add_child(b)
	elif m_dict.status == "in_progress":
		var f = Button.new(); f.text = "ÉCHEC"; f.add_theme_color_override("font_color", Color("#ff4444"))
		f.pressed.connect(func(): GlobalEngine.process_mission_result(m_dict, false); _display_missions_list())
		var r = Button.new(); r.text = "RÉUSSITE"; r.add_theme_color_override("font_color", Color("#00ff99"))
		r.pressed.connect(func(): GlobalEngine.process_mission_result(m_dict, true); _display_missions_list())
		btns.add_child(f); btns.add_child(r)
	else:
		var l = Label.new(); l.text = "MISSION " + m_dict.status.to_upper()
		l.add_theme_color_override("font_color", Color("#777777"))
		btns.add_child(l)

	v.add_child(btns); mar.add_child(v); card.add_child(mar)
	return card

func _process(_delta):
	var d = mission_vbox.get_node_or_null("TimerDaily")
	if d: d.text = "RESET QUOTIDIEN : " + GlobalEngine.get_time_string()
	var w = mission_vbox.get_node_or_null("TimerWeekly")
	if w: w.text = "RESET HEBDO : " + GlobalEngine.get_weekly_time_string()
