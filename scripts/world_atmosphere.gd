class_name WorldAtmosphere
extends Node
## Lush Studio Ghibli x Ori atmospheric parallax layers floating over the 6 painted worlds.
## Zero external assets, zero per-frame allocations inside _draw(), 60-120 FPS mobile.
## Builds two CanvasLayers inside layer <= 5:
##   - MidgroundLayer (layer = -5, parallax = 0.25x): delicate diagonal volumetric light shafts
##     aligned with g_key_light_dir (-0.52, -0.62) + scale-specific animated depth particles
##     (quantum sparks, pearlescent micro-bubbles, pulsing golden fireflies & pollen,
##     rising sky-lanterns, shooting stars & aurora wisps, cosmic stardust & 4-point stars).
##   - ForegroundLayer (layer = +4, parallax = 1.38x): lush out-of-focus bokeh light orbs
##     and ultra-subtle peripheral corner vignette strictly confined to the outer 18% frame.

const KEY_LIGHT_DIR: Vector2 = Vector2(-0.52, -0.62)
# Rotation mapping local +Y (0, 1) onto light travel direction (+0.64262, +0.76618)
const SHAFT_ROTATION: float = -0.69790

const MID_PARALLAX: float = 0.25
const FG_PARALLAX: float = 1.38

const SHAFT_ANCHOR_XS: Array[float] = [0.06, 0.28, 0.50]
const SHAFT_WIDTHS: Array[float] = [0.15, 0.20, 0.14]

const PARTICLE_POOL_SIZE: int = 24
const LANTERN_COUNT: int = 9
const SHOOTING_STAR_COUNT: int = 3
const AURORA_WISP_COUNT: int = 5
const FG_BOKEH_COUNT: int = 10

# CanvasLayers & dual normal/additive drawing canvases
var _midground_layer: CanvasLayer = null
var _mid_canvas: _MidgroundCanvas = null
var _mid_add_canvas: _MidgroundAdditiveCanvas = null

var _foreground_layer: CanvasLayer = null
var _fg_canvas: _ForegroundCanvas = null
var _fg_add_canvas: _ForegroundAdditiveCanvas = null

# Procedural painterly textures baked once in _ready()
var _bokeh_tex: GradientTexture2D = null
var _glow_tex: GradientTexture2D = null
var _wisp_tex: GradientTexture2D = null
var _corner_vig_tex: GradientTexture2D = null
var _shaft_tex: ImageTexture = null
var _bubble_tex: ImageTexture = null
var _lantern_tex: ImageTexture = null
var _star4_tex: ImageTexture = null

# Frame state updated via update_atmosphere()
var _time: float = 0.0
var _parallax_offset: Vector2 = Vector2.ZERO
var _scale_progress: float = 0.0
var _viewport_size: Vector2 = Vector2(1280.0, 720.0)
var _weights: PackedFloat32Array = PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 0.0, 0.0])

var _col_bg_inner: Color = Color(0.045, 0.165, 0.255, 1.0)
var _col_bg_outer: Color = Color(0.016, 0.062, 0.125, 1.0)
var _col_mote: Color = Color(0.360, 0.925, 0.945, 1.0)
var _col_accent: Color = Color(1.0, 0.74, 0.36, 1.0)

# Pre-baked deterministic particle tables (ZERO per-frame allocations inside _draw())
var _p_x: PackedFloat32Array = PackedFloat32Array()
var _p_y: PackedFloat32Array = PackedFloat32Array()
var _p_size: PackedFloat32Array = PackedFloat32Array()
var _p_speed: PackedFloat32Array = PackedFloat32Array()
var _p_phase: PackedFloat32Array = PackedFloat32Array()
var _p_hue: PackedFloat32Array = PackedFloat32Array()

# Pre-baked strictly outer-18% foreground bokeh orb anchors
var _bokeh_x: PackedFloat32Array = PackedFloat32Array()
var _bokeh_y: PackedFloat32Array = PackedFloat32Array()
var _bokeh_size: PackedFloat32Array = PackedFloat32Array()
var _bokeh_phase: PackedFloat32Array = PackedFloat32Array()
var _bokeh_hue: PackedFloat32Array = PackedFloat32Array()


class _MidgroundCanvas:
	extends Node2D
	var owner_atmo: WorldAtmosphere = null

	func _draw() -> void:
		if owner_atmo != null:
			owner_atmo._draw_midground_normal(self)


class _MidgroundAdditiveCanvas:
	extends Node2D
	var owner_atmo: WorldAtmosphere = null

	func _draw() -> void:
		if owner_atmo != null:
			owner_atmo._draw_midground_additive(self)


class _ForegroundCanvas:
	extends Node2D
	var owner_atmo: WorldAtmosphere = null

	func _draw() -> void:
		if owner_atmo != null:
			owner_atmo._draw_foreground_normal(self)


class _ForegroundAdditiveCanvas:
	extends Node2D
	var owner_atmo: WorldAtmosphere = null

	func _draw() -> void:
		if owner_atmo != null:
			owner_atmo._draw_foreground_additive(self)


func _ready() -> void:
	_bake_procedural_textures()
	_init_particle_tables()
	_build_layers()


func _exit_tree() -> void:
	if _mid_canvas != null:
		_mid_canvas.owner_atmo = null
	if _mid_add_canvas != null:
		_mid_add_canvas.owner_atmo = null
	if _fg_canvas != null:
		_fg_canvas.owner_atmo = null
	if _fg_add_canvas != null:
		_fg_add_canvas.owner_atmo = null


