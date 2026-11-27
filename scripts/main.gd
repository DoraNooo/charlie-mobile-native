extends Node2D
## Main game orchestrator for CHARLIE — De l'atome au cosmos (Godot 4.3+ Mobile).
## Programmatically builds HDR WorldEnvironment (AgX + selective bloom), crisp full-res
## GPU backdrop, WorldAtmosphere depth planes, Camera2D, Charlie, Ecosystem, AudioEngine,
## CutscenePlayer, additive HDR VFX, contemplative minimal HUD, world-space direct-glide
## steering, living Ghibli title screen, safe-area layout, mobile lifecycle, and Visual QA harness.

const SETTINGS_PATH: String = "user://settings.cfg"
const BG_SHADER_PATH: String = "res://shaders/biolum_bg.gdshader"
const DANGER_VIGNETTE_SHADER_PATH: String = "res://shaders/danger_vignette.gdshader"
const WORLD_ATMOSPHERE_PATH: String = "res://scripts/world_atmosphere.gd"
const TITLE_KEYART_PATH: String = "res://assets/art/keyart-landscape.jpg"
const FONT_DISPLAY_PATH: String = "res://assets/fonts/Fraunces.ttf"
const FONT_UI_PATH: String = "res://assets/fonts/Outfit.ttf"
const COMBO_WINDOW: float = 1.9
const MAX_COMBO: int = 6
const PASSIVE_HEAL_SECONDS: float = 8.0
const QUICK_TAP_MAX_TIME: float = 0.20
const QUICK_TAP_MAX_MOVE: float = 18.0
const DOUBLE_TAP_MAX_INTERVAL: float = 0.36
const DOUBLE_TAP_MAX_DIST: float = 88.0

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
var _play_time: float = 0.0
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
var _direct_touch_index: int = -1
var _direct_touch_pos: Vector2 = Vector2.ZERO
var _direct_touch_start_pos: Vector2 = Vector2.ZERO
var _direct_touch_start_time: float = 0.0
var _direct_touch_max_move: float = 0.0
var _last_open_tap_time: float = -10.0
var _last_open_tap_pos: Vector2 = Vector2.ZERO
var _global_uniforms: Dictionary = {}
var _is_capture_mode: bool = false
var _capture_steer_override: Vector2 = Vector2.ZERO

# Typography, theme & shared textures
var _font_display: Font = null
var _font_ui: Font = null
var _font_ui_bold: Font = null
var _font_ui_tracked: Font = null
var _ui_theme: Theme = null
var _glow_tex: GradientTexture2D = null
var _cta_pill_normal: ImageTexture = null
var _cta_pill_hover: ImageTexture = null
var _cta_pill_pressed: ImageTexture = null

# Core nodes
var _world_env: WorldEnvironment = null
var _bg_layer: CanvasLayer = null
var _bg_rect: ColorRect = null
var _bg_mat: ShaderMaterial = null
var _world_textures: Array[Texture2D] = []
var _last_bg_idx_a: int = -1
var _last_bg_idx_b: int = -1
var _atmosphere: Node = null
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

# Minimal contemplative HUD nodes
var _hud_layer: CanvasLayer = null
var _danger_vignette: _DangerVignette = null
var _hud_root: Control = null
var _touch_target_overlay: _TouchTargetOverlay = null
var _top_margin: MarginContainer = null
var _pause_btn: _IconButton = null
var _joystick: VirtualJoystick = null
var _spit_btn: _TouchPowerButton = null
var _dash_btn: _TouchPowerButton = null

# Dirty-flagged HUD cache for power buttons (zero redundant redraws)
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

# Overlay menus & living title screen
var _menu_layer: CanvasLayer = null
var _title_panel: Control = null
var _title_art_rect: TextureRect = null
var _title_fireflies: _TitleFireflies = null
var _title_top_margin: MarginContainer = null
var _title_stack: Control = null
var _title_options_btn: _IconButton = null
var _title_diff_buttons: Dictionary = {}
var _pause_panel: Control = null
var _pause_mute_btn: Button = null
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
var _audio_toggle: CheckButton = null
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
	## 1-pass GPU soft breathing dusk-ember edge vignette (danger_vignette.gdshader).
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


class _TouchTargetOverlay:
	extends Control
	## Delicate screen-space gossamer water-ripple expanding gently where the
	## player's fingertip grazes the playfield.
	var target_pos: Vector2 = Vector2.ZERO
	var active: bool = false
	var glow_tex: Texture2D = null

	var _alpha: float = 0.0
	var _ripple_phase: float = 0.0
	var _ripples: Array[Dictionary] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		visible = false

	func spawn_ripple(pos: Vector2) -> void:
		if _ripples.size() >= 6:
			_ripples.pop_front()
		_ripples.append({
			"pos": pos,
			"age": 0.0,
			"duration": 0.62,
		})
		visible = true
		queue_redraw()

	func set_target(pos: Vector2, is_now_active: bool) -> void:
		var was_active: bool = active
		target_pos = pos
		active = is_now_active
		if active:
			if not was_active:
				_ripple_phase = 0.0
				spawn_ripple(pos)
			visible = true
			queue_redraw()

	func release() -> void:
		active = false

	func clear_immediate() -> void:
		active = false
		_alpha = 0.0
		_ripples.clear()
		visible = false
		queue_redraw()

	func _process(delta: float) -> void:
		var dt: float = clampf(delta, 0.0, 0.05)
		var goal: float = 1.0 if active else 0.0
		var any_alive: bool = active or _alpha > 0.004 or not _ripples.is_empty()
		if not any_alive:
			return

		var rate: float = 14.0 if active else 9.0
		_alpha = lerpf(_alpha, goal, 1.0 - exp(-dt * rate))
		if not active and _alpha <= 0.004:
			_alpha = 0.0
		if active:
			_ripple_phase = fposmod(_ripple_phase + dt * 1.15, 1.0)

		var i: int = _ripples.size() - 1
		while i >= 0:
			var r: Dictionary = _ripples[i]
			r["age"] = float(r["age"]) + dt
			if float(r["age"]) >= float(r["duration"]):
				_ripples.remove_at(i)
			i -= 1

		visible = active or _alpha > 0.004 or not _ripples.is_empty()
		queue_redraw()

	func _draw() -> void:
		# One-shot expanding gossamer water-ripples on touch graze
		for r: Dictionary in _ripples:
			var age: float = float(r["age"])
			var dur: float = maxf(0.05, float(r["duration"]))
			var t: float = clampf(age / dur, 0.0, 1.0)
			var ease_out: float = 1.0 - pow(1.0 - t, 2.4)
			var fade: float = (1.0 - t) * (1.0 - t)
			var rad: float = lerpf(10.0, 44.0, ease_out)
			var pos: Vector2 = r["pos"] as Vector2
			draw_arc(pos, rad, 0.0, TAU, 40, Color(0.92, 0.97, 1.0, 0.34 * fade), 1.5, true)

		# Single whisper-delicate gossamer ripple gliding beneath held fingertip
		if _alpha > 0.004:
			var ease_p: float = 1.0 - pow(1.0 - _ripple_phase, 2.0)
			var wave_fade: float = sin(_ripple_phase * PI)
			var rad: float = lerpf(13.0, 34.0, ease_p)
			var col: Color = Color(0.95, 0.98, 1.0, (0.14 + 0.18 * wave_fade) * _alpha)
			if glow_tex != null:
				var halo_r: float = 18.0
				draw_texture_rect(
					glow_tex,
					Rect2(target_pos - Vector2(halo_r, halo_r), Vector2(halo_r * 2.0, halo_r * 2.0)),
					false,
					Color(0.88, 0.96, 1.0, 0.12 * _alpha)
				)
			draw_arc(target_pos, rad, 0.0, TAU, 36, col, 1.35, true)


class _TitleFireflies:
	extends Control
	## Lightweight live golden firefly overlay drifting serenely across the
	## painted Ghibli keyart on the title screen.
	const COUNT: int = 28
	var glow_tex: Texture2D = null
	var _time: float = 0.0
	var _flies: Array[Dictionary] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 20260417
		_flies.clear()
		for i: int in range(COUNT):
			var is_emerald: bool = rng.randf() < 0.24
			var fx: float = 0.0
			var fy: float = 0.0
			var rise_spd: float = rng.randf_range(0.008, 0.022)
			if i < 20:
				# Enchanted forest & left half framing Charlie
				fx = rng.randf_range(0.03, 0.47)
				fy = rng.randf_range(0.08, 0.94)
			elif i < 24:
				# Upper night canopy / moonlit lantern edge above the title
				fx = rng.randf_range(0.50, 0.96)
				fy = rng.randf_range(0.05, 0.20)
				rise_spd = rng.randf_range(0.004, 0.011)
			elif i < 26:
				# Lower foreground foliage edge below the difficulty chips
				fx = rng.randf_range(0.50, 0.94)
				fy = rng.randf_range(0.80, 0.95)
				rise_spd = rng.randf_range(0.004, 0.010)
			else:
				# Far-right tree framing edge
				fx = rng.randf_range(0.93, 0.98)
				fy = rng.randf_range(0.22, 0.78)
				rise_spd = rng.randf_range(0.006, 0.014)
			_flies.append({
				"x": fx,
				"y": fy,
				"rise": rise_spd,
				"sway_x": rng.randf_range(0.010, 0.028),
				"sway_y": rng.randf_range(0.008, 0.018),
				"freq": rng.randf_range(0.45, 1.15),
				"pulse_freq": rng.randf_range(1.1, 2.5),
				"phase": rng.randf_range(0.0, TAU),
				"radius": rng.randf_range(2.2, 4.6),
				"color": Color(0.68, 0.98, 0.66, 1.0) if is_emerald else Color(1.0, 0.86, 0.44, 1.0),
			})

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		_time += clampf(delta, 0.0, 0.05)
		queue_redraw()

	func _draw() -> void:
		var sz: Vector2 = size
		if sz.x <= 1.0 or sz.y <= 1.0:
			return
		for f: Dictionary in _flies:
			var ph: float = float(f["phase"])
			var freq: float = float(f["freq"])
			var y_norm: float = fposmod(float(f["y"]) - _time * float(f["rise"]), 1.06) - 0.03
			var x_norm: float = float(f["x"]) + sin(_time * freq + ph) * float(f["sway_x"])
			var y_off: float = cos(_time * (freq * 0.78) + ph * 1.3) * float(f["sway_y"])
			var cur_y: float = y_norm + y_off
			var pos: Vector2 = Vector2(x_norm * sz.x, cur_y * sz.y)

			var pulse_raw: float = 0.5 + 0.5 * sin(_time * float(f["pulse_freq"]) + ph * 2.1)
			var pulse: float = 0.25 + 0.75 * (pulse_raw * pulse_raw)
			var edge_fade: float = smoothstep(0.0, 0.08, y_norm) * (1.0 - smoothstep(0.92, 1.0, y_norm))
			# Keep bright dots gently clear of the right-side title & subtitle typography stack
			var tdx: float = (x_norm - 0.72) / 0.20
			var tdy: float = (cur_y - 0.50) / 0.21
			var text_clear: float = smoothstep(0.90, 1.35, sqrt(tdx * tdx + tdy * tdy))
			var alpha: float = pulse * edge_fade * text_clear
			if alpha <= 0.01:
				continue

			var base_col: Color = f["color"] as Color
			var r: float = float(f["radius"])
			if glow_tex != null:
				var halo_r: float = r * (4.6 + 1.8 * pulse)
				draw_texture_rect(
					glow_tex,
					Rect2(pos - Vector2(halo_r, halo_r), Vector2(halo_r * 2.0, halo_r * 2.0)),
					false,
					Color(base_col.r, base_col.g, base_col.b, 0.44 * alpha)
				)
			draw_circle(pos, r * 0.58, Color(1.0, 0.98, 0.88, 0.90 * alpha))


