extends PanelContainer

var _body: VBoxContainer
var _balance: Label
var _ad_button: Button
var _ad_status: Label
var _status: Label
var _restore: Button
var _privacy: Button
var _rows: Array = []
var _clock := 0.0
var _scroll: ScrollContainer

func _ready() -> void:
	name = "ShopPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10151d")
	style.border_color = Color("314454")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var scroll := ScrollContainer.new()
	_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.add_theme_constant_override("scrollbar_h_separation", 12)
	margin.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)
	_add_label("shop.title", 32)
	_balance = _add_label("", 28)
	_add_label("shop.frames", 28)
	for entry in GlobalEngine.commerce_system.CATALOG:
		_build_cosmetic(entry)
	_body.add_child(HSeparator.new())
	_add_label("shop.reward_title", 28)
	_ad_status = _add_label("", 24)
	_ad_button = _button()
	_ad_button.pressed.connect(func(): GlobalEngine.commerce_system.request_rewarded())
	_body.add_child(_ad_button)
	_body.add_child(HSeparator.new())
	_restore = _button()
	_restore.pressed.connect(func(): GlobalEngine.commerce_system.restore_purchases())
	_body.add_child(_restore)
	_privacy = _button()
	_privacy.pressed.connect(func(): GlobalEngine.commerce_system.show_privacy_options())
	_body.add_child(_privacy)
	_status = _add_label("", 24)
	GlobalEngine.commerce_changed.connect(refresh)
	GlobalEngine.commerce_system.message_requested.connect(_show_message)
	refresh_locale()

func _add_label(key: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = GlobalEngine.loc(key) if not key.is_empty() else ""
	label.set_meta("locale_key", key)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(label)
	return label

func _button() -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 96)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size", 28)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("233541")
	style.border_color = Color("628596")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.content_margin_left = 12
	style.content_margin_right = 12
	button.add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = Color("345463")
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var disabled: StyleBoxFlat = style.duplicate()
	disabled.bg_color = Color("17222b")
	disabled.border_color = Color("354651")
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color("eef4f5"))
	button.add_theme_color_override("font_disabled_color", Color("96a4ae"))
	return button

func _build_cosmetic(entry: Dictionary) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_body.add_child(row)
	var preview := HBoxContainer.new()
	preview.add_theme_constant_override("separation", 12)
	row.add_child(preview)
	var swatch := PanelContainer.new()
	swatch.custom_minimum_size = Vector2(48, 48)
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("151d27")
	frame.border_color = Color(String(entry["color"]))
	frame.set_border_width_all(3)
	frame.set_corner_radius_all(6)
	swatch.add_theme_stylebox_override("panel", frame)
	preview.add_child(swatch)
	var name_label := Label.new()
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 28)
	preview.add_child(name_label)
	var button := _button()
	button.pressed.connect(_on_cosmetic_pressed.bind(entry))
	row.add_child(button)
	_rows.append({"entry": entry, "label": name_label, "button": button})

func _on_cosmetic_pressed(entry: Dictionary) -> void:
	var commerce = GlobalEngine.commerce_system
	var id := String(entry["id"])
	if commerce.owned.has(id) or not entry.has("product_id"):
		commerce.unlock_or_select(id)
	else:
		commerce.request_purchase(String(entry["product_id"]))

func refresh_locale() -> void:
	if not is_instance_valid(_body):
		return
	for child in _body.get_children():
		if child is Label:
			var key := String(child.get_meta("locale_key", ""))
			if not key.is_empty():
				child.text = GlobalEngine.loc(key)
	_status.text = ""
	refresh()

func refresh() -> void:
	if not is_instance_valid(_balance):
		return
	var commerce = GlobalEngine.commerce_system
	_balance.text = GlobalEngine.loc("shop.balance", [commerce.tokens])
	for row in _rows:
		var entry: Dictionary = row["entry"]
		var id := String(entry["id"])
		var button: Button = row["button"]
		row["label"].text = GlobalEngine.loc("shop.frame." + id)
		button.disabled = commerce.is_busy()
		if commerce.selected == id:
			button.text = GlobalEngine.loc("shop.equipped")
			button.disabled = true
		elif commerce.owned.has(id):
			button.text = GlobalEngine.loc("shop.equip")
		elif entry.has("product_id"):
			var price: String = commerce.product_price(String(entry["product_id"]))
			button.text = GlobalEngine.loc("shop.buy", [price]) if not price.is_empty() else GlobalEngine.loc("shop.store_unavailable")
			button.disabled = button.disabled or price.is_empty()
		else:
			button.text = GlobalEngine.loc("shop.unlock", [int(entry["cost"])])
			button.disabled = button.disabled or commerce.tokens < int(entry["cost"])
	var ad: Dictionary = commerce.get_ad_state()
	_ad_button.text = GlobalEngine.loc("shop.watch", [commerce.AD_REWARD])
	_ad_button.disabled = not bool(ad["available"])
	if int(ad["remaining"]) == 0:
		_ad_status.text = GlobalEngine.loc("shop.ad_limit")
	elif int(ad["cooldown"]) > 0:
		_ad_status.text = GlobalEngine.loc("shop.cooldown", [int(ad["cooldown"])])
	elif not bool(ad["ready"]):
		_ad_status.text = GlobalEngine.loc("shop.ad_unavailable")
	else:
		_ad_status.text = GlobalEngine.loc("shop.ad_remaining", [int(ad["remaining"])])
	_restore.text = GlobalEngine.loc("shop.restore")
	_restore.disabled = commerce.product_price("irlleveling.supporter_frame").is_empty() or commerce.is_busy()
	_privacy.text = GlobalEngine.loc("shop.privacy")
	_privacy.disabled = not is_instance_valid(commerce._provider)

func _show_message(key: String) -> void:
	_status.text = GlobalEngine.loc(key)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	if _clock >= 1.0:
		_clock = 0.0
		refresh()
