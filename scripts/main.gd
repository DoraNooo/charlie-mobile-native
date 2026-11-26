extends Node2D
## Main game orchestrator for CHARLIE — De l'atome au cosmos (Godot 4.3+ Mobile).
## Programmatically builds the GPU background, Camera2D, Charlie, Ecosystem,
## AudioEngine, CutscenePlayer, evolving lava spit & shockwave VFX, HUD,
## multi-touch controls, safe-area layout, mobile lifecycle, and all menus/settings.

const SETTINGS_PATH: String = "user://settings.cfg"
const BG_SHADER_PATH: String = "res://shaders/biolum_bg.gdshader"
const DANGER_VIGNETTE_SHADER_PATH: String = "res://shaders/danger_vignette.gdshader"
const FONT_DISPLAY_PATH: String = "res://assets/fonts/Fraunces.ttf"
const FONT_UI_PATH: String = "res://assets/fonts/Outfit.ttf"
const COMBO_WINDOW: float = 1.9
const MAX_COMBO: int = 6
const PASSIVE_HEAL_SECONDS: float = 8.0

enum GameState {
	TITLE,
	CUTSCENE,
	PLAYING,
	PAUSED,
	DEFEAT,
	VICTORY,
}

# Settings & persistent records (saved to user://settings.cfg)
var difficulty_mode: String = "chill"
var bites_per_scale: int = 15
var cinematic_mode: bool = true
var haptics_enabled: bool = true
var audio_muted: bool = false
var best_scale: int = 1
var best_eaten: int = 0
var victories: int = 0

# Runtime state
var state: GameState = GameState.TITLE
var _options_return_state: GameState = GameState.TITLE
var current_scale_index: int = 0
var bites_in_scale: int = 0
var total_eaten: int = 0
var run_time: float = 0.0
var _heal_bite_counter: int = 0
var _time_since_hurt: float = 0.0
var _combo_count: int = 0
var _combo_timer: float = 0.0
var _spit_cd_left: float = 0.0
var _dash_cd_left: float = 0.0
var _free_roam_after_victory: bool = false
var _current_zoom: float = 1.25
var _camera_base_pos: Vector2 = Vector2.ZERO
var _last_cam_pos: Vector2 = Vector2.ZERO
var _bg_parallax: Vector2 = Vector2.ZERO
var _cam_lookahead: Vector2 = Vector2.ZERO
var _cam_trauma: float = 0.0
var _shake_time: float = 0.0
var _vfx_time: float = 0.0
var _title_swim_time: float = 0.0
var _predator_pulse_timer: float = 0.0
var _safe_insets: Rect2 = Rect2()

# Typography, theme & shared additive glow texture
var _font_display: Font = null
var _font_ui: Font = null
var _font_ui_bold: Font = null
var _ui_theme: Theme = null
var _glow_tex: GradientTexture2D = null

# Core nodes
var _bg_layer: CanvasLayer = null
var _bg_rect: ColorRect = null
var _bg_mat: ShaderMaterial = null
var _camera: Camera2D = null
var _ecosystem: Ecosystem = null
var _charlie: Charlie = null
var _vfx_layer: _WorldVfxLayer = null
var _audio: AudioEngine = null
var _cutscenes: CutscenePlayer = null

# World VFX state (lava spit projectiles, shockwaves, chomp/heal bursts, molten embers, scale warp veil)
var _projectiles: Array[Dictionary] = []
var _shockwaves: Array[Dictionary] = []
var _bursts: Array[Dictionary] = []
var _embers: Array[Dictionary] = []
var _warp_flash_life: float = 0.0
var _warp_flash_max: float = 0.85
var _warp_origin: Vector2 = Vector2.ZERO
var _warp_color: Color = Color(0.56, 0.94, 0.98, 1.0)
var _vfx_was_active: bool = false

# HUD nodes
var _hud_layer: CanvasLayer = null
var _danger_vignette: _DangerVignette = null
var _hud_root: Control = null
var _top_margin: MarginContainer = null
var _scale_label: Label = null
var _size_label: Label = null
var _lives_label: Label = null
var _progress_fill: TextureRect = null
var _progress_count_label: Label = null
var _mute_btn: _IconButton = null
var _pause_btn: _IconButton = null
var _joystick: VirtualJoystick = null
var _spit_btn: _TouchPowerButton = null
var _dash_btn: _TouchPowerButton = null

# Dirty-flagged HUD cache (zero redundant string/theme mutations or redraws)
var _hud_last_scale: int = -1
var _hud_last_size_str: String = ""
var _hud_last_droplets: int = -99
var _hud_last_diff_mode: String = ""
var _hud_last_crit_alpha_step: int = -1
var _hud_last_progress: float = -1.0
var _hud_last_progress_str: String = ""
var _hud_last_spit_cd: float = -1.0
var _hud_last_dash_cd: float = -1.0
var _hud_last_power_lvl: int = -1

# Floating poetic banner (scale transition & power evolution)
var _banner_panel: PanelContainer = null
var _banner_title: Label = null
var _banner_sub: Label = null
var _banner_queue: Array[Dictionary] = []
var _banner_active: bool = false
var _banner_elapsed: float = 0.0
var _banner_duration: float = 2.8

# Overlay menus
var _menu_layer: CanvasLayer = null
var _title_panel: Control = null
var _pause_panel: Control = null
var _options_panel: Control = null
var _options_scroll: ScrollContainer = null
var _defeat_panel: Control = null
var _victory_panel: Control = null
var _pause_stats_label: Label = null
var _defeat_stats_label: Label = null
var _victory_stats_label: Label = null
var _overlay_tween: Tween = null

# Options widgets
var _diff_buttons: Dictionary = {}
var _diff_desc_label: Label = null
var _bites_slider: HSlider = null
var _bites_value_label: Label = null
var _cinematic_toggle: CheckButton = null
var _haptics_toggle: CheckButton = null


class _WorldVfxLayer:
	extends Node2D
	var owner_main: Node2D = null

	func _draw() -> void:
		if owner_main != null:
			owner_main._draw_world_vfx(self)


class _DangerVignette:
	extends ColorRect
	## 1-pass GPU smooth radial crimson edge vignette (danger_vignette.gdshader).
	var intensity: float = 0.0
	var _mat: ShaderMaterial = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		color = Color.WHITE
		_mat = ShaderMaterial.new()
		var sh: Shader = load(DANGER_VIGNETTE_SHADER_PATH) as Shader
		if sh != null:
			_mat.shader = sh
		_mat.set_shader_parameter("intensity", 0.0)
		material = _mat
		visible = false

	func set_intensity(val: float) -> void:
		var clamped: float = clampf(val, 0.0, 1.0)
		if absf(clamped - intensity) > 0.004 or (clamped == 0.0 and intensity != 0.0):
			intensity = clamped
			if _mat != null:
				_mat.set_shader_parameter("intensity", intensity)
			visible = intensity > 0.004


class _ScaleTicksOverlay:
	extends Control
	## Draws 5 subtle scale tick marks across the sleek 8px pill progress bar.
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if w <= 8.0 or h <= 1.0:
			return
		var tick_col: Color = Color(1.0, 1.0, 1.0, 0.34)
		for i: int in range(1, 6):
			var x: float = w * (float(i) / 6.0)
			draw_line(Vector2(x, 1.0), Vector2(x, h - 1.0), tick_col, 1.0, false)


class _IconButton:
	extends Button
	## Circular HUD button that renders crisp anti-aliased vector icons instead of
	## emoji glyphs (which render as tofu boxes on Android/iOS default fonts).
	var icon_name: String = "sound_on"
	var icon_color: Color = Color(0.92, 0.97, 1.0, 0.96)

	func set_icon_name(new_icon: String) -> void:
		if icon_name != new_icon:
			icon_name = new_icon
			queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var s: float = minf(size.x, size.y) * 0.26
		var col: Color = icon_color
		match icon_name:
			"sound_on":
				var cone: PackedVector2Array = PackedVector2Array([
					c + Vector2(-s * 0.95, -s * 0.36),
					c + Vector2(-s * 0.42, -s * 0.36),
					c + Vector2(s * 0.14, -s * 0.84),
					c + Vector2(s * 0.14, s * 0.84),
					c + Vector2(-s * 0.42, s * 0.36),
					c + Vector2(-s * 0.95, s * 0.36),
				])
				draw_colored_polygon(cone, col)
				draw_arc(c + Vector2(s * 0.16, 0.0), s * 0.48, -0.78, 0.78, 16, col, 2.0, true)
				draw_arc(c + Vector2(s * 0.16, 0.0), s * 0.86, -0.84, 0.84, 20, Color(col.r, col.g, col.b, 0.82), 2.0, true)
			"sound_off":
				var muted_col: Color = Color(0.75, 0.84, 0.90, 0.78)
				var cone: PackedVector2Array = PackedVector2Array([
					c + Vector2(-s * 0.95, -s * 0.36),
					c + Vector2(-s * 0.42, -s * 0.36),
					c + Vector2(s * 0.14, -s * 0.84),
					c + Vector2(s * 0.14, s * 0.84),
					c + Vector2(-s * 0.42, s * 0.36),
					c + Vector2(-s * 0.95, s * 0.36),
				])
				draw_colored_polygon(cone, muted_col)
				var x_col: Color = Color(1.0, 0.46, 0.40, 0.96)
				draw_line(c + Vector2(s * 0.35, -s * 0.44), c + Vector2(s * 1.05, s * 0.44), x_col, 2.4, true)
				draw_line(c + Vector2(s * 1.05, -s * 0.44), c + Vector2(s * 0.35, s * 0.44), x_col, 2.4, true)
			"pause":
				var bar_w: float = s * 0.42
				var bar_h: float = s * 1.48
				var gap: float = s * 0.26
				draw_rect(Rect2(c.x - gap - bar_w, c.y - bar_h * 0.5, bar_w, bar_h), col, true)
				draw_rect(Rect2(c.x + gap, c.y - bar_h * 0.5, bar_w, bar_h), col, true)
			"gear":
				draw_arc(c, s * 0.62, 0.0, TAU, 24, col, 2.6, true)
				draw_arc(c, s * 0.24, 0.0, TAU, 16, col, 1.8, true)
				for i: int in range(8):
					var ang: float = float(i) * TAU / 8.0
					var dir: Vector2 = Vector2.from_angle(ang)
					draw_line(c + dir * (s * 0.72), c + dir * (s * 1.02), col, 2.8, true)