class _IconButton:
	extends Button
	## Minimal anti-aliased vector icon button (no emoji tofu boxes on mobile).
	var icon_name: String = "pause"
	var icon_color: Color = Color(0.98, 0.96, 0.90, 0.96)

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
				var bar_w: float = s * 0.36
				var bar_h: float = s * 1.44
				var gap: float = s * 0.30
				draw_line(
					c + Vector2(-gap - bar_w * 0.5, -bar_h * 0.5),
					c + Vector2(-gap - bar_w * 0.5, bar_h * 0.5),
					col,
					bar_w,
					true
				)
				draw_line(
					c + Vector2(gap + bar_w * 0.5, -bar_h * 0.5),
					c + Vector2(gap + bar_w * 0.5, bar_h * 0.5),
					col,
					bar_w,
					true
				)
			"gear":
				draw_arc(c, s * 0.58, 0.0, TAU, 24, col, 2.2, true)
				draw_arc(c, s * 0.22, 0.0, TAU, 16, col, 1.7, true)
				for i: int in range(8):
					var ang: float = float(i) * TAU / 8.0
					var dir: Vector2 = Vector2.from_angle(ang)
					draw_line(c + dir * (s * 0.68), c + dir * (s * 0.98), col, 2.4, true)


class _TouchPowerButton:
	extends Control
	## Borderless translucent liquid-glass teardrop / water-orb power control.
	## Breathes quietly at 0.24 alpha in peaceful moments, smoothly awakens to 0.82
	## when a predator approaches, and renders a diegetic bottom-to-top liquid fill
	## cooldown with meniscus shimmer.
	signal activated

	const PEACEFUL_ALPHA: float = 0.24
	const ALERT_ALPHA: float = 0.82
	const CONTOUR_STEPS: int = 36

	var icon_kind: String = "flame" # "flame" | "shockwave"
	var power_level: int = 1 # 1 = base, 2 = warm gold iridescence, 3 = luminous violet iridescence
	var accent_color: Color = Color(1.0, 0.55, 0.30, 1.0)
	var cooldown_ratio: float = 0.0 # 0.0 = ready, 1.0 = full cooldown
	var glow_tex: Texture2D = null

	var _pressed_index: int = -1
	var _target_context_alpha: float = PEACEFUL_ALPHA
	var _context_alpha: float = PEACEFUL_ALPHA
	var _breath_time: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(88.0, 96.0)
		size = custom_minimum_size

	func set_context_visibility(val: float) -> void:
		_target_context_alpha = clampf(val, PEACEFUL_ALPHA, ALERT_ALPHA)

	func reset_touch() -> void:
		if _pressed_index != -1:
			_pressed_index = -1
			queue_redraw()

	func _process(delta: float) -> void:
		if not is_visible_in_tree():
			return
		var dt: float = clampf(delta, 0.0, 0.05)
		var goal: float = _target_context_alpha
		if _pressed_index != -1:
			goal = 0.94
		elif cooldown_ratio > 0.004:
			goal = maxf(goal, 0.42)
		var rate: float = 7.5 if goal > _context_alpha else 3.2
		var prev_a: float = _context_alpha
		_context_alpha = lerpf(_context_alpha, goal, 1.0 - exp(-dt * rate))
		if absf(_context_alpha - goal) < 0.002:
			_context_alpha = goal
		_breath_time += dt
		if cooldown_ratio > 0.004 or absf(_context_alpha - prev_a) > 0.002 or _pressed_index != -1 or _context_alpha > 0.32:
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

	func _get_liquid_tint() -> Color:
		if power_level >= 3:
			return accent_color.lerp(Color(0.82, 0.58, 1.0, 1.0), 0.65)
		if power_level == 2:
			return accent_color.lerp(Color(1.0, 0.84, 0.44, 1.0), 0.58)
		return accent_color

	func _sample_droplet_point(center: Vector2, rx: float, ry: float, theta: float) -> Vector2:
		# Organic teardrop / liquid water-orb contour: gently tapered crown, plush rounded belly
		var s: float = sin(theta)
		var c: float = cos(theta)
		var taper: float = 1.0 - 0.16 * maxf(0.0, -s) * (1.0 - 0.35 * c * c)
		var pinch_top: float = 1.0 + 0.10 * maxf(0.0, -s)
		return center + Vector2(c * rx * taper, s * ry * pinch_top)

	func _build_droplet_poly(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
		var pts: PackedVector2Array = PackedVector2Array()
		pts.resize(CONTOUR_STEPS)
		for i: int in range(CONTOUR_STEPS):
			var ang: float = (float(i) / float(CONTOUR_STEPS)) * TAU
			pts[i] = _sample_droplet_point(center, rx, ry, ang)
		return pts

	func _build_liquid_fill_poly(
		center: Vector2,
		rx: float,
		ry: float,
		ready_frac: float,
		wave_phase: float
	) -> Dictionary:
		var top_y: float = center.y - ry * 1.10
		var bot_y: float = center.y + ry
		var fill_y: float = lerpf(bot_y, top_y, ready_frac)
		var wave_amp: float = (1.0 - absf(ready_frac * 2.0 - 1.0)) * 3.2
		var slices: int = 14
		var left_pts: Array[Vector2] = []
		var right_pts: Array[Vector2] = []
		var surface_pts: PackedVector2Array = PackedVector2Array()

		for k: int in range(slices + 1):
			var frac_y: float = float(k) / float(slices)
			var y_pos: float = lerpf(bot_y - 1.0, fill_y, frac_y)
			var ny: float = clampf((y_pos - center.y) / maxf(ry, 1.0), -1.06, 0.995)
			var half_w: float = 0.0
			if ny < 0.0:
				var ny_scaled: float = clampf(ny / 1.10, -1.0, 0.0)
				var base_w: float = sqrt(maxf(0.0, 1.0 - ny_scaled * ny_scaled))
				var taper: float = 1.0 - 0.16 * maxf(0.0, -ny_scaled)
				half_w = rx * base_w * taper
			else:
				half_w = rx * sqrt(maxf(0.0, 1.0 - ny * ny))
			if half_w > 0.6:
				left_pts.append(Vector2(center.x - half_w, y_pos))
				right_pts.append(Vector2(center.x + half_w, y_pos))

		var poly: PackedVector2Array = PackedVector2Array()
		if left_pts.size() >= 2:
			# Bottom-right up to right meniscus
			for p: Vector2 in right_pts:
				poly.append(p)
			# Liquid wave surface from right to left
			var r_top: Vector2 = right_pts[right_pts.size() - 1]
			var l_top: Vector2 = left_pts[left_pts.size() - 1]
			var surf_steps: int = 10
			for s_i: int in range(surf_steps + 1):
				var u: float = float(s_i) / float(surf_steps)
				var sx: float = lerpf(r_top.x, l_top.x, u)
				var edge_damp: float = sin(u * PI)
				var sy: float = fill_y + sin(u * PI * 2.2 + wave_phase) * wave_amp * edge_damp
				var sp: Vector2 = Vector2(sx, sy)
				poly.append(sp)
				surface_pts.append(sp)
			# Left meniscus back down to bottom-left
			for idx: int in range(left_pts.size() - 1, -1, -1):
				poly.append(left_pts[idx])

		return {"poly": poly, "surface": surface_pts}

	func _draw() -> void:
		var center: Vector2 = Vector2(size.x * 0.5, size.y * 0.54)
		var rx: float = minf(size.x, size.y) * 0.39
		var ry: float = rx * 1.05
		var is_ready: bool = cooldown_ratio <= 0.004
		var is_down: bool = _pressed_index != -1
		var ready_frac: float = clampf(1.0 - cooldown_ratio, 0.0, 1.0)
		var breath: float = 0.94 + 0.06 * sin(_breath_time * 2.2)
		var a: float = clampf(_context_alpha * (1.0 if is_down else breath), 0.16, 0.98)
		var tint: Color = _get_liquid_tint()

		# 1. Soft translucent ambient bloom halo (borderless, no dark box)
		var halo_r: float = rx * (1.65 if is_down else (1.52 if is_ready else 1.25))
		if glow_tex != null:
			var halo_a: float = (0.34 if is_down else (0.24 if is_ready else 0.10)) * a
			draw_texture_rect(
				glow_tex,
				Rect2(center - Vector2(halo_r, halo_r), Vector2(halo_r * 2.0, halo_r * 2.0)),
				false,
				Color(tint.r, tint.g, tint.b, halo_a)
			)

		# 2. Whisper-translucent frosted water-glass shell (completely borderless)
		var shell_poly: PackedVector2Array = _build_droplet_poly(center, rx, ry)
		draw_colored_polygon(shell_poly, Color(0.84, 0.94, 0.98, 0.13 * a))

		# 3. Diegetic bottom-to-top liquid fill volume
		if is_ready:
			var full_col: Color = Color(
				lerpf(tint.r, 1.0, 0.16),
				lerpf(tint.g, 1.0, 0.14),
				lerpf(tint.b, 1.0, 0.16),
				(0.46 if is_down else 0.32) * a
			)
			draw_colored_polygon(shell_poly, full_col)
			# Soft inner caustic luminance pooled near droplet belly
			if glow_tex != null:
				var pool_c: Vector2 = center + Vector2(0.0, ry * 0.24)
				var pool_r: float = rx * 0.95
				draw_texture_rect(
					glow_tex,
					Rect2(pool_c - Vector2(pool_r, pool_r), Vector2(pool_r * 2.0, pool_r * 2.0)),
					false,
					Color(minf(1.0, tint.r + 0.18), minf(1.0, tint.g + 0.18), minf(1.0, tint.b + 0.15), 0.34 * a)
				)
		elif ready_frac > 0.02:
			var fill_data: Dictionary = _build_liquid_fill_poly(center, rx * 0.96, ry * 0.96, ready_frac, _breath_time * 3.4)
			var liq_poly: PackedVector2Array = fill_data["poly"] as PackedVector2Array
			if liq_poly.size() >= 3:
				draw_colored_polygon(liq_poly, Color(tint.r, tint.g, tint.b, 0.34 * a))
			var surf: PackedVector2Array = fill_data["surface"] as PackedVector2Array
			if surf.size() >= 2:
				draw_polyline(surf, Color(1.0, 0.98, 0.92, 0.56 * a), 1.6, true)

		# 4. Liquid-glass glossy specular highlight (upper-left refraction crescent + glint)
		var glint_c: Vector2 = center + Vector2(-rx * 0.34, -ry * 0.34)
		draw_circle(glint_c, rx * 0.14, Color(1.0, 0.99, 0.97, 0.42 * a))
		draw_circle(glint_c + Vector2(rx * 0.16, -ry * 0.16), rx * 0.055, Color(1.0, 1.0, 1.0, 0.52 * a))
		# Soft lower rim bounce light (subtle, no hard outline)
		draw_arc(center + Vector2(0.0, ry * 0.04), rx * 0.86, PI * 0.22, PI * 0.78, 18, Color(tint.r, tint.g, tint.b, 0.32 * a), 1.5, true)
		if power_level >= 2 and is_ready:
			# Delicate iridescent dewdrop shimmer for evolved powers (Nv.2 gold / Nv.3 violet)
			draw_arc(center, rx * 0.90, -PI * 0.76, -PI * 0.24, 16, Color(tint.r, tint.g, tint.b, 0.44 * a), 1.4, true)

		# 5. Clean glowing vector glyph centered inside the droplet
		var glyph_a: float = a * (0.96 if is_ready else (0.36 + 0.40 * ready_frac))
		if icon_kind == "flame":
			_draw_flame_icon(center + Vector2(0.0, 2.0), rx * 0.54, glyph_a)
		else:
			_draw_ripple_icon(center + Vector2(0.0, 2.0), rx * 0.56, glyph_a)

	func _draw_flame_icon(c: Vector2, s: float, alpha: float) -> void:
		var outer_col: Color = Color(1.0, 0.58, 0.32, alpha * 0.92)
		var inner_col: Color = Color(1.0, 0.93, 0.66, alpha)
		var outer: PackedVector2Array = PackedVector2Array([
			c + Vector2(0.0, -s * 1.06),
			c + Vector2(s * 0.46, -s * 0.30),
			c + Vector2(s * 0.64, s * 0.28),
			c + Vector2(s * 0.44, s * 0.76),
			c + Vector2(0.0, s * 0.94),
			c + Vector2(-s * 0.44, s * 0.76),
			c + Vector2(-s * 0.64, s * 0.28),
			c + Vector2(-s * 0.42, -s * 0.22),
			c + Vector2(-s * 0.14, -s * 0.56),
		])
		draw_colored_polygon(outer, outer_col)
		var inner: PackedVector2Array = PackedVector2Array([
			c + Vector2(0.0, -s * 0.28),
			c + Vector2(s * 0.26, s * 0.22),
			c + Vector2(s * 0.22, s * 0.60),
			c + Vector2(0.0, s * 0.76),
			c + Vector2(-s * 0.22, s * 0.60),
			c + Vector2(-s * 0.26, s * 0.22),
		])
		draw_colored_polygon(inner, inner_col)

	func _draw_ripple_icon(c: Vector2, s: float, alpha: float) -> void:
		var outer_col: Color = Color(0.54, 0.96, 1.0, alpha * 0.52)
		var mid_col: Color = Color(0.76, 0.98, 1.0, alpha * 0.84)
		var core_col: Color = Color(0.98, 1.0, 1.0, alpha)
		# Concentric liquid-wave ripple rings + luminous dew core
		draw_arc(c, s * 0.94, 0.0, TAU, 32, outer_col, 1.5, true)
		draw_arc(c, s * 0.58, 0.0, TAU, 28, mid_col, 2.0, true)
		draw_circle(c, s * 0.20, core_col)



func _ready() -> void:
	get_tree().set_quit_on_go_back(false)
	load_settings()
	_cache_global_shader_uniforms()
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

	var capture_dir: String = _get_capture_shots_dir()
	if not capture_dir.is_empty():
		_is_capture_mode = true
		seed(42069)
		if _audio != null:
			_audio.set_muted(true)
		call_deferred("_run_visual_capture", capture_dir)


func _cache_global_shader_uniforms() -> void:
	_global_uniforms.clear()
	for pname: StringName in [&"g_key_light_dir", &"g_world_ambient", &"g_world_rim_color", &"g_charlie_light", &"g_charlie_color"]:
		if ProjectSettings.has_setting("shader_globals/" + String(pname)):
			_global_uniforms[pname] = true


func _make_font_variation(base: Font, weight: int) -> Font:
	if base == null:
		return null
	var fv: FontVariation = FontVariation.new()
	fv.base_font = base
	var ts: TextServer = TextServerManager.get_primary_interface()
	if ts != null:
		fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	return fv


func _bake_cta_pill_texture(left_col: Color, right_col: Color, glow_strength: float) -> ImageTexture:
	# Anti-aliased horizontal coral-peach gradient pill with warm outer glow halo
	const W: int = 280
	const H: int = 76
	const PAD_X: float = 14.0
	const PAD_Y: float = 12.0
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)
	var half_w: float = float(W) * 0.5
	var half_h: float = float(H) * 0.5
	var cap_r: float = half_h - PAD_Y
	var half_seg: float = maxf(0.0, half_w - PAD_X - cap_r)
	var glow_col: Color = left_col.lerp(right_col, 0.55)

	for y: int in range(H):
		var py: float = float(y) + 0.5 - half_h
		var ny: float = clampf((py + cap_r) / maxf(cap_r * 2.0, 1.0), 0.0, 1.0)
		for x: int in range(W):
			var px: float = float(x) + 0.5 - half_w
			var clamped_x: float = clampf(px, -half_seg, half_seg)
			var dist: float = Vector2(px - clamped_x, py).length() - cap_r
			if dist <= 0.75:
				var u: float = clampf((px + half_seg + cap_r) / maxf((half_seg + cap_r) * 2.0, 1.0), 0.0, 1.0)
				var col: Color = left_col.lerp(right_col, u)
				# Subtle warm top highlight for lush luminous depth
				var top_sheen: float = pow(1.0 - ny, 2.6) * 0.20
				var bot_shade: float = pow(ny, 2.4) * 0.08
				col.r = clampf(col.r + top_sheen - bot_shade, 0.0, 1.0)
				col.g = clampf(col.g + top_sheen * 0.85 - bot_shade, 0.0, 1.0)
				col.b = clampf(col.b + top_sheen * 0.65 - bot_shade, 0.0, 1.0)
				var edge_a: float = clampf(0.75 - dist, 0.0, 1.0)
				col.a = edge_a
				img.set_pixel(x, y, col)
			else:
				var g_t: float = clampf(1.0 - dist / 12.0, 0.0, 1.0)
				var g_a: float = g_t * g_t * glow_strength
				if g_a > 0.002:
					img.set_pixel(x, y, Color(glow_col.r, glow_col.g, glow_col.b, g_a))
	return ImageTexture.create_from_image(img)


