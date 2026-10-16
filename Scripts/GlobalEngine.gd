extends Node

## Thin orchestrator — creates subsystems, wires their signals and exposes a
## backward-compatible surface so existing UI scripts need no changes.
##
## Subsystems are loaded via preload() to guarantee compilation order
## (autoloads are parsed before the global class_name registry is fully built).

# ── Signals (re-emitted from subsystems for backward compat) ──────────────────

signal stats_updated
signal leveled_up(new_level: int)
signal xp_gained(amount: int)
signal mission_completed(xp_amount: int, stat_name: String, stat_amount: int)
signal mission_failed(hp_lost: int)
signal missions_changed
signal inventory_changed
signal dungeon_changed
signal base_changed
signal language_changed(locale: String)
signal commerce_changed
signal save_status_changed(saved: bool)
signal journey_changed

# ── Subsystems ────────────────────────────────────────────────────────────────
# Untyped: autoloads are parsed before the global class_name registry is built,
# so the Core class_names aren't resolvable as types here.
# Runtime types: PlayerData, MissionManager, SaveSystem, InventorySystem.

var player_data      = null
var mission_manager  = null
var save_system      = null
var inventory_system = null
var dungeon_system   = null
var base_manager     = null
var commerce_system = null
var daily_journey = null
var session_metrics = preload("res://Scripts/Core/SessionMetrics.gd").new()
var _metrics_elapsed := 0.0
var _suspended_at: float = 0.0
var _localization = preload("res://Scripts/Core/Localization.gd").new()
var _language_code: String = "en"

const SFX_CLANKS: Array[String] = [
	"res://Assets/Audio/SFX/clank_1.mp3",
	"res://Assets/Audio/SFX/clank_2.mp3",
	"res://Assets/Audio/SFX/clank_3.mp3",
]
const SFX_MENU_CHOICE := "res://Assets/Audio/SFX/menu_choice.mp3"
const SFX_LEVEL_UP_SOFT := "res://Assets/Audio/SFX/level_up_soft.mp3"
const SFX_BEAST_VOICES: Array[String] = [
	"res://Assets/Audio/SFX/Beasts/beast_growl_1.wav",
	"res://Assets/Audio/SFX/Beasts/beast_growl_2.wav",
	"res://Assets/Audio/SFX/Beasts/beast_growl_3.wav",
	"res://Assets/Audio/SFX/Beasts/beast_voice_1.wav",
	"res://Assets/Audio/SFX/Beasts/beast_voice_2.wav",
	"res://Assets/Audio/SFX/Beasts/beast_voice_3.wav",
	"res://Assets/Audio/SFX/Beasts/beast_voice_4.wav",
]
const SFX_CREEPY_PIANO_LONG := "res://Assets/Audio/SFX/creepy_piano_fx_1.mp3"
const SFX_CREEPY_PIANO_SHORT := "res://Assets/Audio/SFX/creepy_piano_fx_4.mp3"
const SFX_CREEPY_STINGER := "res://Assets/Audio/SFX/creepy_2.mp3"
const MUSIC_BASE_WARM := "res://Assets/Audio/Music/base_warm_loop.wav"
const MUSIC_CAMP_DAY := "res://Assets/Audio/Music/day_1_v2.ogg"
const MUSIC_DUNGEON_DARK_INTRO := "res://Assets/Audio/Music/dark_intro.ogg"
const MUSIC_CYBER_STREET := "res://Assets/Audio/Music/cyber_street_urchins.ogg"
const AUDIO_SETTINGS_PATH := "user://audio_settings.cfg"
const UI_SELECT_START_OFFSET := 0.025
const BASE_FEATURE_ENABLED := true