func _bake_procedural_textures() -> void:
	# 1. Lush creamy out-of-focus bokeh orb (GradientTexture2D, 64x64, optical edge bloom)
	var bokeh_grad: Gradient = Gradient.new()
	bokeh_grad.offsets = PackedFloat32Array([0.0, 0.34, 0.64, 0.84, 1.0])
	bokeh_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.78),
		Color(1.0, 1.0, 1.0, 0.68),
		Color(1.0, 1.0, 1.0, 0.44),
		Color(1.0, 1.0, 1.0, 0.14),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	_bokeh_tex = GradientTexture2D.new()
	_bokeh_tex.width = 64
	_bokeh_tex.height = 64
	_bokeh_tex.fill = GradientTexture2D.FILL_RADIAL
	_bokeh_tex.fill_from = Vector2(0.5, 0.5)
	_bokeh_tex.fill_to = Vector2(1.0, 0.5)
	_bokeh_tex.gradient = bokeh_grad

	# 2. Smooth radial glow bloom texture (GradientTexture2D, 64x64)
	var glow_grad: Gradient = Gradient.new()
	glow_grad.offsets = PackedFloat32Array([0.0, 0.22, 0.56, 1.0])
	glow_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.52),
		Color(1.0, 1.0, 1.0, 0.12),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	_glow_tex = GradientTexture2D.new()
	_glow_tex.width = 64
	_glow_tex.height = 64
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.gradient = glow_grad

	# 3. Gossamer elongated aurora / mist wisp (GradientTexture2D, 64x32)
	var wisp_grad: Gradient = Gradient.new()
	wisp_grad.offsets = PackedFloat32Array([0.0, 0.36, 0.74, 1.0])
	wisp_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.54),
		Color(1.0, 1.0, 1.0, 0.28),
		Color(1.0, 1.0, 1.0, 0.07),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	_wisp_tex = GradientTexture2D.new()
	_wisp_tex.width = 64
	_wisp_tex.height = 32
	_wisp_tex.fill = GradientTexture2D.FILL_RADIAL
	_wisp_tex.fill_from = Vector2(0.5, 0.5)
	_wisp_tex.fill_to = Vector2(1.0, 0.5)
	_wisp_tex.gradient = wisp_grad

	# 4. Ultra-soft feathered dark corner vignette cushion (GradientTexture2D, 64x64)
	var vig_grad: Gradient = Gradient.new()
	vig_grad.offsets = PackedFloat32Array([0.0, 0.42, 0.76, 1.0])
	vig_grad.colors = PackedColorArray([
		Color(0.012, 0.024, 0.042, 0.85),
		Color(0.012, 0.024, 0.042, 0.46),
		Color(0.012, 0.024, 0.042, 0.12),
		Color(0.012, 0.024, 0.042, 0.0),
	])
	_corner_vig_tex = GradientTexture2D.new()
	_corner_vig_tex.width = 64
	_corner_vig_tex.height = 64
	_corner_vig_tex.fill = GradientTexture2D.FILL_RADIAL
	_corner_vig_tex.fill_from = Vector2(0.5, 0.5)
	_corner_vig_tex.fill_to = Vector2(1.0, 0.5)
	_corner_vig_tex.gradient = vig_grad

	# 5. Silky diagonal volumetric light shaft (48x64 RGBA8, zero hard edges)
	var shaft_img: Image = Image.create_empty(48, 64, false, Image.FORMAT_RGBA8)
	for y: int in range(64):
		var v: float = float(y) / 63.0
		var v_in: float = clampf(v / 0.16, 0.0, 1.0)
		v_in = v_in * v_in * (3.0 - 2.0 * v_in)
		var v_out: float = pow(maxf(0.0, 1.0 - v), 1.75)
		var v_env: float = v_in * v_out
		for x: int in range(48):
			var u: float = float(x) / 47.0
			var bell: float = sin(u * PI)
			var h_env: float = bell * bell * (0.80 + 0.20 * sin(u * PI * 3.0) * sin(u * PI * 3.0))
			shaft_img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(h_env * v_env, 0.0, 1.0)))
	_shaft_tex = ImageTexture.create_from_image(shaft_img)

	# 6. Translucent pearlescent Ghibli micro-bubble (48x48 RGBA8: thin wet glass rim + top-left glint)
	var bub_img: Image = Image.create_empty(48, 48, false, Image.FORMAT_RGBA8)
	for y: int in range(48):
		var ny: float = (float(y) + 0.5) / 24.0 - 1.0
		for x: int in range(48):
			var nx: float = (float(x) + 0.5) / 24.0 - 1.0
			var d: float = sqrt(nx * nx + ny * ny)
			if d >= 1.0:
				bub_img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			var rim: float = smoothstep(0.62, 0.88, d) * (1.0 - smoothstep(0.88, 1.0, d))
			var interior: float = (1.0 - smoothstep(0.0, 0.94, d)) * 0.12
			# Top-left wet specular highlight aligned with KEY_LIGHT_DIR
			var sx: float = nx + 0.34
			var sy: float = ny + 0.36
			var spec: float = 1.0 - smoothstep(0.02, 0.28, sqrt(sx * sx + sy * sy))
			# Subtle lower-right bounce sheen
			var bx: float = nx - 0.36
			var by: float = ny - 0.38
			var bounce: float = (1.0 - smoothstep(0.05, 0.34, sqrt(bx * bx + by * by))) * 0.28 * rim
			var a: float = clampf(rim * 0.68 + interior + spec * 0.85 + bounce, 0.0, 1.0)
			var r_c: float = clampf(0.76 + spec * 0.24, 0.0, 1.0)
			var g_c: float = clampf(0.96 + spec * 0.04, 0.0, 1.0)
			var b_c: float = 1.0
			bub_img.set_pixel(x, y, Color(r_c, g_c, b_c, a))
	_bubble_tex = ImageTexture.create_from_image(bub_img)

	# 7. Painterly warm glowing paper sky-lantern (40x52 RGBA8: soft tapered lantern + warm flame heart)
	var lan_img: Image = Image.create_empty(40, 52, false, Image.FORMAT_RGBA8)
	for y: int in range(52):
		var v: float = (float(y) + 0.5) / 52.0 # 0=top, 1=bottom
		var ny: float = (v - 0.48) / 0.38
		for x: int in range(40):
			var nx: float = ((float(x) + 0.5) / 40.0 - 0.5) * 2.0
			# Taper slightly narrower toward bottom opening like a real Ghibli paper lantern
			var width_at_y: float = lerpf(0.62, 0.38, clampf(v, 0.0, 1.0))
			var qx: float = nx / maxf(width_at_y, 0.05)
			var body_d: float = sqrt(qx * qx + ny * ny)
			var shell: float = 1.0 - smoothstep(0.70, 1.04, body_d)
			# Bright warm candle core near lower-center
			var fx: float = nx / 0.30
			var fy: float = (v - 0.60) / 0.24
			var flame: float = 1.0 - smoothstep(0.0, 1.0, sqrt(fx * fx + fy * fy))
			var col_r: float = clampf(lerpf(0.98, 1.00, flame), 0.0, 1.0)
			var col_g: float = clampf(lerpf(0.56, 0.94, flame), 0.0, 1.0)
			var col_b: float = clampf(lerpf(0.20, 0.64, flame * flame), 0.0, 1.0)
			var a: float = clampf(shell * 0.90 + flame * 0.35, 0.0, 1.0)
			lan_img.set_pixel(x, y, Color(col_r, col_g, col_b, a))
	_lantern_tex = ImageTexture.create_from_image(lan_img)

	# 8. Delicate 4-point Ghibli diamond star sparkle (48x48 RGBA8)
	var star_img: Image = Image.create_empty(48, 48, false, Image.FORMAT_RGBA8)
	for y: int in range(48):
		var ny: float = absf((float(y) + 0.5) / 24.0 - 1.0)
		for x: int in range(48):
			var nx: float = absf((float(x) + 0.5) / 24.0 - 1.0)
			var d: float = sqrt(nx * nx + ny * ny)
			var core: float = 1.0 - smoothstep(0.02, 0.22, d)
			var halo: float = (1.0 - smoothstep(0.05, 0.58, d)) * 0.26
			var wh: float = lerpf(0.09, 0.012, clampf(nx, 0.0, 1.0))
			var wv: float = lerpf(0.09, 0.012, clampf(ny, 0.0, 1.0))
			var ray_h: float = (1.0 - smoothstep(wh * 0.15, wh, ny)) * (1.0 - smoothstep(0.0, 0.96, nx))
			var ray_v: float = (1.0 - smoothstep(wv * 0.15, wv, nx)) * (1.0 - smoothstep(0.0, 0.96, ny))
			var a: float = clampf(core + maxf(ray_h, ray_v) * 0.88 + halo, 0.0, 1.0)
			star_img.set_pixel(x, y, Color(1.0, 0.98, 0.92, a))
	_star4_tex = ImageTexture.create_from_image(star_img)