class _TouchPowerButton:
	extends Control
	## Multi-touch circular power button with anti-aliased vector icons,
	## translucent cooldown sweep sector, and floating Nv.X pill badge.
	signal activated

	var icon_kind: String = "flame" # "flame" | "shockwave"
	var hotkey_text: String = "F"
	var level_text: String = "Nv.1"
	var accent_color: Color = Color(1.0, 0.55, 0.30, 1.0)
	var cooldown_ratio: float = 0.0 # 0.0 = ready, 1.0 = full cooldown
	var glow_tex: Texture2D = null
	var badge_font: Font = null

	var _pressed_index: int = -1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(94.0, 94.0)
		size = custom_minimum_size

	func reset_touch() -> void:
		if _pressed_index != -1:
			_pressed_index = -1
			queue_redraw()

	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree():
			reset_touch()
			return
		if event is InputEventScreenTouch:
			var tev: InputEventScreenTouch = event as InputEventScreenTouch
			if tev.pressed:
				if _pressed_index == -1 and get_global_rect().grow(14.0).has_point(tev.position):
					_pressed_index = tev.index
					queue_redraw()
					activated.emit()
					get_viewport().set_input_as_handled()
			else:
				if tev.index == _pressed_index:
					_pressed_index = -1
					queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.43
		var is_ready: bool = cooldown_ratio <= 0.001
		var is_down: bool = _pressed_index != -1

		# Soft radial halo when ready
		if is_ready:
			var halo_r: float = r * (1.58 if is_down else 1.44)
			if glow_tex != null:
				draw_texture_rect(
					glow_tex,
					Rect2(center - Vector2(halo_r, halo_r), Vector2(halo_r * 2.0, halo_r * 2.0)),
					false,
					Color(accent_color.r, accent_color.g, accent_color.b, 0.42 if is_down else 0.28)
				)
			else:
				draw_circle(center, r * (1.16 if is_down else 1.10), Color(accent_color.r, accent_color.g, accent_color.b, 0.22))

		# Glassmorphic button fill
		var fill_col: Color = Color(0.04, 0.10, 0.17, 0.78)
		if is_down:
			fill_col = Color(accent_color.r * 0.36, accent_color.g * 0.28, accent_color.b * 0.26, 0.90)
		draw_circle(center, r, fill_col)

		# Subtle inner top highlight
		draw_arc(center, r - 1.5, -PI * 0.85, -PI * 0.15, 20, Color(1.0, 1.0, 1.0, 0.16), 1.5, true)

		# Translucent cooldown sweep sector (pie wedge covering remaining cooldown)
		if not is_ready:
			var cd_clamped: float = clampf(cooldown_ratio, 0.0, 1.0)
			var segs: int = maxi(4, int(ceil(cd_clamped * 28.0)))
			var wedge: PackedVector2Array = PackedVector2Array()
			wedge.append(center)
			var start_a: float = -PI * 0.5
			var end_a: float = start_a + TAU * cd_clamped
			for i: int in range(segs + 1):
				var ang: float = lerpf(start_a, end_a, float(i) / float(segs))
				wedge.append(center + Vector2(cos(ang), sin(ang)) * (r - 1.5))
			draw_colored_polygon(wedge, Color(0.01, 0.04, 0.08, 0.56))

		# Crisp vector icon (Flame or Concentric Shockwave / Bolt)
		var icon_alpha: float = 1.0 if is_ready else 0.45
		var icon_center: Vector2 = center + Vector2(0.0, -3.0)
		if icon_kind == "flame":
			_draw_flame_icon(icon_center, r * 0.54, icon_alpha)
		else:
			_draw_shockwave_icon(icon_center, r * 0.54, icon_alpha)

		# Outer ring + cooldown progress arc
		var ring_col: Color = Color(accent_color.r, accent_color.g, accent_color.b, 0.92) if is_ready else Color(0.60, 0.74, 0.82, 0.34)
		draw_arc(center, r, 0.0, TAU, 44, ring_col, 2.6 if is_ready else 1.8, true)
		if not is_ready:
			var ready_frac: float = clampf(1.0 - cooldown_ratio, 0.0, 1.0)
			draw_arc(center, r - 2.0, -PI * 0.5, -PI * 0.5 + TAU * ready_frac, 36, accent_color, 3.2, true)

		# Floating Nv.X pill badge at bottom edge
		var font: Font = badge_font if badge_font != null else ThemeDB.fallback_font
		if font != null:
			var badge_str: String = level_text if OS.has_feature("mobile") or hotkey_text.is_empty() else "%s · %s" % [level_text, hotkey_text]
			var txt_size: Vector2 = font.get_string_size(badge_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
			var pad_x: float = 8.0
			var pill_w: float = txt_size.x + pad_x * 2.0
			var pill_h: float = 17.0
			var pill_pos: Vector2 = Vector2(center.x - pill_w * 0.5, center.y + r - pill_h * 0.62)
			var pill_rect: Rect2 = Rect2(pill_pos, Vector2(pill_w, pill_h))
			var pill_bg: StyleBoxFlat = StyleBoxFlat.new()
			pill_bg.bg_color = Color(0.03, 0.08, 0.14, 0.92)
			pill_bg.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.78 if is_ready else 0.35)
			pill_bg.set_border_width_all(1)
			pill_bg.set_corner_radius_all(9)
			draw_style_box(pill_bg, pill_rect)
			var text_pos: Vector2 = Vector2(center.x - txt_size.x * 0.5, pill_pos.y + pill_h - 4.5)
			draw_string(font, text_pos, badge_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.98, 0.96, 0.92, 0.96 if is_ready else 0.55))

	func _draw_flame_icon(c: Vector2, s: float, alpha: float) -> void:
		var outer_col: Color = Color(1.0, 0.48, 0.26, alpha)
		var inner_col: Color = Color(1.0, 0.86, 0.48, alpha)
		var outer: PackedVector2Array = PackedVector2Array([
			c + Vector2(0.0, -s * 1.05),
			c + Vector2(s * 0.48, -s * 0.32),
			c + Vector2(s * 0.68, s * 0.26),
			c + Vector2(s * 0.46, s * 0.78),
			c + Vector2(0.0, s * 0.96),
			c + Vector2(-s * 0.46, s * 0.78),
			c + Vector2(-s * 0.68, s * 0.26),
			c + Vector2(-s * 0.44, -s * 0.24),
			c + Vector2(-s * 0.16, -s * 0.56),
		])
		draw_colored_polygon(outer, outer_col)
		var inner: PackedVector2Array = PackedVector2Array([
			c + Vector2(0.0, -s * 0.32),
			c + Vector2(s * 0.28, s * 0.20),
			c + Vector2(s * 0.24, s * 0.62),
			c + Vector2(0.0, s * 0.78),
			c + Vector2(-s * 0.24, s * 0.62),
			c + Vector2(-s * 0.28, s * 0.20),
		])
		draw_colored_polygon(inner, inner_col)

	func _draw_shockwave_icon(c: Vector2, s: float, alpha: float) -> void:
		var ring_col: Color = Color(0.45, 0.94, 0.98, alpha * 0.88)
		var bolt_col: Color = Color(0.94, 0.99, 1.0, alpha)
		# Concentric ripple arcs
		draw_arc(c, s * 0.92, -PI * 0.72, -PI * 0.18, 16, Color(ring_col.r, ring_col.g, ring_col.b, alpha * 0.52), 2.0, true)
		draw_arc(c, s * 0.92, PI * 0.28, PI * 0.82, 16, Color(ring_col.r, ring_col.g, ring_col.b, alpha * 0.52), 2.0, true)
		draw_arc(c, s * 0.62, 0.0, TAU, 24, ring_col, 2.0, true)
		# Crisp central energy bolt
		var bolt: PackedVector2Array = PackedVector2Array([
			c + Vector2(s * 0.14, -s * 0.76),
			c + Vector2(-s * 0.34, s * 0.06),
			c + Vector2(-s * 0.02, s * 0.06),
			c + Vector2(-s * 0.16, s * 0.76),
			c + Vector2(s * 0.34, -s * 0.08),
			c + Vector2(s * 0.02, -s * 0.08),
		])
		draw_colored_polygon(bolt, bolt_col)


func _ready() -> void:
	get_tree().set_quit_on_go_back(false)
	load_settings()
	_setup_fonts_and_vfx_resources()
	_setup_background()
	_setup_world()
	_setup_audio_and_cutscenes()
	_setup_hud()
	_setup_menus()
	_apply_settings_to_systems()
	get_viewport().size_changed.connect(_update_safe_area)
	_update_safe_area()
	_enter_title_screen()


func _make_font_variation(base: Font, weight: int) -> Font:
	if base == null:
		return null
	var fv: FontVariation = FontVariation.new()
	fv.base_font = base
	var ts: TextServer = TextServerManager.get_primary_interface()
	if ts != null:
		fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	return fv


func _setup_fonts_and_vfx_resources() -> void:
	if ResourceLoader.exists(FONT_DISPLAY_PATH):
		var display_base: Font = load(FONT_DISPLAY_PATH) as Font
		_font_display = _make_font_variation(display_base, 680)
	if ResourceLoader.exists(FONT_UI_PATH):
		var ui_base: Font = load(FONT_UI_PATH) as Font
		_font_ui = _make_font_variation(ui_base, 450)
		_font_ui_bold = _make_font_variation(ui_base, 650)

	_ui_theme = Theme.new()
	if _font_ui != null:
		_ui_theme.default_font = _font_ui
		_ui_theme.default_font_size = 15

	# Shared 64x64 soft radial glow texture (white alpha 1.0 -> 0.0) for additive-feeling VFX
	var glow_grad: Gradient = Gradient.new()
	glow_grad.offsets = PackedFloat32Array([0.0, 0.28, 0.65, 1.0])
	glow_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.62),
		Color(1.0, 1.0, 1.0, 0.16),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	_glow_tex = GradientTexture2D.new()
	_glow_tex.width = 64
	_glow_tex.height = 64
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.gradient = glow_grad


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_handle_back_request()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_reset_all_touch_inputs()
			if state == GameState.PLAYING:
				_on_pause_pressed()
			if _audio != null and _audio.has_method("set_app_paused"):
				_audio.set_app_paused(true)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			if _audio != null and _audio.has_method("set_app_paused"):
				_audio.set_app_paused(false)


func _handle_back_request() -> void:
	if _options_panel != null and _options_panel.visible:
		_close_options()
	elif state == GameState.CUTSCENE:
		if _cutscenes != null and _cutscenes.has_method("skip_cutscene"):
			_cutscenes.skip_cutscene()
	elif state == GameState.PLAYING:
		_on_pause_pressed()
	elif state == GameState.PAUSED:
		_resume_game()
	elif state == GameState.DEFEAT or state == GameState.VICTORY:
		_enter_title_screen()
	else:
		get_tree().quit()


func _compute_safe_area_insets() -> Rect2:
	var win_size: Vector2i = DisplayServer.window_get_size()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	if win_size.x <= 0 or win_size.y <= 0 or vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return Rect2()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Rect2()
	var sx: float = vp_size.x / float(win_size.x)
	var sy: float = vp_size.y / float(win_size.y)
	var inset_left: float = maxf(0.0, float(safe.position.x) * sx)
	var inset_top: float = maxf(0.0, float(safe.position.y) * sy)
	var inset_right: float = maxf(0.0, float(win_size.x - (safe.position.x + safe.size.x)) * sx)
	var inset_bottom: float = maxf(0.0, float(win_size.y - (safe.position.y + safe.size.y)) * sy)
	return Rect2(inset_left, inset_top, inset_right, inset_bottom)


func _update_safe_area() -> void:
	var insets: Rect2 = _compute_safe_area_insets()
	_safe_insets = insets
	var left: float = insets.position.x
	var top: float = insets.position.y
	var right: float = insets.size.x
	var bottom: float = insets.size.y

	if _top_margin != null:
		_top_margin.add_theme_constant_override("margin_left", int(round(20.0 + left)))
		_top_margin.add_theme_constant_override("margin_right", int(round(20.0 + right)))
		_top_margin.add_theme_constant_override("margin_top", int(round(16.0 + top)))
		_top_margin.offset_bottom = 96.0 + top

	if _joystick != null:
		_joystick.offset_left = 26.0 + left
		_joystick.offset_right = 206.0 + left
		_joystick.offset_top = -208.0 - bottom
		_joystick.offset_bottom = -28.0 - bottom

	if _spit_btn != null:
		_spit_btn.offset_left = -224.0 - right
		_spit_btn.offset_right = -130.0 - right
		_spit_btn.offset_top = -126.0 - bottom
		_spit_btn.offset_bottom = -32.0 - bottom

	if _dash_btn != null:
		_dash_btn.offset_left = -118.0 - right
		_dash_btn.offset_right = -24.0 - right
		_dash_btn.offset_top = -148.0 - bottom
		_dash_btn.offset_bottom = -54.0 - bottom

	if _banner_panel != null:
		_banner_panel.offset_top = 104.0 + top
		_banner_panel.offset_bottom = 174.0 + top

	if _options_scroll != null:
		var vp_h: float = get_viewport().get_visible_rect().size.y
		var max_scroll_h: float = clampf(vp_h - top - bottom - 120.0, 200.0, 440.0)
		_options_scroll.custom_minimum_size = Vector2(0.0, max_scroll_h)

	if _cutscenes != null and _cutscenes.has_method("apply_safe_area"):
		_cutscenes.apply_safe_area(insets)


func _reset_all_touch_inputs() -> void:
	if _joystick != null:
		_joystick.reset_touch()
	if _spit_btn != null:
		_spit_btn.reset_touch()
	if _dash_btn != null:
		_dash_btn.reset_touch()


func _set_audio_ducked(ducked: bool) -> void:
	if _audio != null and _audio.has_method("set_ducked"):
		_audio.set_ducked(ducked)


func _vibrate(ms: int) -> void:
	if haptics_enabled and ms > 0:
		Input.vibrate_handheld(ms)


func _add_trauma(amount: float) -> void:
	_cam_trauma = minf(1.0, _cam_trauma + amount)


func _setup_background() -> void:
	_bg_layer = CanvasLayer.new()
	_bg_layer.name = "BackgroundLayer"
	_bg_layer.layer = -10
	add_child(_bg_layer)

	_bg_rect = ColorRect.new()
	_bg_rect.name = "BiolumBg"
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_mat = ShaderMaterial.new()
	var bg_shader: Shader = load(BG_SHADER_PATH) as Shader
	if bg_shader != null:
		_bg_mat.shader = bg_shader
	_bg_rect.material = _bg_mat
	_bg_layer.add_child(_bg_rect)