var _sfx_player: AudioStreamPlayer = null
var _ui_sfx_player: AudioStreamPlayer = null
var _combat_sfx_player: AudioStreamPlayer = null
var _loot_sfx_player: AudioStreamPlayer = null
var _music_player: AudioStreamPlayer = null
var _ambience_player: AudioStreamPlayer = null
var _current_music_path: String = ""
var _current_ambience_path: String = ""
var _dungeon_ambience_enabled: bool = false
var _audio_muted: bool = false
var _music_volume: float = 0.8
var _sfx_volume: float = 0.9
var _audio_cache: Dictionary = {}

# ── Inventory display constant ────────────────────────────────────────────────

var items_per_page: int = 45

# ── Auto-save ─────────────────────────────────────────────────────────────────

var _auto_save_timer: float = 0.0
var _proof_save_remaining: float = -1.0

# ── Backward-compatible computed properties ───────────────────────────────────

var player_name: String:
	get: return player_data.player_name
	set(v): player_data.player_name = v

var hp: int:
	get: return player_data.hp
	set(v): player_data.hp = v

var max_hp: int:
	get: return player_data.max_hp
	set(v): player_data.max_hp = v

var end: int:
	get: return player_data.stamina
	set(v): player_data.stamina = v

var max_end: int:
	get: return player_data.max_stamina
	set(v): player_data.max_stamina = v

var xp: int:
	get: return player_data.xp
	set(v): player_data.xp = v

var lvl: int:
	get: return player_data.lvl
	set(v): player_data.lvl = v

var stat_points: int:
	get: return player_data.stat_points
	set(v): player_data.stat_points = v

var atk: int:
	get: return player_data.atk

var def: int:
	get: return player_data.def

var spd: int:
	get: return player_data.spd

var crit: int:
	get: return player_data.crit

var gold: int:
	get: return inventory_system.gold

var stats: Dictionary:
	get: return player_data.get_stats_view()
	set(v): player_data.set_base_stats(v)

var all_missions: Dictionary:
	get: return mission_manager.all_missions

var available_missions: Array:
	get: return mission_manager.available_missions

var available_weekly_missions: Array:
	get: return mission_manager.available_weekly_missions

## Backward compat: MainScene reads GlobalEngine.inventory as an Array.
var inventory: Array:
	get: return inventory_system.items
	set(v): inventory_system.items = v

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	player_data      = preload("res://Scripts/Core/PlayerData.gd").new()
	mission_manager  = preload("res://Scripts/Core/MissionManager.gd").new()
	save_system      = preload("res://Scripts/Core/SaveSystem.gd").new()
	inventory_system = preload("res://Scripts/Core/InventorySystem.gd").new()
	dungeon_system   = preload("res://Scripts/Core/DungeonSystem.gd").new()
	base_manager     = preload("res://Scripts/Core/BaseManager.gd").new()
	commerce_system = preload("res://Scripts/Core/CommerceSystem.gd").new()
	daily_journey = preload("res://Scripts/Core/DailyJourney.gd").new()

	add_child(player_data)
	add_child(mission_manager)
	add_child(save_system)
	add_child(inventory_system)
	add_child(dungeon_system)
	add_child(base_manager)
	add_child(commerce_system)
	add_child(daily_journey)
	_setup_audio()
	inventory_system.load_database()

	mission_manager.initialize(player_data)

	randomize()
	mission_manager.load_all_missions()
	save_system.load_game(player_data, mission_manager, inventory_system, dungeon_system, base_manager)
	commerce_system.from_dict(save_system.get_loaded_commerce())
	daily_journey.from_dict(save_system.get_loaded_journey())
	session_metrics.from_dict(save_system.get_loaded_metrics())
	session_metrics.resume()
	_language_code = _localization.normalize_locale(save_system.get_loaded_language())
	TranslationServer.set_locale(_language_code)
	mission_manager.sanitize_available_missions()
	if not debug_tools_available():
		player_data.debug_invincible = false
	inventory_system.ensure_default_equipment()
	# Applique les bonus d'équipement chargés depuis la save
	player_data.set_equipment_bonuses(inventory_system.get_equipment_bonuses())
	if BASE_FEATURE_ENABLED:
		base_manager.apply_to_player(player_data)
	player_data.update_derived_stats()
	save_system.apply_pending_offline_time(player_data, mission_manager)

	mission_manager.generate_missions()
	save_game()

	_connect_signals()