func _setup_fonts_and_vfx_resources() -> void:
	if ResourceLoader.exists(FONT_DISPLAY_PATH):
		var display_base: Font = load(FONT_DISPLAY_PATH) as Font
		_font_display = _make_font_variation(display_base, 680)
	if ResourceLoader.exists(FONT_UI_PATH):
		var ui_base: Font = load(FONT_UI_PATH) as Font
		_font_ui = _make_font_variation(ui_base, 450)
		_font_ui_bold = _make_font_variation(ui_base, 650)
		var tracked: FontVariation = _make_font_variation(ui_base, 650) as FontVariation
		if tracked != null:
			tracked.spacing_glyph = 4
			_font_ui_tracked = tracked

	_ui_theme = Theme.new()
	if _font_ui != null:
		_ui_theme.default_font = _font_ui
		_ui_theme.default_font_size = 15

	# Shared 64x64 soft radial glow texture (white alpha 1.0 -> 0.0) for additive VFX & fireflies
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

	# Pre-baked warm coral-peach gradient pill textures for the title CTA (#ff9966 -> #ff6f61)
	_cta_pill_normal = _bake_cta_pill_texture(Color("#ff9966"), Color("#ff6f61"), 0.44)
	_cta_pill_hover = _bake_cta_pill_texture(Color("#ffa97a"), Color("#ff7e70"), 0.58)
	_cta_pill_pressed = _bake_cta_pill_texture(Color("#f08252"), Color("#e85e50"), 0.34)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_handle_back_request()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_reset_all_touch_inputs()
			if state == GameState.PLAYING and not _is_capture_mode:
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
	# Intersect display safe area with actual window rect so windowed desktop & fullscreen mobile both map accurately
	# under stretch/mode="viewport" (1280x720 expand) and canvas_items alike.
	var win_rect: Rect2i = Rect2i(DisplayServer.window_get_position(), win_size)
	var clipped: Rect2i = win_rect.intersection(safe)
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return Rect2()
	var sx: float = vp_size.x / float(win_size.x)
	var sy: float = vp_size.y / float(win_size.y)
	var max_hx: float = vp_size.x * 0.25
	var max_vy: float = vp_size.y * 0.25
	var inset_left: float = clampf(float(clipped.position.x - win_rect.position.x) * sx, 0.0, max_hx)
	var inset_top: float = clampf(float(clipped.position.y - win_rect.position.y) * sy, 0.0, max_vy)
	var inset_right: float = clampf(float((win_rect.position.x + win_rect.size.x) - (clipped.position.x + clipped.size.x)) * sx, 0.0, max_hx)
	var inset_bottom: float = clampf(float((win_rect.position.y + win_rect.size.y) - (clipped.position.y + clipped.size.y)) * sy, 0.0, max_vy)
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
		_top_margin.offset_bottom = 84.0 + top

	if _title_top_margin != null:
		_title_top_margin.add_theme_constant_override("margin_left", int(round(20.0 + left)))
		_title_top_margin.add_theme_constant_override("margin_right", int(round(20.0 + right)))
		_title_top_margin.add_theme_constant_override("margin_top", int(round(16.0 + top)))
		_title_top_margin.offset_bottom = 84.0 + top

	if _title_stack != null:
		_title_stack.offset_right = -right
		_title_stack.offset_top = top
		_title_stack.offset_bottom = -bottom

	if _joystick != null:
		_joystick.offset_left = 26.0 + left
		_joystick.offset_right = 206.0 + left
		_joystick.offset_top = -208.0 - bottom
		_joystick.offset_bottom = -28.0 - bottom

	if _spit_btn != null:
		_spit_btn.offset_left = -218.0 - right
		_spit_btn.offset_right = -130.0 - right
		_spit_btn.offset_top = -128.0 - bottom
		_spit_btn.offset_bottom = -32.0 - bottom

	if _dash_btn != null:
		_dash_btn.offset_left = -112.0 - right
		_dash_btn.offset_right = -24.0 - right
		_dash_btn.offset_top = -150.0 - bottom
		_dash_btn.offset_bottom = -54.0 - bottom

	if _banner_panel != null:
		_banner_panel.offset_top = 76.0 + top
		_banner_panel.offset_bottom = 148.0 + top

	if _options_scroll != null:
		var vp_h: float = get_viewport().get_visible_rect().size.y
		var max_scroll_h: float = clampf(vp_h - top - bottom - 120.0, 200.0, 440.0)
		_options_scroll.custom_minimum_size = Vector2(0.0, max_scroll_h)

	if _cutscenes != null and _cutscenes.has_method("apply_safe_area"):
		_cutscenes.apply_safe_area(insets)