func _setup_world() -> void:
	_ecosystem = Ecosystem.new()
	_ecosystem.name = "Ecosystem"
	add_child(_ecosystem)

	_vfx_layer = _WorldVfxLayer.new()
	_vfx_layer.name = "WorldVfxLayer"
	_vfx_layer.owner_main = self
	_vfx_layer.z_index = 4
	add_child(_vfx_layer)

	_charlie = Charlie.new()
	_charlie.name = "Charlie"
	_charlie.z_index = 5
	add_child(_charlie)

	_camera = Camera2D.new()
	_camera.name = "MainCamera"
	_camera.enabled = true
	_camera.position_smoothing_enabled = false
	add_child(_camera)


func _setup_audio_and_cutscenes() -> void:
	_audio = AudioEngine.new()
	_audio.name = "AudioEngine"
	add_child(_audio)

	_cutscenes = CutscenePlayer.new()
	_cutscenes.name = "CutscenePlayer"
	add_child(_cutscenes)


func _apply_hud_text_shadow(lbl: Label) -> void:
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.03, 0.07, 0.85))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_constant_override("shadow_outline_size", 4)


func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HudLayer"
	_hud_layer.layer = 10
	add_child(_hud_layer)

	# 1-pass GPU smooth radial crimson danger vignette behind HUD elements
	_danger_vignette = _DangerVignette.new()
	_danger_vignette.name = "DangerVignette"
	_hud_layer.add_child(_danger_vignette)

	_hud_root = Control.new()
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _ui_theme != null:
		_hud_root.theme = _ui_theme
	_hud_layer.add_child(_hud_root)

	# Top bar container
	_top_margin = MarginContainer.new()
	_top_margin.anchor_left = 0.0
	_top_margin.anchor_top = 0.0
	_top_margin.anchor_right = 1.0
	_top_margin.anchor_bottom = 0.0
	_top_margin.offset_bottom = 96.0
	_top_margin.add_theme_constant_override("margin_left", 20)
	_top_margin.add_theme_constant_override("margin_right", 20)
	_top_margin.add_theme_constant_override("margin_top", 16)
	_top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_top_margin)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 20)
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_margin.add_child(top_row)

	# Left floating info (no heavy opaque box — sleek floating typography + glowing droplets)
	var left_col: VBoxContainer = VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 2)
	left_col.alignment = BoxContainer.ALIGNMENT_CENTER
	left_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(left_col)

	_scale_label = Label.new()
	_scale_label.text = "I · Quantique"
	if _font_display != null:
		_scale_label.add_theme_font_override("font", _font_display)
	_scale_label.add_theme_font_size_override("font_size", 18)
	_scale_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.66, 1.0))
	_apply_hud_text_shadow(_scale_label)
	left_col.add_child(_scale_label)

	var sub_row: HBoxContainer = HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 10)
	sub_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_col.add_child(sub_row)

	_size_label = Label.new()
	_size_label.text = "0.1 nm"
	if _font_ui_bold != null:
		_size_label.add_theme_font_override("font", _font_ui_bold)
	_size_label.add_theme_font_size_override("font_size", 13)
	_size_label.add_theme_color_override("font_color", Color(0.76, 0.95, 0.98, 0.94))
	_apply_hud_text_shadow(_size_label)
	sub_row.add_child(_size_label)

	_lives_label = Label.new()
	_lives_label.text = "●●●"
	_lives_label.add_theme_font_size_override("font_size", 13)
	_lives_label.add_theme_color_override("font_color", Color(1.0, 0.56, 0.44, 1.0))
	_apply_hud_text_shadow(_lives_label)
	sub_row.add_child(_lives_label)

	# Center sleek 8px pill progress bar with teal -> gold -> coral gradient & 5 scale ticks
	var center_col: VBoxContainer = VBoxContainer.new()
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.alignment = BoxContainer.ALIGNMENT_CENTER
	center_col.add_theme_constant_override("separation", 5)
	center_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(center_col)

	var bar_track: Panel = Panel.new()
	bar_track.custom_minimum_size = Vector2(180.0, 8.0)
	bar_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_track.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var track_style: StyleBoxFlat = StyleBoxFlat.new()
	track_style.bg_color = Color(0.03, 0.09, 0.15, 0.64)
	track_style.border_color = Color(1.0, 1.0, 1.0, 0.14)
	track_style.set_border_width_all(1)
	track_style.set_corner_radius_all(4)
	bar_track.add_theme_stylebox_override("panel", track_style)
	center_col.add_child(bar_track)

	var bar_grad: Gradient = Gradient.new()
	bar_grad.offsets = PackedFloat32Array([0.0, 0.52, 1.0])
	bar_grad.colors = PackedColorArray([
		Color("#4fd1c5"), # Luminous teal
		Color("#ffd166"), # Warm storybook gold
		Color("#ff6f61"), # Molten coral
	])
	var bar_tex: GradientTexture2D = GradientTexture2D.new()
	bar_tex.width = 256
	bar_tex.height = 8
	bar_tex.fill = GradientTexture2D.FILL_LINEAR
	bar_tex.fill_from = Vector2(0.0, 0.5)
	bar_tex.fill_to = Vector2(1.0, 0.5)
	bar_tex.gradient = bar_grad

	_progress_fill = TextureRect.new()
	_progress_fill.texture = bar_tex
	_progress_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_progress_fill.stretch_mode = TextureRect.STRETCH_SCALE
	_progress_fill.anchor_left = 0.0
	_progress_fill.anchor_top = 0.0
	_progress_fill.anchor_right = 0.0
	_progress_fill.anchor_bottom = 1.0
	_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_track.add_child(_progress_fill)

	var ticks_overlay: _ScaleTicksOverlay = _ScaleTicksOverlay.new()
	bar_track.add_child(ticks_overlay)

	_progress_count_label = Label.new()
	_progress_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_count_label.text = "0 / 15"
	if _font_ui_bold != null:
		_progress_count_label.add_theme_font_override("font", _font_ui_bold)
	_progress_count_label.add_theme_font_size_override("font_size", 12)
	_progress_count_label.add_theme_color_override("font_color", Color(0.88, 0.95, 0.99, 0.90))
	_apply_hud_text_shadow(_progress_count_label)
	center_col.add_child(_progress_count_label)

	# Right action buttons (Audio & Pause with crisp vector icons)
	var right_row: HBoxContainer = HBoxContainer.new()
	right_row.add_theme_constant_override("separation", 10)
	right_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_child(right_row)

	_mute_btn = _make_hud_icon_button("sound_off" if audio_muted else "sound_on")
	_mute_btn.pressed.connect(_on_toggle_mute)
	right_row.add_child(_mute_btn)

	_pause_btn = _make_hud_icon_button("pause")
	_pause_btn.pressed.connect(_on_pause_pressed)
	right_row.add_child(_pause_btn)

	# Floating poetic scale / power evolution banner
	_banner_panel = PanelContainer.new()
	_banner_panel.name = "FloatingBanner"
	_banner_panel.anchor_left = 0.5
	_banner_panel.anchor_top = 0.0
	_banner_panel.anchor_right = 0.5
	_banner_panel.anchor_bottom = 0.0
	_banner_panel.offset_left = -230.0
	_banner_panel.offset_right = 230.0
	_banner_panel.offset_top = 104.0
	_banner_panel.offset_bottom = 176.0
	_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var banner_style: StyleBoxFlat = _make_glass_box(20)
	banner_style.content_margin_top = 10.0
	banner_style.content_margin_bottom = 10.0
	banner_style.content_margin_left = 22.0
	banner_style.content_margin_right = 22.0
	_banner_panel.add_theme_stylebox_override("panel", banner_style)
	_banner_panel.visible = false
	_hud_root.add_child(_banner_panel)

	var banner_col: VBoxContainer = VBoxContainer.new()
	banner_col.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_col.add_theme_constant_override("separation", 2)
	banner_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner_panel.add_child(banner_col)

	_banner_title = Label.new()
	_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font_display != null:
		_banner_title.add_theme_font_override("font", _font_display)
	_banner_title.add_theme_font_size_override("font_size", 19)
	_banner_title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.56, 1.0))
	_banner_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_col.add_child(_banner_title)

	_banner_sub = Label.new()
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.add_theme_font_size_override("font_size", 13)
	_banner_sub.add_theme_color_override("font_color", Color(0.76, 0.94, 0.98, 0.92))
	_banner_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_col.add_child(_banner_sub)

	# Bottom-left VirtualJoystick
	_joystick = VirtualJoystick.new()
	_joystick.name = "VirtualJoystick"
	_joystick.anchor_left = 0.0
	_joystick.anchor_top = 1.0
	_joystick.anchor_right = 0.0
	_joystick.anchor_bottom = 1.0
	_joystick.offset_left = 26.0
	_joystick.offset_top = -208.0
	_joystick.offset_right = 206.0
	_joystick.offset_bottom = -28.0
	_hud_root.add_child(_joystick)

	# Bottom-right multi-touch power buttons (Flame / F & Shockwave / E)
	_spit_btn = _TouchPowerButton.new()
	_spit_btn.name = "SpitButton"
	_spit_btn.icon_kind = "flame"
	_spit_btn.hotkey_text = "F"
	_spit_btn.accent_color = Color(1.0, 0.54, 0.30, 1.0)
	_spit_btn.glow_tex = _glow_tex
	_spit_btn.badge_font = _font_ui_bold
	_spit_btn.anchor_left = 1.0
	_spit_btn.anchor_top = 1.0
	_spit_btn.anchor_right = 1.0
	_spit_btn.anchor_bottom = 1.0
	_spit_btn.offset_left = -224.0
	_spit_btn.offset_top = -126.0
	_spit_btn.offset_right = -130.0
	_spit_btn.offset_bottom = -32.0
	_spit_btn.activated.connect(_trigger_lava_spit)
	_hud_root.add_child(_spit_btn)

	_dash_btn = _TouchPowerButton.new()
	_dash_btn.name = "DashButton"
	_dash_btn.icon_kind = "shockwave"
	_dash_btn.hotkey_text = "E"
	_dash_btn.accent_color = Color(0.42, 0.92, 0.96, 1.0)
	_dash_btn.glow_tex = _glow_tex
	_dash_btn.badge_font = _font_ui_bold
	_dash_btn.anchor_left = 1.0
	_dash_btn.anchor_top = 1.0
	_dash_btn.anchor_right = 1.0
	_dash_btn.anchor_bottom = 1.0
	_dash_btn.offset_left = -118.0
	_dash_btn.offset_top = -148.0
	_dash_btn.offset_right = -24.0
	_dash_btn.offset_bottom = -54.0
	_dash_btn.activated.connect(_trigger_shockwave_dash)
	_hud_root.add_child(_dash_btn)


func _setup_menus() -> void:
	_menu_layer = CanvasLayer.new()
	_menu_layer.name = "MenuLayer"
	_menu_layer.layer = 20
	add_child(_menu_layer)

	_build_title_panel()
	_build_pause_panel()
	_build_options_panel()
	_build_defeat_panel()
	_build_victory_panel()


func _build_title_panel() -> void:
	_title_panel = Control.new()
	_title_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _ui_theme != null:
		_title_panel.theme = _ui_theme
	_menu_layer.add_child(_title_panel)

	# Ultra-light atmospheric scrim so live swimming Charlie + quantum world shine right through!
	var scrim: ColorRect = ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.01, 0.04, 0.08, 0.16)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_panel.add_child(scrim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_panel.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(440.0, 0.0)
	card.add_theme_stylebox_override("panel", _make_glass_box(24))
	center.add_child(card)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 15)
	card.add_child(col)

	var title_lbl: Label = Label.new()
	title_lbl.text = "CHARLIE"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font_display != null:
		title_lbl.add_theme_font_override("font", _font_display)
	title_lbl.add_theme_font_size_override("font_size", 56)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.56, 1.0))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.96, 0.40, 0.24, 0.35))
	title_lbl.add_theme_constant_override("shadow_offset_y", 3)
	title_lbl.add_theme_constant_override("shadow_outline_size", 10)
	col.add_child(title_lbl)

	var sub_lbl: Label = Label.new()
	sub_lbl.text = "De l'atome au cosmos"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font_display != null:
		sub_lbl.add_theme_font_override("font", _font_display)
	sub_lbl.add_theme_font_size_override("font_size", 20)
	sub_lbl.add_theme_color_override("font_color", Color(0.74, 0.94, 0.96, 0.94))
	col.add_child(sub_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = "Guide la petite Charlie, une goutte de lave aux deux petites dents, à travers 6 mondes bioluminescents."
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", Color(0.88, 0.93, 0.97, 0.86))
	col.add_child(desc_lbl)

	var play_btn: Button = _make_menu_button("Plonger", true)
	play_btn.pressed.connect(_on_start_game)
	col.add_child(play_btn)

	var opt_btn: Button = _make_menu_button("Options", false)
	opt_btn.pressed.connect(func() -> void: _open_options(GameState.TITLE))
	col.add_child(opt_btn)


func _build_pause_panel() -> void:
	_pause_panel = _make_overlay_backdrop()
	_menu_layer.add_child(_pause_panel)

	var card: PanelContainer = _add_centered_card(_pause_panel, 420.0)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)

	col.add_child(_make_heading("Pause"))

	_pause_stats_label = _make_stats_label()
	col.add_child(_pause_stats_label)

	var resume_btn: Button = _make_menu_button("Reprendre", true)
	resume_btn.pressed.connect(_resume_game)
	col.add_child(resume_btn)

	var opt_btn: Button = _make_menu_button("Options", false)
	opt_btn.pressed.connect(func() -> void: _open_options(GameState.PAUSED))
	col.add_child(opt_btn)

	var restart_btn: Button = _make_menu_button("Recommencer", false)
	restart_btn.pressed.connect(_on_start_game)
	col.add_child(restart_btn)

	var menu_btn: Button = _make_menu_button("Menu principal", false)
	menu_btn.pressed.connect(_enter_title_screen)
	col.add_child(menu_btn)