func _init_particle_tables() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 19880416 # Totoro release date — deterministic painterly scatter

	_p_x.resize(PARTICLE_POOL_SIZE)
	_p_y.resize(PARTICLE_POOL_SIZE)
	_p_size.resize(PARTICLE_POOL_SIZE)
	_p_speed.resize(PARTICLE_POOL_SIZE)
	_p_phase.resize(PARTICLE_POOL_SIZE)
	_p_hue.resize(PARTICLE_POOL_SIZE)

	for i: int in range(PARTICLE_POOL_SIZE):
		# Golden-ratio stratified horizontal distribution for zero clumping
		_p_x[i] = fposmod(float(i) * 0.6180339 + rng.randf_range(-0.04, 0.04), 1.0)
		_p_y[i] = rng.randf_range(0.06, 0.94)
		_p_size[i] = rng.randf_range(0.58, 1.38)
		_p_speed[i] = rng.randf_range(0.65, 1.45)
		_p_phase[i] = rng.randf_range(0.0, TAU)
		_p_hue[i] = rng.randf()

	# 10 lush foreground bokeh orbs strictly pinned inside the outer 18% frame corners & bottom margin
	_bokeh_x = PackedFloat32Array([
		0.055, 0.130, 0.870, 0.945,
		0.060, 0.145, 0.855, 0.940,
		0.320, 0.680,
	])
	_bokeh_y = PackedFloat32Array([
		0.085, 0.055, 0.060, 0.095,
		0.910, 0.940, 0.935, 0.900,
		0.955, 0.950,
	])
	_bokeh_size = PackedFloat32Array([
		0.068, 0.048, 0.054, 0.072,
		0.076, 0.056, 0.060, 0.074,
		0.052, 0.058,
	])
	_bokeh_phase = PackedFloat32Array([0.4, 2.1, 3.8, 5.2, 1.3, 4.4, 2.9, 5.7, 0.9, 3.4])
	_bokeh_hue = PackedFloat32Array([0.12, 0.78, 0.24, 0.86, 0.18, 0.68, 0.82, 0.30, 0.15, 0.72])


