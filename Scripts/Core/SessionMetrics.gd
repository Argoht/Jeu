extends RefCounted

const SESSION_GAP := 1800
const DAY_LIMIT := 90
const MILESTONES := ["mission_started", "mission_completed", "item_equipped", "dungeon_started", "base_upgraded"]

var first_seen := 0
var last_seen := 0
var days: Dictionary = {}
var milestones: Dictionary = {}
var _foreground := false
var _now: Callable = func(): return int(Time.get_unix_time_from_system())

func resume() -> void:
	if _foreground:
		return
	var now := maxi(1, int(_now.call()))
	var new_session := first_seen == 0 or now - last_seen >= SESSION_GAP
	if first_seen == 0:
		first_seen = now
	_foreground = true
	heartbeat()
	if new_session:
		var key := str(int(float(maxi(now, last_seen)) / 86400.0))
		days[key] = int(days.get(key, 0)) + 1

func heartbeat() -> void:
	if not _foreground:
		return
	last_seen = maxi(last_seen, int(_now.call()))
	var key := str(int(float(last_seen) / 86400.0))
	if not days.has(key):
		days[key] = 0
	var keys := days.keys()
	keys.sort_custom(func(a, b): return int(a) < int(b))
	while keys.size() > DAY_LIMIT:
		days.erase(keys.pop_front())

func suspend() -> void:
	heartbeat()
	_foreground = false

func mark(event: String) -> void:
	if event not in MILESTONES or milestones.has(event):
		return
	heartbeat()
	if first_seen > 0:
		milestones[event] = maxi(0, last_seen - first_seen)

func to_dict() -> Dictionary:
	return {"first_seen": first_seen, "last_seen": last_seen, "days": days.duplicate(), "milestones": milestones.duplicate()}

func from_dict(data: Dictionary) -> void:
	_foreground = false
	first_seen = _number(data.get("first_seen", 0))
	last_seen = maxi(first_seen, _number(data.get("last_seen", 0)))
	days = {}
	milestones = {}
	var raw_days = data.get("days", {})
	if raw_days is Dictionary:
		for key in raw_days:
			if str(key).is_valid_int() and int(key) >= 0:
				days[str(key)] = _number(raw_days[key])
	var raw_milestones = data.get("milestones", {})
	if raw_milestones is Dictionary:
		for event in MILESTONES:
			if raw_milestones.has(event):
				milestones[event] = _number(raw_milestones[event])

func _number(value) -> int:
	if (value is int or value is float) and is_finite(float(value)):
		return maxi(0, int(value))
	return 0
