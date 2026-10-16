extends Node

@onready var root: Window = get_tree().root

const Commerce = preload("res://Scripts/Core/CommerceSystem.gd")
const Provider = preload("res://Scripts/Core/MobileCommerceProvider.gd")
const Journey = preload("res://Scripts/Core/DailyJourney.gd")
var _failures: Array[String] = []
var _assertions := 0

class TestProvider:
	extends "res://Scripts/Core/MobileCommerceProvider.gd"
	var request_id := ""
	var requested_product := ""
	var consent := true
	var service_ready := true
	func can_request_ads() -> bool: return consent
	func is_rewarded_ready() -> bool: return service_ready
	func show_rewarded(id: String) -> void: request_id = id
	func is_billing_ready() -> bool: return service_ready
	func get_price(_id: String) -> String: return "2,99 EUR"
	func purchase(id: String) -> void: requested_product = id
	func restore() -> void: pass

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(description)
		push_error("CHECK FAILED: " + description)

func _run() -> void:
	_test_commerce()
	_test_journey()
	_test_session_metrics()
	_test_material_preview()
	_test_missions()
	_test_mission_time()
	_test_regen()
	_test_loaded_vitals()
	_test_saves()
	if OS.get_cmdline_user_args().has("--visual"):
		await _test_visual()
	if _failures.is_empty():
		print("MOBILE_CHECKS_PASSED: %d assertions" % _assertions)
		get_tree().quit(0)
	else:
		print("MOBILE_CHECKS_FAILED: ", _failures)
		get_tree().quit(1)

func _test_commerce() -> void:
	var commerce := Commerce.new()
	var now := [2000000000]
	commerce._now = func(): return now[0]
	_check(not commerce.request_rewarded(), "No provider grants no ad reward")
	_check(not commerce.request_purchase("irlleveling.supporter_frame"), "No provider grants no purchase")
	for i in range(10): commerce.award_mission_token()
	_check(commerce.tokens == 5, "Mission tokens have a daily cap")
	_check(not commerce.unlock_or_select("emerald"), "Insufficient balance cannot unlock")
	var provider := TestProvider.new()
	commerce.set_provider(provider)
	provider.consent = false
	_check(not commerce.request_rewarded(), "Consent gates ads")
	provider.consent = true
	for i in range(3):
		_check(commerce.request_rewarded(), "Ready ad can be requested")
		var id := provider.request_id
		_check(not commerce.request_rewarded(), "Concurrent ad requests blocked")
		provider.reward_earned.emit("incorrect")
		_check(commerce.tokens == 5 + i * 5, "Unmatched callback ignored")
		provider.reward_earned.emit(id)
		provider.reward_earned.emit(id)
		provider.reward_closed.emit(id)
		_check(commerce.tokens == 10 + i * 5, "Reward granted exactly once")
		_check(not commerce.request_rewarded(), "Reward cooldown respected")
		now[0] += 121
	_check(not commerce.request_rewarded(), "Daily ad cap respected")
	now[0] -= 86400
	_check(not commerce.request_rewarded(), "Backward clock does not reset quota")
	now[0] += 172800
	_check(commerce.request_rewarded(), "New day restores quota")
	provider.reward_closed.emit(provider.request_id)
	_check(commerce.tokens == 20, "Dismissal gives no reward")
	_check(commerce.unlock_or_select("emerald"), "Tokens unlock cosmetic")
	_check(commerce.tokens == 0 and commerce.selected == "emerald", "Cost deducted once and frame equipped")
	_check(commerce.unlock_or_select("emerald") and commerce.tokens == 0, "Owned frame selection is free")
	_check(commerce.request_purchase("irlleveling.supporter_frame"), "Known product can start billing")
	provider.purchase_finished.emit("irlleveling.supporter_frame", "pending")
	_check(not commerce.owned.has("supporter"), "Pending payment gives no entitlement")
	provider.purchase_verified.emit("unknown")
	_check(not commerce.owned.has("unknown"), "Unknown products rejected")
	provider.purchase_verified.emit("irlleveling.supporter_frame")
	provider.purchase_verified.emit("irlleveling.supporter_frame")
	_check(commerce.owned.count("supporter") == 1, "Verified nonconsumable is idempotent")
	commerce.unlock_or_select("supporter")
	var restored := Commerce.new()
	restored._now = commerce._now
	restored.from_dict(JSON.parse_string(JSON.stringify(commerce.to_dict())))
	_check(restored.selected == "supporter" and restored.owned.has("emerald"), "Cosmetics survive JSON roundtrip")
	provider.entitlements_restored.emit([])
	_check(not commerce.owned.has("supporter") and commerce.selected == "classic", "Revoked product removed and selected frame reset")
	_check(commerce.owned.has("emerald"), "Restoration preserves earned frames")
	commerce.free()
	restored.free()
	provider.free()