func _build_layers() -> void:
	var add_mat: CanvasItemMaterial = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# Layer -5: Midground atmosphere floating over the painted backdrop, behind gameplay (layer 0)
	_midground_layer = CanvasLayer.new()
	_midground_layer.name = "MidgroundLayer"
	_midground_layer.layer = -5
	add_child(_midground_layer)

	_mid_canvas = _MidgroundCanvas.new()
	_mid_canvas.name = "MidgroundNormal"
	_mid_canvas.owner_atmo = self
	_midground_layer.add_child(_mid_canvas)

	_mid_add_canvas = _MidgroundAdditiveCanvas.new()
	_mid_add_canvas.name = "MidgroundAdditive"
	_mid_add_canvas.owner_atmo = self
	_mid_add_canvas.material = add_mat
	_midground_layer.add_child(_mid_add_canvas)

	# Layer +4: Foreground peripheral bokeh & soft corner framing passing in front of Charlie
	_foreground_layer = CanvasLayer.new()
	_foreground_layer.name = "ForegroundLayer"
	_foreground_layer.layer = 4
	add_child(_foreground_layer)

	_fg_canvas = _ForegroundCanvas.new()
	_fg_canvas.name = "ForegroundFraming"
	_fg_canvas.owner_atmo = self
	_foreground_layer.add_child(_fg_canvas)

	_fg_add_canvas = _ForegroundAdditiveCanvas.new()
	_fg_add_canvas.name = "ForegroundBokeh"
	_fg_add_canvas.owner_atmo = self
	_fg_add_canvas.material = add_mat
	_foreground_layer.add_child(_fg_add_canvas)


func update_atmosphere(dt: float, parallax_offset: Vector2, scale_progress: float, palette: Dictionary, viewport_size: Vector2) -> void:
	var step_dt: float = clampf(dt, 0.0, 0.05)
	_time += step_dt
	_parallax_offset = parallax_offset
	_scale_progress = clampf(scale_progress, 0.0, 5.0)

	if viewport_size.x > 1.0 and viewport_size.y > 1.0:
		_viewport_size = viewport_size

	if not palette.is_empty():
		var c_in: Variant = palette.get("bg_inner", _col_bg_inner)
		var c_out: Variant = palette.get("bg_outer", _col_bg_outer)
		var c_mote: Variant = palette.get("mote_color", _col_mote)
		var c_acc: Variant = palette.get("blob_core", palette.get("accent", _col_accent))
		if c_in is Color:
			_col_bg_inner = c_in
		if c_out is Color:
			_col_bg_outer = c_out
		if c_mote is Color:
			_col_mote = c_mote
		if c_acc is Color:
			_col_accent = c_acc

	# Smooth C1 crossfade weights synchronized with biolum_bg.gdshader & Scales.get_blended_palette
	var idx_f: float = floor(minf(_scale_progress, 4.9999))
	var idx: int = int(idx_f)
	var frac: float = _scale_progress - idx_f
	var t_b: float = clampf((frac - 0.62) / 0.38, 0.0, 1.0)
	var blend: float = t_b * t_b * (3.0 - 2.0 * t_b)

	for i: int in range(6):
		_weights[i] = 0.0
	_weights[idx] = 1.0 - blend
	if idx + 1 < 6:
		_weights[idx + 1] = blend

	if _mid_canvas != null:
		_mid_canvas.queue_redraw()
	if _mid_add_canvas != null:
		_mid_add_canvas.queue_redraw()
	if _fg_canvas != null:
		_fg_canvas.queue_redraw()
	if _fg_add_canvas != null:
		_fg_add_canvas.queue_redraw()


# ==============================================================================
# MIDGROUND NORMAL (Layer -5, 0.25x Parallax — Translucent Bubbles & Paper Lanterns)
# ==============================================================================

func _draw_midground_normal(canvas: Node2D) -> void:
	var w: float = _viewport_size.x
	var h: float = _viewport_size.y
	if w <= 1.0 or h <= 1.0:
		return

	# Scale 1 (Microscopique): rising translucent pearlescent micro-bubbles
	if _weights[1] > 0.004 and _bubble_tex != null:
		_draw_micro_bubbles(canvas, w, h, _weights[1])

	# Scale 3 (Ville Endormie): gentle rising warm glowing paper sky-lanterns in the distance
	if _weights[3] > 0.004 and _lantern_tex != null:
		_draw_city_lantern_bodies(canvas, w, h, _weights[3])


func _draw_micro_bubbles(canvas: Node2D, w: float, h: float, alpha: float) -> void:
	var unit: float = h / 720.0
	var wrap_w: float = w + 120.0
	var wrap_h: float = h + 120.0
	var par_x: float = _parallax_offset.x * MID_PARALLAX
	var par_y: float = _parallax_offset.y * MID_PARALLAX

	for i: int in range(18):
		var ph: float = _p_phase[i]
		var spd: float = _p_speed[i]
		var rise: float = _time * (18.0 + spd * 18.0)
		var wobble: float = sin(_time * (1.1 + spd * 0.4) + ph) * (14.0 * unit)
		var bx: float = fposmod(_p_x[i] * wrap_w - par_x + wobble, wrap_w) - 60.0
		var by: float = fposmod(_p_y[i] * wrap_h - par_y - rise, wrap_h) - 60.0

		# Soft vertical fade at top meniscus and bottom edge
		var y_norm: float = clampf(by / h, 0.0, 1.0)
		var env: float = smoothstep(0.06, 0.20, y_norm) * (1.0 - smoothstep(0.86, 0.99, y_norm))
		if env <= 0.01:
			continue

		var rad: float = (4.5 + _p_size[i] * 7.8) * unit
		var col: Color = Color(0.80, 0.98, 0.96, (0.34 + 0.26 * _p_hue[i]) * env * alpha)
		canvas.draw_texture_rect(_bubble_tex, Rect2(bx - rad, by - rad, rad * 2.0, rad * 2.0), false, col)


