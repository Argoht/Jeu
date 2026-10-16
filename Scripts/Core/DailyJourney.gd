extends Node

signal changed

const STEP_REWARDS := [2, 3, 5]
const STEP_INTERVAL := 2 * 3600

var _day := -1
var _steps := 0
var _next_step_at := 0
var _pending_tokens := 0
var _seen_floors: Array[String] = []
var _now: Callable = func(): return int(Time.get_unix_time_from_system())

func _refresh_day() -> void:
	var today := int(floor(float(_now.call()) / 86400.0))
	if today > _day:
		_day = today
		_steps = 0
		_next_step_at = 0
		_seen_floors.clear()
		# Earned rewards survive the daily reset until collected.

func record_mission() -> bool:
	return _record_activity()

func record_floor(rank: String, floor_number: int) -> bool:
	_refresh_day()
	if not ["F", "E", "D", "C", "B", "A", "S"].has(rank) or floor_number < 1 or floor_number > 100:
		return false
	var key := "%s:%d" % [rank, floor_number]
	if _seen_floors.has(key):
		return false
	# Replaying a callback after the cooldown cannot turn an old victory into progress.
	_seen_floors.append(key)
	return _record_activity()

func _record_activity() -> bool:
	_refresh_day()
	var now := int(_now.call())
	if _steps >= STEP_REWARDS.size() or now < _next_step_at:
		return false
	_pending_tokens += int(STEP_REWARDS[_steps])
	_steps += 1
	_next_step_at = now + STEP_INTERVAL
	changed.emit()
	return true

func get_state() -> Dictionary:
	_refresh_day()
	return {"steps": _steps, "total": STEP_REWARDS.size(), "pending_tokens": _pending_tokens,
		"wait_seconds": maxi(0, _next_step_at - int(_now.call())) if _steps < STEP_REWARDS.size() else 0,
		"complete": _steps >= STEP_REWARDS.size()}

# The orchestrator credits the wallet before emitting any save-triggering signals.
func take_reward() -> int:
	var amount := _pending_tokens
	_pending_tokens = 0
	return amount

func to_dict() -> Dictionary:
	_refresh_day()
	return {"day": _day, "steps": _steps, "next_step_at": _next_step_at,
		"pending_tokens": _pending_tokens, "seen_floors": _seen_floors.duplicate()}

func from_dict(data: Dictionary) -> void:
	_day = int(data.get("day", -1))
	_steps = clampi(int(data.get("steps", 0)), 0, STEP_REWARDS.size())
	_next_step_at = maxi(0, int(data.get("next_step_at", 0)))
	_pending_tokens = clampi(int(data.get("pending_tokens", 0)), 0, 1000000)
	_seen_floors.clear()
	var raw = data.get("seen_floors", [])
	if raw is Array:
		for entry in raw.slice(0, 700):
			if entry is String and not _seen_floors.has(entry):
				_seen_floors.append(entry)
	_refresh_day()