func _test_missions() -> void:
	var player := PlayerData.new()
	var manager := MissionManager.new()
	manager.initialize(player)
	var data := MissionData.new()
	data.id = "test_mission"
	data.validation_mode = MissionData.ValidationMode.SIMPLE
	manager.all_missions[data.id] = data
	var mission := {"id": data.id, "status": "available", "end_cost": 15}
	manager.available_missions.append(mission)
	_check(not manager.accept_mission(mission.duplicate()), "Detached mission rejected")
	_check(manager.accept_mission(mission), "Available mission accepted")
	var remaining := player.stamina
	_check(not manager.accept_mission(mission) and player.stamina == remaining, "Repeated acceptance does not spend stamina")
	_check(manager.process_result(mission, false), "Active mission can fail")
	_check(not manager.process_result(mission, false), "Failed mission cannot fail twice")
	mission["status"] = "in_progress"
	_check(manager.process_result(mission, true), "Active mission can complete")
	_check(not manager.process_result(mission, true), "Completed mission cannot reward twice")
	manager.free()
	player.free()

func _test_mission_time() -> void:
	var player := PlayerData.new()
	var manager := MissionManager.new()
	manager.initialize(player)
	manager.load_all_missions()
	manager.generate_missions()
	var active: Dictionary = manager.available_missions[0]
	active.merge({"status": "in_progress", "progress_amount": 1, "proof_text": "Retained note", "started_at": 123.0}, true)
	var weekly: Dictionary = manager.available_weekly_missions[0]
	weekly["status"] = "in_progress"
	manager.time_until_reset = 10.0
	manager.time_until_weekly_reset = 10.0
	var notifications := [0]
	manager.missions_changed.connect(func(): notifications[0] += 1)
	manager.advance_time(10.0)
	_check(manager.time_until_reset == manager.reset_duration, "Exact reset boundary refreshes immediately")
	_check(notifications[0] == 1, "Simultaneous resets emit one coherent update")
	_check(is_same(manager.available_missions[0], active) and is_same(manager.available_weekly_missions[0], weekly), "Reset preserves active mission identities")
	_check(active["proof_text"] == "Retained note" and active["progress_amount"] == 1 and active["started_at"] == 123.0, "Reset preserves notes progress and start time")
	manager.advance_time(manager.weekly_reset_duration * 3.0 + 120.0)
	_check(manager.time_until_reset == manager.reset_duration - 120.0 and manager.time_until_weekly_reset == manager.weekly_reset_duration - 120.0, "Multi-week absence preserves countdown phase")
	_check(notifications[0] == 2, "Long absence refreshes once rather than replaying every cycle")
	var remaining := manager.time_until_reset
	manager.advance_time(-100.0)
	manager.advance_time(INF)
	_check(manager.time_until_reset == remaining, "Invalid elapsed time leaves countdown unchanged")
	manager.free()
	player.free()

func _test_journey() -> void:
	var journey := Journey.new()
	var now := [21000 * 86400 + 10 * 3600]
	journey._now = func(): return now[0]
	_check(journey.get_state()["steps"] == 0, "Journey starts empty")
	_check(journey.record_mission(), "Quest advances first journey step")
	_check(journey.get_state()["pending_tokens"] == 2, "First step earns two cosmetic tokens")
	_check(not journey.record_mission(), "Same-session quest cannot advance next step")
	_check(not journey.record_floor("F", 1), "Cooldown blocks a dungeon step")
	now[0] += Journey.STEP_INTERVAL
	_check(not journey.record_floor("F", 1), "Repeated floor callback cannot become a new activity")
	_check(journey.record_floor("F", 2), "New floor advances second step after interval")
	_check(journey.get_state()["pending_tokens"] == 5, "Step rewards accumulate")
	var restored := Journey.new()
	restored._now = journey._now
	restored.from_dict(JSON.parse_string(JSON.stringify(journey.to_dict())))
	_check(restored.get_state() == journey.get_state(), "Journey survives save roundtrip")
	_check(not restored.record_mission(), "Reload cannot bypass cooldown")
	now[0] += Journey.STEP_INTERVAL
	_check(restored.record_mission(), "Later quest advances third step")
	_check(restored.get_state()["complete"], "Three steps complete daily journey")
	now[0] += Journey.STEP_INTERVAL
	_check(not restored.record_mission(), "Daily journey cannot over-reward")
	now[0] += 86400
	_check(restored.get_state()["steps"] == 0, "New day resets steps")
	_check(restored.get_state()["pending_tokens"] == 10, "Unclaimed rewards survive midnight")
	_check(restored.take_reward() == 10 and restored.take_reward() == 0, "Rewards claimed exactly once")
	_check(not restored.record_floor("F", 0), "Invalid floor cannot advance")
	_check(restored.record_floor("F", 1), "New day allows a new floor victory")
	now[0] -= 86400
	_check(not restored.record_mission(), "Backward clock cannot reopen journey")
	journey.free()
	restored.free()