func _draw_city_lantern_bodies(canvas: Node2D, w: float, h: float, alpha: float) -> void:
	var unit: float = h / 720.0
	var wrap_w: float = w + 140.0
	var sky_h: float = h * 0.72
	var par_x: float = _parallax_offset.x * (MID_PARALLAX * 0.85)
	var par_y: float = _parallax_offset.y * (MID_PARALLAX * 0.65)

	for i: int in range(LANTERN_COUNT):
		var ph: float = _p_phase[i]
		var spd: float = _p_speed[i]
		var sway: float = sin(_time * (0.45 + spd * 0.14) + ph) * (20.0 * unit)
		var lx: float = fposmod(_p_x[i] * wrap_w - par_x + sway, wrap_w) - 70.0
		var ly_raw: float = fposmod(_p_y[i] * sky_h - par_y - _time * (9.5 + spd * 6.5), sky_h)
		var ly: float = ly_raw + h * 0.04

		var env: float = smoothstep(0.0, h * 0.10, ly_raw) * (1.0 - smoothstep(sky_h * 0.84, sky_h, ly_raw))
		if env <= 0.01:
			continue

		var flick: float = 0.90 + 0.10 * sin(_time * (2.6 + spd * 0.9) + ph)
		var rw: float = (5.2 + _p_size[i] * 4.4) * unit
		var rh: float = rw * 1.32
		var col: Color = Color(1.0 * flick, 0.86 * flick, 0.66 * flick, 0.78 * env * alpha)
		canvas.draw_texture_rect(_lantern_tex, Rect2(lx - rw, ly - rh, rw * 2.0, rh * 2.0), false, col)


# ==============================================================================
# MIDGROUND ADDITIVE (Layer -5, BLEND_MODE_ADD — Shafts & Living Depth Particles)
# ==============================================================================

func _draw_midground_additive(canvas: Node2D) -> void:
	var w: float = _viewport_size.x
	var h: float = _viewport_size.y
	if w <= 1.0 or h <= 1.0:
		return

	# 1. Delicate diagonal volumetric moonlight/sunlight shafts from top-left
	_draw_volumetric_light_shafts(canvas, w, h)

	# 2. Scale-specific animated depth particles floating over the painted worlds
	if _weights[0] > 0.004:
		_draw_quantum_sparks(canvas, w, h, _weights[0])
	if _weights[2] > 0.004:
		_draw_forest_fireflies_and_pollen(canvas, w, h, _weights[2])
	if _weights[3] > 0.004:
		_draw_city_lantern_halos(canvas, w, h, _weights[3])
	if _weights[4] > 0.004:
		_draw_planetary_meteors_and_aurora(canvas, w, h, _weights[4])
	if _weights[5] > 0.004:
		_draw_cosmic_stardust_and_stars(canvas, w, h, _weights[5])


func _draw_volumetric_light_shafts(canvas: Node2D, w: float, h: float) -> void:
	if _shaft_tex == null:
		return

	# Restrained, luminous scale-specific tint that breathes over painted rays without washing out
	var shaft_tint: Color = (
		Color(0.32, 0.92, 0.98, 0.068) * _weights[0]
		+ Color(0.42, 0.96, 0.86, 0.095) * _weights[1]
		+ Color(0.92, 0.94, 0.56, 0.098) * _weights[2]
		+ Color(0.58, 0.78, 1.00, 0.052) * _weights[3]
		+ Color(0.42, 0.86, 0.98, 0.040) * _weights[4]
		+ Color(0.96, 0.80, 0.62, 0.045) * _weights[5]
	)
	if shaft_tint.a <= 0.004:
		return

	var diag_len: float = sqrt(w * w + h * h) * 0.84
	var par_shift: float = -sin(_parallax_offset.x * 0.0005 * MID_PARALLAX * 4.0) * (w * 0.042)

	for i: int in range(3):
		var breath: float = 0.76 + 0.24 * sin(_time * (0.40 + float(i) * 0.14) + float(i) * 2.1)
		var sway_x: float = sin(_time * (0.26 + float(i) * 0.08) + float(i) * 1.4) * (w * 0.016)
		var origin: Vector2 = Vector2(w * SHAFT_ANCHOR_XS[i] + sway_x + par_shift, -h * 0.10)
		var bw: float = w * SHAFT_WIDTHS[i] * (0.94 + 0.06 * breath)
		var bl: float = diag_len * (0.90 + float(i % 2) * 0.12)
		var col: Color = Color(shaft_tint.r, shaft_tint.g, shaft_tint.b, shaft_tint.a * breath)

		canvas.draw_set_transform(origin, SHAFT_ROTATION, Vector2.ONE)
		canvas.draw_texture_rect(_shaft_tex, Rect2(-bw * 0.5, 0.0, bw, bl), false, col)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Scale 0 (Quantique): luminous turquoise & warm gold quantum sparks drifting in harmonic currents