func _reset_all_touch_inputs() -> void:
	_direct_touch_index = -1
	if _touch_target_overlay != null:
		_touch_target_overlay.clear_immediate()
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
	_world_textures = [
		preload("res://assets/art/worlds/world_0_quantum.jpg"),
		preload("res://assets/art/worlds/world_1_micro.jpg"),
		preload("res://assets/art/worlds/world_2_forest.jpg"),
		preload("res://assets/art/worlds/world_3_city.jpg"),
		preload("res://assets/art/worlds/world_4_planetary.jpg"),
		preload("res://assets/art/worlds/world_5_cosmic.jpg"),
	]
	_last_bg_idx_a = -1
	_last_bg_idx_b = -1

	_bg_layer = CanvasLayer.new()
	_bg_layer.name = "BackgroundLayer"
	_bg_layer.layer = -10
	add_child(_bg_layer)

	# Crisp full-resolution GPU backdrop attached directly inside BackgroundLayer (-10)
	_bg_rect = ColorRect.new()
	_bg_rect.name = "BiolumBg"
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_mat = ShaderMaterial.new()
	var bg_shader: Shader = load(BG_SHADER_PATH) as Shader
	if bg_shader != null:
		_bg_mat.shader = bg_shader
	_bg_rect.material = _bg_mat
	_apply_world_backdrop_textures(0.0)
	_bg_layer.add_child(_bg_rect)


func _setup_world() -> void:
	# Vibrant, crisp Miyazaki color grading on world layers <= 5 (HUD 10, Menus 20, Cutscenes 30 untouched).
	# Linear tonemap + glow disabled avoids Vulkan Mobile white highlight blowout while
	# calibrated brightness/contrast/saturation adjustments keep the 6 painted worlds lush & jewel-toned.
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = 5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.glow_enabled = false
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.04
	env.adjustment_contrast = 1.09
	env.adjustment_saturation = 1.18

	_world_env = WorldEnvironment.new()
	_world_env.name = "WorldEnvironment"
	_world_env.environment = env
	add_child(_world_env)

	# Multi-plane atmospheric parallax depth (WorldAtmosphere) when available
	if ResourceLoader.exists(WORLD_ATMOSPHERE_PATH):
		var atmo_script: Script = load(WORLD_ATMOSPHERE_PATH) as Script
		if atmo_script != null:
			var atmo_inst: Object = atmo_script.new()
			if atmo_inst is Node:
				_atmosphere = atmo_inst as Node
				_atmosphere.name = "WorldAtmosphere"
				add_child(_atmosphere)

	_ecosystem = Ecosystem.new()
	_ecosystem.name = "Ecosystem"
	add_child(_ecosystem)

	_vfx_layer = _WorldVfxLayer.new()
	_vfx_layer.name = "WorldVfxLayer"
	_vfx_layer.owner_main = self
	_vfx_layer.z_index = 4
	var vfx_mat: CanvasItemMaterial = CanvasItemMaterial.new()
	vfx_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_vfx_layer.material = vfx_mat
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


func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HudLayer"
	_hud_layer.layer = 10
	add_child(_hud_layer)

	# 1-pass GPU soft breathing dusk-ember edge vignette behind HUD elements
	_danger_vignette = _DangerVignette.new()
	_danger_vignette.name = "DangerVignette"
	_hud_layer.add_child(_danger_vignette)

	_hud_root = Control.new()
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _ui_theme != null:
		_hud_root.theme = _ui_theme
	_hud_layer.add_child(_hud_root)

	# Gossamer translucent water-ripple overlay for world-space direct-glide steering
	_touch_target_overlay = _TouchTargetOverlay.new()
	_touch_target_overlay.name = "TouchTargetOverlay"
	_touch_target_overlay.glow_tex = _glow_tex
	_hud_root.add_child(_touch_target_overlay)

	# Contemplative minimal top-right HUD: ONE whisper-quiet borderless Pause icon (0.36 alpha)
	_top_margin = MarginContainer.new()
	_top_margin.anchor_left = 0.0
	_top_margin.anchor_top = 0.0
	_top_margin.anchor_right = 1.0
	_top_margin.anchor_bottom = 0.0
	_top_margin.offset_bottom = 84.0
	_top_margin.add_theme_constant_override("margin_left", 20)
	_top_margin.add_theme_constant_override("margin_right", 20)
	_top_margin.add_theme_constant_override("margin_top", 16)
	_top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_top_margin)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_END
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_margin.add_child(top_row)

	_pause_btn = _make_borderless_icon_button("pause", 0.36)
	_pause_btn.pressed.connect(_on_pause_pressed)
	top_row.add_child(_pause_btn)

	# Floating poetic scale / power evolution banner
	_banner_panel = PanelContainer.new()
	_banner_panel.name = "FloatingBanner"
	_banner_panel.anchor_left = 0.5
	_banner_panel.anchor_top = 0.0
	_banner_panel.anchor_right = 0.5
	_banner_panel.anchor_bottom = 0.0
	_banner_panel.offset_left = -230.0
	_banner_panel.offset_right = 230.0
	_banner_panel.offset_top = 76.0
	_banner_panel.offset_bottom = 148.0
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

	# Bottom-left VirtualJoystick (100% invisible at rest, appears smoothly on thumb touch)
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

	# Bottom-right borderless translucent liquid-glass teardrop power droplets
	_spit_btn = _TouchPowerButton.new()
	_spit_btn.name = "SpitButton"
	_spit_btn.icon_kind = "flame"
	_spit_btn.accent_color = Color(1.0, 0.56, 0.32, 1.0)
	_spit_btn.glow_tex = _glow_tex
	_spit_btn.anchor_left = 1.0
	_spit_btn.anchor_top = 1.0
	_spit_btn.anchor_right = 1.0
	_spit_btn.anchor_bottom = 1.0
	_spit_btn.offset_left = -218.0
	_spit_btn.offset_top = -128.0
	_spit_btn.offset_right = -130.0
	_spit_btn.offset_bottom = -32.0
	_spit_btn.activated.connect(_trigger_lava_spit)
	_hud_root.add_child(_spit_btn)

	_dash_btn = _TouchPowerButton.new()
	_dash_btn.name = "DashButton"
	_dash_btn.icon_kind = "shockwave"
	_dash_btn.accent_color = Color(0.46, 0.92, 0.98, 1.0)
	_dash_btn.glow_tex = _glow_tex
	_dash_btn.anchor_left = 1.0
	_dash_btn.anchor_top = 1.0
	_dash_btn.anchor_right = 1.0
	_dash_btn.anchor_bottom = 1.0
	_dash_btn.offset_left = -112.0
	_dash_btn.offset_top = -150.0
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
	_title_panel.name = "TitlePanel"
	_title_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _ui_theme != null:
		_title_panel.theme = _ui_theme
	_menu_layer.add_child(_title_panel)

	# Full-bleed living Ghibli keyart with gentle breathing zoom (clipped cleanly)
	var art_clip: Control = Control.new()
	art_clip.name = "TitleArtClip"
	art_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_clip.clip_contents = true
	art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_panel.add_child(art_clip)

	_title_art_rect = TextureRect.new()
	_title_art_rect.name = "TitleKeyArt"
	_title_art_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_title_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(TITLE_KEYART_PATH):
		_title_art_rect.texture = load(TITLE_KEYART_PATH) as Texture2D
	art_clip.add_child(_title_art_rect)

	# Whisper-light atmospheric night gradient on the right sky ONLY (leaves Charlie 100% open & bright!)
	var right_grad_tex: GradientTexture2D = GradientTexture2D.new()
	var rg: Gradient = Gradient.new()
	rg.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	rg.colors = PackedColorArray([
		Color(0.015, 0.04, 0.08, 0.0),
		Color(0.015, 0.04, 0.08, 0.22),
		Color(0.015, 0.04, 0.08, 0.42),
	])
	right_grad_tex.gradient = rg
	right_grad_tex.width = 64
	right_grad_tex.height = 4
	right_grad_tex.fill_from = Vector2(0.0, 0.5)
	right_grad_tex.fill_to = Vector2(1.0, 0.5)

	var sky_veil: TextureRect = TextureRect.new()
	sky_veil.anchor_left = 0.36
	sky_veil.anchor_top = 0.0
	sky_veil.anchor_right = 1.0
	sky_veil.anchor_bottom = 1.0
	sky_veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky_veil.texture = right_grad_tex
	sky_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_panel.add_child(sky_veil)

	# Live drifting golden firefly particles over the storybook painting
	_title_fireflies = _TitleFireflies.new()
	_title_fireflies.name = "TitleFireflies"
	_title_fireflies.glow_tex = _glow_tex
	_title_panel.add_child(_title_fireflies)

	# Floating storybook typographic stack gracefully positioned over the open right-center sky
	# (NO opaque dark modal card covering Charlie!)
	_title_stack = Control.new()
	_title_stack.name = "TitleTypoStack"
	_title_stack.anchor_left = 0.50
	_title_stack.anchor_top = 0.0
	_title_stack.anchor_right = 0.94
	_title_stack.anchor_bottom = 1.0
	_title_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_panel.add_child(_title_stack)

	# Super-soft borderless radial dark mist glow behind the title stack (0.36 -> 0.0 alpha, zero visible edges)
	var mist_grad: Gradient = Gradient.new()
	mist_grad.offsets = PackedFloat32Array([0.0, 0.24, 0.46, 0.68, 0.86, 1.0])
	mist_grad.colors = PackedColorArray([
		Color(0.0, 0.0, 0.0, 0.36),
		Color(0.0, 0.0, 0.0, 0.31),
		Color(0.0, 0.0, 0.0, 0.21),
		Color(0.0, 0.0, 0.0, 0.10),
		Color(0.0, 0.0, 0.0, 0.025),
		Color(0.0, 0.0, 0.0, 0.0),
	])
	var mist_tex: GradientTexture2D = GradientTexture2D.new()
	mist_tex.width = 128
	mist_tex.height = 128
	mist_tex.fill = GradientTexture2D.FILL_RADIAL
	mist_tex.fill_from = Vector2(0.5, 0.5)
	mist_tex.fill_to = Vector2(1.0, 0.5)
	mist_tex.gradient = mist_grad

	var title_mist: TextureRect = TextureRect.new()
	title_mist.name = "TitleMistGlow"
	title_mist.anchor_left = -0.20
	title_mist.anchor_top = 0.12
	title_mist.anchor_right = 1.20
	title_mist.anchor_bottom = 0.86
	title_mist.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title_mist.stretch_mode = TextureRect.STRETCH_SCALE
	title_mist.texture = mist_tex
	title_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_stack.add_child(title_mist)

	var stack_center: CenterContainer = CenterContainer.new()
	stack_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_stack.add_child(stack_center)

	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack_center.add_child(col)

	var title_lbl: Label = Label.new()
	title_lbl.text = "CHARLIE"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font_display != null:
		title_lbl.add_theme_font_override("font", _font_display)
	title_lbl.add_theme_font_size_override("font_size", 64)
	title_lbl.add_theme_color_override("font_color", Color("#fff6e5"))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.18, 0.06, 0.04, 0.65))
	title_lbl.add_theme_constant_override("shadow_offset_x", 0)
	title_lbl.add_theme_constant_override("shadow_offset_y", 3)
	title_lbl.add_theme_constant_override("shadow_outline_size", 4)
	title_lbl.add_theme_color_override("font_outline_color", Color(0.18, 0.06, 0.04, 0.18))
	title_lbl.add_theme_constant_override("outline_size", 1)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(title_lbl)

	var sub_lbl: Label = Label.new()
	sub_lbl.text = "DE L'ATOME AU COSMOS"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _font_ui_tracked != null:
		sub_lbl.add_theme_font_override("font", _font_ui_tracked)
	elif _font_ui_bold != null:
		sub_lbl.add_theme_font_override("font", _font_ui_bold)
	sub_lbl.add_theme_font_size_override("font_size", 14)
	sub_lbl.add_theme_color_override("font_color", Color("#ffd166"))
	sub_lbl.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.10, 0.82))
	sub_lbl.add_theme_constant_override("shadow_offset_y", 2)
	sub_lbl.add_theme_constant_override("shadow_outline_size", 6)
	sub_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sub_lbl)

	var cta_spacer: Control = Control.new()
	cta_spacer.custom_minimum_size = Vector2(0.0, 18.0)
	cta_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cta_spacer)

	var cta_wrap: CenterContainer = CenterContainer.new()
	cta_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(cta_wrap)

	var play_btn: Button = _make_title_cta_button("Plonger")
	play_btn.pressed.connect(_on_start_game)
	cta_wrap.add_child(play_btn)

	var chip_spacer: Control = Control.new()
	chip_spacer.custom_minimum_size = Vector2(0.0, 10.0)
	chip_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(chip_spacer)

	# Subtle floating borderless difficulty chips underneath Plonger
	var chips_wrap: CenterContainer = CenterContainer.new()
	chips_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(chips_wrap)

	var chips_row: HBoxContainer = HBoxContainer.new()
	chips_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chips_row.add_theme_constant_override("separation", 8)
	chips_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chips_wrap.add_child(chips_row)

	_title_diff_buttons.clear()
	for mode_key: String in ["toddler", "chill", "wild"]:
		var preset: Dictionary = Scales.DIFFICULTY_PRESETS[mode_key] as Dictionary
		var chip: Button = Button.new()
		chip.text = String(preset["label"])
		chip.custom_minimum_size = Vector2(0.0, 34.0)
		if _font_ui != null:
			chip.add_theme_font_override("font", _font_ui)
		chip.add_theme_font_size_override("font_size", 13)
		chip.pressed.connect(func() -> void: _set_difficulty_option(mode_key))
		chips_row.add_child(chip)
		_title_diff_buttons[mode_key] = chip

	# Minimal top-right gear icon (Options) respecting safe-area insets
	_title_top_margin = MarginContainer.new()
	_title_top_margin.name = "TitleTopMargin"
	_title_top_margin.anchor_left = 0.0
	_title_top_margin.anchor_top = 0.0
	_title_top_margin.anchor_right = 1.0
	_title_top_margin.anchor_bottom = 0.0
	_title_top_margin.offset_bottom = 84.0
	_title_top_margin.add_theme_constant_override("margin_left", 20)
	_title_top_margin.add_theme_constant_override("margin_right", 20)
	_title_top_margin.add_theme_constant_override("margin_top", 16)
	_title_top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_panel.add_child(_title_top_margin)

	var title_top_row: HBoxContainer = HBoxContainer.new()
	title_top_row.alignment = BoxContainer.ALIGNMENT_END
	title_top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_top_margin.add_child(title_top_row)

	_title_options_btn = _make_borderless_icon_button("gear", 0.68)
	_title_options_btn.tooltip_text = "Options"
	_title_options_btn.pressed.connect(func() -> void: _open_options(GameState.TITLE))
	title_top_row.add_child(_title_options_btn)


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

	_pause_mute_btn = _make_menu_button("Son : Coupé" if audio_muted else "Son : Activé", false)
	_pause_mute_btn.pressed.connect(_on_toggle_mute)
	col.add_child(_pause_mute_btn)

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

	# Audio toggle (lives cleanly in Options & Pause instead of cluttering the HUD)
	_audio_toggle = CheckButton.new()
	_audio_toggle.text = "Son et musique"
	_audio_toggle.button_pressed = not audio_muted
	_audio_toggle.add_theme_font_size_override("font_size", 15)
	_audio_toggle.toggled.connect(_on_audio_toggled)
	col.add_child(_audio_toggle)

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
	box.bg_color = Color(0.035, 0.085, 0.135, 0.72)
	box.border_color = Color(1.0, 0.90, 0.72, 0.18)
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0.0, 0.02, 0.06, 0.48)
	box.shadow_size = 28
	box.shadow_offset = Vector2(0.0, 10.0)
	box.content_margin_left = 30.0
	box.content_margin_right = 30.0
	box.content_margin_top = 26.0
	box.content_margin_bottom = 26.0
	return box


