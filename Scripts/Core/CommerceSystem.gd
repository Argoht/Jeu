extends Node

signal changed
signal message_requested(key: String)

const DAILY_AD_LIMIT := 3
const AD_COOLDOWN_SECONDS := 120
const AD_REWARD := 5
const DAILY_MISSION_TOKEN_LIMIT := 5
const CATALOG := [
	{"id": "classic", "color": "00bfff", "cost": 0},
	{"id": "emerald", "color": "63dfac", "cost": 20},
	{"id": "rose", "color": "ef91b5", "cost": 40},
	{"id": "sunrise", "color": "ffd16b", "cost": 60},
	{"id": "supporter", "color": "f3f1e8", "product_id": "irlleveling.supporter_frame"},
]

var tokens := 0
var owned: Array[String] = ["classic"]
var selected := "classic"
var _day := -1
var _ads_today := 0
var _mission_tokens_today := 0
var _last_ad_at := 0
var _provider: Node = null
var _pending_ad := ""
var _pending_product := ""
var _request_started := 0
var _now: Callable = func(): return int(Time.get_unix_time_from_system())

# The provider owns native consent, store verification and SDK callbacks.
# No purchase or reward is simulated in a production build.
func set_provider(provider: Node) -> void:
	if is_instance_valid(_provider) or provider == null:
		return
	for method in ["can_request_ads", "is_rewarded_ready", "show_rewarded", "is_billing_ready", "get_price", "purchase", "restore", "show_privacy_options"]:
		if not provider.has_method(method):
			push_error("Commerce provider missing method: " + method)
			return
	for event in ["availability_changed", "reward_earned", "reward_closed", "purchase_verified", "purchase_finished", "entitlements_restored"]:
		if not provider.has_signal(event):
			push_error("Commerce provider missing signal: " + event)
			return
	_provider = provider
	_provider.connect("availability_changed", _on_availability_changed)
	_provider.connect("reward_earned", _on_reward_earned)
	_provider.connect("reward_closed", _on_reward_closed)
	_provider.connect("purchase_verified", _on_purchase_verified)
	_provider.connect("purchase_finished", _on_purchase_finished)
	_provider.connect("entitlements_restored", _on_entitlements_restored)
	changed.emit()

func _process(_delta: float) -> void:
	if _request_started > 0 and Time.get_ticks_msec() - _request_started >= 120000:
		_pending_ad = ""
		_pending_product = ""
		_request_started = 0
		message_requested.emit("shop.timeout")
		changed.emit()

func _on_availability_changed() -> void:
	changed.emit()

func _refresh_day() -> void:
	var today := int(floor(float(_now.call()) / 86400.0))
	# A backward clock change must not reopen already consumed quotas.
	if today > _day:
		_day = today
		_ads_today = 0
		_mission_tokens_today = 0

func award_mission_token() -> void:
	_refresh_day()
	if _mission_tokens_today >= DAILY_MISSION_TOKEN_LIMIT:
		return
	_mission_tokens_today += 1
	tokens += 1
	changed.emit()

func get_ad_state() -> Dictionary:
	_refresh_day()
	var cooldown := maxi(0, _last_ad_at + AD_COOLDOWN_SECONDS - int(_now.call()))
	var ready := false
	if is_instance_valid(_provider):
		ready = bool(_provider.call("can_request_ads")) and bool(_provider.call("is_rewarded_ready"))
	return {"ready": ready, "remaining": maxi(0, DAILY_AD_LIMIT - _ads_today), "cooldown": cooldown,
		"available": ready and _ads_today < DAILY_AD_LIMIT and cooldown == 0 and not is_busy()}

func is_busy() -> bool:
	return not _pending_ad.is_empty() or not _pending_product.is_empty()

func request_rewarded() -> bool:
	if not bool(get_ad_state()["available"]):
		return false
	_pending_ad = Crypto.new().generate_random_bytes(16).hex_encode()
	_request_started = Time.get_ticks_msec()
	changed.emit()
	_provider.call("show_rewarded", _pending_ad)
	return true

func _on_reward_earned(request_id: String) -> void:
	if request_id.is_empty() or request_id != _pending_ad:
		return
	_refresh_day()
	_pending_ad = ""
	_request_started = 0
	if _ads_today >= DAILY_AD_LIMIT:
		changed.emit()
		return
	_ads_today += 1
	_last_ad_at = int(_now.call())
	tokens += AD_REWARD
	changed.emit()
	message_requested.emit("shop.reward_received")