func _draw_quantum_sparks(canvas: Node2D, w: float, h: float, alpha: float) -> void:
	if _glow_tex == null:
		return
	var unit: float = h / 720.0
	var wrap_w: float = w + 120.0
	var wrap_h: float = h + 120.0
	var par_x: float = _parallax_offset.x * MID_PARALLAX
	var par_y: float = _parallax_offset.y * MID_PARALLAX

	for i: int in range(18):
		var ph: float = _p_phase[i]
		var spd: float = _p_speed[i]
		var drift_x: float = _time * (12.0 + spd * 8.0) + sin(_time * (0.75 + spd * 0.25) + ph) * (24.0 * unit)
		var drift_y: float = cos(_time * (0.62 + spd * 0.22) + ph * 1.3) * (22.0 * unit)
		var px: float = fposmod(_p_x[i] * wrap_w - par_x + drift_x, wrap_w) - 60.0
		var py: float = fposmod(_p_y[i] * wrap_h - par_y + drift_y, wrap_h) - 60.0

		var pulse_raw: float = 0.5 + 0.5 * sin(_time * (1.5 + spd * 0.9) + ph * 2.0)
		var pulse: float = 0.30 + 0.70 * (pulse_raw * pulse_raw)
		var is_gold: bool = _p_hue[i] > 0.66
		var base_c: Color = Color(1.0, 0.84, 0.42, 1.0) if is_gold else Color(0.28, 0.94, 0.98, 1.0)

		var halo_r: float = (10.0 + _p_size[i] * 11.0) * unit * (0.85 + 0.15 * pulse)
		canvas.draw_texture_rect(
			_glow_tex,
			Rect2(px - halo_r, py - halo_r, halo_r * 2.0, halo_r * 2.0),
			false,
			Color(base_c.r, base_c.g, base_c.b, 0.34 * pulse * alpha)
		)
		if _star4_tex != null and _p_size[i] > 0.92:
			var sr: float = (6.5 + _p_size[i] * 4.5) * unit * pulse
			canvas.draw_texture_rect(
				_star4_tex,
				Rect2(px - sr, py - sr, sr * 2.0, sr * 2.0),
				false,
				Color(1.0, 0.97, 0.88, 0.52 * pulse * alpha)
			)


# Scale 2 (Sous-Bois): softly pulsing golden Ghibli fireflies & floating forest pollen
func _draw_forest_fireflies_and_pollen(canvas: Node2D, w: float, h: float, alpha: float) -> void:
	if _glow_tex == null:
		return
	var unit: float = h / 720.0
	var wrap_w: float = w + 120.0
	var wrap_h: float = h + 120.0
	var par_x: float = _parallax_offset.x * MID_PARALLAX
	var par_y: float = _parallax_offset.y * MID_PARALLAX

	for i: int in range(PARTICLE_POOL_SIZE):
		var ph: float = _p_phase[i]
		var spd: float = _p_speed[i]
		var is_firefly: bool = i < 14
		var sway_x: float = sin(_time * (0.55 + spd * 0.25) + ph) * ((28.0 if is_firefly else 16.0) * unit)
		var sway_y: float = cos(_time * (0.48 + spd * 0.22) + ph * 1.4) * ((22.0 if is_firefly else 12.0) * unit)
		var rise: float = _time * (4.5 * spd) if not is_firefly else 0.0
		var px: float = fposmod(_p_x[i] * wrap_w - par_x + sway_x, wrap_w) - 60.0
		var py: float = fposmod(_p_y[i] * wrap_h - par_y + sway_y - rise, wrap_h) - 60.0

		if is_firefly:
			var p_raw: float = 0.5 + 0.5 * sin(_time * (1.35 + spd * 0.85) + ph * 2.3)
			var pulse: float = 0.22 + 0.78 * (p_raw * p_raw * p_raw)
			var is_emerald: bool = _p_hue[i] > 0.78
			var glow_c: Color = Color(0.46, 0.98, 0.56, 1.0) if is_emerald else Color(1.0, 0.84, 0.30, 1.0)
			var halo_r: float = (12.0 + _p_size[i] * 12.0) * unit * (0.82 + 0.18 * pulse)
			var core_r: float = (3.4 + _p_size[i] * 2.6) * unit
			canvas.draw_texture_rect(
				_glow_tex,
				Rect2(px - halo_r, py - halo_r, halo_r * 2.0, halo_r * 2.0),
				false,
				Color(glow_c.r, glow_c.g, glow_c.b, 0.42 * pulse * alpha)
			)
			canvas.draw_texture_rect(
				_glow_tex,
				Rect2(px - core_r, py - core_r, core_r * 2.0, core_r * 2.0),
				false,
				Color(1.0, 0.98, 0.82, 0.72 * pulse * alpha)
			)
		else:
			# Floating sunlit forest pollen motes drifting slowly through the sunbeams
			var twinkle: float = 0.48 + 0.52 * sin(_time * (0.9 + spd * 0.5) + ph)
			var r_p: float = (3.6 + _p_size[i] * 3.8) * unit
			canvas.draw_texture_rect(
				_glow_tex,
				Rect2(px - r_p, py - r_p, r_p * 2.0, r_p * 2.0),
				false,
				Color(0.96, 0.94, 0.62, 0.26 * twinkle * alpha)
			)


# Scale 3 (Ville Endormie): warm lantern aura halos matching the rising sky-lanterns
func _draw_city_lantern_halos(canvas: Node2D, w: float, h: float, alpha: float) -> void:
	if _glow_tex == null:
		return
	var unit: float = h / 720.0
	var wrap_w: float = w + 140.0
	var sky_h: float = h * 0.72
	var par_x: float = _parallax_offset.x * (MID_PARALLAX * 0.85)
	var par_y: float = _parallax_offset.y * (MID_PARALLAX * 0.65)

	for i: int in range(LANTERN_COUNT):
		var ph: float = _p_phase[i]
		var spd: float = _p_speed[i]
		var sway: float = sin(_time * (0.45 + spd * 0.14) + ph) * (20.0 * unit)
		var lx: float = fposmod(_p_x[i] * wrap_w - par_x + sway, wrap_w) - 70.0
		var ly_raw: float = fposmod(_p_y[i] * sky_h - par_y - _time * (9.5 + spd * 6.5), sky_h)
		var ly: float = ly_raw + h * 0.04

		var env: float = smoothstep(0.0, h * 0.10, ly_raw) * (1.0 - smoothstep(sky_h * 0.84, sky_h, ly_raw))
		if env <= 0.01:
			continue

		var flick: float = 0.88 + 0.12 * sin(_time * (2.6 + spd * 0.9) + ph)
		var hr: float = (20.0 + _p_size[i] * 14.0) * unit
		canvas.draw_texture_rect(
			_glow_tex,
			Rect2(lx - hr, ly - hr, hr * 2.0, hr * 2.0),
			false,
			Color(1.0 * flick, 0.64 * flick, 0.24 * flick, 0.28 * env * alpha)
		)