func _make_borderless_icon_button(icon_id: String, idle_alpha: float) -> _IconButton:
	var b: _IconButton = _IconButton.new()
	b.text = ""
	b.icon_name = icon_id
	b.custom_minimum_size = Vector2(44.0, 44.0)
	b.modulate.a = idle_alpha
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var hover: StyleBoxFlat = StyleBoxFlat.new()
	hover.bg_color = Color(1.0, 0.96, 0.90, 0.14)
	hover.set_corner_radius_all(22)
	b.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = StyleBoxFlat.new()
	pressed.bg_color = Color(1.0, 0.96, 0.90, 0.24)
	pressed.set_corner_radius_all(22)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


func _make_title_cta_button(label_txt: String) -> Button:
	var b: Button = Button.new()
	b.text = label_txt
	b.custom_minimum_size = Vector2(264.0, 66.0)
	if _font_ui_bold != null:
		b.add_theme_font_override("font", _font_ui_bold)
	b.add_theme_font_size_override("font_size", 20)
	var ink: Color = Color("#141012")
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", ink)
	b.add_theme_color_override("font_pressed_color", ink)
	b.add_theme_color_override("font_focus_color", ink)

	if _cta_pill_normal != null:
		var st_n: StyleBoxTexture = StyleBoxTexture.new()
		st_n.texture = _cta_pill_normal
		st_n.content_margin_left = 28.0
		st_n.content_margin_right = 28.0
		st_n.content_margin_top = 12.0
		st_n.content_margin_bottom = 12.0
		b.add_theme_stylebox_override("normal", st_n)

		var st_h: StyleBoxTexture = st_n.duplicate() as StyleBoxTexture
		st_h.texture = _cta_pill_hover
		b.add_theme_stylebox_override("hover", st_h)

		var st_p: StyleBoxTexture = st_n.duplicate() as StyleBoxTexture
		st_p.texture = _cta_pill_pressed
		b.add_theme_stylebox_override("pressed", st_p)
	else:
		var fallback: StyleBoxFlat = StyleBoxFlat.new()
		fallback.bg_color = Color("#ff8364")
		fallback.set_corner_radius_all(30)
		fallback.shadow_color = Color(1.0, 0.46, 0.34, 0.48)
		fallback.shadow_size = 18
		b.add_theme_stylebox_override("normal", fallback)
		b.add_theme_stylebox_override("hover", fallback)
		b.add_theme_stylebox_override("pressed", fallback)
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
		# Warm glowing coral-orange CTA with high-contrast dark ink (#141012)
		st.bg_color = Color("#ff8364")
		st.border_color = Color(1.0, 0.84, 0.66, 0.62)
		st.shadow_color = Color(1.0, 0.44, 0.34, 0.36)
		st.shadow_size = 14
		st.shadow_offset = Vector2(0.0, 4.0)
		var dark_ink: Color = Color("#141012")
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
		_audio.set_muted(audio_muted or _is_capture_mode)
	if _pause_mute_btn != null:
		_pause_mute_btn.text = "Son : Coupé" if audio_muted else "Son : Activé"
	_refresh_options_ui()


func _apply_title_difficulty_chip_style(btn: Button, selected: bool) -> void:
	# Translucent borderless floating chip on the Ghibli title screen
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.set_corner_radius_all(18)
	st.set_border_width_all(0)
	st.content_margin_left = 15.0
	st.content_margin_right = 15.0
	st.content_margin_top = 6.0
	st.content_margin_bottom = 6.0
	if selected:
		st.bg_color = Color(1.0, 0.62, 0.38, 0.34)
		st.shadow_color = Color(1.0, 0.64, 0.34, 0.28)
		st.shadow_size = 10
		st.shadow_offset = Vector2(0.0, 2.0)
		var active_ink: Color = Color("#fff6e5")
		btn.add_theme_color_override("font_color", active_ink)
		btn.add_theme_color_override("font_hover_color", active_ink)
		btn.add_theme_color_override("font_pressed_color", active_ink)
		btn.add_theme_color_override("font_focus_color", active_ink)
	else:
		st.bg_color = Color(0.04, 0.08, 0.14, 0.38)
		btn.add_theme_color_override("font_color", Color(0.88, 0.90, 0.92, 0.72))
		btn.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.88, 0.96))
		btn.add_theme_color_override("font_pressed_color", Color(1.0, 0.96, 0.88, 0.96))
		btn.add_theme_color_override("font_focus_color", Color(0.88, 0.90, 0.92, 0.72))
	btn.add_theme_stylebox_override("normal", st)
	var hover: StyleBoxFlat = st.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 0.66, 0.42, 0.44) if selected else Color(0.08, 0.14, 0.22, 0.54)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = st.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.98, 0.56, 0.34, 0.48) if selected else Color(0.06, 0.12, 0.20, 0.62)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _apply_difficulty_pill_style(btn: Button, selected: bool) -> void:
	btn.modulate = Color.WHITE
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.set_corner_radius_all(20)
	if selected:
		st.bg_color = Color(0.98, 0.50, 0.34, 0.28)
		st.border_color = Color(1.0, 0.80, 0.48, 0.94)
		st.set_border_width_all(2)
		st.shadow_color = Color(1.0, 0.52, 0.30, 0.32)
		st.shadow_size = 10
		st.shadow_offset = Vector2(0.0, 2.0)
		var active_ink: Color = Color("#fff5df")
		btn.add_theme_color_override("font_color", active_ink)
		btn.add_theme_color_override("font_hover_color", active_ink)
		btn.add_theme_color_override("font_pressed_color", active_ink)
		btn.add_theme_color_override("font_focus_color", active_ink)
	else:
		st.bg_color = Color(0.04, 0.10, 0.17, 0.62)
		st.border_color = Color(1.0, 1.0, 1.0, 0.12)
		st.set_border_width_all(1)
		btn.add_theme_color_override("font_color", Color(0.76, 0.86, 0.92, 0.80))
		btn.add_theme_color_override("font_hover_color", Color(0.94, 0.98, 1.0, 0.95))
		btn.add_theme_color_override("font_pressed_color", Color(0.94, 0.98, 1.0, 0.95))
		btn.add_theme_color_override("font_focus_color", Color(0.76, 0.86, 0.92, 0.80))
	btn.add_theme_stylebox_override("normal", st)
	var hover: StyleBoxFlat = st.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 0.56, 0.38, 0.36) if selected else Color(0.08, 0.17, 0.26, 0.78)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = st.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.96, 0.46, 0.30, 0.40) if selected else Color(0.06, 0.14, 0.22, 0.86)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _refresh_options_ui() -> void:
	for mode_key: String in _title_diff_buttons.keys():
		var chip: Button = _title_diff_buttons[mode_key] as Button
		_apply_title_difficulty_chip_style(chip, mode_key == difficulty_mode)

	if _diff_desc_label == null:
		return
	var preset: Dictionary = Scales.DIFFICULTY_PRESETS[difficulty_mode] as Dictionary
	_diff_desc_label.text = String(preset["desc"])
	for mode_key: String in _diff_buttons.keys():
		var btn: Button = _diff_buttons[mode_key] as Button
		var selected: bool = (mode_key == difficulty_mode)
		_apply_difficulty_pill_style(btn, selected)
	if _bites_slider != null:
		_bites_slider.set_value_no_signal(float(bites_per_scale))
	if _bites_value_label != null:
		_bites_value_label.text = str(bites_per_scale)
	if _audio_toggle != null:
		_audio_toggle.set_pressed_no_signal(not audio_muted)
	if _pause_mute_btn != null:
		_pause_mute_btn.text = "Son : Coupé" if audio_muted else "Son : Activé"
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