func _build_options_panel() -> void:
	_options_panel = _make_overlay_backdrop()
	_menu_layer.add_child(_options_panel)

	var card: PanelContainer = _add_centered_card(_options_panel, 520.0)
	var outer_col: VBoxContainer = VBoxContainer.new()
	outer_col.add_theme_constant_override("separation", 12)
	card.add_child(outer_col)

	outer_col.add_child(_make_heading("Options"))

	_options_scroll = ScrollContainer.new()
	_options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_options_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_options_scroll.custom_minimum_size = Vector2(0.0, 300.0)
	_options_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_col.add_child(_options_scroll)

	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 14)
	_options_scroll.add_child(col)

	var diff_title: Label = Label.new()
	diff_title.text = "Difficulté"
	diff_title.add_theme_font_size_override("font_size", 16)
	diff_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.62, 1.0))
	col.add_child(diff_title)

	var diff_row: HBoxContainer = HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 8)
	col.add_child(diff_row)

	for mode_key: String in ["toddler", "chill", "wild"]:
		var preset: Dictionary = Scales.DIFFICULTY_PRESETS[mode_key] as Dictionary
		var btn: Button = _make_menu_button(String(preset["label"]), false)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(func() -> void: _set_difficulty_option(mode_key))
		diff_row.add_child(btn)
		_diff_buttons[mode_key] = btn

	_diff_desc_label = Label.new()
	_diff_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diff_desc_label.add_theme_font_size_override("font_size", 13)
	_diff_desc_label.add_theme_color_override("font_color", Color(0.76, 0.92, 0.95, 0.88))
	col.add_child(_diff_desc_label)

	# Bites per scale slider (3..50)
	var bites_header: HBoxContainer = HBoxContainer.new()
	col.add_child(bites_header)

	var bites_lbl: Label = Label.new()
	bites_lbl.text = "Bouchées par monde"
	bites_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bites_lbl.add_theme_font_size_override("font_size", 16)
	bites_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.62, 1.0))
	bites_header.add_child(bites_lbl)

	_bites_value_label = Label.new()
	_bites_value_label.text = str(bites_per_scale)
	_bites_value_label.add_theme_font_size_override("font_size", 16)
	_bites_value_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	bites_header.add_child(_bites_value_label)

	_bites_slider = HSlider.new()
	_bites_slider.min_value = 3.0
	_bites_slider.max_value = 50.0
	_bites_slider.step = 1.0
	_bites_slider.value = float(bites_per_scale)
	_bites_slider.value_changed.connect(_on_bites_slider_changed)
	col.add_child(_bites_slider)

	# Cinematic mode toggle
	_cinematic_toggle = CheckButton.new()
	_cinematic_toggle.text = "Mode cinématique (illustrations d'histoire)"
	_cinematic_toggle.button_pressed = cinematic_mode
	_cinematic_toggle.add_theme_font_size_override("font_size", 15)
	_cinematic_toggle.toggled.connect(_on_cinematic_toggled)
	col.add_child(_cinematic_toggle)

	# Haptics toggle
	_haptics_toggle = CheckButton.new()
	_haptics_toggle.text = "Vibrations"
	_haptics_toggle.button_pressed = haptics_enabled
	_haptics_toggle.add_theme_font_size_override("font_size", 15)
	_haptics_toggle.toggled.connect(_on_haptics_toggled)
	col.add_child(_haptics_toggle)

	var back_btn: Button = _make_menu_button("Retour", true)
	back_btn.pressed.connect(_close_options)
	outer_col.add_child(back_btn)

	_refresh_options_ui()


func _build_defeat_panel() -> void:
	_defeat_panel = _make_overlay_backdrop()
	_menu_layer.add_child(_defeat_panel)

	var card: PanelContainer = _add_centered_card(_defeat_panel, 440.0)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)

	col.add_child(_make_heading("Oups ! Petite pause"))

	var txt: Label = Label.new()
	txt.text = "La petite Charlie a perdu sa flamme protectrice, mais elle peut aussitôt replonger !"
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.add_theme_font_size_override("font_size", 15)
	col.add_child(txt)

	_defeat_stats_label = _make_stats_label()
	col.add_child(_defeat_stats_label)

	var retry_btn: Button = _make_menu_button("Réessayer ce monde", true)
	retry_btn.pressed.connect(_retry_current_scale)
	col.add_child(retry_btn)

	var menu_btn: Button = _make_menu_button("Menu principal", false)
	menu_btn.pressed.connect(_enter_title_screen)
	col.add_child(menu_btn)


func _build_victory_panel() -> void:
	_victory_panel = _make_overlay_backdrop()
	_menu_layer.add_child(_victory_panel)

	var card: PanelContainer = _add_centered_card(_victory_panel, 460.0)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	card.add_child(col)

	col.add_child(_make_heading("✦ Un avec le Cosmos ✦"))

	var txt: Label = Label.new()
	txt.text = "Bravo ! La petite Charlie a traversé les 6 mondes, du quark minuscule jusqu'aux galaxies spirales."
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.add_theme_font_size_override("font_size", 16)
	col.add_child(txt)

	_victory_stats_label = _make_stats_label()
	col.add_child(_victory_stats_label)

	var explore_btn: Button = _make_menu_button("Flotter librement", true)
	explore_btn.pressed.connect(_continue_free_roam)
	col.add_child(explore_btn)

	var replay_btn: Button = _make_menu_button("Rejouer depuis l'atome", false)
	replay_btn.pressed.connect(_on_start_game)
	col.add_child(replay_btn)

	var menu_btn: Button = _make_menu_button("Menu principal", false)
	menu_btn.pressed.connect(_enter_title_screen)
	col.add_child(menu_btn)


func _make_stats_label() -> Label:
	var lbl: Label = Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _font_display != null:
		lbl.add_theme_font_override("font", _font_display)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.76, 0.94, 0.98, 0.94))
	return lbl


func _format_run_stats_text() -> String:
	var total_sec: int = int(floor(run_time))
	var mins: int = total_sec / 60
	var secs: int = total_sec % 60
	var sc_idx: int = clampi(best_scale - 1, 0, Scales.NUM_SCALES - 1)
	var best_roman: String = String((Scales.SCALES[sc_idx] as Dictionary)["roman"])
	var line1: String = "Bouchées : %d  ·  Temps : %02d:%02d" % [total_eaten, mins, secs]
	var line2: String = "Records : Échelle %s  ·  Meilleur : %d" % [best_roman, best_eaten]
	if victories > 0:
		line2 += "  ·  Victoires : %d" % victories
	return "%s\n%s" % [line1, line2]


func _refresh_stats_labels() -> void:
	var txt: String = _format_run_stats_text()
	if _pause_stats_label != null:
		_pause_stats_label.text = txt
	if _defeat_stats_label != null:
		_defeat_stats_label.text = txt
	if _victory_stats_label != null:
		_victory_stats_label.text = txt


func _make_glass_box(radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.08, 0.14, 0.78)
	box.border_color = Color(1.0, 1.0, 1.0, 0.14)
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	box.shadow_size = 24
	box.shadow_offset = Vector2(0.0, 8.0)
	box.content_margin_left = 24.0
	box.content_margin_right = 24.0
	box.content_margin_top = 20.0
	box.content_margin_bottom = 20.0
	return box


func _make_hud_icon_button(icon_id: String) -> _IconButton:
	var b: _IconButton = _IconButton.new()
	b.text = ""
	b.icon_name = icon_id
	b.custom_minimum_size = Vector2(44.0, 44.0)
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(0.04, 0.10, 0.17, 0.66)
	st.border_color = Color(1.0, 1.0, 1.0, 0.18)
	st.set_border_width_all(1)
	st.set_corner_radius_all(22)
	b.add_theme_stylebox_override("normal", st)
	var hover: StyleBoxFlat = st.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.10, 0.21, 0.31, 0.86)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _make_menu_button(label_txt: String, is_primary: bool) -> Button:
	var b: Button = Button.new()
	b.text = label_txt
	b.custom_minimum_size = Vector2(0.0, 48.0)
	if _font_ui_bold != null:
		b.add_theme_font_override("font", _font_ui_bold)
	b.add_theme_font_size_override("font_size", 17)
	var st: StyleBoxFlat = StyleBoxFlat.new()
	if is_primary:
		# Warm glowing coral-orange CTA with high-contrast dark ink (#10161b)
		st.bg_color = Color("#ff8364")
		st.border_color = Color(1.0, 0.84, 0.66, 0.62)
		st.shadow_color = Color(1.0, 0.44, 0.34, 0.36)
		st.shadow_size = 14
		st.shadow_offset = Vector2(0.0, 4.0)
		var dark_ink: Color = Color("#10161b")
		b.add_theme_color_override("font_color", dark_ink)
		b.add_theme_color_override("font_hover_color", dark_ink)
		b.add_theme_color_override("font_pressed_color", dark_ink)
		b.add_theme_color_override("font_focus_color", dark_ink)
	else:
		st.bg_color = Color(0.06, 0.14, 0.22, 0.78)
		st.border_color = Color(1.0, 1.0, 1.0, 0.16)
		b.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 0.96))
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.99, 0.96, 1.0))
	st.set_border_width_all(1)
	st.set_corner_radius_all(24)
	b.add_theme_stylebox_override("normal", st)
	var hover: StyleBoxFlat = st.duplicate() as StyleBoxFlat
	hover.bg_color = Color("#ff9670") if is_primary else Color(0.11, 0.22, 0.32, 0.90)
	b.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = st.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#ff6f61") if is_primary else Color(0.08, 0.18, 0.27, 0.92)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _make_overlay_backdrop() -> Control:
	var panel: Control = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _ui_theme != null:
		panel.theme = _ui_theme
	var scrim: ColorRect = ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.01, 0.04, 0.08, 0.62)
	panel.add_child(scrim)
	return panel


func _add_centered_card(parent_ctrl: Control, min_w: float) -> PanelContainer:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent_ctrl.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(min_w, 0.0)
	card.add_theme_stylebox_override("panel", _make_glass_box(24))
	center.add_child(card)
	return card


func _make_heading(text_val: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text_val
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font_display != null:
		lbl.add_theme_font_override("font", _font_display)
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.56, 1.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.02, 0.06, 0.55))
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_constant_override("shadow_outline_size", 6)
	return lbl


# --- Settings & records persistence (user://settings.cfg) ---

func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	var saved_diff: String = String(cfg.get_value("gameplay", "difficulty", "chill"))
	if Scales.DIFFICULTY_PRESETS.has(saved_diff):
		difficulty_mode = saved_diff
	bites_per_scale = clampi(int(cfg.get_value("gameplay", "bites_per_scale", 15)), 3, 50)
	cinematic_mode = bool(cfg.get_value("gameplay", "cinematic_mode", true))
	haptics_enabled = bool(cfg.get_value("gameplay", "haptics", true))
	audio_muted = bool(cfg.get_value("audio", "muted", false))
	best_scale = clampi(int(cfg.get_value("records", "best_scale", 1)), 1, Scales.NUM_SCALES)
	best_eaten = maxi(0, int(cfg.get_value("records", "best_eaten", 0)))
	victories = maxi(0, int(cfg.get_value("records", "victories", 0)))


