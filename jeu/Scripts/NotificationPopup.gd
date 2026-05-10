extends CanvasLayer

var _queue: Array = []
var _showing: bool = false

func _ready():
	layer = 10

func notify_xp(amount: int):
	_enqueue("+ %d XP" % amount, Color("#00ff99"), false)

func notify_level_up(new_level: int):
	_enqueue("LEVEL UP !\nNiveau %d  —  +3 Points de Stats" % new_level, Color("#ffd700"), true)

func _enqueue(text: String, color: Color, big: bool):
	_queue.append({"text": text, "color": color, "big": big})
	_flush()

func _flush():
	if _showing or _queue.is_empty(): return
	_showing = true
	_show(_queue.pop_front())

func _show(data: Dictionary):
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.12, 0.93)
	style.border_width_left = 2; style.border_width_top = 2
	style.border_width_right = 2; style.border_width_bottom = 2
	style.border_color = data.color
	style.corner_radius_top_left = 8; style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	style.shadow_color = Color(data.color.r, data.color.g, data.color.b, 0.3)
	style.shadow_size = 6
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)

	var label = Label.new()
	label.text = data.text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", data.color)
	label.add_theme_font_size_override("font_size", 22 if data.big else 16)

	margin.add_child(label)
	panel.add_child(margin)
	add_child(panel)

	await get_tree().process_frame

	var vp = get_viewport().get_visible_rect().size
	panel.position = Vector2((vp.x - panel.size.x) / 2.0, -panel.size.y - 10)
	panel.modulate.a = 0.0

	var t_in = create_tween().set_parallel(true)
	t_in.tween_property(panel, "position:y", 50.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t_in.tween_property(panel, "modulate:a", 1.0, 0.25)
	await t_in.finished

	await get_tree().create_timer(3.0 if data.big else 2.0).timeout

	var t_out = create_tween().set_parallel(true)
	t_out.tween_property(panel, "position:y", -panel.size.y - 10, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	t_out.tween_property(panel, "modulate:a", 0.0, 0.35)
	await t_out.finished

	panel.queue_free()
	_showing = false
	_flush()