func _on_reward_closed(request_id: String) -> void:
	if request_id != _pending_ad or request_id.is_empty():
		return
	_pending_ad = ""
	_request_started = 0
	changed.emit()

func unlock_or_select(id: String) -> bool:
	for entry in CATALOG:
		if String(entry["id"]) != id:
			continue
		if not owned.has(id):
			if entry.has("product_id") or tokens < int(entry["cost"]):
				return false
			tokens -= int(entry["cost"])
			owned.append(id)
		selected = id
		changed.emit()
		return true
	return false

func selected_color() -> Color:
	for entry in CATALOG:
		if String(entry["id"]) == selected:
			return Color(String(entry["color"]))
	return Color("00bfff")

func product_price(product_id: String) -> String:
	if not is_instance_valid(_provider) or not bool(_provider.call("is_billing_ready")):
		return ""
	return String(_provider.call("get_price", product_id))

func request_purchase(product_id: String) -> bool:
	if is_busy() or product_price(product_id).is_empty() or _cosmetic_for_product(product_id).is_empty():
		return false
	if owned.has(_cosmetic_for_product(product_id)):
		return false
	_pending_product = product_id
	_request_started = Time.get_ticks_msec()
	changed.emit()
	_provider.call("purchase", product_id)
	return true

func restore_purchases() -> void:
	if is_instance_valid(_provider) and bool(_provider.call("is_billing_ready")) and not is_busy():
		_pending_product = "restore"
		_request_started = Time.get_ticks_msec()
		changed.emit()
		_provider.call("restore")

func show_privacy_options() -> void:
	if is_instance_valid(_provider):
		_provider.call("show_privacy_options")

func _cosmetic_for_product(product_id: String) -> String:
	for entry in CATALOG:
		if String(entry.get("product_id", "")) == product_id and not product_id.is_empty():
			return String(entry["id"])
	return ""

func _on_purchase_verified(product_id: String) -> void:
	var id := _cosmetic_for_product(product_id)
	if id.is_empty():
		return
	if not owned.has(id):
		owned.append(id)
	if _pending_product == product_id:
		_pending_product = ""
		_request_started = 0
	changed.emit()

func _on_purchase_finished(product_id: String, status: String) -> void:
	if product_id != _pending_product:
		return
	_pending_product = ""
	_request_started = 0
	changed.emit()
	if status != "success":
		message_requested.emit("shop.purchase_" + ("pending" if status == "pending" else "cancelled"))

func _on_entitlements_restored(product_ids: Array) -> void:
	# Restoration is an authoritative snapshot, including revoked/refunded products.
	for entry in CATALOG:
		if entry.has("product_id"):
			var id := String(entry["id"])
			if product_ids.has(String(entry["product_id"])):
				if not owned.has(id):
					owned.append(id)
			else:
				owned.erase(id)
	if not owned.has(selected):
		selected = "classic"
	_pending_product = ""
	_request_started = 0
	changed.emit()

func to_dict() -> Dictionary:
	_refresh_day()
	return {"tokens": tokens, "owned": owned.duplicate(), "selected": selected, "day": _day,
		"ads_today": _ads_today, "mission_tokens_today": _mission_tokens_today, "last_ad_at": _last_ad_at}

func from_dict(data: Dictionary) -> void:
	tokens = clampi(int(data.get("tokens", 0)), 0, 1000000)
	owned = ["classic"]
	var saved_owned = data.get("owned", [])
	if saved_owned is Array:
		for entry in CATALOG:
			var id := String(entry["id"])
			if id != "classic" and saved_owned.has(id):
				owned.append(id)
	selected = String(data.get("selected", "classic"))
	if not owned.has(selected):
		selected = "classic"
	_day = int(data.get("day", -1))
	_ads_today = clampi(int(data.get("ads_today", 0)), 0, DAILY_AD_LIMIT)
	_mission_tokens_today = clampi(int(data.get("mission_tokens_today", 0)), 0, DAILY_MISSION_TOKEN_LIMIT)
	_last_ad_at = maxi(0, int(data.get("last_ad_at", 0)))
	_refresh_day()