func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("gameplay", "difficulty", difficulty_mode)
	cfg.set_value("gameplay", "bites_per_scale", bites_per_scale)
	cfg.set_value("gameplay", "cinematic_mode", cinematic_mode)
	cfg.set_value("gameplay", "haptics", haptics_enabled)
	cfg.set_value("audio", "muted", audio_muted)
	cfg.set_value("records", "best_scale", best_scale)
	cfg.set_value("records", "best_eaten", best_eaten)
	cfg.set_value("records", "victories", victories)
	cfg.save(SETTINGS_PATH)


func _update_records(is_victory: bool = false) -> void:
	var changed: bool = false
	var reached_scale: int = current_scale_index + 1
	if reached_scale > best_scale:
		best_scale = reached_scale
		changed = true
	if total_eaten > best_eaten:
		best_eaten = total_eaten
		changed = true
	if is_victory:
		victories += 1
		changed = true
	if changed:
		save_settings()


func _apply_settings_to_systems() -> void:
	if _ecosystem != null:
		_ecosystem.set_difficulty(difficulty_mode)
	if _audio != null:
		_audio.set_muted(audio_muted)
	if _mute_btn != null:
		_mute_btn.set_icon_name("sound_off" if audio_muted else "sound_on")
	_refresh_options_ui()


func _refresh_options_ui() -> void:
	if _diff_desc_label == null:
		return
	var preset: Dictionary = Scales.DIFFICULTY_PRESETS[difficulty_mode] as Dictionary
	_diff_desc_label.text = String(preset["desc"])
	for mode_key: String in _diff_buttons.keys():
		var btn: Button = _diff_buttons[mode_key] as Button
		var selected: bool = (mode_key == difficulty_mode)
		btn.modulate = Color(1.0, 0.84, 0.58, 1.0) if selected else Color(0.72, 0.82, 0.88, 0.78)
	if _bites_slider != null:
		_bites_slider.set_value_no_signal(float(bites_per_scale))
	if _bites_value_label != null:
		_bites_value_label.text = str(bites_per_scale)
	if _cinematic_toggle != null:
		_cinematic_toggle.set_pressed_no_signal(cinematic_mode)
	if _haptics_toggle != null:
		_haptics_toggle.set_pressed_no_signal(haptics_enabled)


func _set_difficulty_option(mode_key: String) -> void:
	if not Scales.DIFFICULTY_PRESETS.has(mode_key):
		return
	difficulty_mode = mode_key
	save_settings()
	_apply_settings_to_systems()
	if _audio != null:
		_audio.play_chime(1.1)


func _on_bites_slider_changed(val: float) -> void:
	bites_per_scale = clampi(roundi(val), 3, 50)
	if _bites_value_label != null:
		_bites_value_label.text = str(bites_per_scale)
	save_settings()


func _on_cinematic_toggled(toggled_on: bool) -> void:
	cinematic_mode = toggled_on
	save_settings()
	if _audio != null:
		_audio.play_chime(1.2 if toggled_on else 0.85)


func _on_haptics_toggled(toggled_on: bool) -> void:
	haptics_enabled = toggled_on
	save_settings()
	if haptics_enabled:
		_vibrate(18)
	if _audio != null:
		_audio.play_chime(1.15 if toggled_on else 0.85)


# --- Floating poetic banners ---

func _queue_banner(title_txt: String, sub_txt: String, duration: float = 2.8, accent: Color = Color(1.0, 0.86, 0.56, 1.0)) -> void:
	_banner_queue.append({
		"title": title_txt,
		"sub": sub_txt,
		"duration": duration,
		"accent": accent,
	})


func _queue_scale_banner(scale_idx: int) -> void:
	var sc: Dictionary = Scales.SCALES[clampi(scale_idx, 0, Scales.NUM_SCALES - 1)] as Dictionary
	var title_txt: String = "ÉCHELLE %s · %s" % [String(sc["roman"]), String(sc["poetic_title"])]
	var sub_txt: String = String(sc["unit_sub"])
	_queue_banner(title_txt, sub_txt, 2.9, Color(1.0, 0.86, 0.56, 1.0))


func _queue_power_evolution_banner(level: int) -> void:
	if level == 2:
		_queue_banner("✦ Pouvoirs évolués · Nv.2 ✦", "Triple jet de lave & onde amplifiée", 2.7, Color(0.55, 0.95, 1.0, 1.0))
	elif level == 3:
		_queue_banner("✦ Pouvoirs évolués · Nv.3 ✦", "Orbe plasma explosif & onde supernova", 2.9, Color(1.0, 0.72, 0.36, 1.0))


func _clear_banners() -> void:
	_banner_queue.clear()
	_banner_active = false
	_banner_elapsed = 0.0
	if _banner_panel != null:
		_banner_panel.visible = false


func _step_banners(dt: float) -> void:
	if _banner_panel == null:
		return
	if state != GameState.PLAYING:
		_banner_panel.visible = false
		return

	if not _banner_active:
		if _banner_queue.is_empty():
			_banner_panel.visible = false
			return
		var next_b: Dictionary = _banner_queue.pop_front() as Dictionary
		_banner_title.text = String(next_b["title"])
		_banner_title.add_theme_color_override("font_color", next_b["accent"] as Color)
		_banner_sub.text = String(next_b["sub"])
		_banner_duration = float(next_b["duration"])
		_banner_elapsed = 0.0
		_banner_active = true
		_banner_panel.visible = true

	_banner_elapsed += dt
	var fade_in: float = clampf(_banner_elapsed / 0.35, 0.0, 1.0)
	var fade_out: float = clampf((_banner_duration - _banner_elapsed) / 0.45, 0.0, 1.0)
	var alpha: float = minf(fade_in, fade_out)
	_banner_panel.modulate = Color(1.0, 1.0, 1.0, alpha)

	if _banner_elapsed >= _banner_duration:
		_banner_active = false
		_banner_panel.visible = false


# --- State transitions & Menu actions ---

func _hide_all_overlays() -> void:
	if _overlay_tween != null and _overlay_tween.is_valid():
		_overlay_tween.kill()
	_title_panel.visible = false
	_pause_panel.visible = false
	_options_panel.visible = false
	_defeat_panel.visible = false
	_victory_panel.visible = false


func _show_overlay(panel: Control) -> void:
	if panel == null:
		return
	if _overlay_tween != null and _overlay_tween.is_valid():
		_overlay_tween.kill()
	panel.modulate.a = 0.0
	panel.visible = true
	_overlay_tween = create_tween()
	_overlay_tween.set_trans(Tween.TRANS_CUBIC)
	_overlay_tween.set_ease(Tween.EASE_OUT)
	_overlay_tween.tween_property(panel, "modulate:a", 1.0, 0.22)


func _invalidate_hud_cache() -> void:
	_hud_last_scale = -1
	_hud_last_size_str = ""
	_hud_last_droplets = -99
	_hud_last_diff_mode = ""
	_hud_last_crit_alpha_step = -1
	_hud_last_progress = -1.0
	_hud_last_progress_str = ""
	_hud_last_spit_cd = -1.0
	_hud_last_dash_cd = -1.0
	_hud_last_power_lvl = -1


func _enter_title_screen() -> void:
	state = GameState.TITLE
	_free_roam_after_victory = false
	_hide_all_overlays()
	_clear_banners()
	_show_overlay(_title_panel)
	_hud_root.visible = false
	_reset_all_touch_inputs()
	if _danger_vignette != null:
		_danger_vignette.set_intensity(0.0)
	_set_audio_ducked(false)
	_title_swim_time = 0.0
	_reset_world_to_scale(0)


func _open_options(return_to: GameState) -> void:
	_options_return_state = return_to
	_hud_root.visible = false
	_reset_all_touch_inputs()
	_hide_all_overlays()
	_refresh_options_ui()
	_show_overlay(_options_panel)
	if _audio != null:
		_audio.play_chime(1.0)


func _close_options() -> void:
	_hide_all_overlays()
	if _options_return_state == GameState.PAUSED:
		state = GameState.PAUSED
		_hud_root.visible = false
		_reset_all_touch_inputs()
		_refresh_stats_labels()
		_show_overlay(_pause_panel)
	else:
		state = GameState.TITLE
		_hud_root.visible = false
		_reset_all_touch_inputs()
		_show_overlay(_title_panel)
	if _audio != null:
		_audio.play_chime(0.92)


func _on_start_game() -> void:
	_free_roam_after_victory = false
	total_eaten = 0
	run_time = 0.0
	_combo_count = 0
	_combo_timer = 0.0
	_clear_banners()
	_reset_world_to_scale(0)
	_hide_all_overlays()
	_set_audio_ducked(false)
	if _audio != null:
		_audio.play_chime(1.25)

	if cinematic_mode and _cutscenes != null:
		state = GameState.CUTSCENE
		_hud_root.visible = false
		_reset_all_touch_inputs()
		_queue_scale_banner(0)
		_cutscenes.play_cutscene("intro", _begin_playing)
	else:
		_queue_scale_banner(0)
		_begin_playing()


func _begin_playing() -> void:
	_hide_all_overlays()
	state = GameState.PLAYING
	_hud_root.visible = true
	_set_audio_ducked(false)
	_invalidate_hud_cache()
	_update_hud()


func _on_pause_pressed() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.PAUSED
	_hud_root.visible = false
	_reset_all_touch_inputs()
	_hide_all_overlays()
	_refresh_stats_labels()
	_show_overlay(_pause_panel)
	_set_audio_ducked(true)
	if _audio != null:
		_audio.play_chime(0.88)


func _resume_game() -> void:
	_hide_all_overlays()
	state = GameState.PLAYING
	_hud_root.visible = true
	_set_audio_ducked(false)
	_invalidate_hud_cache()
	_update_hud()
	if _audio != null:
		_audio.play_chime(1.12)


func _retry_current_scale() -> void:
	_reset_world_to_scale(current_scale_index)
	_queue_scale_banner(current_scale_index)
	_begin_playing()


func _continue_free_roam() -> void:
	_free_roam_after_victory = true
	_begin_playing()


func _on_toggle_mute() -> void:
	if _audio == null:
		return
	audio_muted = _audio.toggle_mute()
	if _mute_btn != null:
		_mute_btn.set_icon_name("sound_off" if audio_muted else "sound_on")
	save_settings()


func _reset_world_to_scale(scale_idx: int) -> void:
	current_scale_index = clampi(scale_idx, 0, Scales.NUM_SCALES - 1)
	bites_in_scale = 0
	_heal_bite_counter = 0
	_time_since_hurt = 0.0
	_combo_count = 0
	_combo_timer = 0.0
	_spit_cd_left = 0.0
	_dash_cd_left = 0.0
	_cam_trauma = 0.0
	_cam_lookahead = Vector2.ZERO
	_predator_pulse_timer = 0.0
	_projectiles.clear()
	_shockwaves.clear()
	_bursts.clear()
	_embers.clear()
	_warp_flash_life = 0.0
	if _vfx_was_active and _vfx_layer != null:
		_vfx_layer.queue_redraw()
	_vfx_was_active = false

	var start_size: float = Scales.scale_start_size(current_scale_index)
	_charlie.reset_charlie(Vector2.ZERO, start_size)
	_ecosystem.set_difficulty(difficulty_mode)
	_ecosystem.reset_for_scale(_charlie, current_scale_index)
	if _audio != null:
		_audio.set_scale_index(current_scale_index)

	_current_zoom = _compute_target_zoom(start_size)
	_camera_base_pos = _charlie.position
	_camera.position = _camera_base_pos
	_last_cam_pos = _camera_base_pos
	_camera.zoom = Vector2(_current_zoom, _current_zoom)
	if _danger_vignette != null:
		_danger_vignette.set_intensity(0.0)
	_invalidate_hud_cache()
	_update_hud()


# --- Power helpers ---

func _get_power_level() -> int:
	if current_scale_index >= 4:
		return 3
	if current_scale_index >= 2:
		return 2
	return 1


func _get_dash_cooldown() -> float:
	var lvl: int = _get_power_level()
	var base_cd: float = 3.0 - float(lvl - 1) * 0.2 # 3.0s (Nv.1), 2.8s (Nv.2), 2.6s (Nv.3)
	if difficulty_mode == "toddler":
		return base_cd * 0.55
	return base_cd