func _process(delta: float) -> void:
	_metrics_elapsed += delta
	if _metrics_elapsed >= 1.0:
		_metrics_elapsed = 0.0
		session_metrics.heartbeat()
	if _proof_save_remaining >= 0.0:
		_proof_save_remaining -= delta
		if _proof_save_remaining <= 0.0:
			_proof_save_remaining = -1.0
			save_game()
	_auto_save_timer += delta
	if _auto_save_timer >= 30.0:
		_auto_save_timer = 0.0
		save_game()

func _notification(what: int) -> void:
	if player_data == null or save_system == null:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if _suspended_at <= 0.0:
			_suspended_at = Time.get_unix_time_from_system()
			session_metrics.suspend()
			save_game()
	elif what == NOTIFICATION_APPLICATION_RESUMED and _suspended_at > 0.0:
		var elapsed := maxf(0.0, Time.get_unix_time_from_system() - _suspended_at)
		_suspended_at = 0.0
		session_metrics.resume()
		player_data.apply_offline_regen(elapsed)
		mission_manager.advance_time(elapsed)
		save_game()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		session_metrics.suspend()
		save_game()

# ── Signal wiring ─────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	daily_journey.changed.connect(func():
		journey_changed.emit()
		save_game()
	)
	commerce_system.changed.connect(func():
		commerce_changed.emit()
		save_game()
	)
	player_data.stats_updated.connect(func(): stats_updated.emit())
	player_data.xp_gained.connect(func(a: int): xp_gained.emit(a))
	player_data.leveled_up.connect(func(l: int): leveled_up.emit(l))

	mission_manager.mission_completed.connect(_on_mission_completed)
	mission_manager.mission_failed.connect(_on_mission_failed)
	mission_manager.missions_changed.connect(func(): missions_changed.emit())

	inventory_system.inventory_changed.connect(_on_inventory_changed)
	dungeon_system.dungeon_changed.connect(_on_dungeon_changed)
	base_manager.base_changed.connect(_on_base_changed)

func _on_inventory_changed() -> void:
	# Recalcule les bonus d'équipement → PlayerData.stats_updated → UI refresh
	player_data.set_equipment_bonuses(inventory_system.get_equipment_bonuses())
	inventory_changed.emit()

func _on_dungeon_changed() -> void:
	if dungeon_system.phase in ["floor_cleared", "completed"]:
		daily_journey.record_floor(dungeon_system.active_rank, dungeon_system.current_floor)
	dungeon_changed.emit()

func _on_base_changed() -> void:
	if BASE_FEATURE_ENABLED:
		base_manager.apply_to_player(player_data)
	base_changed.emit()

func _on_mission_completed(xp_reward: int, stat_key: String, stat_amount: int) -> void:
	session_metrics.mark("mission_completed")
	if xp_reward > 0:
		commerce_system.award_mission_token()
		daily_journey.record_mission()
	if not stat_key.is_empty() and stat_amount != 0:
		player_data.add_base_stat(stat_key, stat_amount)
	if BASE_FEATURE_ENABLED and (xp_reward > 0 or stat_amount != 0) and base_manager != null:
		base_manager.award_mission_materials(stat_key, player_data.get_rank_index(player_data.lvl))
	player_data.add_xp(xp_reward)
	mission_completed.emit(xp_reward, stat_key, stat_amount)

func _on_mission_failed(hp_lost: int) -> void:
	player_data.take_damage(hp_lost)
	play_creepy_stinger()
	mission_failed.emit(hp_lost)