func _on_audio_toggled(enabled: bool) -> void:
	audio_muted = not enabled
	if _audio != null:
		_audio.set_muted(audio_muted or _is_capture_mode)
		if enabled and not _is_capture_mode:
			_audio.play_chime(1.15)
	if _pause_mute_btn != null:
		_pause_mute_btn.text = "Son : Coupé" if audio_muted else "Son : Activé"
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
	if _pause_mute_btn != null:
		_pause_mute_btn.text = "Son : Coupé" if audio_muted else "Son : Activé"
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
	if _pause_mute_btn != null:
		_pause_mute_btn.text = "Son : Coupé" if audio_muted else "Son : Activé"
	if _audio_toggle != null:
		_audio_toggle.set_pressed_no_signal(not audio_muted)
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
	if _charlie.has_method("set_regen_progress"):
		_charlie.call("set_regen_progress", 0.0)
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
	if _spit_btn != null:
		_spit_btn.set_context_visibility(_TouchPowerButton.PEACEFUL_ALPHA)
	if _dash_btn != null:
		_dash_btn.set_context_visibility(_TouchPowerButton.PEACEFUL_ALPHA)
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
	_trigger_lava_spit_at(_find_auto_aim_angle())


func _trigger_lava_spit_at(base_angle: float) -> void:
	if state != GameState.PLAYING or _spit_cd_left > 0.0:
		return
	var preset: Dictionary = Scales.DIFFICULTY_PRESETS[difficulty_mode] as Dictionary
	_spit_cd_left = float(preset.get("spit_cd", 2.4))

	var lvl: int = _get_power_level()
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
	var input_dir: Vector2 = _read_move_input()
	var dash_angle: float = input_dir.angle() if input_dir.length_squared() > 0.04 else _charlie.facing_angle
	_trigger_shockwave_dash_at(dash_angle)


func _trigger_shockwave_dash_at(dash_angle: float) -> void:
	if state != GameState.PLAYING or _dash_cd_left > 0.0:
		return
	var lvl: int = _get_power_level()
	_dash_cd_left = _get_dash_cooldown()

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

func _is_point_on_top_hud_button(pos: Vector2) -> bool:
	if _pause_btn != null and _pause_btn.is_visible_in_tree() and _pause_btn.get_global_rect().grow(10.0).has_point(pos):
		return true
	return false


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	var xf: Transform2D = get_canvas_transform()
	if absf(xf.determinant()) > 0.0000001:
		return xf.affine_inverse() * screen_pos
	if _camera != null:
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		var zx: float = maxf(_camera.zoom.x, 0.0001)
		var zy: float = maxf(_camera.zoom.y, 0.0001)
		var delta_px: Vector2 = screen_pos - vp_size * 0.5
		return _camera.get_screen_center_position() + Vector2(delta_px.x / zx, delta_px.y / zy)
	return screen_pos


func _find_predator_near_world_point(world_pos: Vector2) -> Creature:
	if _ecosystem == null or _charlie == null:
		return null
	var min_pred_size: float = _charlie.world_size * 0.94
	var best_pred: Creature = null
	var best_dist: float = INF
	var creatures: Array[Creature] = _ecosystem.get_creatures()
	for c: Creature in creatures:
		if not is_instance_valid(c) or not c.alive:
			continue
		if c.world_size < min_pred_size:
			continue
		var tap_radius: float = maxf(c.world_size * 2.3, _charlie.world_size * 2.6)
		var d: float = world_pos.distance_to(c.position)
		if d <= tap_radius and d < best_dist:
			best_dist = d
			best_pred = c
	return best_pred


func _unhandled_input(event: InputEvent) -> void:
	# World-space direct-glide touch steering + one-handed tap gestures
	# (events handled by VirtualJoystick or liquid-glass power droplets never arrive here)
	if event is InputEventScreenTouch:
		var tev: InputEventScreenTouch = event as InputEventScreenTouch
		if tev.pressed:
			if state == GameState.PLAYING and _direct_touch_index == -1 and not _is_point_on_top_hud_button(tev.position):
				_direct_touch_index = tev.index
				_direct_touch_pos = tev.position
				_direct_touch_start_pos = tev.position
				_direct_touch_start_time = _vfx_time
				_direct_touch_max_move = 0.0
				if _touch_target_overlay != null:
					_touch_target_overlay.set_target(_direct_touch_pos, true)
		else:
			if tev.index == _direct_touch_index:
				var elapsed: float = _vfx_time - _direct_touch_start_time
				var total_move: float = maxf(_direct_touch_max_move, tev.position.distance_to(_direct_touch_start_pos))
				_direct_touch_index = -1
				if _touch_target_overlay != null:
					_touch_target_overlay.release()

				if state == GameState.PLAYING and elapsed < QUICK_TAP_MAX_TIME and total_move < QUICK_TAP_MAX_MOVE:
					var world_tap: Vector2 = _screen_to_world(tev.position)
					var tapped_pred: Creature = _find_predator_near_world_point(world_tap)
					if tapped_pred != null:
						_last_open_tap_time = -10.0
						_trigger_lava_spit_at((tapped_pred.position - _charlie.position).angle())
					else:
						var dt_tap: float = _vfx_time - _last_open_tap_time
						var d_tap: float = tev.position.distance_to(_last_open_tap_pos)
						if dt_tap <= DOUBLE_TAP_MAX_INTERVAL and d_tap <= DOUBLE_TAP_MAX_DIST:
							_last_open_tap_time = -10.0
							var to_tap: Vector2 = world_tap - _charlie.position
							var dash_ang: float = to_tap.angle() if to_tap.length() > _charlie.world_size * 0.4 else _charlie.facing_angle
							_trigger_shockwave_dash_at(dash_ang)
						else:
							_last_open_tap_time = _vfx_time
							_last_open_tap_pos = tev.position
		return

	if event is InputEventScreenDrag:
		var dev: InputEventScreenDrag = event as InputEventScreenDrag
		if state == GameState.PLAYING and dev.index == _direct_touch_index:
			_direct_touch_pos = dev.position
			_direct_touch_max_move = maxf(_direct_touch_max_move, dev.position.distance_to(_direct_touch_start_pos))
			if _touch_target_overlay != null:
				_touch_target_overlay.set_target(_direct_touch_pos, true)
		return

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
	if _is_capture_mode and _capture_steer_override.length_squared() > 0.0001:
		return _capture_steer_override

	var vec: Vector2 = Vector2.ZERO
	if _joystick != null and _joystick.is_active:
		vec = _joystick.output_vector
	elif _direct_touch_index != -1:
		var world_target: Vector2 = _screen_to_world(_direct_touch_pos)
		var delta_w: Vector2 = world_target - _charlie.position
		var dist_w: float = delta_w.length()
		var deadzone_w: float = _charlie.world_size * 0.45
		var full_r_w: float = _charlie.world_size * 3.6
		if dist_w > deadzone_w:
			var strength: float = clampf(
				(dist_w - deadzone_w) / maxf(full_r_w - deadzone_w, 0.001),
				0.0,
				1.0
			)
			vec = (delta_w / dist_w) * strength
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
	_play_time += dt
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
	if _atmosphere != null and _atmosphere.has_method("update_atmosphere"):
		_atmosphere.call("update_atmosphere", dt, _bg_parallax, progress, palette, get_viewport().get_visible_rect().size)
	_update_global_shader_uniforms(palette)


func _step_title_swim(dt: float, palette: Dictionary) -> void:
	# Subtle alive breathing zoom & drift on the full-bleed Ghibli title painting
	_title_swim_time += dt
	if _title_art_rect != null and _title_art_rect.is_visible_in_tree():
		_title_art_rect.pivot_offset = _title_art_rect.size * 0.5
		var breath_zoom: float = 1.045 + 0.022 * sin(_title_swim_time * 0.38)
		var pan_x: float = sin(_title_swim_time * 0.23) * 5.0
		var pan_y: float = cos(_title_swim_time * 0.19) * 3.5
		_title_art_rect.scale = Vector2(breath_zoom, breath_zoom)
		_title_art_rect.position = Vector2(pan_x, pan_y)

	# Keep Charlie gently swimming behind the scene so entering gameplay is instant & fluid
	var t: float = _title_swim_time * 0.58
	var rx: float = _charlie.world_size * 7.8
	var ry: float = _charlie.world_size * 4.4
	var center_offset: Vector2 = Vector2(-_charlie.world_size * 3.8, _charlie.world_size * 1.2)
	var target_pos: Vector2 = center_offset + Vector2(sin(t) * rx, sin(t * 2.0) * ry)
	var to_target: Vector2 = target_pos - _charlie.position
	var move_dir: Vector2 = to_target.normalized() * clampf(to_target.length() / maxf(_charlie.world_size * 2.2, 1.0), 0.25, 0.72)

	_charlie.step_motion(dt, move_dir, true, null, null, palette)
	if _vfx_was_active:
		_vfx_layer.queue_redraw()
		_vfx_was_active = false

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

	# Passive & bite-based droplet regeneration with live diegetic progress feedback
	var regen_progress: float = 0.0
	if _charlie.droplets_alive < Charlie.MAX_DROPLETS:
		_time_since_hurt += dt
		if _time_since_hurt >= PASSIVE_HEAL_SECONDS:
			_heal_one_droplet()
		else:
			var time_prog: float = clampf(_time_since_hurt / PASSIVE_HEAL_SECONDS, 0.0, 1.0)
			var bite_prog: float = clampf(float(_heal_bite_counter) / 5.0, 0.0, 1.0)
			regen_progress = maxf(time_prog, bite_prog)
	else:
		_time_since_hurt = 0.0
		regen_progress = 0.0
	if _charlie.has_method("set_regen_progress"):
		_charlie.call("set_regen_progress", regen_progress)

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

	# Danger vignette, predator pulse audio & contextual liquid-glass power droplet awakening
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
		(_charlie != null and _charlie.visible)
		or not _projectiles.is_empty()
		or not _shockwaves.is_empty()
		or not _bursts.is_empty()
		or not _embers.is_empty()
		or _warp_flash_life > 0.0
	)
	if has_vfx or _vfx_was_active:
		_vfx_layer.queue_redraw()
		_vfx_was_active = has_vfx