func _find_auto_aim_angle() -> float:
	var max_range: float = _charlie.world_size * 11.5
	var min_pred_size: float = _charlie.world_size * 0.94
	var best_dist: float = max_range
	var best_target: Creature = null
	var creatures: Array[Creature] = _ecosystem.get_creatures()
	for c: Creature in creatures:
		if not is_instance_valid(c) or not c.alive:
			continue
		if c.world_size < min_pred_size:
			continue
		var d: float = _charlie.position.distance_to(c.position)
		if d < best_dist:
			best_dist = d
			best_target = c
	if best_target != null:
		return (best_target.position - _charlie.position).angle()
	return _charlie.facing_angle


func _trigger_lava_spit() -> void:
	if state != GameState.PLAYING or _spit_cd_left > 0.0:
		return
	var preset: Dictionary = Scales.DIFFICULTY_PRESETS[difficulty_mode] as Dictionary
	_spit_cd_left = float(preset.get("spit_cd", 2.4))

	var lvl: int = _get_power_level()
	var base_angle: float = _find_auto_aim_angle()
	_charlie.facing_angle = base_angle
	var speed: float = _charlie.world_size * (12.5 + float(lvl) * 1.6)
	var angles: Array[float] = [base_angle]
	if lvl == 2:
		angles = [base_angle - 0.24, base_angle, base_angle + 0.24]

	for ang: float in angles:
		var dir: Vector2 = Vector2.from_angle(ang)
		var spawn_pos: Vector2 = _charlie.position + dir * (_charlie.world_size * 1.05)
		_projectiles.append({
			"pos": spawn_pos,
			"vel": dir * speed,
			"radius": _charlie.world_size * (0.42 if lvl == 3 else 0.26),
			"life": 1.35 if lvl == 3 else 1.05,
			"max_life": 1.35 if lvl == 3 else 1.05,
			"level": lvl,
			"ember_cd": 0.0,
		})
		_spawn_embers(spawn_pos, 4, _charlie.world_size * 0.6)

	_add_trauma(0.20 + float(lvl) * 0.04)
	_vibrate(22)
	if _audio != null:
		_audio.play_spit(lvl)


func _trigger_shockwave_dash() -> void:
	if state != GameState.PLAYING or _dash_cd_left > 0.0:
		return
	var lvl: int = _get_power_level()
	_dash_cd_left = _get_dash_cooldown()

	var input_dir: Vector2 = _read_move_input()
	var dash_angle: float = input_dir.angle() if input_dir.length_squared() > 0.04 else _charlie.facing_angle
	_charlie.trigger_dash(dash_angle, lvl)
	_charlie.invuln_timer = maxf(_charlie.invuln_timer, 0.26 + float(lvl) * 0.06)

	var start_r: float = _charlie.world_size * 0.6
	var wave_radius: float = _charlie.world_size * (4.2 + float(lvl) * 1.4)
	_shockwaves.append({
		"pos": _charlie.position,
		"start_radius": start_r,
		"radius": start_r,
		"max_radius": wave_radius,
		"life": 0.42,
		"max_life": 0.42,
		"color": Color(1.0, 0.78, 0.44, 1.0) if lvl == 3 else Color(0.45, 0.92, 0.98, 1.0),
	})

	# Repel nearby predators (and shrink them at Nv.3 supernova!)
	var creatures: Array[Creature] = _ecosystem.get_creatures()
	for c: Creature in creatures:
		if not is_instance_valid(c) or not c.alive:
			continue
		var delta_v: Vector2 = c.position - _charlie.position
		var dist: float = delta_v.length()
		if dist > 0.001 and dist < wave_radius and c.world_size >= _charlie.world_size * 0.90:
			var push_dir: Vector2 = delta_v / dist
			c.velocity = push_dir * (_charlie.world_size * (7.0 + float(lvl) * 2.5))
			c.burn_flash = 0.85
			if lvl >= 3:
				c.world_size = maxf(_charlie.world_size * 0.72, c.world_size * 0.76)

	_add_trauma(0.32 + float(lvl) * 0.05)
	_vibrate(28)
	if _audio != null:
		_audio.play_dash(lvl)


# --- Input & Main Loop ---

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var kev: InputEventKey = event as InputEventKey
	if not kev.pressed or kev.echo:
		return

	if kev.keycode == KEY_M:
		_on_toggle_mute()
		return

	if _options_panel != null and _options_panel.visible:
		if kev.keycode == KEY_ESCAPE:
			_close_options()
		return

	if state == GameState.CUTSCENE:
		if kev.keycode == KEY_ESCAPE and _cutscenes != null and _cutscenes.has_method("skip_cutscene"):
			_cutscenes.skip_cutscene()
		return

	if state == GameState.PAUSED:
		if kev.keycode == KEY_ESCAPE or kev.keycode == KEY_P:
			_resume_game()
		return

	if state != GameState.PLAYING:
		return

	if kev.keycode == KEY_J or kev.keycode == KEY_F or kev.keycode == KEY_SHIFT:
		_trigger_lava_spit()
	elif kev.keycode == KEY_E or kev.keycode == KEY_K or kev.keycode == KEY_SPACE:
		_trigger_shockwave_dash()
	elif kev.keycode == KEY_ESCAPE or kev.keycode == KEY_P:
		_on_pause_pressed()


func _read_move_input() -> Vector2:
	var vec: Vector2 = Vector2.ZERO
	if _joystick != null and _joystick.is_active:
		vec = _joystick.output_vector
	else:
		var kb: Vector2 = Vector2.ZERO
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
			kb.x += 1.0
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q):
			kb.x -= 1.0
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
			kb.y += 1.0
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z):
			kb.y -= 1.0
		if kb.length_squared() > 0.0:
			vec = kb.normalized()
	return vec


func _process(delta: float) -> void:
	var dt: float = clampf(delta, 0.0, 0.05)
	_vfx_time += dt
	var progress: float = Scales.size_to_progress(_charlie.world_size)
	var palette: Dictionary = Scales.get_blended_palette(progress)

	if _charlie != null and _charlie.has_method("set_palette"):
		_charlie.call("set_palette", palette["blob_core"], palette["blob_edge"], palette.get("blob_glow", palette["blob_edge"]))

	if state == GameState.PLAYING:
		_step_playing(dt, palette)
	elif state == GameState.TITLE:
		_step_title_swim(dt, palette)

	_step_banners(dt)
	_update_background_shader(palette, progress)


func _step_title_swim(dt: float, palette: Dictionary) -> void:
	# Gentle figure-8 swim offset around the title card so Charlie stays lively & visible
	_title_swim_time += dt
	var t: float = _title_swim_time * 0.58
	var rx: float = _charlie.world_size * 7.8
	var ry: float = _charlie.world_size * 4.4
	var center_offset: Vector2 = Vector2(-_charlie.world_size * 3.8, _charlie.world_size * 1.2)
	var target_pos: Vector2 = center_offset + Vector2(sin(t) * rx, sin(t * 2.0) * ry)
	var to_target: Vector2 = target_pos - _charlie.position
	var move_dir: Vector2 = to_target.normalized() * clampf(to_target.length() / maxf(_charlie.world_size * 2.2, 1.0), 0.25, 0.72)

	_charlie.step_motion(dt, move_dir, true, null, null, palette)

	# Keep camera gently drifting near origin so Charlie loops into clear view around the card
	var desired_cam: Vector2 = _charlie.position * 0.18
	_camera_base_pos = _camera_base_pos.lerp(desired_cam, 1.0 - exp(-dt * 2.0))
	var cam_delta: Vector2 = _camera_base_pos - _last_cam_pos
	_bg_parallax += cam_delta * _current_zoom
	_last_cam_pos = _camera_base_pos
	_camera.position = _camera_base_pos


func _step_playing(dt: float, palette: Dictionary) -> void:
	run_time += dt
	_spit_cd_left = maxf(0.0, _spit_cd_left - dt)
	_dash_cd_left = maxf(0.0, _dash_cd_left - dt)

	if _combo_timer > 0.0:
		_combo_timer -= dt
		if _combo_timer <= 0.0:
			_combo_count = 0

	# Passive droplet regeneration after 8.0s without taking damage
	if _charlie.droplets_alive < Charlie.MAX_DROPLETS:
		_time_since_hurt += dt
		if _time_since_hurt >= PASSIVE_HEAL_SECONDS:
			_heal_one_droplet()
	else:
		_time_since_hurt = 0.0

	var move_dir: Vector2 = _read_move_input()
	var has_input: bool = move_dir.length_squared() > 0.0025

	var view_px: Vector2 = get_viewport_rect().size
	var view_world: Vector2 = view_px / maxf(_current_zoom, 0.0001)

	var eco_info: Dictionary = _ecosystem.step_ecosystem(dt, _charlie, view_world, current_scale_index)
	var creatures: Array[Creature] = _ecosystem.get_creatures()

	var nearest_prey: Variant = eco_info.get("nearest_prey", null)
	var nearest_pred: Variant = eco_info.get("nearest_predator", null)
	var predator_chasing: bool = bool(eco_info.get("predator_chasing", false))

	_charlie.step_motion(dt, move_dir, has_input, nearest_prey, nearest_pred, palette)
	_step_projectiles_and_vfx(dt, creatures)
	_resolve_creature_collisions(creatures)
	if state != GameState.PLAYING:
		return

	# Danger vignette & predator pulse audio
	_step_danger_feedback(dt, predator_chasing, nearest_pred)

	# Smooth logarithmic Camera2D zoom, velocity look-ahead, trauma shake, & jump-free parallax
	var target_zoom: float = _compute_target_zoom(_charlie.world_size)
	var zoom_t: float = 1.0 - exp(-dt * 4.5)
	_current_zoom = exp(lerpf(log(maxf(_current_zoom, 0.0001)), log(maxf(target_zoom, 0.0001)), zoom_t))
	_camera.zoom = Vector2(_current_zoom, _current_zoom)

	var desired_ahead: Vector2 = _charlie.velocity * 0.22
	var max_ahead: float = _charlie.world_size * 2.2
	if desired_ahead.length() > max_ahead:
		desired_ahead = desired_ahead.normalized() * max_ahead
	_cam_lookahead = _cam_lookahead.lerp(desired_ahead, 1.0 - exp(-dt * 4.5))

	_camera_base_pos = _camera_base_pos.lerp(_charlie.position + _cam_lookahead, 1.0 - exp(-dt * 8.5))
	var cam_delta: Vector2 = _camera_base_pos - _last_cam_pos
	_bg_parallax += cam_delta * _current_zoom
	_last_cam_pos = _camera_base_pos

	_cam_trauma = maxf(0.0, _cam_trauma - dt * 1.8)
	var shake_off: Vector2 = Vector2.ZERO
	if _cam_trauma > 0.001:
		_shake_time += dt * 42.0
		var shake_mag: float = (_cam_trauma * _cam_trauma) * (_charlie.world_size * 0.45)
		shake_off = Vector2(
			sin(_shake_time * 1.7) * cos(_shake_time * 0.9),
			cos(_shake_time * 2.1) * sin(_shake_time * 1.3)
		) * shake_mag
	_camera.position = _camera_base_pos + shake_off

	_update_hud()
	var has_vfx: bool = (
		not _projectiles.is_empty()
		or not _shockwaves.is_empty()
		or not _bursts.is_empty()
		or not _embers.is_empty()
		or _warp_flash_life > 0.0
	)
	if has_vfx or _vfx_was_active:
		_vfx_layer.queue_redraw()
		_vfx_was_active = has_vfx


func _step_danger_feedback(dt: float, predator_chasing: bool, nearest_pred: Variant) -> void:
	if _danger_vignette == null:
		return
	if difficulty_mode == "toddler":
		_danger_vignette.set_intensity(0.0)
		return

	var target_danger: float = 0.0
	if _charlie.droplets_alive <= 0:
		# Critical 0-droplet state: pulsing crimson edge warning
		target_danger = 0.46 + 0.34 * (0.5 + 0.5 * sin(_vfx_time * 6.5))

	if predator_chasing:
		var prox: float = 0.45
		if nearest_pred is Creature and is_instance_valid(nearest_pred):
			var pred_c: Creature = nearest_pred as Creature
			var d: float = _charlie.position.distance_to(pred_c.position)
			var danger_r: float = maxf(_charlie.world_size * 6.4, pred_c.world_size * 4.6)
			prox = clampf(1.0 - d / maxf(danger_r, 1.0), 0.15, 1.0)
		var chase_glow: float = (0.16 + 0.40 * prox) * (0.65 + 0.35 * sin(_vfx_time * 8.0))
		target_danger = maxf(target_danger, chase_glow)

		_predator_pulse_timer -= dt
		if _predator_pulse_timer <= 0.0:
			_predator_pulse_timer = lerpf(0.95, 0.48, prox)
			if _audio != null and _audio.has_method("play_predator_pulse"):
				_audio.play_predator_pulse()
	else:
		_predator_pulse_timer = maxf(0.0, _predator_pulse_timer - dt)

	var next_val: float = lerpf(_danger_vignette.intensity, target_danger, 1.0 - exp(-dt * 8.0))
	_danger_vignette.set_intensity(next_val)