func _test_session_metrics() -> void:
	var metrics = preload("res://Scripts/Core/SessionMetrics.gd").new()
	var now := [22000 * 86400]
	metrics._now = func(): return now[0]
	metrics.resume()
	metrics.resume()
	_check(metrics.days["22000"] == 1, "Duplicate foreground notification counts one session")
	now[0] += 5
	metrics.mark("mission_started")
	now[0] += 10
	metrics.mark("mission_started")
	metrics.mark("private_note")
	_check(metrics.milestones["mission_started"] == 5 and metrics.milestones.size() == 1, "Only first allowlisted milestone retained")
	metrics.suspend()
	now[0] += 1799
	metrics.resume()
	_check(metrics.days["22000"] == 1, "Short absence stays in same session")
	metrics.suspend()
	now[0] += 1800
	metrics.resume()
	_check(metrics.days["22000"] == 2, "Thirty minute absence starts another session")
	var restored = preload("res://Scripts/Core/SessionMetrics.gd").new()
	restored._now = metrics._now
	restored.from_dict(JSON.parse_string(JSON.stringify(metrics.to_dict())))
	restored.resume()
	_check(restored.days["22000"] == 2, "Immediate process restart does not inflate sessions")
	now[0] = 22001 * 86400
	restored.heartbeat()
	_check(restored.days.has("22001") and restored.days["22001"] == 0, "Midnight records foreground day without inventing session")
	restored.suspend()
	now[0] -= 86400
	restored.resume()
	_check(restored.days["22000"] == 2 and restored.last_seen == 22001 * 86400, "Clock rollback does not create sessions or move observation backwards")
	for i in range(100):
		now[0] = (22002 + i) * 86400
		restored.heartbeat()
	_check(restored.days.size() == 90, "Local daily observations bounded to ninety days")

func _test_material_preview() -> void:
	var base := BaseManager.new()
	var before := base.to_dict()
	var preview := base.preview_mission_materials("INT", 2)
	_check(base.to_dict() == before, "Material preview never credits inventory")
	_check(preview == {"portal_wood": 5, "dungeon_stone": 1, "shadow_crystal": 1}, "Material preview includes rank and secondary drops")
	_check(base.award_mission_materials("INT", 2) == preview, "Granted materials match preview calculation")
	_check(base.get_materials() == preview, "Previewed material amounts reach stock")
	base.free()

func _test_regen() -> void:
	var player := PlayerData.new()
	player.hp = 50
	player.stamina = 50
	for i in range(12): player.apply_offline_regen(30.0)
	_check(player.stamina == 51, "Short offline sessions accumulate stamina")
	var second := PlayerData.new()
	second.hp = player.hp
	second.stamina = player.stamina
	second.load_regen_state(player.get_regen_state())
	second.apply_offline_regen(360.0)
	_check(second.hp == 51 and second.stamina == 52, "Fractional regeneration survives save")
	second.apply_offline_regen(-3600)
	_check(second.hp == 51, "Negative offline time cannot remove health")
	player.free()
	second.free()

func _test_loaded_vitals() -> void:
	var saves := SaveSystem.new()
	var player := PlayerData.new()
	var manager := MissionManager.new()
	manager.initialize(player)
	var saved := {"hp": 108, "max_hp": 115, "stamina": 107, "max_stamina": 115, "base_stats": player.base_stats.duplicate()}
	saves._load_player(player, saved)
	player.set_equipment_bonuses({"HP": 10, "STAMINA": 10})
	player.set_passive_bonuses({"HP": 5, "STAMINA": 5})
	saves.apply_pending_offline_time(player, manager)
	_check(player.hp == 108 and player.stamina == 107, "Partial boosted vitals restored after bonus calculation")
	player.hp = 90
	saves.apply_pending_offline_time(player, manager)
	_check(player.hp == 90, "Loaded vitals restored only once")
	saves._load_player(player, saved)
	player.set_equipment_bonuses({})
	player.set_passive_bonuses({})
	saves.apply_pending_offline_time(player, manager)
	_check(player.hp == 100 and player.stamina == 100, "Restored vitals clamp to actual maxima when bonuses removed")
	saves.free()
	manager.free()
	player.free()