func _step_danger_feedback(dt: float, predator_chasing: bool, nearest_pred: Variant) -> void:
	# Contextual power droplet awakening: 0.24 peaceful -> 0.82 as a predator approaches
	var power_alert: float = 0.0
	if difficulty_mode != "toddler":
		if predator_chasing:
			power_alert = 1.0
		elif nearest_pred is Creature and is_instance_valid(nearest_pred):
			var pred_near: Creature = nearest_pred as Creature
			var dist_p: float = _charlie.position.distance_to(pred_near.position)
			var sense_r: float = maxf(_charlie.world_size * 8.2, pred_near.world_size * 5.8)
			power_alert = clampf(1.0 - dist_p / maxf(sense_r, 1.0), 0.0, 1.0)
	var droplet_vis: float = lerpf(_TouchPowerButton.PEACEFUL_ALPHA, _TouchPowerButton.ALERT_ALPHA, power_alert)
	if _spit_btn != null:
		_spit_btn.set_context_visibility(droplet_vis)
	if _dash_btn != null:
		_dash_btn.set_context_visibility(droplet_vis)

	if _danger_vignette == null:
		return
	if difficulty_mode == "toddler":
		_danger_vignette.set_intensity(0.0)
		return

	var target_danger: float = 0.0
	if _charlie.droplets_alive <= 0:
		# Critical 0-droplet state: gentle breathing dusk-ember edge warmth
		target_danger = 0.48 + 0.30 * (0.5 + 0.5 * sin(_vfx_time * 4.5))

	if predator_chasing:
		var prox: float = 0.45
		if nearest_pred is Creature and is_instance_valid(nearest_pred):
			var pred_c: Creature = nearest_pred as Creature
			var d: float = _charlie.position.distance_to(pred_c.position)
			var danger_r: float = maxf(_charlie.world_size * 6.4, pred_c.world_size * 4.6)
			prox = clampf(1.0 - d / maxf(danger_r, 1.0), 0.15, 1.0)
		var chase_glow: float = (0.18 + 0.42 * prox) * (0.72 + 0.28 * sin(_vfx_time * 5.2))
		target_danger = maxf(target_danger, chase_glow)

		_predator_pulse_timer -= dt
		if _predator_pulse_timer <= 0.0:
			_predator_pulse_timer = lerpf(0.95, 0.48, prox)
			if _audio != null and _audio.has_method("play_predator_pulse"):
				_audio.play_predator_pulse()
	else:
		_predator_pulse_timer = maxf(0.0, _predator_pulse_timer - dt)

	var next_val: float = lerpf(_danger_vignette.intensity, target_danger, 1.0 - exp(-dt * 6.5))
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
			# Edible prey! Capture visual snapshot BEFORE marking dead for gelatinous absorption
			var sp_col: Color = c.species.get("color", Color(1.0, 0.85, 0.52, 1.0)) as Color
			var sp_accent: Color = c.species.get("accent", Color(1.0, 0.94, 0.74, 1.0)) as Color
			var world_offset: Vector2 = c.position - _charlie.position
			var prey_size_ratio: float = clampf(c.world_size / maxf(_charlie.world_size, 0.001), 0.15, 0.95)
			if _charlie.has_method("swallow_prey"):
				var snap: Dictionary = {}
				if c.has_method("get_visual_snapshot"):
					snap = c.call("get_visual_snapshot") as Dictionary
				var prey_tex: Texture2D = snap.get("texture", snap.get("tex", null)) as Texture2D
				var prey_frame: int = int(snap.get("frame", snap.get("frame_idx", 0)))
				var prey_hframes: int = maxi(1, int(snap.get("hframes", 4)))
				var prey_tint: Color = snap.get("tint", snap.get("color", sp_col)) as Color
				_charlie.call("swallow_prey", prey_tex, prey_frame, prey_hframes, prey_tint, world_offset, prey_size_ratio)

			c.alive = false
			if _combo_timer > 0.0:
				_combo_count = mini(MAX_COMBO, _combo_count + 1)
			else:
				_combo_count = 1
			_combo_timer = COMBO_WINDOW

			var prey_angle: float = world_offset.angle()
			_charlie.trigger_chomp(prey_angle, 1.0 + float(_combo_count - 1) * 0.06)
			var burst_r: float = maxf(c.world_size * 1.65, _charlie.world_size * 0.72)
			_spawn_burst(c.position, sp_col, burst_r)
			_spawn_stardust(c.position, 8, maxf(c.world_size * 1.15, _charlie.world_size * 0.55), sp_col, sp_accent)
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
	if _charlie.has_method("set_regen_progress"):
		_charlie.call("set_regen_progress", 0.0)
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
		if _charlie.has_method("set_regen_progress"):
			_charlie.call("set_regen_progress", 0.0)
		# Seamless logarithmic scale transition: old creatures shrink away visibly during zoom
		if _ecosystem.has_method("begin_scale_transition"):
			_ecosystem.call("begin_scale_transition", current_scale_index)
		else:
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
	# Pull camera out ~8% (0.92x) so the player sees more of the living world and feels faster
	return clampf((36.0 * 0.92) / maxf(charlie_size, 1.0), 0.0001, 4.0)


func _apply_world_backdrop_textures(progress: float) -> void:
	if _bg_mat == null or _world_textures.is_empty():
		return
	var tex_count: int = _world_textures.size()
	var idx_a: int = clampi(int(floor(progress)), 0, tex_count - 1)
	var idx_b: int = mini(idx_a + 1, tex_count - 1)
	var blend: float = clampf(progress - float(idx_a), 0.0, 1.0)
	if idx_a != _last_bg_idx_a:
		_bg_mat.set_shader_parameter("world_tex_a", _world_textures[idx_a])
		_last_bg_idx_a = idx_a
	if idx_b != _last_bg_idx_b:
		_bg_mat.set_shader_parameter("world_tex_b", _world_textures[idx_b])
		_last_bg_idx_b = idx_b
	_bg_mat.set_shader_parameter("world_blend", blend)


func _update_background_shader(palette: Dictionary, progress: float) -> void:
	if _bg_mat == null:
		return
	var accent_col: Color = palette.get("accent", palette["mote_color"]) as Color
	_bg_mat.set_shader_parameter("bg_inner", palette["bg_inner"])
	_bg_mat.set_shader_parameter("bg_outer", palette["bg_outer"])
	_bg_mat.set_shader_parameter("mote_color", palette["mote_color"])
	_bg_mat.set_shader_parameter("accent", accent_col)
	_bg_mat.set_shader_parameter("cam_offset", _bg_parallax)
	_bg_mat.set_shader_parameter("time_sec", _play_time)
	_bg_mat.set_shader_parameter("viewport_size", get_viewport().get_visible_rect().size)
	_bg_mat.set_shader_parameter("scale_progress", progress)
	_apply_world_backdrop_textures(progress)


func _update_global_shader_uniforms(palette: Dictionary) -> void:
	if _global_uniforms.is_empty():
		return
	var bg_inner: Color = palette.get("bg_inner", Color(0.055, 0.153, 0.200, 1.0)) as Color
	var ambient_col: Color = palette.get("ambient", bg_inner) as Color
	var rim_col: Color = palette.get("rim", palette.get("accent", palette.get("mote_color", Color(0.431, 0.906, 0.855, 1.0)))) as Color
	var charlie_col: Color = Color(1.0, 0.56, 0.22, 1.0)
	if _global_uniforms.has(&"g_world_ambient"):
		RenderingServer.global_shader_parameter_set(&"g_world_ambient", ambient_col)
	if _global_uniforms.has(&"g_world_rim_color"):
		RenderingServer.global_shader_parameter_set(&"g_world_rim_color", rim_col)
	if _global_uniforms.has(&"g_charlie_light") and _charlie != null:
		var light_vec: Vector4 = Vector4(
			_charlie.position.x,
			_charlie.position.y,
			_charlie.world_size * 6.4,
			0.92 + 0.06 * sin(_play_time * 3.0)
		)
		RenderingServer.global_shader_parameter_set(&"g_charlie_light", light_vec)
	if _global_uniforms.has(&"g_charlie_color"):
		RenderingServer.global_shader_parameter_set(&"g_charlie_color", charlie_col)


func _update_hud() -> void:
	if _spit_btn == null or _dash_btn == null:
		return

	# Power droplets (only redraw when cooldown ratio or power evolution level changes)
	var preset: Dictionary = Scales.DIFFICULTY_PRESETS[difficulty_mode] as Dictionary
	var spit_max: float = maxf(0.1, float(preset.get("spit_cd", 2.4)))
	var dash_max: float = maxf(0.1, _get_dash_cooldown())
	var power_lvl: int = _get_power_level()
	var lvl_changed: bool = (power_lvl != _hud_last_power_lvl)

	var spit_ratio: float = clampf(_spit_cd_left / spit_max, 0.0, 1.0)
	if lvl_changed or absf(spit_ratio - _hud_last_spit_cd) > 0.004 or (spit_ratio == 0.0 and _hud_last_spit_cd != 0.0):
		_hud_last_spit_cd = spit_ratio
		_spit_btn.power_level = power_lvl
		_spit_btn.cooldown_ratio = spit_ratio
		_spit_btn.queue_redraw()

	var dash_ratio: float = clampf(_dash_cd_left / dash_max, 0.0, 1.0)
	if lvl_changed or absf(dash_ratio - _hud_last_dash_cd) > 0.004 or (dash_ratio == 0.0 and _hud_last_dash_cd != 0.0):
		_hud_last_dash_cd = dash_ratio
		_dash_btn.power_level = power_lvl
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
		if _embers.size() >= 84:
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