func _detonate_plasma_orb(p_pos: Vector2, p_rad: float, creatures: Array[Creature]) -> void:
	var blast_r: float = _charlie.world_size * 3.6
	var min_pred_size: float = _charlie.world_size * 0.94
	_shockwaves.append({
		"pos": p_pos,
		"start_radius": p_rad,
		"radius": p_rad,
		"max_radius": blast_r,
		"life": 0.34,
		"max_life": 0.34,
		"color": Color(1.0, 0.62, 0.32, 1.0),
	})
	for other: Creature in creatures:
		if is_instance_valid(other) and other.alive and other.world_size >= min_pred_size:
			var delta_v: Vector2 = other.position - p_pos
			var dist: float = delta_v.length()
			if dist <= blast_r:
				_shrink_creature(other, 0.64)
				if dist > 0.001:
					other.velocity = (delta_v / dist) * (_charlie.world_size * 7.5)
	_spawn_burst(p_pos, Color(1.0, 0.68, 0.32, 1.0), _charlie.world_size * 1.25)
	_spawn_embers(p_pos, 14, _charlie.world_size * 1.2)
	_add_trauma(0.28)
	if _audio != null:
		_audio.play_shrink()


func _step_projectiles_and_vfx(dt: float, creatures: Array[Creature]) -> void:
	if _warp_flash_life > 0.0:
		_warp_flash_life = maxf(0.0, _warp_flash_life - dt)

	var min_pred_size: float = _charlie.world_size * 0.94
	var p_idx: int = _projectiles.size() - 1
	while p_idx >= 0:
		var p: Dictionary = _projectiles[p_idx]
		p["life"] = float(p["life"]) - dt
		var p_vel: Vector2 = p["vel"] as Vector2
		p["pos"] = (p["pos"] as Vector2) + p_vel * dt

		var hit: bool = false
		var p_pos: Vector2 = p["pos"] as Vector2
		var p_rad: float = float(p["radius"])
		var lvl: int = int(p["level"])

		# Molten ember trail behind lava spit
		var ember_cd: float = float(p.get("ember_cd", 0.0)) - dt
		if ember_cd <= 0.0:
			ember_cd = 0.035
			_spawn_embers(p_pos, 1, _charlie.world_size * 0.45)
		p["ember_cd"] = ember_cd

		for c: Creature in creatures:
			if not is_instance_valid(c) or not c.alive:
				continue
			# Collide only with predators
			if c.world_size < min_pred_size:
				continue
			if p_pos.distance_to(c.position) <= p_rad + c.world_size * 0.85:
				hit = true
				if lvl >= 3:
					_detonate_plasma_orb(p_pos, p_rad, creatures)
				else:
					_shrink_creature(c, 0.68)
					var push_dir: Vector2 = p_vel.normalized() if p_vel.length_squared() > 0.01 else (c.position - p_pos).normalized()
					c.velocity = push_dir * (_charlie.world_size * (5.6 + float(lvl) * 1.6))
					_spawn_burst(p_pos, Color(1.0, 0.65, 0.32, 1.0), _charlie.world_size * 0.9)
					_spawn_embers(p_pos, 10, _charlie.world_size * 0.9)
					if _audio != null:
						_audio.play_shrink()
				break

		if not hit and float(p["life"]) <= 0.0:
			# Nv.3 plasma orbs detonate on timeout even if they miss
			if lvl >= 3:
				_detonate_plasma_orb(p_pos, p_rad, creatures)
			_projectiles.remove_at(p_idx)
		elif hit:
			_projectiles.remove_at(p_idx)
		p_idx -= 1

	var w_idx: int = _shockwaves.size() - 1
	while w_idx >= 0:
		var w: Dictionary = _shockwaves[w_idx]
		w["life"] = float(w["life"]) - dt
		var frac: float = 1.0 - clampf(float(w["life"]) / maxf(0.01, float(w["max_life"])), 0.0, 1.0)
		var start_r: float = float(w.get("start_radius", _charlie.world_size * 0.5))
		w["radius"] = lerpf(start_r, float(w["max_radius"]), frac)
		if float(w["life"]) <= 0.0:
			_shockwaves.remove_at(w_idx)
		w_idx -= 1

	var b_idx: int = _bursts.size() - 1
	while b_idx >= 0:
		var b: Dictionary = _bursts[b_idx]
		b["life"] = float(b["life"]) - dt
		if float(b["life"]) <= 0.0:
			_bursts.remove_at(b_idx)
		b_idx -= 1

	var e_idx: int = _embers.size() - 1
	while e_idx >= 0:
		var em: Dictionary = _embers[e_idx]
		em["life"] = float(em["life"]) - dt
		var em_vel: Vector2 = (em["vel"] as Vector2) * exp(-dt * 4.2)
		em["vel"] = em_vel
		em["pos"] = (em["pos"] as Vector2) + em_vel * dt
		if float(em["life"]) <= 0.0:
			_embers.remove_at(e_idx)
		e_idx -= 1


func _shrink_creature(c: Creature, factor: float) -> void:
	var min_s: float = _charlie.world_size * 0.45
	c.world_size = maxf(min_s, c.world_size * factor)
	c.burn_flash = 1.0


func _resolve_creature_collisions(creatures: Array[Creature]) -> void:
	for c: Creature in creatures:
		if not is_instance_valid(c) or not c.alive:
			continue
		var dist: float = _charlie.position.distance_to(c.position)
		var touch_dist: float = _charlie.world_size * 0.88 + c.world_size * 0.72
		if dist > touch_dist:
			continue

		if c.world_size < _charlie.world_size * Ecosystem.EDIBLE_RATIO:
			# Edible prey!
			c.alive = false
			if _combo_timer > 0.0:
				_combo_count = mini(MAX_COMBO, _combo_count + 1)
			else:
				_combo_count = 1
			_combo_timer = COMBO_WINDOW

			var prey_angle: float = (c.position - _charlie.position).angle()
			_charlie.trigger_chomp(prey_angle, 1.0 + float(_combo_count - 1) * 0.06)
			_spawn_burst(c.position, Color(1.0, 0.85, 0.52, 1.0), c.world_size * 1.4)
			_add_trauma(0.11)
			_vibrate(14)
			if _audio != null:
				_audio.play_chomp(_combo_count)
			_on_prey_eaten()
			if state != GameState.PLAYING:
				return
		elif c.world_size >= _charlie.world_size * Ecosystem.PREDATOR_RATIO:
			# Larger predator!
			if _charlie.invuln_timer > 0.0:
				continue
			var away_angle: float = (_charlie.position - c.position).angle()
			_charlie.trigger_hurt(away_angle)
			if difficulty_mode == "toddler":
				# Gentle harmless bounce in 3-year-old Toddler mode
				_add_trauma(0.18)
				if _audio != null:
					_audio.play_shrink()
			else:
				_time_since_hurt = 0.0
				_combo_count = 0
				_combo_timer = 0.0
				_vibrate(45)
				if _audio != null:
					_audio.play_hurt()
				if _charlie.droplets_alive > 0:
					# Survive at 0 droplets (critical state); 4th hit triggers defeat
					_charlie.droplets_alive -= 1
					_add_trauma(0.55)
				else:
					_add_trauma(0.85)
					_trigger_defeat()
					return


func _heal_one_droplet() -> void:
	if _charlie.droplets_alive >= Charlie.MAX_DROPLETS:
		return
	_heal_bite_counter = 0
	_time_since_hurt = 0.0
	_charlie.droplets_alive += 1
	_spawn_burst(_charlie.position, Color(1.0, 0.90, 0.46, 1.0), _charlie.world_size * 1.85)
	if _audio != null:
		_audio.play_heal()


func _on_prey_eaten() -> void:
	total_eaten += 1
	bites_in_scale += 1
	_heal_bite_counter += 1
	if total_eaten > best_eaten:
		best_eaten = total_eaten

	# Regenerate 1 missing droplet every 5 bites
	if _heal_bite_counter >= 5 and _charlie.droplets_alive < Charlie.MAX_DROPLETS:
		_heal_one_droplet()

	if _free_roam_after_victory:
		_charlie.world_size = minf(Scales.MAX_SIZE * 1.25, _charlie.world_size * 1.015)
		return

	var frac: float = clampf(float(bites_in_scale) / float(maxi(1, bites_per_scale)), 0.0, 1.0)
	var scale_base: float = Scales.scale_start_size(current_scale_index)
	_charlie.world_size = scale_base * pow(Scales.SCALE_FACTOR, frac)

	if bites_in_scale >= bites_per_scale:
		_advance_scale()


func _trigger_scale_warp_veil(scale_idx: int) -> void:
	var sc: Dictionary = Scales.SCALES[clampi(scale_idx, 0, Scales.NUM_SCALES - 1)] as Dictionary
	_warp_origin = _charlie.position
	_warp_color = sc.get("mote_color", Color(0.56, 0.94, 0.98, 1.0)) as Color
	_warp_flash_max = 0.92
	_warp_flash_life = _warp_flash_max
	if _vfx_layer != null:
		_vfx_layer.queue_redraw()
		_vfx_was_active = true


func _advance_scale() -> void:
	_projectiles.clear()
	_shockwaves.clear()
	_bursts.clear()
	_embers.clear()

	if current_scale_index + 1 < Scales.NUM_SCALES:
		var prev_lvl: int = _get_power_level()
		current_scale_index += 1
		var new_lvl: int = _get_power_level()
		bites_in_scale = 0
		_heal_bite_counter = 0
		_time_since_hurt = 0.0
		_charlie.droplets_alive = Charlie.MAX_DROPLETS
		_ecosystem.reset_for_scale(_charlie, current_scale_index)
		_trigger_scale_warp_veil(current_scale_index)
		_update_records(false)
		_vibrate(60)

		if _audio != null:
			_audio.set_scale_index(current_scale_index)
			_audio.play_scale_up()
			if new_lvl > prev_lvl and _audio.has_method("play_power_evolve"):
				_audio.play_power_evolve()

		_queue_scale_banner(current_scale_index)
		if new_lvl > prev_lvl:
			_queue_power_evolution_banner(new_lvl)

		if cinematic_mode and _cutscenes != null:
			state = GameState.CUTSCENE
			_hud_root.visible = false
			_reset_all_touch_inputs()
			var cid: String = "scale_%d" % current_scale_index
			_cutscenes.play_cutscene(cid, _begin_playing)
	else:
		_update_records(true)
		_vibrate(60)
		if _audio != null:
			_audio.play_victory()
		if cinematic_mode and _cutscenes != null:
			state = GameState.CUTSCENE
			_hud_root.visible = false
			_reset_all_touch_inputs()
			_cutscenes.play_cutscene("victory", _show_victory_overlay)
		else:
			_show_victory_overlay()


func _trigger_defeat() -> void:
	state = GameState.DEFEAT
	_reset_all_touch_inputs()
	_hud_root.visible = false
	_clear_banners()
	if _danger_vignette != null:
		_danger_vignette.set_intensity(0.0)
	_update_records(false)
	_refresh_stats_labels()
	_hide_all_overlays()
	_show_overlay(_defeat_panel)
	_set_audio_ducked(true)


func _show_victory_overlay() -> void:
	state = GameState.VICTORY
	_reset_all_touch_inputs()
	_hud_root.visible = false
	_clear_banners()
	if _danger_vignette != null:
		_danger_vignette.set_intensity(0.0)
	_refresh_stats_labels()
	_hide_all_overlays()
	_show_overlay(_victory_panel)
	_set_audio_ducked(false)


func _compute_target_zoom(charlie_size: float) -> float:
	# Keep Charlie at ~36 screen pixels radius across all 6 logarithmic scales
	return clampf(36.0 / maxf(charlie_size, 1.0), 0.0001, 4.0)


func _update_background_shader(palette: Dictionary, progress: float) -> void:
	if _bg_mat == null:
		return
	_bg_mat.set_shader_parameter("bg_inner", palette["bg_inner"])
	_bg_mat.set_shader_parameter("bg_outer", palette["bg_outer"])
	_bg_mat.set_shader_parameter("mote_color", palette["mote_color"])
	_bg_mat.set_shader_parameter("cam_offset", _bg_parallax)
	_bg_mat.set_shader_parameter("viewport_size", get_viewport().get_visible_rect().size)
	_bg_mat.set_shader_parameter("scale_progress", progress)