func _setup_audio() -> void:
	_load_audio_settings()

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SfxPlayer"
	add_child(_sfx_player)

	_ui_sfx_player = AudioStreamPlayer.new()
	_ui_sfx_player.name = "UiSfxPlayer"
	add_child(_ui_sfx_player)

	_combat_sfx_player = AudioStreamPlayer.new()
	_combat_sfx_player.name = "CombatSfxPlayer"
	add_child(_combat_sfx_player)

	_loot_sfx_player = AudioStreamPlayer.new()
	_loot_sfx_player.name = "LootSfxPlayer"
	add_child(_loot_sfx_player)

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbiencePlayer"
	add_child(_ambience_player)
	_prewarm_audio()
	_apply_audio_settings()

func _load_audio_settings() -> void:
	var config := ConfigFile.new()
	if config.load(AUDIO_SETTINGS_PATH) != OK:
		return
	_audio_muted = bool(config.get_value("audio", "muted", _audio_muted))
	_music_volume = clampf(float(config.get_value("audio", "music_volume", _music_volume)), 0.0, 1.0)
	_sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", _sfx_volume)), 0.0, 1.0)

func _save_audio_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "muted", _audio_muted)
	config.set_value("audio", "music_volume", _music_volume)
	config.set_value("audio", "sfx_volume", _sfx_volume)
	config.save(AUDIO_SETTINGS_PATH)

func _load_audio(path: String):
	if path.is_empty():
		return null
	if _audio_cache.has(path):
		return _audio_cache[path]
	var stream = load(path)
	if stream == null:
		push_warning("Audio introuvable: %s" % path)
	else:
		_audio_cache[path] = stream
	return stream

func _prewarm_audio() -> void:
	for path in [SFX_MENU_CHOICE, SFX_LEVEL_UP_SOFT, SFX_CREEPY_STINGER, SFX_CREEPY_PIANO_SHORT]:
		_load_audio(path)
	for path in SFX_CLANKS:
		_load_audio(path)
	if _ui_sfx_player != null:
		var ui_stream = _load_audio(SFX_MENU_CHOICE)
		if ui_stream != null:
			_set_audio_loop(ui_stream, false)
			_ui_sfx_player.stream = ui_stream

func _set_audio_loop(stream, enabled: bool) -> void:
	if stream == null:
		return
	for property in stream.get_property_list():
		var property_name := String(property.get("name", ""))
		if property_name == "loop":
			stream.set("loop", enabled)
			return
		if property_name == "loop_mode":
			stream.set("loop_mode", 1 if enabled else 0)
			return

func _volume_to_db(volume: float, base_db: float) -> float:
	if _audio_muted or volume <= 0.001:
		return -80.0
	return base_db + linear_to_db(clampf(volume, 0.0, 1.0))

func _sfx_db(base_db: float) -> float:
	return _volume_to_db(_sfx_volume, base_db)

func _music_db(base_db: float) -> float:
	return _volume_to_db(_music_volume, base_db)

func _apply_audio_settings() -> void:
	if _sfx_player != null:
		_sfx_player.volume_db = _sfx_db(-5.0)
	if _ui_sfx_player != null:
		_ui_sfx_player.volume_db = _sfx_db(-12.0)
	if _combat_sfx_player != null:
		_combat_sfx_player.volume_db = _sfx_db(-7.0)
	if _loot_sfx_player != null:
		_loot_sfx_player.volume_db = _sfx_db(-6.0)
	if _music_player != null:
		_music_player.volume_db = _music_db(-18.0)
	if _ambience_player != null:
		_ambience_player.volume_db = _music_db(-12.0)

func set_audio_muted(enabled: bool) -> void:
	_audio_muted = enabled
	_apply_audio_settings()
	_save_audio_settings()

func is_audio_muted() -> bool:
	return _audio_muted

func set_music_volume(value: float) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	_apply_audio_settings()
	_save_audio_settings()

func get_music_volume() -> float:
	return _music_volume

func set_sfx_volume(value: float) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)
	_apply_audio_settings()
	_save_audio_settings()

func get_sfx_volume() -> float:
	return _sfx_volume