func _spawn_stardust(pos: Vector2, count: int, spread_scale: float, base_col: Color, accent_col: Color) -> void:
	for i: int in range(count):
		if _embers.size() >= 84:
			_embers.pop_front()
		var ang: float = (float(i) / float(maxi(1, count))) * TAU + randf_range(-0.35, 0.35)
		var spd: float = spread_scale * randf_range(2.0, 5.2)
		var life: float = randf_range(0.28, 0.54)
		var col: Color = base_col.lerp(accent_col, randf_range(0.0, 0.65))
		_embers.append({
			"pos": pos + Vector2.from_angle(ang) * (spread_scale * 0.18),
			"vel": Vector2.from_angle(ang) * spd,
			"radius": maxf(1.4, spread_scale * randf_range(0.09, 0.18)),
			"life": life,
			"max_life": life,
			"color": col,
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
	# Soft warm honey-amber ambient lantern light pool cast gently beneath Charlie (low alpha, never glaring white)
	if state == GameState.PLAYING and _charlie != null and _charlie.visible:
		var pulse: float = 0.94 + 0.06 * sin(_play_time * 2.6)
		var c_pos: Vector2 = _charlie.position
		var c_sz: float = _charlie.world_size
		_draw_soft_glow(canvas, c_pos, c_sz * 4.6, Color(1.0, 0.54, 0.18, 0.14 * pulse))
		_draw_soft_glow(canvas, c_pos, c_sz * 2.1, Color(1.0, 0.66, 0.26, 0.06 * pulse))

	# Additive bioluminescent VFX layer (BLEND_MODE_ADD)
	if _warp_flash_life > 0.0:
		var wf_frac: float = clampf(_warp_flash_life / maxf(0.01, _warp_flash_max), 0.0, 1.0)
		var wf_inv: float = 1.0 - wf_frac
		var base_r: float = _charlie.world_size
		var mist_col: Color = Color(_warp_color.r, _warp_color.g, _warp_color.b, wf_frac * wf_frac * 0.32)
		_draw_soft_glow(canvas, _warp_origin, base_r * (4.0 + wf_inv * 14.0), mist_col)
		var core_mist: Color = Color(1.28, 1.18, 0.96, wf_frac * wf_frac * 0.40)
		_draw_soft_glow(canvas, _warp_origin, base_r * (2.2 + wf_inv * 6.5), core_mist)
		for ring_i: int in range(3):
			var delay: float = float(ring_i) * 0.14
			var r_t: float = clampf((wf_inv - delay) / (1.0 - delay), 0.0, 1.0)
			if r_t > 0.0 and r_t < 1.0:
				var r_fade: float = (1.0 - r_t) * (1.0 - r_t)
				var ring_r: float = base_r * (1.4 + r_t * (11.5 - float(ring_i) * 1.6))
				var outer_ring: Color = Color(_warp_color.r, _warp_color.g, _warp_color.b, r_fade * 0.34)
				var inner_ring: Color = Color(1.32, 1.24, 1.06, r_fade * 0.78)
				canvas.draw_arc(_warp_origin, ring_r, 0.0, TAU, 56, outer_ring, maxf(3.0, base_r * 0.30 * r_fade), true)
				canvas.draw_arc(_warp_origin, ring_r, 0.0, TAU, 56, inner_ring, maxf(1.5, base_r * 0.10 * r_fade), true)

	# Shockwaves (soft outer halo band + HDR luminous core ring + spawn flash)
	for w: Dictionary in _shockwaves:
		var frac: float = clampf(float(w["life"]) / maxf(0.01, float(w["max_life"])), 0.0, 1.0)
		var w_pos: Vector2 = w["pos"] as Vector2
		var col: Color = w["color"] as Color
		var rad: float = float(w["radius"])
		var halo_col: Color = Color(col.r, col.g, col.b, frac * 0.32)
		var core_ring_col: Color = Color(col.r * 1.32 + 0.20, col.g * 1.32 + 0.20, col.b * 1.32 + 0.20, frac * 0.92)
		canvas.draw_arc(w_pos, rad, 0.0, TAU, 48, halo_col, maxf(4.0, _charlie.world_size * 0.34 * frac), true)
		canvas.draw_arc(w_pos, rad, 0.0, TAU, 48, core_ring_col, maxf(1.8, _charlie.world_size * 0.11 * frac), true)
		if frac > 0.45:
			var flash_a: float = ((frac - 0.45) / 0.55) * 0.34
			_draw_soft_glow(canvas, w_pos, rad * 0.72, Color(col.r, col.g, col.b, flash_a))

	# Molten embers & species-colored stardust droplets (additive HDR sparks)
	for em: Dictionary in _embers:
		var frac: float = clampf(float(em["life"]) / maxf(0.01, float(em["max_life"])), 0.0, 1.0)
		var em_pos: Vector2 = em["pos"] as Vector2
		var em_r: float = float(em["radius"]) * (0.45 + 0.55 * frac)
		var col: Color = em["color"] as Color
		_draw_soft_glow(canvas, em_pos, em_r * 2.5, Color(col.r, col.g, col.b, frac * 0.50))
		_draw_soft_glow(canvas, em_pos, em_r * 1.12, Color(1.36, 1.28, 1.08, frac * 0.90))

	# Lava spit projectiles (multi-layer HDR molten glow)
	for p: Dictionary in _projectiles:
		var pos: Vector2 = p["pos"] as Vector2
		var r: float = float(p["radius"])
		var lvl: int = int(p["level"])
		var outer_col: Color = Color(1.0, 0.42, 0.20, 0.42) if lvl < 3 else Color(1.0, 0.70, 0.24, 0.54)
		var mid_col: Color = Color(1.22, 0.62, 0.32, 0.86) if lvl < 3 else Color(1.28, 0.92, 0.40, 0.92)
		var core_col: Color = Color(1.48, 1.38, 1.12, 0.98)
		_draw_soft_glow(canvas, pos, r * (3.1 if lvl >= 3 else 2.5), outer_col)
		_draw_soft_glow(canvas, pos, r * 1.45, mid_col)
		_draw_soft_glow(canvas, pos, r * 0.78, core_col)

	# Chomp / impact / heal bursts (soft flash + expanding glow ring + HDR sparkles)
	for b: Dictionary in _bursts:
		var frac: float = clampf(float(b["life"]) / maxf(0.01, float(b["max_life"])), 0.0, 1.0)
		var inv_f: float = 1.0 - frac
		var pos: Vector2 = b["pos"] as Vector2
		var col: Color = b["color"] as Color
		var max_r: float = float(b["radius"])
		_draw_soft_glow(canvas, pos, max_r * (0.95 + inv_f * 0.65), Color(col.r, col.g, col.b, frac * frac * 0.46))
		var ring_r: float = max_r * (0.32 + inv_f * 0.92)
		canvas.draw_arc(pos, ring_r, 0.0, TAU, 32, Color(col.r, col.g, col.b, frac * 0.38), maxf(3.0, max_r * 0.20 * frac), true)
		canvas.draw_arc(pos, ring_r, 0.0, TAU, 32, Color(1.30, 1.24, 1.08, frac * 0.82), maxf(1.4, max_r * 0.065 * frac), true)
		for i: int in range(6):
			var ang: float = float(i) * TAU / 6.0 + inv_f * 0.65
			var p_off: Vector2 = Vector2.from_angle(ang) * (max_r * (0.25 + inv_f * 0.98))
			var sp_r: float = maxf(1.4, max_r * 0.18 * frac)
			_draw_soft_glow(canvas, pos + p_off, sp_r * 2.2, Color(col.r, col.g, col.b, frac * 0.56))
			_draw_soft_glow(canvas, pos + p_off, sp_r * 1.0, Color(1.36, 1.30, 1.12, frac * 0.90))


# --- Visual QA Deterministic Screenshot Harness (--capture-shots=<dir>) ---

func _get_capture_shots_dir() -> String:
	for raw_arg: String in OS.get_cmdline_user_args():
		if raw_arg.begins_with("--capture-shots="):
			return raw_arg.substr("--capture-shots=".length()).strip_edges()
	for raw_arg: String in OS.get_cmdline_args():
		if raw_arg.begins_with("--capture-shots="):
			return raw_arg.substr("--capture-shots=".length()).strip_edges()
	return ""


func _wait_capture_frames(count: int) -> void:
	for _i: int in range(count):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _save_capture_png(out_dir: String, filename: String) -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img: Image = get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		var out_path: String = out_dir.path_join(filename)
		var err: Error = img.save_png(out_path)
		print("[capture_shots] Saved %s (%dx%d, err=%d)" % [out_path, img.get_width(), img.get_height(), int(err)])
	else:
		push_warning("[capture_shots] Empty viewport image for %s" % filename)


func _prepare_capture_world(scale_idx: int, steer_dir: Vector2) -> void:
	_capture_steer_override = steer_dir
	_hide_all_overlays()
	_clear_banners()
	state = GameState.PLAYING
	_hud_root.visible = true
	_reset_world_to_scale(scale_idx)
	_charlie.invuln_timer = 10.0

	# Frame a rich, unobstructed composition of illuminated creatures around Charlie's 24-frame swim path
	var sz: float = _charlie.world_size
	var creatures: Array[Creature] = _ecosystem.get_creatures()
	var prey_offsets: Array[Vector2] = [
		Vector2(5.6, -2.5),
		Vector2(-1.6, -2.6),
		Vector2(5.8, 1.8),
		Vector2(-1.2, 2.4),
		Vector2(3.4, -4.0),
		Vector2(1.2, 3.6),
	]
	var pred_offsets: Array[Vector2] = [
		Vector2(-4.8, -2.8),
		Vector2(9.2, 1.9),
		Vector2(-4.4, 2.8),
		Vector2(8.8, -3.4),
	]
	var prey_i: int = 0
	var pred_i: int = 0
	for c: Creature in creatures:
		if not is_instance_valid(c):
			continue
		c.alpha = 1.0
		c.modulate.a = 1.0
		if c.world_size < sz * Ecosystem.EDIBLE_RATIO and prey_i < prey_offsets.size():
			c.position = _charlie.position + prey_offsets[prey_i] * sz
			prey_i += 1
		elif c.world_size >= sz * Ecosystem.PREDATOR_RATIO and pred_i < pred_offsets.size():
			c.position = _charlie.position + pred_offsets[pred_i] * sz
			pred_i += 1
		c.update_visuals(sz)


func _run_visual_capture(out_dir: String) -> void:
	# Ensure exact 1280x720 16:9 windowed capture even when project.godot defaults to fullscreen
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _wait_capture_frames(4)
	_update_safe_area()

	# 1. Living Ghibli Title Screen
	_enter_title_screen()
	if _overlay_tween != null and _overlay_tween.is_valid():
		_overlay_tween.kill()
	_title_panel.modulate.a = 1.0
	await _wait_capture_frames(14)
	_save_capture_png(out_dir, "01_title.png")

	# 2. Miyazaki Bedroom Window Prologue Cutscene
	if _cutscenes != null:
		_hide_all_overlays()
		_hud_root.visible = false
		state = GameState.CUTSCENE
		_cutscenes.play_cutscene("intro", func() -> void: pass)
		await _wait_capture_frames(18)
		_save_capture_png(out_dir, "02_prologue.png")
		if _cutscenes.has_method("skip_cutscene"):
			_cutscenes.skip_cutscene()

	var swim_dir: Vector2 = Vector2(0.88, -0.22)

	# 3. Scale 0 — Quantique (with active liquid-glass joystick preview for visual QA)
	_prepare_capture_world(0, swim_dir)
	if _joystick != null and _joystick.has_method("debug_set_preview"):
		_joystick.call("debug_set_preview", true, Vector2(0.72, -0.32))
	await _wait_capture_frames(24)
	_save_capture_png(out_dir, "03_quantum.png")
	if _joystick != null and _joystick.has_method("debug_set_preview"):
		_joystick.call("debug_set_preview", false, Vector2.ZERO)

	# 4. Scale 1 — Microscopique
	_prepare_capture_world(1, swim_dir)
	await _wait_capture_frames(24)
	_save_capture_png(out_dir, "04_micro.png")

	# 5. Scale 2 — Sous-Bois
	_prepare_capture_world(2, swim_dir)
	await _wait_capture_frames(24)
	_save_capture_png(out_dir, "05_forest.png")

	# 6. Scale 3 — Ville Endormie
	_prepare_capture_world(3, swim_dir)
	await _wait_capture_frames(24)
	_save_capture_png(out_dir, "06_city.png")

	# 7. Scale 4 — Planétaire
	_prepare_capture_world(4, swim_dir)
	await _wait_capture_frames(24)
	_save_capture_png(out_dir, "07_planetary.png")

	# 8. Scale 5 — Cosmique
	_prepare_capture_world(5, swim_dir)
	await _wait_capture_frames(24)
	_save_capture_png(out_dir, "08_cosmic.png")

	_capture_steer_override = Vector2.ZERO
	get_tree().quit(0)