# Scale 4 (Planetaire): twinkling shooting stars & ethereal aurora mist wisps
func _draw_planetary_meteors_and_aurora(canvas: Node2D, w: float, h: float, alpha: float) -> void:
	var unit: float = h / 720.0
	var s: float = minf(w, h)

	# 1. Soft ethereal aurora mist wisps undulating gently above the painted Earth & aurora
	if _wisp_tex != null:
		var par_x: float = -sin(_parallax_offset.x * 0.0005) * (w * 0.032)
		var par_y: float = -sin(_parallax_offset.y * 0.0005) * (h * 0.016)
		for k: int in range(AURORA_WISP_COUNT):
			var u: float = (float(k) + 0.5) / float(AURORA_WISP_COUNT)
			var ph: float = float(k) * 1.65
			var breath: float = 0.65 + 0.35 * sin(_time * (0.55 + float(k) * 0.12) + ph)
			var cx: float = w * lerpf(0.18, 0.82, u) + par_x + sin(_time * 0.32 + ph) * (w * 0.030)
			var cy: float = h * (0.64 + 0.06 * sin(u * PI * 2.0 + 0.8)) + par_y + cos(_time * 0.38 + ph) * (h * 0.018)
			var ww: float = s * (0.34 + float(k % 2) * 0.08)
			var wh: float = s * 0.10
			var ang: float = -0.18 + float(k % 3) * 0.16 + sin(_time * 0.25 + ph) * 0.06
			var wisp_c: Color = (
				Color(0.24, 0.96, 0.68, 0.13 * breath * alpha) if (k % 2 == 0)
				else Color(0.68, 0.42, 0.98, 0.12 * breath * alpha)
			)
			canvas.draw_set_transform(Vector2(cx, cy), ang, Vector2.ONE)
			canvas.draw_texture_rect(_wisp_tex, Rect2(-ww * 0.5, -wh * 0.5, ww, wh), false, wisp_c)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 2. Periodic graceful shooting stars streaking diagonally across the upper starry cosmos
	for m: int in range(SHOOTING_STAR_COUNT):
		var period: float = 6.2 + float(m) * 2.7
		var local_t: float = fposmod(_time + float(m) * 3.1, period)
		var duration: float = 1.15
		if local_t > duration:
			continue

		var prog: float = local_t / duration
		var fade: float = sin(prog * PI)
		var start_x: float = w * (0.16 + float(m) * 0.27)
		var start_y: float = h * (0.08 + float(m % 2) * 0.13)
		var dir: Vector2 = Vector2(0.86, 0.51)
		var travel: float = (210.0 + float(m) * 45.0) * unit
		var head: Vector2 = Vector2(start_x, start_y) + dir * (travel * prog)
		var tail_len: float = (68.0 + 26.0 * fade) * unit
		var tail: Vector2 = head - dir * tail_len

		canvas.draw_line(tail, head, Color(0.76, 0.94, 1.0, 0.52 * fade * alpha), 1.8 * unit, true)
		if _glow_tex != null:
			var hr: float = 8.5 * unit * fade
			canvas.draw_texture_rect(
				_glow_tex,
				Rect2(head.x - hr, head.y - hr, hr * 2.0, hr * 2.0),
				false,
				Color(0.92, 0.98, 1.0, 0.65 * fade * alpha)
			)
		if _star4_tex != null:
			var sr: float = 10.5 * unit * fade
			canvas.draw_texture_rect(
				_star4_tex,
				Rect2(head.x - sr, head.y - sr, sr * 2.0, sr * 2.0),
				false,
				Color(1.0, 0.98, 0.92, 0.72 * fade * alpha)
			)


# Scale 5 (Cosmique): drifting golden cosmic stardust & soft twinkling four-point stars
func _draw_cosmic_stardust_and_stars(canvas: Node2D, w: float, h: float, alpha: float) -> void:
	if _glow_tex == null:
		return
	var unit: float = h / 720.0
	var wrap_w: float = w + 120.0
	var wrap_h: float = h + 120.0
	var par_x: float = _parallax_offset.x * MID_PARALLAX
	var par_y: float = _parallax_offset.y * MID_PARALLAX

	for i: int in range(PARTICLE_POOL_SIZE):
		var ph: float = _p_phase[i]
		var spd: float = _p_speed[i]
		var drift_x: float = _time * (5.0 + spd * 4.5) + sin(_time * 0.35 + ph) * (14.0 * unit)
		var drift_y: float = cos(_time * 0.30 + ph * 1.2) * (12.0 * unit)
		var px: float = fposmod(_p_x[i] * wrap_w - par_x + drift_x, wrap_w) - 60.0
		var py: float = fposmod(_p_y[i] * wrap_h - par_y + drift_y, wrap_h) - 60.0

		var tw_raw: float = 0.5 + 0.5 * sin(_time * (1.2 + spd * 0.85) + ph * 2.4)
		var tw: float = 0.25 + 0.75 * (tw_raw * tw_raw)

		if i < 12 and _star4_tex != null:
			# Crisp twinkling 4-point Miyazaki diamond stars (warm gold & celestial cyan)
			var is_gold: bool = _p_hue[i] < 0.72
			var sc: Color = Color(1.0, 0.90, 0.58, 1.0) if is_gold else Color(0.68, 0.92, 1.0, 1.0)
			var sr: float = (7.5 + _p_size[i] * 7.5) * unit * (0.76 + 0.24 * tw)
			canvas.draw_texture_rect(
				_star4_tex,
				Rect2(px - sr, py - sr, sr * 2.0, sr * 2.0),
				false,
				Color(sc.r, sc.g, sc.b, 0.58 * tw * alpha)
			)
		else:
			# Drifting golden cosmic stardust motes
			var dr: float = (5.0 + _p_size[i] * 7.0) * unit
			var dc: Color = Color(1.0, 0.86, 0.48, 0.32 * tw * alpha) if (_p_hue[i] < 0.65) else Color(0.76, 0.58, 1.0, 0.28 * tw * alpha)
			canvas.draw_texture_rect(_glow_tex, Rect2(px - dr, py - dr, dr * 2.0, dr * 2.0), false, dc)