func play_sfx(path: String, volume_db: float = -5.0) -> void:
	if _sfx_player == null:
		return
	var stream = _load_audio(path)
	if stream == null:
		return
	_set_audio_loop(stream, false)
	_sfx_player.stop()
	_sfx_player.stream = stream
	_sfx_player.volume_db = _sfx_db(volume_db)
	_sfx_player.play()
	_ensure_dungeon_ambience()
	call_deferred("_ensure_dungeon_ambience")

func play_combat_sfx(path: String, volume_db: float = -7.0) -> void:
	if _combat_sfx_player == null:
		return
	var stream = _load_audio(path)
	if stream == null:
		return
	_set_audio_loop(stream, false)
	_combat_sfx_player.stop()
	_combat_sfx_player.stream = stream
	_combat_sfx_player.volume_db = _sfx_db(volume_db)
	_combat_sfx_player.play()

func play_loot_sfx(path: String, volume_db: float = -6.0) -> void:
	if _loot_sfx_player == null:
		return
	var stream = _load_audio(path)
	if stream == null:
		return
	_set_audio_loop(stream, false)
	_loot_sfx_player.stop()
	_loot_sfx_player.stream = stream
	_loot_sfx_player.volume_db = _sfx_db(volume_db)
	_loot_sfx_player.play()

func play_ui_select(volume_db: float = -12.0) -> void:
	if _ui_sfx_player == null:
		play_sfx(SFX_MENU_CHOICE, volume_db)
		return
	if _ui_sfx_player.stream == null:
		_ui_sfx_player.stream = _load_audio(SFX_MENU_CHOICE)
	if _ui_sfx_player.stream == null:
		return
	_ui_sfx_player.stop()
	_ui_sfx_player.volume_db = _sfx_db(volume_db)
	_ui_sfx_player.play(UI_SELECT_START_OFFSET)

func play_level_up_additive() -> void:
	_play_additive_sfx(SFX_LEVEL_UP_SOFT, -8.0, 1.0)
	_play_additive_sfx(SFX_MENU_CHOICE, -23.0, 1.28, UI_SELECT_START_OFFSET)
	_play_additive_sfx(SFX_MENU_CHOICE, -26.0, 1.52, UI_SELECT_START_OFFSET)

func _play_additive_sfx(path: String, volume_db: float = -8.0, pitch_scale: float = 1.0, from_position: float = 0.0) -> void:
	var stream = _load_audio(path)
	if stream == null:
		return
	_set_audio_loop(stream, false)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = _sfx_db(volume_db)
	player.pitch_scale = pitch_scale
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play(maxf(0.0, from_position))

func play_random_clank(volume_db: float = -5.0) -> void:
	if SFX_CLANKS.is_empty():
		return
	play_sfx(SFX_CLANKS.pick_random(), volume_db)

func play_random_beast_voice(volume_db: float = -8.0) -> void:
	if SFX_BEAST_VOICES.is_empty():
		return
	play_combat_sfx(SFX_BEAST_VOICES.pick_random(), volume_db)

func play_enemy_death() -> void:
	if SFX_BEAST_VOICES.is_empty():
		return
	play_combat_sfx(SFX_BEAST_VOICES.pick_random(), -7.0)

func play_loot_drop(rarity: String = "common") -> void:
	match rarity:
		"mythic":
			play_loot_sfx(SFX_CREEPY_STINGER, -4.0)
			play_random_clank(-2.0)
		"legendary":
			play_loot_sfx(SFX_CREEPY_PIANO_SHORT, -9.0)
			play_random_clank(-3.0)
		"epic":
			play_random_clank(-4.0)
			if not SFX_BEAST_VOICES.is_empty():
				play_loot_sfx(SFX_BEAST_VOICES.pick_random(), -13.0)
		"rare":
			play_random_clank(-6.0)
		_:
			play_random_clank(-10.0)

func play_creepy_stinger() -> void:
	play_sfx(SFX_CREEPY_STINGER, -7.0)

func play_creepy_piano_long() -> void:
	play_dungeon_ambience()

