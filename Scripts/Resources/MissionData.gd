class_name MissionData
extends Resource

## Énumérations pour structurer les données proprement
enum Rank { F, E, D, C, B, A, S }
enum MissionType { QUOTIDIENNE, HEBDOMADAIRE }
enum Stat { AUCUNE, STR, DEX, VIT, INT, WIS, CHA, PER, WIL }
enum ValidationMode { AUTO, SIMPLE, TIMER, AMOUNT, TIMER_AND_AMOUNT, PROOF }

@export_category("Informations Générales")
@export var id: String = "mission_001"
@export var title: String = "New Mission"
@export_multiline var description: String = "IRL task description..."
@export var rank: Rank = Rank.F
@export var type: MissionType = MissionType.QUOTIDIENNE

@export_category("Pré-requis des Statistiques")
@export var req_str: int = 0
@export var req_dex: int = 0
@export var req_end: int = 0
@export var req_int: int = 0
@export var req_wis: int = 0
@export var req_cha: int = 0
@export var req_per: int = 0
@export var req_wil: int = 0

@export_category("Récompenses de Base")
@export var base_xp: int = 50
@export var reward_stat: Stat = Stat.AUCUNE
@export var reward_stat_amount: int = 0

@export_category("Validation IRL")
@export var validation_mode: ValidationMode = ValidationMode.AUTO
@export var min_duration_seconds: int = 0
@export var target_amount: int = 0
@export var amount_label: String = ""
@export var proof_required: bool = false
@export var failure_penalty_hp: int = 0

const MODE_SIMPLE := "simple"
const MODE_TIMER := "timer"
const MODE_AMOUNT := "amount"
const MODE_TIMER_AMOUNT := "timer_amount"
const MODE_PROOF := "proof"

const _DAILY_MINUTES_BY_RANK: Array[int] = [3, 5, 8, 12, 18, 25, 35]
const _WEEKLY_MINUTES_BY_RANK: Array[int] = [20, 30, 45, 60, 90, 120, 180]

func get_requirement_map() -> Dictionary:
	return StatTypes.normalize_requirements({
		"STR": req_str,
		"AGI": req_dex,
		"STAMINA": req_end,
		"INT": req_int,
		"wis": req_wis,
		"cha": req_cha,
		"per": req_per,
		"WIL": req_wil,
	})

func get_reward_stat_key() -> String:
	match reward_stat:
		Stat.STR:
			return StatTypes.KEY_STR
		Stat.DEX:
			return StatTypes.KEY_AGI
		Stat.VIT:
			return StatTypes.KEY_HP
		Stat.INT:
			return StatTypes.KEY_INT
		Stat.WIS, Stat.CHA, Stat.PER, Stat.WIL:
			return StatTypes.KEY_WIL
	return ""

func get_base_xp_reward() -> int:
	return _round_xp_value(base_xp)

func get_validation_rules() -> Dictionary:
	if validation_mode == ValidationMode.AUTO:
		return _infer_validation_rules()

	var mode_key := _mode_key(validation_mode)
	return _make_validation_rules(
		mode_key,
		maxi(0, min_duration_seconds),
		maxi(0, target_amount),
		amount_label,
		proof_required or mode_key == MODE_PROOF
	)

func get_failure_penalty_hp() -> int:
	if failure_penalty_hp > 0:
		return failure_penalty_hp
	var rank_i := int(rank)
	var weekly_bonus := 12 if int(type) == MissionType.HEBDOMADAIRE else 0
	return 10 + rank_i * 5 + weekly_bonus

func _infer_validation_rules() -> Dictionary:
	var text := ("%s %s" % [title, description]).to_lower()
	var duration := _extract_duration_seconds(text)
	var amount_info := _extract_amount_info(text)
	var amount_target := int(amount_info.get("target", 0))
	var label := String(amount_info.get("label", ""))
	var mode_key := MODE_TIMER

	if duration <= 0:
		duration = _default_min_duration_seconds()

	if amount_target > 0 and duration > 0:
		mode_key = MODE_TIMER_AMOUNT
	elif amount_target > 0:
		mode_key = MODE_AMOUNT
	elif duration > 0:
		mode_key = MODE_TIMER
	else:
		mode_key = MODE_SIMPLE

	var needs_proof := _auto_requires_proof(text)
	return _make_validation_rules(mode_key, duration, amount_target, label, needs_proof)

