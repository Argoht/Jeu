extends Control

const HUNTER_ATLASES = [
	preload("res://Assets/Avatar/Hunter/hunter_idle_0.png"),
	preload("res://Assets/Avatar/Hunter/hunter_idle_1.png"),
	preload("res://Assets/Avatar/Hunter/hunter_idle_2.png"),
	preload("res://Assets/Avatar/Hunter/hunter_idle_3.png"),
	preload("res://Assets/Avatar/Hunter/hunter_idle_4.png"),
	preload("res://Assets/Avatar/Hunter/hunter_idle_5.png"),
	preload("res://Assets/Avatar/Hunter/hunter_idle_6.png"),
	preload("res://Assets/Avatar/Hunter/hunter_idle_7.png"),
	preload("res://Assets/Avatar/Hunter/hunter_idle_8.png")]
const HUNTER_FRAME_SIZE := Vector2(256, 384)
const HUNTER_CELL_SIZE := Vector2(260, 388)
const HUNTER_FRAME_COUNT := 300
const HUNTER_FPS := 60.0
const HUNTER_LOOP_SECONDS := 2.0 * (HUNTER_FRAME_COUNT - 1) / HUNTER_FPS
var _hunter_elapsed := 0.0
var _hunter_frame := 0
var _hunter_material: ShaderMaterial

var _background_video: VideoStreamPlayer
var _ground_shadow: ColorRect
var _scroll_viewport: ScrollContainer
var _application_suspended := false

func _ready() -> void:
	custom_minimum_size = Vector2(180, 560)
	get_parent().custom_minimum_size.y = 560
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	clip_contents = true
	_hunter_material = ShaderMaterial.new()
	_hunter_material.shader = preload("res://Scripts/Avatar/hunter_interpolation.gdshader")
	material = _hunter_material
	_update_hunter_blend()
	_load_background()
	_load_ground_shadow()
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			_scroll_viewport = ancestor
			_scroll_viewport.get_v_scroll_bar().value_changed.connect(func(_value): _sync_animation_visibility())
			break
		ancestor = ancestor.get_parent()
	visibility_changed.connect(_sync_animation_visibility)
	resized.connect(_layout_background)
	_sync_animation_visibility()

func _sync_animation_visibility() -> void:
	var active := is_visible_in_tree() and not _application_suspended
	if active and is_instance_valid(_scroll_viewport):
		active = get_global_rect().intersects(_scroll_viewport.get_global_rect())
	set_process(active)
	if is_instance_valid(_background_video):
		_background_video.paused = not active

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_application_suspended = true
		_sync_animation_visibility()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_application_suspended = false
		_sync_animation_visibility()

func _frame_at_time(seconds: float) -> int:
	return int(floor(_pose_at_time(seconds) + 0.00001))

func _pose_at_time(seconds: float) -> float:
	var step := fposmod(seconds, HUNTER_LOOP_SECONDS) * HUNTER_FPS
	return minf(step, 2.0 * (HUNTER_FRAME_COUNT - 1) - step)

func _region_for_frame(frame: int) -> Vector4:
	var cell := frame % 35
	var origin := Vector2(cell % 7, cell / 7) * HUNTER_CELL_SIZE + Vector2(2, 2)
	var atlas_size: Vector2 = HUNTER_ATLASES[frame / 35].get_size()
	return Vector4(origin.x / atlas_size.x, origin.y / atlas_size.y, HUNTER_FRAME_SIZE.x / atlas_size.x, HUNTER_FRAME_SIZE.y / atlas_size.y)

func _update_hunter_blend() -> void:
	var pose := _pose_at_time(_hunter_elapsed)
	var next_frame := mini(_hunter_frame + 1, HUNTER_FRAME_COUNT - 1)
	_hunter_material.set_shader_parameter("current_region", _region_for_frame(_hunter_frame))
	_hunter_material.set_shader_parameter("next_region", _region_for_frame(next_frame))
	_hunter_material.set_shader_parameter("next_atlas", HUNTER_ATLASES[next_frame / 35])
	_hunter_material.set_shader_parameter("frame_mix", clampf(pose - _hunter_frame, 0.0, 1.0))

func _process(delta: float) -> void:
	_hunter_elapsed = fposmod(_hunter_elapsed + delta, HUNTER_LOOP_SECONDS)
	var next_frame := _frame_at_time(_hunter_elapsed)
	if next_frame != _hunter_frame:
		_hunter_frame = next_frame
		queue_redraw()
	_update_hunter_blend()

func _hunter_rect() -> Rect2:
	var available := Vector2(maxf(size.x - 16.0, 1.0), maxf(size.y - 80.0, 1.0))
	var factor := minf(available.x / HUNTER_FRAME_SIZE.x, available.y / HUNTER_FRAME_SIZE.y)
	var drawn_size := HUNTER_FRAME_SIZE * factor
	return Rect2(Vector2((size.x - drawn_size.x) * 0.5, 64.0 + (available.y - drawn_size.y) * 0.5), drawn_size)

func set_avatar_state(_level: int, _rank: String, _equipment: Dictionary) -> void:
	# This baked appearance is independent of gameplay equipment and stats.
	queue_redraw()

func _draw() -> void:
	var cell := _hunter_frame % 35
	var origin := Vector2(cell % 7, cell / 7) * HUNTER_CELL_SIZE + Vector2(2, 2)
	draw_texture_rect_region(HUNTER_ATLASES[_hunter_frame / 35], _hunter_rect(), Rect2(origin, HUNTER_FRAME_SIZE))

func _layout_background() -> void:
	if not is_instance_valid(_background_video):
		return
	var source_size := Vector2(432, 768)
	var factor := maxf(size.x / source_size.x, size.y / source_size.y)
	_background_video.size = source_size * factor
	_background_video.position = (size - _background_video.size) * 0.5
	if is_instance_valid(_ground_shadow):
		var hunter_rect := _hunter_rect()
		_ground_shadow.position = hunter_rect.position
		_ground_shadow.size = hunter_rect.size
	_sync_animation_visibility()

func _load_ground_shadow() -> void:
	_ground_shadow = ColorRect.new()
	_ground_shadow.name = "HunterGroundShadow"
	_ground_shadow.show_behind_parent = true
	_ground_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = preload("res://Scripts/Avatar/hunter_ground_shadow.gdshader")
	_ground_shadow.material = shadow_material
	add_child(_ground_shadow)
	_layout_background()

func _load_background() -> void:
	_background_video = VideoStreamPlayer.new()
	_background_video.name = "AnimatedForest"
	_background_video.expand = true
	_background_video.loop = true
	_background_video.show_behind_parent = true
	_background_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background_video.stream = preload("res://Assets/Avatar/Backgrounds/forest_animated_120.ogv")
	_background_video.volume = 0.0
	add_child(_background_video)
	_layout_background()
	_background_video.play()