func play_creepy_piano_short() -> void:
	play_sfx(SFX_CREEPY_PIANO_SHORT, -10.0)

func play_camp_music() -> void:
	play_music(MUSIC_CYBER_STREET, -18.0)

func play_base_music() -> void:
	stop_ambience()
	play_music(MUSIC_BASE_WARM, -18.0)

func play_mission_music() -> void:
	play_music(MUSIC_CAMP_DAY, -20.0)

func play_dungeon_music() -> void:
	stop_ambience()
	play_music(MUSIC_DUNGEON_DARK_INTRO, -15.0)

func play_music(path: String, volume_db: float = -16.0) -> void:
	if _music_player == null:
		return
	if _current_music_path == path and _music_player.playing:
		return
	var stream = _load_audio(path)
	if stream == null:
		return
	_set_audio_loop(stream, true)
	_music_player.stop()
	_music_player.stream = stream
	_music_player.volume_db = _music_db(volume_db)
	_current_music_path = path
	_music_player.play()

func stop_music() -> void:
	if _music_player != null:
		_music_player.stop()
	_current_music_path = ""

func play_ambience(path: String, volume_db: float = -12.0) -> void:
	if _ambience_player == null:
		return
	if _current_ambience_path == path and _ambience_player.playing:
		return
	var stream = _load_audio(path)
	if stream == null:
		return
	_set_audio_loop(stream, true)
	_ambience_player.stop()
	_ambience_player.stream = stream
	_ambience_player.volume_db = _music_db(volume_db)
	_current_ambience_path = path
	_ambience_player.play()

func stop_ambience() -> void:
	if _ambience_player != null:
		_ambience_player.stop()
	_current_ambience_path = ""
	_dungeon_ambience_enabled = false

func play_dungeon_ambience() -> void:
	_dungeon_ambience_enabled = true
	play_ambience(SFX_CREEPY_PIANO_LONG, -12.0)

func _ensure_dungeon_ambience() -> void:
	if not _dungeon_ambience_enabled:
		return
	if _ambience_player == null:
		return
	if _current_ambience_path != SFX_CREEPY_PIANO_LONG:
		play_ambience(SFX_CREEPY_PIANO_LONG, -12.0)
		return
	if not _ambience_player.playing:
		_ambience_player.play()

# ── Delegated public API (backward compat) ────────────────────────────────────

func save_game() -> void:
	_proof_save_remaining = -1.0
	var saved: bool = save_system.save_game(player_data, mission_manager, inventory_system, dungeon_system, base_manager,
		{"language": _language_code, "commerce": commerce_system.to_dict(), "journey": daily_journey.to_dict(), "metrics": session_metrics.to_dict()})
	save_status_changed.emit(saved)

func claim_journey_reward() -> int:
	var amount: int = daily_journey.take_reward()
	if amount <= 0:
		return 0
	commerce_system.tokens += amount
	# Both persisted states change together, before either UI signal can save.
	commerce_system.changed.emit()
	journey_changed.emit()
	play_ui_select()
	return amount

func loc(key: String, args: Array = []) -> String:
	return _localization.text(_language_code, key, args)

func has_loc(key: String) -> bool:
	return _localization.has_text(_language_code, key)

func localize_item_name(item: Dictionary) -> String:
	var template_id := String(item.get("template_id", ""))
	if not template_id.is_empty():
		var key := "item_data.%s.name" % template_id
		if has_loc(key):
			return loc(key)
	return String(item.get("name", "?"))

func set_language(locale: String) -> void:
	var normalized := _localization.normalize_locale(locale)
	if normalized == _language_code:
		return
	_language_code = normalized
	TranslationServer.set_locale(_language_code)
	language_changed.emit(_language_code)
	save_game()

func get_language() -> String:
	return _language_code

func add_stat(stat_name: String) -> void:
	player_data.add_stat(stat_name)
	save_game()