# ==============================================================================
# FOREGROUND FRAMING (Layer +4, 1.38x Parallax — Strictly Outer 18% Edges/Corners)
# ==============================================================================

func _draw_foreground_normal(canvas: Node2D) -> void:
	# Ultra-subtle soft peripheral corner vignette framing — ZERO solid opaque shapes blocking gameplay
	if _corner_vig_tex == null:
		return
	var w: float = _viewport_size.x
	var h: float = _viewport_size.y
	if w <= 1.0 or h <= 1.0:
		return

	var rx: float = w * 0.24
	var ry: float = h * 0.28
	var vig_col: Color = Color(1.0, 1.0, 1.0, 0.22)
	canvas.draw_texture_rect(_corner_vig_tex, Rect2(-rx * 0.42, -ry * 0.42, rx, ry), false, vig_col)
	canvas.draw_texture_rect(_corner_vig_tex, Rect2(w - rx * 0.58, -ry * 0.42, rx, ry), false, vig_col)
	canvas.draw_texture_rect(_corner_vig_tex, Rect2(-rx * 0.42, h - ry * 0.58, rx, ry), false, vig_col)
	canvas.draw_texture_rect(_corner_vig_tex, Rect2(w - rx * 0.58, h - ry * 0.58, rx, ry), false, vig_col)


func _draw_foreground_additive(canvas: Node2D) -> void:
	# Lush, soft, out-of-focus golden & emerald bokeh light orbs drifting lazily across outer 18% corners
	if _bokeh_tex == null:
		return
	var w: float = _viewport_size.x
	var h: float = _viewport_size.y
	if w <= 1.0 or h <= 1.0:
		return

	var s: float = minf(w, h)

	# Jewel-toned scale-responsive bokeh palette (warm golden & emerald primary tones)
	var primary_col: Color = (
		Color(0.32, 0.94, 0.98, 0.22) * _weights[0]
		+ Color(0.42, 0.98, 0.86, 0.22) * _weights[1]
		+ Color(1.00, 0.84, 0.34, 0.28) * _weights[2]
		+ Color(1.00, 0.68, 0.26, 0.26) * _weights[3]
		+ Color(0.46, 0.88, 1.00, 0.21) * _weights[4]
		+ Color(1.00, 0.82, 0.42, 0.24) * _weights[5]
	)
	var secondary_col: Color = (
		Color(1.00, 0.84, 0.44, 0.20) * _weights[0]
		+ Color(0.96, 0.90, 0.50, 0.20) * _weights[1]
		+ Color(0.34, 0.96, 0.58, 0.24) * _weights[2]
		+ Color(1.00, 0.84, 0.42, 0.22) * _weights[3]
		+ Color(0.32, 0.96, 0.70, 0.20) * _weights[4]
		+ Color(0.54, 0.82, 1.00, 0.21) * _weights[5]
	)
	primary_col = primary_col.lerp(Color(_col_mote.r, _col_mote.g, _col_mote.b, primary_col.a), 0.14)

	var par_x: float = -sin(_parallax_offset.x * 0.00095 * FG_PARALLAX) * (w * 0.026)
	var par_y: float = -sin(_parallax_offset.y * 0.00095 * FG_PARALLAX) * (h * 0.024)

	for i: int in range(FG_BOKEH_COUNT):
		var ph: float = _bokeh_phase[i]
		var px: float = w * _bokeh_x[i] + par_x + sin(_time * (0.42 + float(i) * 0.06) + ph) * (w * 0.018)
		var py: float = h * _bokeh_y[i] + par_y + cos(_time * (0.46 + float(i) * 0.05) + ph) * (h * 0.018)

		# Strict outer-18% frame envelope: keeps central playfield 100% open & unobstructed
		var u_x: float = px / w
		var u_y: float = py / h
		var edge_dist: float = minf(minf(u_x, 1.0 - u_x), minf(u_y, 1.0 - u_y))
		var edge_mask: float = 1.0 - smoothstep(0.08, 0.19, edge_dist)
		if edge_mask <= 0.005:
			continue

		var pulse: float = 0.72 + 0.28 * sin(_time * (0.96 + float(i) * 0.13) + ph * 1.8)
		var r: float = s * _bokeh_size[i] * (0.94 + 0.06 * pulse)
		var col: Color = primary_col.lerp(secondary_col, _bokeh_hue[i])
		col.a = clampf(col.a * pulse * edge_mask, 0.0, 0.30)
		canvas.draw_texture_rect(_bokeh_tex, Rect2(px - r, py - r, r * 2.0, r * 2.0), false, col)
