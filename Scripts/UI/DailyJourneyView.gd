extends VBoxContainer

var _progress: Label
var _state: Label
var _claim: Button
var _bars: Array[ProgressBar] = []
var _elapsed := 0.0

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_progress = Label.new()
	_progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_progress.add_theme_font_size_override("font_size", 28)
	_progress.add_theme_color_override("font_color", Color("f6da8f"))
	add_child(_progress)
	var bar_row := HBoxContainer.new()
	bar_row.add_theme_constant_override("separation", 8)
	add_child(bar_row)
	for i in range(3):
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 12)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.show_percentage = false
		bar.max_value = 1
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("66d6ab")
		bar.add_theme_stylebox_override("fill", fill)
		bar_row.add_child(bar)
		_bars.append(bar)
	_state = Label.new()
	_state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_state.add_theme_font_size_override("font_size", 24)
	add_child(_state)
	_claim = Button.new()
	_claim.custom_minimum_size = Vector2(0, 96)
	_claim.add_theme_font_size_override("font_size", 28)
	_claim.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_claim.pressed.connect(func(): GlobalEngine.claim_journey_reward())
	add_child(_claim)
	GlobalEngine.journey_changed.connect(refresh)
	GlobalEngine.language_changed.connect(func(_locale: String): refresh())
	refresh()

func refresh() -> void:
	if not is_instance_valid(_progress):
		return
	var state: Dictionary = GlobalEngine.daily_journey.get_state()
	_progress.text = GlobalEngine.loc("journey.title", [int(state["steps"]), int(state["total"])])
	for i in range(_bars.size()):
		_bars[i].value = 1 if i < int(state["steps"]) else 0
	if bool(state["complete"]):
		_state.text = GlobalEngine.loc("journey.complete")
	elif int(state["wait_seconds"]) > 0:
		var seconds := int(state["wait_seconds"])
		_state.text = GlobalEngine.loc("journey.next", [seconds / 3600, (seconds % 3600) / 60, seconds % 60])
	else:
		_state.text = GlobalEngine.loc("journey.ready")
	_claim.visible = int(state["pending_tokens"]) > 0
	_claim.text = GlobalEngine.loc("journey.claim", [int(state["pending_tokens"])])

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_elapsed += delta
	if _elapsed >= 1.0:
		_elapsed = 0.0
		refresh()
