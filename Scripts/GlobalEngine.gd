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
signal language_changed(locale: String)

# ── Subsystems ────────────────────────────────────────────────────────────────
# Untyped: autoloads are parsed before the global class_name registry is built,
# so the Core class_names aren't resolvable as types here.
# Runtime types: PlayerData, MissionManager, SaveSystem, InventorySystem.

var player_data      = null
var mission_manager  = null
var save_system      = null
var inventory_system = null
var dungeon_system   = null
var _localization = preload("res://Scripts/Core/Localization.gd").new()
var _language_code: String = "en"

const SFX_CLANKS: Array[String] = [
	"res://Assets/Audio/SFX/clank_1.mp3",
	"res://Assets/Audio/SFX/clank_2.mp3",
	"res://Assets/Audio/SFX/clank_3.mp3",
]
const SFX_CREEPY_PIANO_LONG := "res://Assets/Audio/SFX/creepy_piano_fx_1.mp3"
const SFX_CREEPY_PIANO_SHORT := "res://Assets/Audio/SFX/creepy_piano_fx_4.mp3"
const SFX_CREEPY_STINGER := "res://Assets/Audio/SFX/creepy_2.mp3"
const MUSIC_CYBER_STREET := "res://Assets/Audio/Music/cyber_street_urchins.ogg"
const AUDIO_SETTINGS_PATH := "user://audio_settings.cfg"

var _sfx_player: AudioStreamPlayer = null
var _music_player: AudioStreamPlayer = null
var _ambience_player: AudioStreamPlayer = null
var _current_music_path: String = ""
var _current_ambience_path: String = ""
var _dungeon_ambience_enabled: bool = false
var _audio_muted: bool = false
var _music_volume: float = 0.8
var _sfx_volume: float = 0.9

# ── Inventory display constant ────────────────────────────────────────────────

var items_per_page: int = 45

# ── Auto-save ─────────────────────────────────────────────────────────────────

var _auto_save_timer: float = 0.0

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

	add_child(player_data)
	add_child(mission_manager)
	add_child(save_system)
	add_child(inventory_system)
	add_child(dungeon_system)
	_setup_audio()
	inventory_system.load_database()

	mission_manager.initialize(player_data)

	randomize()
	mission_manager.load_all_missions()
	save_system.load_game(player_data, mission_manager, inventory_system, dungeon_system)
	_language_code = _localization.normalize_locale(save_system.get_loaded_language())
	TranslationServer.set_locale(_language_code)
	mission_manager.sanitize_available_missions()
	if not debug_tools_available():
		player_data.debug_invincible = false
	inventory_system.ensure_default_equipment()
	# Applique les bonus d'équipement chargés depuis la save
	player_data.set_equipment_bonuses(inventory_system.get_equipment_bonuses())
	player_data.update_derived_stats()
	save_system.apply_pending_offline_time(player_data, mission_manager)

	mission_manager.generate_missions()
	save_game()

	_connect_signals()

func _process(delta: float) -> void:
	_auto_save_timer += delta
	if _auto_save_timer >= 30.0:
		_auto_save_timer = 0.0
		save_game()

# ── Signal wiring ─────────────────────────────────────────────────────────────

func _connect_signals() -> void:
	player_data.stats_updated.connect(func(): stats_updated.emit())
	player_data.xp_gained.connect(func(a: int): xp_gained.emit(a))
	player_data.leveled_up.connect(func(l: int): leveled_up.emit(l))

	mission_manager.mission_completed.connect(_on_mission_completed)
	mission_manager.mission_failed.connect(_on_mission_failed)
	mission_manager.missions_changed.connect(func(): missions_changed.emit())

	inventory_system.inventory_changed.connect(_on_inventory_changed)
	dungeon_system.dungeon_changed.connect(_on_dungeon_changed)

func _on_inventory_changed() -> void:
	# Recalcule les bonus d'équipement → PlayerData.stats_updated → UI refresh
	player_data.set_equipment_bonuses(inventory_system.get_equipment_bonuses())
	inventory_changed.emit()

func _on_dungeon_changed() -> void:
	dungeon_changed.emit()

func _on_mission_completed(xp_reward: int, stat_key: String, stat_amount: int) -> void:
	if not stat_key.is_empty() and stat_amount != 0:
		player_data.add_base_stat(stat_key, stat_amount)
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

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.name = "AmbiencePlayer"
	add_child(_ambience_player)
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
	var stream = load(path)
	if stream == null:
		push_warning("Audio introuvable: %s" % path)
	return stream

func _set_audio_loop(stream, enabled: bool) -> void:
	if stream == null:
		return
	for property in stream.get_property_list():
		if String(property.get("name", "")) == "loop":
			stream.set("loop", enabled)
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

func play_random_clank(volume_db: float = -5.0) -> void:
	if SFX_CLANKS.is_empty():
		return
	play_sfx(SFX_CLANKS.pick_random(), volume_db)

func play_creepy_stinger() -> void:
	play_sfx(SFX_CREEPY_STINGER, -7.0)

func play_creepy_piano_long() -> void:
	play_dungeon_ambience()

func play_creepy_piano_short() -> void:
	play_sfx(SFX_CREEPY_PIANO_SHORT, -10.0)

func play_camp_music() -> void:
	play_music(MUSIC_CYBER_STREET, -18.0)

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
	save_system.save_game(player_data, mission_manager, inventory_system, dungeon_system, {"language": _language_code})

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
	if result: save_game()
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

func update_mission_proof(mission_dict: Dictionary, proof_text: String) -> bool:
	var result: bool = mission_manager.update_mission_proof(mission_dict, proof_text)
	if result:
		save_game()
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

func get_dungeon_state() -> Dictionary:
	return dungeon_system.get_view_state(get_rank_by_level(lvl))

func start_dungeon(rank: String) -> bool:
	var result: bool = dungeon_system.start_run(rank, get_rank_by_level(lvl), player_data)
	if result:
		save_game()
	return result

func dungeon_auto_exchange() -> bool:
	var result: bool = dungeon_system.resolve_auto_exchange(player_data)
	if result:
		_collect_dungeon_drop_if_pending()
		save_game()
	return result

func dungeon_use_skill(skill: String) -> bool:
	var result: bool = dungeon_system.use_skill(skill, player_data)
	if result:
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