func accept_mission(mission_dict: Dictionary) -> bool:
	var result: bool = mission_manager.accept_mission(mission_dict)
	if result:
		session_metrics.mark("mission_started")
		save_game()
	return result

func process_mission_result(mission_dict: Dictionary, success: bool) -> bool:
	var result: bool = mission_manager.process_result(mission_dict, success)
	if result:
		save_game()
	return result

func update_mission_progress(mission_dict: Dictionary, delta: int) -> bool:
	var result: bool = mission_manager.update_mission_progress(mission_dict, delta)
	if result:
		save_game()
	return result

func update_mission_proof(mission_dict: Dictionary, proof_text: String, immediate: bool = true) -> bool:
	var result: bool = mission_manager.update_mission_proof(mission_dict, proof_text)
	if result:
		if immediate:
			_proof_save_remaining = -1.0
			save_game()
		else:
			_proof_save_remaining = 0.6
	return result

func get_mission_validation_state(mission_dict: Dictionary) -> Dictionary:
	return mission_manager.get_validation_state(mission_dict)

func get_mission_history_summary() -> Dictionary:
	return mission_manager.get_history_summary()

func get_mission_history_view(limit: int = 5) -> Dictionary:
	return mission_manager.get_history_view(limit)

func get_daily_mission_reward_state() -> Dictionary:
	return mission_manager.get_daily_reward_state()

func equip_inventory_item(index: int) -> bool:
	var result: bool = inventory_system.equip_at(index)
	if result:
		session_metrics.mark("item_equipped")
		play_random_clank()
		save_game()
	return result

func unequip_item(slot: String) -> bool:
	var result: bool = inventory_system.unequip(slot)
	if result:
		play_random_clank(-7.0)
		save_game()
	return result

func sell_inventory_item(index: int) -> Dictionary:
	var result: Dictionary = inventory_system.sell_at(index)
	if not result.is_empty():
		play_random_clank(-9.0)
		save_game()
	return result

func get_item_sell_value(item: Dictionary) -> int:
	return inventory_system.get_item_sell_value(item)

func get_time_string() -> String:
	return mission_manager.get_time_string()

func get_weekly_time_string() -> String:
	return mission_manager.get_weekly_time_string()

func ensure_missions_available() -> bool:
	var changed: bool = mission_manager.ensure_missions_available()
	if changed:
		save_game()
	return changed

func get_xp_for_level(l: int) -> int:
	return player_data.get_xp_for_level(l)

func get_rank_index(l: int) -> int:
	return player_data.get_rank_index(l)

func get_rank_by_level(l: int) -> String:
	return player_data.get_rank_by_level(l)

func update_derived_stats() -> void:
	player_data.update_derived_stats()

func get_final_stat(stat_key) -> int:
	return player_data.get_final_stat(stat_key)

func get_base_materials() -> Dictionary:
	if not BASE_FEATURE_ENABLED or base_manager == null:
		return {}
	return base_manager.get_materials()

func get_base_buildings_view() -> Array:
	if not BASE_FEATURE_ENABLED or base_manager == null:
		return []
	return base_manager.get_buildings_view(get_rank_index(lvl))

func upgrade_base_building(building_id: String) -> Dictionary:
	if not BASE_FEATURE_ENABLED or base_manager == null:
		return {"ok": false}
	var result: Dictionary = base_manager.upgrade_building(building_id, get_rank_index(lvl))
	if bool(result.get("ok", false)):
		session_metrics.mark("base_upgraded")
		save_game()
	return result

func get_dungeon_state() -> Dictionary:
	return dungeon_system.get_view_state(get_rank_by_level(lvl))

func start_dungeon(rank: String) -> bool:
	var result: bool = dungeon_system.start_run(rank, get_rank_by_level(lvl), player_data)
	if result:
		session_metrics.mark("dungeon_started")
		play_dungeon_music()
		play_random_beast_voice(-10.0)
		save_game()
	return result