func _update_hud() -> void:
	if _scale_label == null:
		return

	# Scale label (only mutate on scale change)
	if current_scale_index != _hud_last_scale:
		_hud_last_scale = current_scale_index
		var sc: Dictionary = Scales.SCALES[current_scale_index] as Dictionary
		_scale_label.text = "%s · %s" % [String(sc["roman"]), String(sc["name"])]

	# Scientific size label (only mutate when formatted string changes)
	var prog: float = Scales.size_to_progress(_charlie.world_size)
	var size_str: String = Scales.format_scientific_size(prog)
	if size_str != _hud_last_size_str:
		_hud_last_size_str = size_str
		_size_label.text = size_str

	# Droplets / lives indicator (dirty-flagged by droplets + difficulty mode)
	var droplets: int = _charlie.droplets_alive
	var lives_dirty: bool = (droplets != _hud_last_droplets or difficulty_mode != _hud_last_diff_mode)
	if difficulty_mode == "toddler":
		if lives_dirty:
			_lives_label.text = "Tout-petit · ∞"
			_lives_label.add_theme_color_override("font_color", Color(0.68, 0.95, 0.82, 1.0))
			_hud_last_crit_alpha_step = -1
	elif droplets <= 0:
		if lives_dirty:
			_lives_label.text = "○○○ · CRITIQUE"
		var blink_red: float = 0.55 + 0.45 * sin(_vfx_time * 9.0)
		var alpha_step: int = roundi(blink_red * 20.0)
		if lives_dirty or alpha_step != _hud_last_crit_alpha_step:
			_hud_last_crit_alpha_step = alpha_step
			_lives_label.add_theme_color_override("font_color", Color(1.0, 0.24, 0.28, blink_red))
	else:
		if lives_dirty:
			var dots: String = ""
			for i: int in range(Charlie.MAX_DROPLETS):
				dots += "●" if i < droplets else "○"
			_lives_label.text = dots
			_lives_label.add_theme_color_override("font_color", Color(1.0, 0.56, 0.44, 1.0))
			_hud_last_crit_alpha_step = -1
	if lives_dirty:
		_hud_last_droplets = droplets
		_hud_last_diff_mode = difficulty_mode

	# Sleek 8px pill progress bar & counter (only mutate on actual change)
	var combo_suffix: String = "  ·  ×%d" % _combo_count if _combo_count >= 2 else ""
	var progress_frac: float = 1.0
	var count_str: String = ""
	if _free_roam_after_victory:
		progress_frac = 1.0
		count_str = "Cosmos infini · %d bouchées%s" % [total_eaten, combo_suffix]
	else:
		progress_frac = clampf(float(bites_in_scale) / float(maxi(1, bites_per_scale)), 0.0, 1.0)
		count_str = "%d / %d%s" % [bites_in_scale, bites_per_scale, combo_suffix]

	if _progress_fill != null and absf(progress_frac - _hud_last_progress) > 0.002:
		_hud_last_progress = progress_frac
		_progress_fill.anchor_right = progress_frac
	if count_str != _hud_last_progress_str:
		_hud_last_progress_str = count_str
		_progress_count_label.text = count_str

	# Power buttons (only redraw when cooldown ratio or power level changes)
	var preset: Dictionary = Scales.DIFFICULTY_PRESETS[difficulty_mode] as Dictionary
	var spit_max: float = maxf(0.1, float(preset.get("spit_cd", 2.4)))
	var dash_max: float = maxf(0.1, _get_dash_cooldown())
	var power_lvl: int = _get_power_level()
	var lvl_changed: bool = (power_lvl != _hud_last_power_lvl)
	var lvl_str: String = "Nv.%d" % power_lvl

	var spit_ratio: float = clampf(_spit_cd_left / spit_max, 0.0, 1.0)
	if lvl_changed or absf(spit_ratio - _hud_last_spit_cd) > 0.004 or (spit_ratio == 0.0 and _hud_last_spit_cd != 0.0):
		_hud_last_spit_cd = spit_ratio
		_spit_btn.level_text = lvl_str
		_spit_btn.cooldown_ratio = spit_ratio
		_spit_btn.queue_redraw()

	var dash_ratio: float = clampf(_dash_cd_left / dash_max, 0.0, 1.0)
	if lvl_changed or absf(dash_ratio - _hud_last_dash_cd) > 0.004 or (dash_ratio == 0.0 and _hud_last_dash_cd != 0.0):
		_hud_last_dash_cd = dash_ratio
		_dash_btn.level_text = lvl_str
		_dash_btn.cooldown_ratio = dash_ratio
		_dash_btn.queue_redraw()

	if lvl_changed:
		_hud_last_power_lvl = power_lvl


func _spawn_burst(pos: Vector2, col: Color, radius: float) -> void:
	_bursts.append({
		"pos": pos,
		"color": col,
		"radius": radius,
		"life": 0.30,
		"max_life": 0.30,
	})


func _spawn_embers(pos: Vector2, count: int, spread_scale: float) -> void:
	for i: int in range(count):
		if _embers.size() >= 72:
			_embers.pop_front()
		var ang: float = randf_range(0.0, TAU)
		var spd: float = spread_scale * randf_range(1.6, 4.8)
		var life: float = randf_range(0.22, 0.48)
		_embers.append({
			"pos": pos + Vector2.from_angle(ang) * (spread_scale * 0.15),
			"vel": Vector2.from_angle(ang) * spd,
			"radius": maxf(1.2, spread_scale * randf_range(0.07, 0.14)),
			"life": life,
			"max_life": life,
			"color": Color(1.0, randf_range(0.48, 0.84), 0.24, 1.0),
		})


func _draw_soft_glow(canvas: Node2D, pos: Vector2, radius: float, col: Color) -> void:
	if radius <= 0.05 or col.a <= 0.004:
		return
	if _glow_tex != null:
		canvas.draw_texture_rect(
			_glow_tex,
			Rect2(pos - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)),
			false,
			col
		)
	else:
		canvas.draw_circle(pos, radius * 0.65, col)


func _draw_world_vfx(canvas: Node2D) -> void:
	# Luminous scale-transition warp veil (expanding glow rings + soft radial mist flash)
	if _warp_flash_life > 0.0:
		var wf_frac: float = clampf(_warp_flash_life / maxf(0.01, _warp_flash_max), 0.0, 1.0)
		var wf_inv: float = 1.0 - wf_frac
		var base_r: float = _charlie.world_size
		# Soft radial mist flash
		var mist_col: Color = Color(_warp_color.r, _warp_color.g, _warp_color.b, wf_frac * wf_frac * 0.34)
		_draw_soft_glow(canvas, _warp_origin, base_r * (4.0 + wf_inv * 14.0), mist_col)
		var core_mist: Color = Color(1.0, 0.94, 0.78, wf_frac * wf_frac * 0.42)
		_draw_soft_glow(canvas, _warp_origin, base_r * (2.2 + wf_inv * 6.5), core_mist)
		# Three staggered luminous warp rings
		for ring_i: int in range(3):
			var delay: float = float(ring_i) * 0.14
			var r_t: float = clampf((wf_inv - delay) / (1.0 - delay), 0.0, 1.0)
			if r_t > 0.0 and r_t < 1.0:
				var r_fade: float = (1.0 - r_t) * (1.0 - r_t)
				var ring_r: float = base_r * (1.4 + r_t * (11.5 - float(ring_i) * 1.6))
				var outer_ring: Color = Color(_warp_color.r, _warp_color.g, _warp_color.b, r_fade * 0.35)
				var inner_ring: Color = Color(1.0, 0.95, 0.84, r_fade * 0.78)
				canvas.draw_arc(_warp_origin, ring_r, 0.0, TAU, 56, outer_ring, maxf(3.0, base_r * 0.30 * r_fade), true)
				canvas.draw_arc(_warp_origin, ring_r, 0.0, TAU, 56, inner_ring, maxf(1.5, base_r * 0.10 * r_fade), true)

	# Shockwaves (soft outer halo band + crisp bright core ring + spawn flash)
	for w: Dictionary in _shockwaves:
		var frac: float = clampf(float(w["life"]) / maxf(0.01, float(w["max_life"])), 0.0, 1.0)
		var w_pos: Vector2 = w["pos"] as Vector2
		var col: Color = w["color"] as Color
		var rad: float = float(w["radius"])
		var halo_col: Color = Color(col.r, col.g, col.b, frac * 0.32)
		var core_ring_col: Color = Color(minf(1.0, col.r + 0.25), minf(1.0, col.g + 0.25), minf(1.0, col.b + 0.25), frac * 0.92)
		canvas.draw_arc(w_pos, rad, 0.0, TAU, 48, halo_col, maxf(4.0, _charlie.world_size * 0.34 * frac), true)
		canvas.draw_arc(w_pos, rad, 0.0, TAU, 48, core_ring_col, maxf(1.8, _charlie.world_size * 0.11 * frac), true)
		if frac > 0.45:
			var flash_a: float = ((frac - 0.45) / 0.55) * 0.36
			_draw_soft_glow(canvas, w_pos, rad * 0.72, Color(col.r, col.g, col.b, flash_a))

	# Molten ember particles (soft layered radial glow)
	for em: Dictionary in _embers:
		var frac: float = clampf(float(em["life"]) / maxf(0.01, float(em["max_life"])), 0.0, 1.0)
		var em_pos: Vector2 = em["pos"] as Vector2
		var em_r: float = float(em["radius"]) * (0.45 + 0.55 * frac)
		var col: Color = em["color"] as Color
		_draw_soft_glow(canvas, em_pos, em_r * 2.5, Color(col.r, col.g * 0.72, col.b * 0.5, frac * 0.48))
		_draw_soft_glow(canvas, em_pos, em_r * 1.15, Color(1.0, 0.94, 0.74, frac * 0.95))

	# Lava spit projectiles (multi-layer additive-feeling radial glow)
	for p: Dictionary in _projectiles:
		var pos: Vector2 = p["pos"] as Vector2
		var r: float = float(p["radius"])
		var lvl: int = int(p["level"])
		var outer_col: Color = Color(1.0, 0.42, 0.20, 0.44) if lvl < 3 else Color(1.0, 0.70, 0.24, 0.56)
		var mid_col: Color = Color(1.0, 0.52, 0.28, 0.88) if lvl < 3 else Color(1.0, 0.78, 0.34, 0.94)
		var core_col: Color = Color(1.0, 0.96, 0.82, 0.98)
		_draw_soft_glow(canvas, pos, r * (3.1 if lvl >= 3 else 2.5), outer_col)
		_draw_soft_glow(canvas, pos, r * 1.45, mid_col)
		_draw_soft_glow(canvas, pos, r * 0.78, core_col)

	# Chomp / impact / heal bursts (soft flash + glowing ring + radial glow sparkles)
	for b: Dictionary in _bursts:
		var frac: float = clampf(float(b["life"]) / maxf(0.01, float(b["max_life"])), 0.0, 1.0)
		var inv_f: float = 1.0 - frac
		var pos: Vector2 = b["pos"] as Vector2
		var col: Color = b["color"] as Color
		var max_r: float = float(b["radius"])
		# Soft central glow flash
		_draw_soft_glow(canvas, pos, max_r * (0.9 + inv_f * 0.6), Color(col.r, col.g, col.b, frac * frac * 0.45))
		# Soft outer halo ring + crisp inner ring
		var ring_r: float = max_r * (0.35 + inv_f * 0.85)
		canvas.draw_arc(pos, ring_r, 0.0, TAU, 28, Color(col.r, col.g, col.b, frac * 0.32), maxf(3.0, max_r * 0.18 * frac), true)
		canvas.draw_arc(pos, ring_r, 0.0, TAU, 28, Color(1.0, 0.96, 0.86, frac * 0.78), maxf(1.4, max_r * 0.06 * frac), true)
		# 6 glowing radial sparkle motes
		for i: int in range(6):
			var ang: float = float(i) * TAU / 6.0 + inv_f * 0.65
			var p_off: Vector2 = Vector2.from_angle(ang) * (max_r * (0.25 + inv_f * 0.98))
			var sp_r: float = maxf(1.4, max_r * 0.18 * frac)
			_draw_soft_glow(canvas, pos + p_off, sp_r * 2.2, Color(col.r, col.g, col.b, frac * 0.55))
			_draw_soft_glow(canvas, pos + p_off, sp_r * 1.0, Color(1.0, 0.97, 0.88, frac * 0.92))
