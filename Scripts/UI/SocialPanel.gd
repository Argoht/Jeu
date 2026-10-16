extends PanelContainer

var _body: VBoxContainer
var _title: Label
var _profile: Label
var _summary: Label
var _availability: Label
var _copy: Button
var _status: Label

func _ready() -> void:
	name = "SocialPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10151d")
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	add_theme_stylebox_override("panel", style)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 24)
	scroll.add_child(_body)
	_title = _label(32, Color("f6da8f"))
	_profile = _label(30, Color("e5eef5"))
	_body.add_child(HSeparator.new())
	_summary = _label(28, Color("aee8d0"))
	_copy = Button.new()
	_copy.custom_minimum_size = Vector2(0, 96)
	_copy.add_theme_font_size_override("font_size", 28)
	_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_copy.pressed.connect(_copy_summary)
	_body.add_child(_copy)
	_status = _label(24, Color("aee8d0"))
	_body.add_child(HSeparator.new())
	_availability = _label(24, Color("b8c7d6"))
	GlobalEngine.missions_changed.connect(refresh)
	GlobalEngine.stats_updated.connect(refresh)
	refresh_locale()

func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_body.add_child(label)
	return label

func refresh_locale() -> void:
	_title.text = GlobalEngine.loc("social.title")
	_copy.text = GlobalEngine.loc("social.copy")
	_availability.text = GlobalEngine.loc("social.offline")
	refresh()

func refresh() -> void:
	if not is_instance_valid(_profile):
		return
	_profile.text = GlobalEngine.player_name + "\n" + GlobalEngine.loc("social.rank", [GlobalEngine.lvl, GlobalEngine.get_rank_by_level(GlobalEngine.lvl)])
	_summary.text = _progress_text()
	_status.text = ""
	_status.hide()

func _progress_text() -> String:
	var history := GlobalEngine.get_mission_history_summary()
	return GlobalEngine.loc("social.progress", [int(history.get("completed_total", 0)), int(history.get("best_streak", 0))])

func share_text() -> String:
	return "IRL Leveling\n%s\n%s\n%s" % [GlobalEngine.player_name, GlobalEngine.loc("social.rank", [GlobalEngine.lvl, GlobalEngine.get_rank_by_level(GlobalEngine.lvl)]), _progress_text()]

func _copy_summary() -> void:
	DisplayServer.clipboard_set(share_text())
	_status.text = GlobalEngine.loc("social.copied")
	_status.show()