func dungeon_auto_exchange() -> bool:
	var result: bool = dungeon_system.resolve_auto_exchange(player_data)
	if result:
		var enemy_died := String(dungeon_system.combat_fx.get("kind", "")) == "death"
		if enemy_died:
			play_enemy_death()
		elif randf() < 0.35:
			play_random_beast_voice(-12.0)
		_collect_dungeon_drop_if_pending()
		save_game()
	return result

func dungeon_use_skill(skill: String) -> bool:
	var result: bool = dungeon_system.use_skill(skill, player_data)
	if result:
		var enemy_died := String(dungeon_system.combat_fx.get("kind", "")) == "death"
		if enemy_died:
			play_enemy_death()
		elif skill == "special" or randf() < 0.4:
			play_random_beast_voice(-10.0)
		_collect_dungeon_drop_if_pending()
		save_game()
	return result

func _collect_dungeon_drop_if_pending() -> void:
	if dungeon_system == null or inventory_system == null:
		return
	if not dungeon_system.has_method("has_pending_drop") or not dungeon_system.has_pending_drop():
		return
	var item: Dictionary = inventory_system.generate_loot(player_data.lvl)
	if item.is_empty():
		if dungeon_system.has_method("register_drop_failed"):
			dungeon_system.register_drop_failed()
		return
	if dungeon_system.has_method("register_drop"):
		dungeon_system.register_drop(item)
	play_loot_drop(String(item.get("rarity", "common")))

func dungeon_advance_floor() -> bool:
	var result: bool = dungeon_system.advance_floor()
	if result:
		save_game()
	return result

func dungeon_choose_event(choice_index: int) -> bool:
	var result: bool = dungeon_system.resolve_event(choice_index, player_data)
	if result:
		save_game()
	return result

func forfeit_dungeon() -> bool:
	var result: bool = dungeon_system.forfeit_run()
	if result:
		save_game()
	return result

# ── Debug helpers ─────────────────────────────────────────────────────────────

func debug_tools_available() -> bool:
	if OS.has_feature("android") or OS.has_feature("ios"):
		return false
	return OS.has_feature("editor") or OS.is_debug_build()

func is_debug_invincible() -> bool:
	return debug_tools_available() and player_data != null and player_data.debug_invincible

func debug_toggle_invincible() -> bool:
	if not debug_tools_available():
		return false
	player_data.debug_invincible = not player_data.debug_invincible
	if player_data.debug_invincible:
		player_data.hp = player_data.max_hp
		player_data.stamina = player_data.max_stamina
	player_data.stats_updated.emit()
	return player_data.debug_invincible

func debug_reset_daily() -> void:
	if not debug_tools_available():
		return
	mission_manager.debug_reset_daily()

func debug_reset_weekly() -> void:
	if not debug_tools_available():
		return
	mission_manager.debug_reset_weekly()

func debug_add_level() -> void:
	if not debug_tools_available():
		return
	player_data.lvl += 1
	player_data.stat_points += 3
	player_data.update_derived_stats()
	player_data.leveled_up.emit(player_data.lvl)
	player_data.stats_updated.emit()
	save_game()

## Returns the Texture2D icon for an item dict, or null if no template/icon.
func get_item_icon(item: Dictionary): # -> Texture2D or null
	var tid: String = item.get("template_id", "")
	if tid.is_empty(): return null
	var db = inventory_system._item_db
	if db == null: return null
	var tmpl = db.get_template(tid)
	if tmpl == null: return null
	return tmpl.icon

func debug_add_loot() -> Dictionary:
	if not debug_tools_available():
		return {}
	var item: Dictionary = inventory_system.generate_loot(player_data.lvl)
	play_random_clank()
	save_game()
	return item

func debug_add_base_materials(amount: int = 50) -> void:
	if not debug_tools_available():
		return
	if not BASE_FEATURE_ENABLED or base_manager == null:
		return
	base_manager.add_materials({
		"dungeon_stone": amount,
		"portal_wood": amount,
		"shadow_crystal": amount,
	})
	save_game()