func _make_validation_rules(mode_key: String, duration: int, amount_target: int, label: String, needs_proof: bool) -> Dictionary:
	if mode_key == MODE_PROOF:
		needs_proof = true
	if label.is_empty() and amount_target > 0:
		label = "actions"

	return {
		"mode": mode_key,
		"min_duration_seconds": duration,
		"target_amount": amount_target,
		"amount_label": label,
		"amount_step": _amount_step(amount_target),
		"proof_required": needs_proof,
		"failure_penalty_hp": get_failure_penalty_hp(),
	}

func _mode_key(mode: int) -> String:
	match mode:
		ValidationMode.SIMPLE:
			return MODE_SIMPLE
		ValidationMode.TIMER:
			return MODE_TIMER
		ValidationMode.AMOUNT:
			return MODE_AMOUNT
		ValidationMode.TIMER_AND_AMOUNT:
			return MODE_TIMER_AMOUNT
		ValidationMode.PROOF:
			return MODE_PROOF
	return MODE_SIMPLE

func _default_min_duration_seconds() -> int:
	var rank_i := clampi(int(rank), 0, Rank.S)
	var minutes := _DAILY_MINUTES_BY_RANK[rank_i]
	if int(type) == MissionType.HEBDOMADAIRE:
		minutes = _WEEKLY_MINUTES_BY_RANK[rank_i]
	return minutes * 60

func _auto_requires_proof(text: String) -> bool:
	if proof_required:
		return true
	if int(rank) >= Rank.A and int(type) == MissionType.HEBDOMADAIRE:
		return true
	if base_xp >= 10000:
		return true
	for marker in ["plan", "coaching", "habitudes", "defi", "extreme", "apotheose"]:
		if text.contains(marker):
			return true
	return false

func _extract_duration_seconds(text: String) -> int:
	var minutes := _regex_int(text, "(\\d+)\\s*(?:min|minute|minutes)")
	var hours := _regex_int(text, "(\\d+)\\s*(?:h|heure|heures)")
	var seconds := 0
	if minutes > 0:
		seconds = maxi(seconds, minutes * 60)
	if hours > 0:
		seconds = maxi(seconds, hours * 3600)
	return seconds

func _extract_amount_info(text: String) -> Dictionary:
	var km := _regex_int(text, "(\\d+)\\s*(?:km|kilometre|kilometres)")
	if km > 0:
		return {"target": km, "label": "km"}

	for keyword in ["pompes", "squats", "burpees", "tractions", "abdos"]:
		var reps := _regex_int(text, "(\\d+)\\s*" + keyword)
		if reps > 0:
			return {"target": reps, "label": "reps"}

	var steps := _regex_int(text, "(\\d+)\\s*pas")
	if steps > 0:
		return {"target": steps, "label": "pas"}

	var pages := _regex_int(text, "(\\d+)\\s*pages")
	if pages > 0:
		return {"target": pages, "label": "pages"}

	return {"target": 0, "label": ""}

func _regex_int(text: String, pattern: String) -> int:
	var regex := RegEx.new()
	if regex.compile(pattern) != OK:
		return 0
	var result := regex.search(text)
	if result == null:
		return 0
	return int(result.get_string(1))

func _amount_step(target: int) -> int:
	if target >= 1000:
		return 100
	if target >= 100:
		return 10
	if target >= 30:
		return 5
	return 1

func _round_xp_value(value: int) -> int:
	if value <= 0:
		return 0
	var step := 50
	if value >= 10000:
		step = 500
	elif value >= 1000:
		step = 100
	return maxi(step, int(round(float(value) / float(step))) * step)