func _write_save(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _test_saves() -> void:
	# This runner uses the dedicated IRLLevelingValidation user directory.
	_check(ProjectSettings.get_setting("application/config/custom_user_dir_name", "") == "IRLLevelingValidation", "Tests use isolated user data")
	if not _failures.is_empty(): return
	var player := PlayerData.new()
	var manager := MissionManager.new()
	var inventory = preload("res://Scripts/Core/InventorySystem.gd").new()
	var saves := SaveSystem.new()
	_check(saves.save_game(player, manager, inventory), "First save succeeds")
	player.player_name = "Second save"
	_check(saves.save_game(player, manager, inventory), "Replacement save succeeds")
	_check(FileAccess.file_exists(SaveSystem.BACKUP_PATH), "Backup created")
	_write_save(SaveSystem.SAVE_PATH, "broken json")
	_check(saves.load_game(player, manager, inventory), "Corrupted primary recovers from backup")
	_check(player.player_name == "Player", "Backup contents recovered")
	_write_save(SaveSystem.SAVE_PATH, "{}")
	_write_save(SaveSystem.BACKUP_PATH, "{}")
	_check(not saves.load_game(player, manager, inventory), "Invalid schemas rejected")
	_check(not saves.save_game(player, manager, inventory), "Unreadable saves protected from overwrite")
	_check(FileAccess.get_file_as_string(SaveSystem.SAVE_PATH) == "{}", "Unreadable original preserved")
	_write_save(SaveSystem.SAVE_PATH, '{"version":999,"lvl":1,"inventory":[]}')
	_write_save(SaveSystem.BACKUP_PATH, '{"version":5,"lvl":1,"inventory":[]}')
	_check(not saves.load_game(player, manager, inventory) and not saves.writes_allowed, "Newer primary save cannot be downgraded via backup")
	_check(saves._read_save(SaveSystem.BACKUP_PATH).get("version") == 5, "Legacy save remains readable")
	_write_save(SaveSystem.TEMP_PATH, '{"lvl":{},"inventory":[]}')
	_check(saves._read_save(SaveSystem.TEMP_PATH).is_empty(), "Wrong scalar types rejected")
	_write_save(SaveSystem.TEMP_PATH, '{"lvl":1,"inventory":{"items":{},"equipment":{}}}')
	_check(saves._read_save(SaveSystem.TEMP_PATH).is_empty(), "Wrong inventory shape rejected")
	_write_save(SaveSystem.TEMP_PATH, '{"lvl":1,"inventory":[],"commerce":{"tokens":{}}}')
	_check(saves._read_save(SaveSystem.TEMP_PATH).is_empty(), "Malformed commerce balance rejected")
	# Restore fixture files so future visual checks start normally.
	saves.writes_allowed = true
	_check(saves.save_game(player, manager, inventory), "Fixture reset succeeds")
	player.free()
	manager.free()
	inventory.free()
	saves.free()

func _test_visual() -> void:
	var scene = load("res://Scenes/Main/main_scene.tscn").instantiate()
	root.add_child(scene)
	await get_tree().process_frame
	_check(scene._active_tab_name == "Missions" and scene.btn_missions.button_pressed, "Game opens on missions with selected navigation")
	_check(scene.btn_campement.is_visible_in_tree() and scene.btn_social.is_visible_in_tree(), "Base and social remain visible in navigation")
	for tab in ["Campement", "Social"]:
		scene._navigation_buttons[tab].pressed.emit()
		_check(scene._active_tab_name == tab and scene._empty_tab_panels[tab].visible, "Restored tab opens its screen: " + tab)
		scene._handle_back()
	root.get_node("GlobalEngine").set_language("fr")
	var engine = root.get_node("GlobalEngine")
	scene._on_nav_pressed("Personnage")
	await get_tree().create_timer(0.4).timeout
	var initial_slot_size: Vector2 = scene.inv_grid.get_child(0).size
	var hunter = scene.avatar_view
	_check(hunter.is_processing(), "Hunter animation runs in visible character tab")
	_check(hunter._frame_at_time(0.0) == hunter._frame_at_time(hunter.HUNTER_LOOP_SECONDS), "Hunter loop closes on the same frame")
	_check(hunter._frame_at_time(hunter.HUNTER_LOOP_SECONDS / 2.0) == 299, "Hunter loop reaches last interpolated pose")
	var distinct_poses := {}
	for tick in range(60): distinct_poses[hunter._frame_at_time(float(tick) / 60.0)] = true
	_check(distinct_poses.size() == 60, "Hunter advances through 60 interpolated frames per second")
	var atlas_image: Image = hunter.HUNTER_ATLASES[0].get_image()
	if atlas_image.is_compressed(): atlas_image.decompress()
	_check(atlas_image.get_pixel(12, 12).a < 0.01, "Hunter atlas has transparent exterior")
	_check(atlas_image.get_pixel(1674, 938).a < 0.01, "Hunter closed arm gap is transparent in source pose twenty")
	_check(atlas_image.get_pixel(130, 178).a > 0.95, "Hunter interior remains opaque")
	# Poses where the free hand closes against the scarf trapped white background.
	for sample in [[75, 198, 180], [125, 200, 190], [275, 201, 180]]:
		var pose_atlas: Image = hunter.HUNTER_ATLASES[sample[0] / 35].get_image()
		if pose_atlas.is_compressed(): pose_atlas.decompress()
		var cell: int = sample[0] % 35
		_check(pose_atlas.get_pixel((cell % 7) * 260 + 2 + sample[1], (cell / 7) * 388 + 2 + sample[2]).a < 0.05, "Free hand/scarf gap stays transparent in pose " + str(sample[0]))
	var hand_atlas: Image = hunter.HUNTER_ATLASES[2].get_image()
	if hand_atlas.is_compressed(): hand_atlas.decompress()
	for preserved in [Vector2i(196, 132), Vector2i(196, 146), Vector2i(204, 172)]:
		_check(hand_atlas.get_pixel(1302 + preserved.x, 2 + preserved.y).a > 0.95, "Hand cutout preserves cuff, skin and glove: " + str(preserved))
	hunter._hunter_elapsed = 75.0 / hunter.HUNTER_FPS
	hunter._hunter_frame = 75
	hunter._update_hunter_blend()
	hunter.queue_redraw()
	hunter.set_process(false)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../tmp/hunter_hand_gap.png"))
	hunter.set_process(true)
	# Exercise interpolation across an atlas boundary, where UV errors expose other poses.
	hunter._hunter_elapsed = 34.5 / hunter.HUNTER_FPS
	hunter._hunter_frame = 34
	hunter._update_hunter_blend()
	_check(is_equal_approx(float(hunter._hunter_material.get_shader_parameter("frame_mix")), 0.5), "Hunter blends adjacent poses between source ticks")
	_check(hunter._hunter_material.get_shader_parameter("next_atlas") == hunter.HUNTER_ATLASES[1], "Hunter blend crosses to the next atlas")
	hunter.queue_redraw()
	hunter.set_process(false)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../tmp/hunter_blend_boundary.png"))
	hunter.set_process(true)
	var hunter_frame_before: int = hunter._hunter_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../tmp/hunter_720.png"))
	await get_tree().create_timer(0.9).timeout
	_check(hunter._hunter_frame != hunter_frame_before, "Hunter advances to a different pose")
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../tmp/hunter_motion_720.png"))
	var frame_times: Array[float] = []
	var benchmark_started := Time.get_ticks_usec()
	var last_tick := benchmark_started
	var pose_changes := 0
	var last_pose: int = hunter._hunter_frame
	var video_start: float = hunter._background_video.stream_position
	while Time.get_ticks_usec() - benchmark_started < 10000000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frame_times.append(float(now - last_tick) / 1000.0)
		last_tick = now
		if hunter._hunter_frame != last_pose:
			pose_changes += 1
			last_pose = hunter._hunter_frame
	frame_times.sort()
	var measured := {"frames": frame_times.size(), "median_ms": frame_times[frame_times.size() / 2], "p95_ms": frame_times[int(frame_times.size() * 0.95)], "max_ms": frame_times.back(), "pose_changes": pose_changes, "scope": "desktop fixture; renderer in engine header; not an Android benchmark"}
	print("AVATAR_PERFORMANCE: ", JSON.stringify(measured))
	_check(pose_changes >= 540, "Hunter displays at least 540 pose changes in ten seconds")
	_check(hunter._background_video.stream_position != video_start, "Animated forest video advances")
	# Pixel readback is intentionally outside the performance timing above.
	var forest_samples_started := Time.get_ticks_usec()
	var forest_changes := 0
	var previous_forest_hash := 0
	while Time.get_ticks_usec() - forest_samples_started < 2000000:
		await RenderingServer.frame_post_draw
		var forest_image: Image = hunter._background_video.get_video_texture().get_image()
		forest_image.resize(108, 192)
		var forest_hash := hash(forest_image.get_data())
		if forest_hash != previous_forest_hash:
			forest_changes += 1
			previous_forest_hash = forest_hash
	print("FOREST_DISPLAYED_CHANGES_2S: ", forest_changes)
	_check(forest_changes >= 90, "Forest displays at least 90 distinct decoded images in two seconds")
	scene.btn_next.pressed.emit()
	await get_tree().create_timer(0.2).timeout
	_check(scene.inv_grid.get_child(0).size.is_equal_approx(initial_slot_size), "Inventory first page matches next page without manual relayout")
	scene.btn_prev.pressed.emit()
	engine.mission_manager.mission_history = {}
	engine.missions_changed.emit()
	var before: Dictionary = engine.player_data.get_stats_view()
	engine.commerce_system.tokens = 20
	_check(engine.commerce_system.unlock_or_select("emerald"), "Earned frame can be equipped from UI state")
	_check(scene.hero_frame.get_theme_stylebox("panel").border_color == Color("63dfac"), "Equipped frame changes hero appearance")
	_check(engine.player_data.get_stats_view() == before, "Cosmetic does not alter combat stats")
	scene._on_nav_pressed("Boutique")
	await get_tree().create_timer(1.0).timeout
	_check(not hunter.is_processing(), "Hunter animation stops on hidden tabs")
	_check(hunter._background_video.paused, "Animated forest pauses on hidden tabs")
	var paused_hunter_frame: int = hunter._hunter_frame
	await get_tree().create_timer(0.2).timeout
	_check(hunter._hunter_frame == paused_hunter_frame, "Hidden hunter pose stays unchanged")
	var output := ProjectSettings.globalize_path("res://../../tmp/shop_720.png")
	var image := root.get_texture().get_image()
	_check(not image.is_empty(), "Shop viewport renders")
	image.save_png(output)
	root.size = Vector2i(360, 800)
	await get_tree().create_timer(0.5).timeout
	_check(scene.btn_missions.size.y * absf(scene.btn_missions.get_screen_transform().get_scale().y) >= 44.0, "Navigation target is at least 44 rendered pixels")
	var shop = scene._empty_tab_panels["Boutique"]
	_check(not scene.game_zone.is_visible_in_tree(), "Character scroll is hidden behind shop")
	for nav_button in scene._navigation_buttons.values():
		_check(absf(nav_button.size.x - scene.btn_missions.size.x) <= 1.0, "All navigation tabs have equal width")
		var nav_text_width: float = nav_button.get_theme_font("font").get_string_size(nav_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, nav_button.get_theme_font_size("font_size")).x
		_check(nav_text_width <= nav_button.size.x - nav_button.get_theme_stylebox("normal").get_minimum_size().x, "Navigation label fits without clipping")
	var shop_bar: VScrollBar = shop._scroll.get_v_scroll_bar()
	_check(shop._body.get_global_rect().end.x <= shop_bar.get_global_rect().position.x, "Shop content does not overlap scrollbar")
	_check(shop._ad_button.size.y * absf(shop._ad_button.get_screen_transform().get_scale().y) >= 44.0, "Rewarded ad target is at least 44 rendered pixels")
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../tmp/shop_360.png"))
	scene._on_nav_pressed("Personnage")
	await get_tree().create_timer(0.4).timeout
	var mobile_slot_size: Vector2 = scene.inv_grid.get_child(0).size
	_check(hunter.is_processing(), "Hunter animation resumes when character tab reopens")
	_check(not hunter._background_video.paused, "Animated forest resumes with character tab")
	_check(Rect2(Vector2.ZERO, hunter.size).encloses(hunter._hunter_rect()), "Entire hunter fits within mobile character view")
	scene.game_zone.scroll_vertical = 0
	await get_tree().create_timer(0.2).timeout
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../tmp/hunter_360.png"))
	scene.btn_next.pressed.emit()
	await get_tree().create_timer(0.2).timeout
	_check(scene.inv_grid.get_child(0).size.is_equal_approx(mobile_slot_size), "Inventory pagination remains stable after mobile resize")
	scene.btn_prev.pressed.emit()
	scene.game_zone.ensure_control_visible(scene.inv_grid)
	await get_tree().create_timer(0.2).timeout
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../tmp/inventory_360.png"))
	scene._on_nav_pressed("Boutique")
	_check(scene._empty_tab_panels["Boutique"].size.x > 0, "Responsive shop remains visible")
	scene._on_nav_pressed("Missions")
	_check(scene.btn_missions.button_pressed and not scene.btn_boutique.button_pressed, "Navigation selection follows displayed screen")
	engine.daily_journey.from_dict({})
	engine.daily_journey.record_mission()
	await get_tree().create_timer(0.5).timeout
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../tmp/journey_360.png"))
	var balance_before: int = engine.commerce_system.tokens
	var reward: int = engine.daily_journey.get_state()["pending_tokens"]
	_check(reward > 0, "Journey reward is available in game")
	_check(engine.claim_journey_reward() == reward, "Game claims earned journey reward")
	_check(engine.commerce_system.tokens == balance_before + reward, "Journey reward reaches cosmetic wallet")
	_check(engine.claim_journey_reward() == 0, "Repeated game claim gives no reward")
	var persisted: Dictionary = engine.save_system._read_save(SaveSystem.SAVE_PATH)
	_check(persisted["journey"]["pending_tokens"] == 0 and int(persisted["commerce"]["tokens"]) == engine.commerce_system.tokens, "Wallet and consumed journey reward persisted together")
	var missions = scene._missions_panel
	var saved_history: Dictionary = engine.mission_manager.mission_history.duplicate(true)
	var cap_entries: Array = []
	for i in range(MissionManager.DAILY_FULL_REWARD_LIMIT):
		cap_entries.append({"timestamp": Time.get_unix_time_from_system(), "type": 0, "success": true, "rewarded": true})
	engine.mission_manager.mission_history["entries"] = cap_entries
	var reward_data := MissionData.new()
	reward_data.type = MissionData.MissionType.QUOTIDIENNE
	_check(missions._mission_reward_text({"status": "in_progress"}, reward_data) == engine.loc("mission.journal_only_cap"), "Active capped mission does not promise XP")
	_check(missions._mission_reward_text({"status": "completed", "rewarded": false}, reward_data) == engine.loc("popup.journal_only"), "Unrewarded completion stays journal-only")
	_check(missions._mission_reward_text({"status": "completed", "rewarded": true}, reward_data).contains("XP"), "Past earned rewards unaffected by current cap")
	_check(missions._mission_reward_text({"status": "failed"}, reward_data) == engine.loc("mission.no_reward"), "Failed mission displays no reward")
	reward_data.type = MissionData.MissionType.HEBDOMADAIRE
	_check(missions._mission_reward_text({"status": "available"}, reward_data).contains("XP"), "Weekly reward unaffected by daily cap")
	engine.mission_manager.mission_history = saved_history
	var display_source := [{"status": "completed"}, {"status": "available"}, {"status": "in_progress"}, {"status": "in_progress"}]
	var display_order: Array = missions._missions_for_display(display_source)
	_check(is_same(display_order[0], display_source[2]) and is_same(display_order[1], display_source[3]), "Active quests shown first with stable identity and order")
	_check(is_same(display_order[2], display_source[1]) and is_same(display_order[3], display_source[0]), "New quests precede finished quests without changing source")
	_check(missions._daily_scroll.is_ancestor_of(missions._weekly_vbox), "Weekly missions share the daily scroll")
	_check(not scene._is_popup_active(), "Effect layer does not block scrolling")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = missions._daily_scroll.get_global_rect().get_center()
	var start := touch.position
	scene._input(touch)
	_check(scene._touch_scroll_target == missions._daily_scroll, "Touch selects the mission scroll")
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = start - Vector2(0, 240)
	scene._input(drag)
	await get_tree().process_frame
	_check(missions._daily_scroll.scroll_vertical > 0, "Touch drag advances missions")
	touch.pressed = false
	scene._input(touch)
	_check(scene._touch_scroll_target == null, "Touch release clears scroll tracking")
	scene._popup_manager.show_rename()
	await get_tree().create_timer(0.3).timeout
	var rename_confirm: Button = scene._popup_manager._rename_confirm_button
	_check(rename_confirm.size.y * absf(rename_confirm.get_screen_transform().get_scale().y) >= 44.0, "Rename confirmation has mobile touch target")
	_check(rename_confirm.size.x >= 240.0, "Rename action has room for readable label")
	_check(scene._popup_manager._rename_popup.get_global_rect().encloses(rename_confirm.get_global_rect()), "Rename confirmation stays within viewport")
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../tmp/journey_rename_360.png"))
	_check(scene._is_popup_active(), "Rename popup blocks background gestures")
	touch.pressed = true
	scene._input(touch)
	_check(scene._touch_scroll_target == null, "Open popup prevents background scrolling")
	_check(scene._handle_back() and not scene._is_popup_active(), "Back dismisses popup first")
	scene._on_nav_pressed("Boutique")
	_check(scene._handle_back() and scene._active_tab_name == "Missions", "Back returns to missions")
	_check(not scene._handle_back(), "Root back is distinguished from in-app navigation")
	missions._daily_scroll.scroll_vertical = 100000
	await get_tree().create_timer(0.3).timeout
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../tmp/journey_weekly_360.png"))
	_check(missions._daily_scroll.get_global_rect().encloses(missions._weekly_vbox.get_global_rect()), "Entire weekly mission reachable at end of scroll")
	_check(missions.global_position.y >= scene.vitals_section.global_position.y + scene.vitals_section.size.y, "Mission content remains below navigation after switching tabs")
	scene._on_nav_pressed("Boutique")
	engine.set_language("en")
	engine.missions_changed.emit()
	_check(missions._needs_rebuild, "Hidden mission updates wait until screen is shown")
	scene._handle_back()
	await get_tree().create_timer(0.4).timeout
	_check(missions._built_locale == "en" and not missions._needs_rebuild, "Returning rebuilds updated missions in current language")
	_check(missions.global_position.y >= scene.vitals_section.global_position.y + scene.vitals_section.size.y, "Hidden locale changes preserve mission panel position")
	engine.set_language("fr")
	var active_mission: Dictionary = engine.available_missions[0]
	active_mission["status"] = "in_progress"
	active_mission["started_at"] = Time.get_unix_time_from_system()
	missions._on_missions_changed()
	await get_tree().create_timer(0.3).timeout
	var active_widget: Dictionary = missions._validation_widgets[0]
	_check(engine.update_mission_proof(active_mission, "  Note de test  ", false), "Active mission accepts draft through manager")
	_check(active_mission["proof_text"] == "Note de test", "Draft uses normalized mission proof")
	_check(not engine.update_mission_proof(active_mission.duplicate(), "Foreign note", false), "Detached draft cannot modify owned mission")
	await get_tree().create_timer(0.8).timeout
	var draft_save: Dictionary = engine.save_system._read_save(SaveSystem.SAVE_PATH)
	_check(draft_save["available_missions"][0]["proof_text"] == "Note de test", "Draft saved without field losing focus")
	_check(engine._proof_save_remaining < 0.0, "Draft save timer stops after writing")
	var hp_before: int = engine.player_data.hp
	active_widget["abandon_button"].pressed.emit()
	_check(active_mission["status"] == "in_progress" and engine.player_data.hp == hp_before, "Abandon first tap does not fail mission or remove health")
	_check(active_widget["abandon_box"].visible, "Abandon displays confirmation")
	active_widget["keep_button"].pressed.emit()
	_check(not active_widget["abandon_box"].visible and active_mission["status"] == "in_progress", "Keeping quest cancels abandonment")
	active_widget["abandon_button"].pressed.emit()
	missions._daily_scroll.scroll_vertical = 0
	await get_tree().create_timer(0.3).timeout
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../tmp/journey_abandon_360.png"))
	active_widget["confirm_abandon_button"].pressed.emit()
	_check(active_mission["status"] == "failed", "Confirmed abandonment applies mission failure")
	await get_tree().create_timer(1.0).timeout
	scene._popup_manager.dismiss_top_popup()
	scene._on_nav_pressed("Campement")
	var base_panel = scene._empty_tab_panels["Campement"]
	var original_base: Dictionary = engine.base_manager.to_dict()
	engine.base_manager.from_dict({})
	engine.base_manager.base_changed.emit()
	base_panel._show_details("sanctuary")
	_check(base_panel._upgrade_button.disabled, "Base blocks upgrades without earned materials")
	for i in range(4): engine.base_manager.award_mission_materials("WIL", 0)
	_check(not base_panel._upgrade_button.disabled, "Mission materials unlock first base improvement")
	base_panel._upgrade_button.pressed.emit()
	_check(engine.base_manager.building_levels["sanctuary"] == 1, "Base upgrade button builds sanctuary")
	_check(engine.base_manager.materials["shadow_crystal"] == 4 and engine.base_manager.materials["dungeon_stone"] == 0, "Base upgrade consumes exact earned materials")
	var base_save: Dictionary = engine.save_system._read_save(SaveSystem.SAVE_PATH)
	_check(base_save["base"]["building_levels"]["sanctuary"] == 1, "Base upgrade persists")
	_check(base_save["metrics"]["milestones"].has("base_upgraded"), "Successful base action persists local milestone")
	_check(engine.base_manager.get_passive_bonuses()["WIL"] == 1 and engine.base_manager.get_passive_bonuses()["STAMINA"] == 5, "Sanctuary provides displayed passive bonuses")
	await get_tree().create_timer(0.4).timeout
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../tmp/journey_base_360.png"))
	_check(scene._handle_back() and scene._active_tab_name == "Campement" and not base_panel._detail_panel.visible, "Back closes base details before leaving base")
	await get_tree().process_frame
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../tmp/journey_base_scene_360.png"))
	engine.base_manager.from_dict(original_base)
	engine.base_manager.base_changed.emit()
	engine.save_game()
	scene._on_nav_pressed("Social")
	var fx_before: float = base_panel._fx_time
	var atmosphere_before: float = base_panel._atmosphere_layer.elapsed
	_check(not base_panel.is_processing() and not base_panel._bird_layer.is_processing() and not base_panel._atmosphere_layer.is_processing(), "Hidden base disables all decorative process loops")
	var social = scene._empty_tab_panels["Social"]
	var shared: String = social.share_text()
	_check(shared.contains(engine.player_name) and shared.contains("IRL Leveling"), "Social summary identifies player and game")
	_check(not shared.contains("Note de test") and not shared.contains("proof_text"), "Social summary excludes private mission notes")
	_check(social._availability.text == engine.loc("social.offline"), "Social screen identifies unavailable online features")
	await get_tree().create_timer(0.3).timeout
	_check(base_panel._fx_time == fx_before and base_panel._atmosphere_layer.elapsed == atmosphere_before, "Hidden base animations remain suspended across frames")
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../tmp/journey_social_360.png"))
	_check(social._copy.size.y * absf(social._copy.get_screen_transform().get_scale().y) >= 44.0, "Social copy action has mobile touch target")
	scene._on_nav_pressed("Campement")
	await get_tree().create_timer(0.1).timeout
	_check(base_panel.is_processing() and base_panel._fx_time > fx_before and base_panel._atmosphere_layer.elapsed > atmosphere_before, "Returning to base resumes visual animation")
	root.size = Vector2i(360, 640)
	var popup = scene._popup_manager
	var long_item := {"name": "Armure de protection renforcee des anciens gardiens du sanctuaire", "type": "armor", "rarity": "legendary", "base_power": 999, "stat_bonuses": {"STR": 12, "INT": 12, "WIL": 12, "AGI": 12, "HP": 12, "STAMINA": 12}}
	popup.show_item_details(long_item, "Equiper", func(): pass, "Ameliorer", func(): pass, "Recycler", func(): pass)
	await get_tree().create_timer(1.0).timeout
	_check(popup._item_popup.get_global_rect().encloses(popup._item_close_button.get_global_rect()), "Long item close action remains on small screen")
	_check(popup._item_popup.get_global_rect().encloses(popup._item_name_label.get_global_rect()), "Long item title remains on small screen")
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../tmp/journey_item_360.png"))
	popup.dismiss_top_popup()
	scene._on_nav_pressed("Options")
	var options = scene._empty_tab_panels["Options"]
	var original_language: String = engine.get_language()
	var original_music: float = engine.get_music_volume()
	var original_sfx: float = engine.get_sfx_volume()
	var original_muted: bool = engine.is_audio_muted()
	options._french_button.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	_check(engine.get_language() == "fr" and options._french_button.button_pressed and not options._english_button.button_pressed, "Options language selection stays exclusive")
	for control in [options._french_button, options._mute_button, options._music_slider, options._sfx_slider]:
		_check(control.size.y * absf(control.get_screen_transform().get_scale().y) >= 44.0, "Options control has mobile touch height")
	options._music_slider.value = 37
	options._sfx_slider.value = 63
	_check(is_equal_approx(engine.get_music_volume(), 0.37) and options._music_value_label.text == "37%", "Music slider updates volume and readable value")
	_check(is_equal_approx(engine.get_sfx_volume(), 0.63) and options._sfx_value_label.text == "63%", "Effects slider updates volume and readable value")
	options._mute_button.button_pressed = not original_muted
	_check(engine.is_audio_muted() != original_muted, "Sound toggle changes mute state")
	options._options_scroll.ensure_control_visible(options._sfx_slider)
	await get_tree().create_timer(0.3).timeout
	_check(options._options_scroll.get_global_rect().encloses(options._sfx_slider.get_global_rect()), "Last audio setting remains accessible on small screen")
	_check(not options._music_slider.scrollable and not options._sfx_slider.scrollable, "Scrolling options does not adjust volume by wheel")
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../../tmp/options_360.png"))
	engine.set_music_volume(original_music)
	engine.set_sfx_volume(original_sfx)
	engine.set_audio_muted(original_muted)
	engine.set_language(original_language)
	scene.queue_free()
	await get_tree().process_frame
