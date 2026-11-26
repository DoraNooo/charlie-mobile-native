class_name WorldAtmosphere
extends Node
## 4-Plane Ori x Ghibli atmospheric parallax system (zero external textures, 60-120 FPS mobile).
## Builds two HDR-aware CanvasLayers inside layer <= 5 (receiving WorldEnvironment AgX + Bloom):
##   - MidgroundLayer (layer = -5, parallax ~0.22x): per-scale painterly silhouettes + diagonal
##     top-left volumetric light shafts aligned with g_key_light_dir = (-0.52, -0.62).
##   - ForegroundLayer (layer = +4, parallax = 1.42x): out-of-focus peripheral bokeh orbs &
##     swaying foreground framing silhouettes strictly confined to outer 22% edges/corners.

const KEY_LIGHT_DIR: Vector2 = Vector2(-0.52, -0.62)
# Unit light-ray travel direction (from top-left key light toward bottom-right)
const RAY_DIR: Vector2 = Vector2(0.64262, 0.76618)
# Rotation mapping local +Y (0, 1) onto RAY_DIR in Godot 2D Y-down coordinates
const SHAFT_ROTATION: float = -0.69790

const MID_PARALLAX: float = 0.22
const FG_PARALLAX: float = 1.42

const ORBIT_SEGMENTS: int = 64
const WAVE_SAMPLES: int = 32
const MENISCUS_SAMPLES: int = 32
const KELP_STEPS: int = 9
const FOREST_HILL_SAMPLES: int = 48
const BOUGH_SEGMENTS: int = 14
const TWIG_SEGMENTS: int = 10
const VILLAGE_SLOTS: int = 10
const VILLAGE_VISIBLE_SLOTS: int = 11
const VILLAGE_WINDOW_MAX: int = 14
const EARTH_SAMPLES: int = 36
const AURORA_STEPS: int = 24
const FG_BOKEH_COUNT: int = 8

# Pre-baked constant lookup tables (zero per-frame allocations inside _draw())
const QUANTUM_RX_FRACS: Array[float] = [0.44, 0.64, 0.84]
const QUANTUM_RY_FRACS: Array[float] = [0.22, 0.34, 0.46]
const QUANTUM_TILTS: Array[float] = [-0.34, 0.28, -0.14]
const QUANTUM_ORBIT_COLS: Array[Color] = [
	Color(0.38, 0.94, 1.0, 0.19),
	Color(1.0, 0.86, 0.44, 0.16),
	Color(0.32, 0.90, 0.86, 0.14),
]

const KELP_ANCHORS: Array[float] = [0.07, 0.19, 0.81, 0.93]
const KELP_HEIGHTS: Array[float] = [0.46, 0.34, 0.38, 0.48]
const KELP_WIDTHS: Array[float] = [26.0, 20.0, 22.0, 28.0]

# Feathery translucent leaf-tuft clusters tucked softly along curved upper-corner forest boughs
const FOREST_TUFT_T: Array[float] = [0.08, 0.22, 0.36, 0.52, 0.68, 0.84, 0.96]
const FOREST_TUFT_OFF_Y: Array[float] = [-0.014, 0.012, -0.010, 0.014, -0.008, 0.009, -0.004]
const FOREST_TUFT_RX: Array[float] = [0.074, 0.066, 0.060, 0.052, 0.044, 0.036, 0.026]
const FOREST_TUFT_RY: Array[float] = [0.042, 0.038, 0.034, 0.030, 0.025, 0.021, 0.016]
const FOREST_TUFT_ANG: Array[float] = [0.22, -0.18, 0.26, -0.24, 0.18, -0.16, 0.12]

const PLANET_RX_FRACS: Array[float] = [0.48, 0.72, 0.98]
const PLANET_RY_FRACS: Array[float] = [0.19, 0.29, 0.40]
const PLANET_OPACITIES: Array[float] = [0.30, 0.22, 0.16]

# Large ultra-soft feathered radial nebula mist puffs for Scale 5 (Cosmique) — zero polygon edges
const COSMIC_PUFF_X: Array[float] = [0.22, 0.76, 0.42, 0.64, 0.26, 0.18, 0.82]
const COSMIC_PUFF_Y: Array[float] = [0.36, 0.62, 0.70, 0.32, 0.76, 0.20, 0.78]
const COSMIC_PUFF_RX: Array[float] = [0.56, 0.60, 0.50, 0.50, 0.52, 0.42, 0.46]
const COSMIC_PUFF_RY: Array[float] = [0.36, 0.38, 0.34, 0.34, 0.35, 0.28, 0.31]
const COSMIC_PUFF_ANG: Array[float] = [-0.28, 0.22, -0.16, 0.32, -0.22, 0.18, -0.30]
const COSMIC_PUFF_COLS: Array[Color] = [
	Color(0.96, 0.34, 0.72, 0.17),
	Color(0.18, 0.78, 0.98, 0.17),
	Color(1.00, 0.78, 0.34, 0.14),
	Color(0.90, 0.28, 0.66, 0.15),
	Color(0.16, 0.68, 0.96, 0.15),
	Color(0.98, 0.70, 0.30, 0.13),
	Color(0.84, 0.40, 0.88, 0.14),
]

const SHAFT_ANCHOR_XS: Array[float] = [0.04, 0.26, 0.50]
const SHAFT_WIDTHS: Array[float] = [0.16, 0.22, 0.15]

# Strictly outer-corner foreground bokeh anchors (never intruding on the center playfield)
const FG_DROPLET_XS: Array[float] = [0.055, 0.080, 0.920, 0.945]
const FG_DROPLET_YS: Array[float] = [0.115, 0.875, 0.130, 0.865]
const FG_DROPLET_RADS: Array[float] = [0.050, 0.042, 0.044, 0.054]

const FG_FOLIAGE_XS: Array[float] = [0.045, 0.955, 0.055, 0.945]
const FG_FOLIAGE_YS: Array[float] = [0.925, 0.915, 0.075, 0.085]
const FG_FOLIAGE_ANGS: Array[float] = [-0.38, 0.38, 0.34, -0.34]
const FG_FOLIAGE_RADS: Array[float] = [0.135, 0.145, 0.115, 0.125]

const FG_LANTERN_XS: Array[float] = [0.055, 0.945, 0.080, 0.920]
const FG_LANTERN_YS: Array[float] = [0.135, 0.860, 0.850, 0.150]
const FG_LANTERN_RADS: Array[float] = [0.062, 0.070, 0.056, 0.060]

# CanvasLayers & dual normal/additive drawing canvases
var _midground_layer: CanvasLayer = null
var _mid_canvas: _MidgroundCanvas = null
var _mid_add_canvas: _MidgroundAdditiveCanvas = null

var _foreground_layer: CanvasLayer = null
var _fg_canvas: _ForegroundCanvas = null
var _fg_add_canvas: _ForegroundAdditiveCanvas = null

# Procedural zero-external-asset textures baked once in _ready()
var _bokeh_tex: GradientTexture2D = null
var _glow_tex: GradientTexture2D = null
var _wisp_tex: GradientTexture2D = null
var _nebula_puff_tex: GradientTexture2D = null
var _leaf_puff_tex: GradientTexture2D = null
var _shaft_tex: ImageTexture = null

# Frame state updated via update_atmosphere()
var _time: float = 0.0
var _parallax_offset: Vector2 = Vector2.ZERO
var _scale_progress: float = 0.0
var _viewport_size: Vector2 = Vector2(1280.0, 720.0)
var _weights: PackedFloat32Array = PackedFloat32Array([1.0, 0.0, 0.0, 0.0, 0.0, 0.0])

var _col_bg_inner: Color = Color(0.055, 0.153, 0.200, 1.0)
var _col_bg_outer: Color = Color(0.024, 0.067, 0.098, 1.0)
var _col_mote: Color = Color(0.431, 0.906, 0.855, 1.0)
var _col_accent: Color = Color(1.0, 0.72, 0.48, 1.0)

# Pre-allocated reusable geometry buffers (ZERO per-frame allocations inside _draw())
var _orbit_pts: PackedVector2Array = PackedVector2Array()
var _wave_line_pts: PackedVector2Array = PackedVector2Array()
var _wave_poly_pts: PackedVector2Array = PackedVector2Array()
var _wave_poly_cols: PackedColorArray = PackedColorArray()

var _meniscus_poly_pts: PackedVector2Array = PackedVector2Array()
var _meniscus_rim_pts: PackedVector2Array = PackedVector2Array()
var _meniscus_sub_pts: PackedVector2Array = PackedVector2Array()
var _kelp_pts: PackedVector2Array = PackedVector2Array()

var _forest_far_pts: PackedVector2Array = PackedVector2Array()
var _forest_near_pts: PackedVector2Array = PackedVector2Array()
var _bough_pts: PackedVector2Array = PackedVector2Array()
var _twig_pts: PackedVector2Array = PackedVector2Array()

var _city_far_poly_pts: PackedVector2Array = PackedVector2Array()
var _roof_poly_pts: PackedVector2Array = PackedVector2Array()
var _window_pts: PackedVector2Array = PackedVector2Array()
var _window_cols: PackedColorArray = PackedColorArray()
var _window_centers: PackedVector2Array = PackedVector2Array()
var _city_win_count: int = 0
var _lava_window_pts: PackedVector2Array = PackedVector2Array()
var _lava_base_pts: PackedVector2Array = PackedVector2Array()
var _lava_glass_pts: PackedVector2Array = PackedVector2Array()
var _lava_cap_pts: PackedVector2Array = PackedVector2Array()
var _lava_window_screen_pos: Vector2 = Vector2(-9999.0, -9999.0)
var _lava_window_visible: bool = false

var _earth_poly_pts: PackedVector2Array = PackedVector2Array()
var _earth_arc_pts: PackedVector2Array = PackedVector2Array()
var _aurora_pts: PackedVector2Array = PackedVector2Array()
var _aurora_cols: PackedColorArray = PackedColorArray()

# Pre-baked deterministic village architecture & outer-corner bokeh anchors
var _city_far_wall_h: PackedFloat32Array = PackedFloat32Array()
var _city_far_peak_h: PackedFloat32Array = PackedFloat32Array()
var _village_wall_h: PackedFloat32Array = PackedFloat32Array()
var _village_peak_h: PackedFloat32Array = PackedFloat32Array()
var _village_roof_kind: PackedInt32Array = PackedInt32Array()

var _bokeh_corner_x: PackedFloat32Array = PackedFloat32Array()
var _bokeh_corner_y: PackedFloat32Array = PackedFloat32Array()
var _bokeh_size: PackedFloat32Array = PackedFloat32Array()
var _bokeh_phase: PackedFloat32Array = PackedFloat32Array()
var _bokeh_hue_pick: PackedFloat32Array = PackedFloat32Array()


class _MidgroundCanvas:
	extends Node2D
	var owner_atmo: WorldAtmosphere = null

	func _draw() -> void:
		if owner_atmo != null:
			owner_atmo._draw_midground_silhouettes(self)


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
			owner_atmo._draw_foreground_silhouettes(self)


class _ForegroundAdditiveCanvas:
	extends Node2D
	var owner_atmo: WorldAtmosphere = null

	func _draw() -> void:
		if owner_atmo != null:
			owner_atmo._draw_foreground_additive(self)


func _ready() -> void:
	_bake_procedural_textures()
	_allocate_buffers()
	_init_village_and_rails()
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
	# 1. Soft optical out-of-focus bokeh orb (GradientTexture2D, 64x64, silky feathered edge)
	var bokeh_grad: Gradient = Gradient.new()
	bokeh_grad.offsets = PackedFloat32Array([0.0, 0.28, 0.56, 0.80, 1.0])
	bokeh_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.88),
		Color(1.0, 1.0, 1.0, 0.66),
		Color(1.0, 1.0, 1.0, 0.34),
		Color(1.0, 1.0, 1.0, 0.09),
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
	glow_grad.offsets = PackedFloat32Array([0.0, 0.24, 0.58, 1.0])
	glow_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 0.54),
		Color(1.0, 1.0, 1.0, 0.13),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	_glow_tex = GradientTexture2D.new()
	_glow_tex.width = 64
	_glow_tex.height = 64
	_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_glow_tex.fill_from = Vector2(0.5, 0.5)
	_glow_tex.fill_to = Vector2(1.0, 0.5)
	_glow_tex.gradient = glow_grad

	# 3. Gossamer elongated cloud/nebula wisp (GradientTexture2D, 64x32)
	var wisp_grad: Gradient = Gradient.new()
	wisp_grad.offsets = PackedFloat32Array([0.0, 0.36, 0.74, 1.0])
	wisp_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.50),
		Color(1.0, 1.0, 1.0, 0.28),
		Color(1.0, 1.0, 1.0, 0.08),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	_wisp_tex = GradientTexture2D.new()
	_wisp_tex.width = 64
	_wisp_tex.height = 32
	_wisp_tex.fill = GradientTexture2D.FILL_RADIAL
	_wisp_tex.fill_from = Vector2(0.5, 0.5)
	_wisp_tex.fill_to = Vector2(1.0, 0.5)
	_wisp_tex.gradient = wisp_grad

	# 4. Ultra-soft feathered radial nebula mist puff (GradientTexture2D, 128x128, zero hard edges)
	var neb_grad: Gradient = Gradient.new()
	neb_grad.offsets = PackedFloat32Array([0.0, 0.22, 0.48, 0.74, 1.0])
	neb_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.92),
		Color(1.0, 1.0, 1.0, 0.64),
		Color(1.0, 1.0, 1.0, 0.30),
		Color(1.0, 1.0, 1.0, 0.08),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	_nebula_puff_tex = GradientTexture2D.new()
	_nebula_puff_tex.width = 128
	_nebula_puff_tex.height = 128
	_nebula_puff_tex.fill = GradientTexture2D.FILL_RADIAL
	_nebula_puff_tex.fill_from = Vector2(0.5, 0.5)
	_nebula_puff_tex.fill_to = Vector2(1.0, 0.5)
	_nebula_puff_tex.gradient = neb_grad

	# 5. Soft feathered botanical foliage tuft (GradientTexture2D, 64x48, painterly misty canopy)
	var leaf_grad: Gradient = Gradient.new()
	leaf_grad.offsets = PackedFloat32Array([0.0, 0.36, 0.70, 1.0])
	leaf_grad.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.92),
		Color(1.0, 1.0, 1.0, 0.64),
		Color(1.0, 1.0, 1.0, 0.20),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	_leaf_puff_tex = GradientTexture2D.new()
	_leaf_puff_tex.width = 64
	_leaf_puff_tex.height = 48
	_leaf_puff_tex.fill = GradientTexture2D.FILL_RADIAL
	_leaf_puff_tex.fill_from = Vector2(0.5, 0.5)
	_leaf_puff_tex.fill_to = Vector2(1.0, 0.5)
	_leaf_puff_tex.gradient = leaf_grad

	# 6. Silky procedural volumetric light shaft texture (48x64 RGBA8, zero hard edges)
	var img: Image = Image.create_empty(48, 64, false, Image.FORMAT_RGBA8)
	for y: int in range(64):
		var v: float = float(y) / 63.0
		var v_in: float = clampf(v / 0.14, 0.0, 1.0)
		v_in = v_in * v_in * (3.0 - 2.0 * v_in)
		var v_out: float = pow(maxf(0.0, 1.0 - v), 1.65)
		var v_env: float = v_in * v_out
		for x: int in range(48):
			var u: float = float(x) / 47.0
			var bell: float = sin(u * PI)
			var h_env: float = bell * bell * (0.78 + 0.22 * sin(u * PI * 3.0) * sin(u * PI * 3.0))
			var alpha: float = clampf(h_env * v_env, 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_shaft_tex = ImageTexture.create_from_image(img)


func _allocate_buffers() -> void:
	_orbit_pts.resize(ORBIT_SEGMENTS + 1)
	_wave_line_pts.resize(WAVE_SAMPLES)
	_wave_poly_pts.resize(WAVE_SAMPLES * 2)
	_wave_poly_cols.resize(WAVE_SAMPLES * 2)

	_meniscus_poly_pts.resize(MENISCUS_SAMPLES + 2)
	_meniscus_rim_pts.resize(MENISCUS_SAMPLES)
	_meniscus_sub_pts.resize(MENISCUS_SAMPLES)
	_kelp_pts.resize(KELP_STEPS * 2 + 1)

	_forest_far_pts.resize(FOREST_HILL_SAMPLES + 2)
	_forest_near_pts.resize(FOREST_HILL_SAMPLES + 2)
	_bough_pts.resize(BOUGH_SEGMENTS * 2)
	_twig_pts.resize(TWIG_SEGMENTS * 2)

	_city_far_poly_pts.resize(VILLAGE_VISIBLE_SLOTS * 5 + 2)
	_roof_poly_pts.resize(VILLAGE_VISIBLE_SLOTS * 5 + 2)
	_window_pts.resize(VILLAGE_WINDOW_MAX * 2)
	_window_cols.resize(VILLAGE_WINDOW_MAX)
	_window_centers.resize(VILLAGE_WINDOW_MAX)
	_lava_window_pts.resize(7)
	_lava_base_pts.resize(4)
	_lava_glass_pts.resize(6)
	_lava_cap_pts.resize(3)

	_earth_poly_pts.resize(EARTH_SAMPLES + 2)
	_earth_arc_pts.resize(EARTH_SAMPLES)
	_aurora_pts.resize(AURORA_STEPS * 2)
	_aurora_cols.resize(AURORA_STEPS * 2)


func _init_village_and_rails() -> void:
	# Distant soft misty twilight-indigo skyline silhouettes (gentle broad roofs, zero spikes)
	_city_far_wall_h = PackedFloat32Array([0.145, 0.168, 0.132, 0.174, 0.150, 0.162, 0.138, 0.170, 0.142, 0.158])
	_city_far_peak_h = PackedFloat32Array([0.028, 0.024, 0.032, 0.036, 0.026, 0.042, 0.028, 0.025, 0.030, 0.034])

	# 10 distinct cozy Ghibli sleeping village silhouettes (slot 3 = Charlie's cozy attic lava-lamp house!)
	# roof_kind: 0=soft pitched gable, 1=French mansard, 2=broad cottage gable, 3=Charlie's attic, 4=soft cupola tower
	_village_wall_h = PackedFloat32Array([0.100, 0.124, 0.088, 0.136, 0.110, 0.122, 0.098, 0.116, 0.092, 0.112])
	_village_peak_h = PackedFloat32Array([0.034, 0.026, 0.032, 0.052, 0.034, 0.056, 0.034, 0.030, 0.032, 0.038])
	_village_roof_kind = PackedInt32Array([2, 1, 0, 3, 0, 4, 1, 2, 0, 1])

	# 8 soft peripheral bokeh orbs strictly pinned into the 4 outer corners (2 per corner quadrant)
	_bokeh_corner_x = PackedFloat32Array([0.065, 0.145, 0.855, 0.935, 0.070, 0.155, 0.845, 0.930])
	_bokeh_corner_y = PackedFloat32Array([0.090, 0.065, 0.070, 0.110, 0.905, 0.930, 0.925, 0.885])
	_bokeh_size = PackedFloat32Array([0.074, 0.056, 0.062, 0.078, 0.080, 0.058, 0.066, 0.076])
	_bokeh_phase = PackedFloat32Array([0.4, 2.1, 3.8, 5.2, 1.3, 4.4, 2.9, 5.7])
	_bokeh_hue_pick = PackedFloat32Array([0.14, 0.78, 0.28, 0.88, 0.62, 0.20, 0.82, 0.42])


func _build_layers() -> void:
	var add_mat: CanvasItemMaterial = CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# Layer A: MidgroundLayer (layer = -5, behind gameplay world at 0, receives HDR AgX + Bloom)
	_midground_layer = CanvasLayer.new()
	_midground_layer.name = "MidgroundLayer"
	_midground_layer.layer = -5
	add_child(_midground_layer)

	_mid_canvas = _MidgroundCanvas.new()
	_mid_canvas.name = "MidgroundSilhouettes"
	_mid_canvas.owner_atmo = self
	_midground_layer.add_child(_mid_canvas)

	_mid_add_canvas = _MidgroundAdditiveCanvas.new()
	_mid_add_canvas.name = "MidgroundAdditive"
	_mid_add_canvas.owner_atmo = self
	_mid_add_canvas.material = add_mat
	_midground_layer.add_child(_mid_add_canvas)

	# Layer B: ForegroundLayer (layer = +4, passes IN FRONT of Charlie, still <= 5 for HDR AgX + Bloom)
	_foreground_layer = CanvasLayer.new()
	_foreground_layer.name = "ForegroundLayer"
	_foreground_layer.layer = 4
	add_child(_foreground_layer)

	_fg_canvas = _ForegroundCanvas.new()
	_fg_canvas.name = "ForegroundSilhouettes"
	_fg_canvas.owner_atmo = self
	_foreground_layer.add_child(_fg_canvas)

	_fg_add_canvas = _ForegroundAdditiveCanvas.new()
	_fg_add_canvas.name = "ForegroundAdditive"
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
# MIDGROUND SILHOUETTES (Layer -5, Normal Alpha Blend)
# ==============================================================================

func _draw_midground_silhouettes(canvas: Node2D) -> void:
	var w: float = _viewport_size.x
	var h: float = _viewport_size.y
	if w <= 1.0 or h <= 1.0:
		return

	_lava_window_visible = false
	_city_win_count = 0

	if _weights[0] > 0.004:
		_draw_mid_quantum(canvas, w, h, _weights[0])
	if _weights[1] > 0.004:
		_draw_mid_micro(canvas, w, h, _weights[1])
	if _weights[2] > 0.004:
		_draw_mid_forest(canvas, w, h, _weights[2])
	if _weights[3] > 0.004:
		_draw_mid_city(canvas, w, h, _weights[3])
	if _weights[4] > 0.004:
		_draw_mid_planetary(canvas, w, h, _weights[4])
	if _weights[5] > 0.004:
		_draw_mid_cosmic(canvas, w, h, _weights[5])


# --- Scale 0: Quantique (Whisper-soft harmonic orbital arcs + translucent probability waves) ---
func _draw_mid_quantum(canvas: Node2D, w: float, h: float, alpha: float) -> void:
	var s: float = minf(w, h)
	var drift: Vector2 = Vector2(
		-fposmod(_parallax_offset.x * MID_PARALLAX, w * 1.4) + w * 0.7,
		-fposmod(_parallax_offset.y * MID_PARALLAX, h * 1.4) + h * 0.7
	)
	var center: Vector2 = Vector2(w * 0.5, h * 0.5) + (drift - Vector2(w * 0.5, h * 0.5)) * 0.14

	# 3 large concentric tilted harmonic orbital arcs (sleek 1.2px anti-aliased depth whispers)
	for k: int in range(3):
		var rx: float = s * QUANTUM_RX_FRACS[k] * (1.0 + 0.025 * sin(_time * (0.45 + float(k) * 0.18) + float(k)))
		var ry: float = s * QUANTUM_RY_FRACS[k] * (1.0 + 0.025 * cos(_time * (0.38 + float(k) * 0.16) + float(k)))
		var ang_tilt: float = QUANTUM_TILTS[k] + sin(_time * 0.16 + float(k) * 2.1) * 0.06
		var ca: float = cos(ang_tilt)
		var sa: float = sin(ang_tilt)
		for i: int in range(ORBIT_SEGMENTS + 1):
			var theta: float = (float(i) / float(ORBIT_SEGMENTS)) * TAU
			var lx: float = cos(theta) * rx
			var ly: float = sin(theta) * ry
			_orbit_pts[i] = Vector2(center.x + lx * ca - ly * sa, center.y + lx * sa + ly * ca)
		var oc: Color = QUANTUM_ORBIT_COLS[k]
		canvas.draw_polyline(_orbit_pts, Color(oc.r, oc.g, oc.b, oc.a * alpha), 1.2, true)

	# 2 whisper-soft drifting sinusoidal probability waves (upper & lower bands)
	var scroll_x: float = _parallax_offset.x * MID_PARALLAX * 0.008
	for band: int in range(2):
		var base_y: float = h * (0.20 if band == 0 else 0.81)
		var amp: float = h * (0.042 if band == 0 else 0.048)
		var ribbon_h: float = h * 0.052
		var freq: float = 2.6 if band == 0 else 2.1
		var phase: float = _time * (0.72 if band == 0 else -0.58) + scroll_x
		var wave_col: Color = Color(0.34, 0.94, 0.96, 1.0) if band == 0 else Color(1.0, 0.82, 0.42, 1.0)

		for i: int in range(WAVE_SAMPLES):
			var u: float = float(i) / float(WAVE_SAMPLES - 1)
			var x: float = lerpf(-16.0, w + 16.0, u)
			var env: float = sin(u * PI)
			var wy: float = base_y + sin(u * TAU * freq + phase) * amp * (0.45 + 0.55 * env)
			_wave_line_pts[i] = Vector2(x, wy)
			_wave_poly_pts[i] = Vector2(x, wy - ribbon_h * 0.35)
			_wave_poly_cols[i] = Color(wave_col.r, wave_col.g, wave_col.b, 0.065 * alpha * env)
			var rev: int = WAVE_SAMPLES * 2 - 1 - i
			_wave_poly_pts[rev] = Vector2(x, wy + ribbon_h * 0.85)
			_wave_poly_cols[rev] = Color(wave_col.r, wave_col.g, wave_col.b, 0.0)
		canvas.draw_polygon(_wave_poly_pts, _wave_poly_cols)
		canvas.draw_polyline(_wave_line_pts, Color(wave_col.r, wave_col.g, wave_col.b, 0.18 * alpha), 1.2, true)


# --- Scale 1: Microscopique (Dewdrop meniscus arch + swaying translucent kelp ribbons) ---
func _draw_mid_micro(canvas: Node2D, w: float, h: float, alpha: float) -> void:
	# 1. Curved translucent luminous dewdrop meniscus arch across the top
	var par_y: float = clampf(-sin(_parallax_offset.y * 0.0008) * h * 0.015, -14.0, 14.0)
	var arch_edge_y: float = h * 0.165 + par_y
	var arch_crown_y: float = h * 0.068 + par_y
	var wave_scroll: float = _parallax_offset.x * MID_PARALLAX * 0.012

	for i: int in range(MENISCUS_SAMPLES):
		var u: float = float(i) / float(MENISCUS_SAMPLES - 1)
		var x: float = lerpf(-18.0, w + 18.0, u)
		var centered: float = (u - 0.5) * 2.0
		var curve: float = centered * centered
		var ripple: float = sin(u * TAU * 2.5 + _time * 1.15 + wave_scroll) * (h * 0.0065)
		var y: float = lerpf(arch_crown_y, arch_edge_y, curve) + ripple
		_meniscus_rim_pts[i] = Vector2(x, y)
		_meniscus_sub_pts[i] = Vector2(x, y + h * 0.018 + cos(u * TAU * 3.0 - _time * 0.9) * 2.5)
		_meniscus_poly_pts[i] = Vector2(x, y)
	_meniscus_poly_pts[MENISCUS_SAMPLES] = Vector2(w + 18.0, -24.0)
	_meniscus_poly_pts[MENISCUS_SAMPLES + 1] = Vector2(-18.0, -24.0)

	# Translucent upper water-glass dome cap + crisp luminous HDR meniscus rim + inner caustic shimmer
	canvas.draw_colored_polygon(_meniscus_poly_pts, Color(0.025, 0.145, 0.170, 0.44 * alpha))
	canvas.draw_polyline(_meniscus_rim_pts, Color(0.50, 0.88, 0.84, 0.34 * alpha), 2.0, true)
	canvas.draw_polyline(_meniscus_sub_pts, Color(0.36, 0.82, 0.76, 0.16 * alpha), 1.2, true)

	# 2. 4 gently swaying translucent kelp / algal ribbons wrapping seamlessly along the bottom flanks
	var wrap_w: float = w + 260.0
	var unit: float = h / 720.0
	for k: int in range(4):
		var raw_x: float = KELP_ANCHORS[k] * wrap_w - _parallax_offset.x * MID_PARALLAX
		var root_x: float = fposmod(raw_x, wrap_w) - 130.0
		var kelp_h: float = h * KELP_HEIGHTS[k]
		var kelp_w: float = KELP_WIDTHS[k] * unit
		var sway_ph: float = _time * (0.95 + float(k) * 0.14) + float(k) * 1.75
		var side_tint: Color = Color(0.08, 0.44, 0.36, 0.34 * alpha) if (k % 2 == 0) else Color(0.14, 0.58, 0.46, 0.26 * alpha)

		for step: int in range(KELP_STEPS):
			var t_s: float = float(step) / float(KELP_STEPS)
			var y: float = h + 16.0 - t_s * kelp_h
			var sway: float = sin(sway_ph + t_s * 3.6) * (t_s * t_s * 36.0 * unit)
			var cx: float = root_x + sway
			var half_w: float = kelp_w * (1.0 - t_s * 0.82) * (0.85 + 0.15 * sin(t_s * PI * 4.0))
			_kelp_pts[step] = Vector2(cx - half_w, y)
			_kelp_pts[KELP_STEPS * 2 - step] = Vector2(cx + half_w, y)
		var tip_sway: float = sin(sway_ph + 3.6) * (36.0 * unit)
		_kelp_pts[KELP_STEPS] = Vector2(root_x + tip_sway, h + 16.0 - kelp_h)
		canvas.draw_colored_polygon(_kelp_pts, side_tint)


# --- Scale 2: Sous-Bois (Painterly misty rolling canopy hills + curved overhanging corner boughs) ---
func _draw_mid_forest(canvas: Node2D, w: float, h: float, alpha: float) -> void:
	# 1. Back rolling mossy canopy hills (smooth multi-harmonic sine-bell curves, ZERO spikes)
	var phase_far: float = _parallax_offset.x * 0.14 * 0.0022
	for i: int in range(FOREST_HILL_SAMPLES):
		var u: float = float(i) / float(FOREST_HILL_SAMPLES - 1)
		var x: float = lerpf(-24.0, w + 24.0, u)
		var edge_curve: float = pow(absf(u - 0.5) * 2.0, 2.0)
		var bell_a: float = 0.5 + 0.5 * sin(u * TAU * 1.45 + phase_far + 0.6)
		var bell_b: float = 0.5 + 0.5 * sin(u * TAU * 2.55 + phase_far * 1.35 + 2.3)
		var smooth_crown: float = bell_a * bell_a * 0.056 + bell_b * bell_b * 0.028
		var y: float = h * (0.868 - edge_curve * 0.110 - smooth_crown)
		_forest_far_pts[i] = Vector2(x, y)
	_forest_far_pts[FOREST_HILL_SAMPLES] = Vector2(w + 24.0, h + 24.0)
	_forest_far_pts[FOREST_HILL_SAMPLES + 1] = Vector2(-24.0, h + 24.0)
	canvas.draw_colored_polygon(_forest_far_pts, Color(0.02, 0.11, 0.09, 0.42 * alpha))

	# Soft misty emerald ground-veil hovering gently between back & front rolling hills
	if _nebula_puff_tex != null:
		var mist_shift: float = -sin(_parallax_offset.x * 0.0005) * w * 0.04
		var mw: float = w * 0.62
		var mh: float = h * 0.22
		canvas.draw_texture_rect(
			_nebula_puff_tex,
			Rect2(w * 0.24 + mist_shift - mw * 0.5, h * 0.87 - mh * 0.5, mw, mh),
			false,
			Color(0.08, 0.36, 0.26, 0.12 * alpha)
		)
		canvas.draw_texture_rect(
			_nebula_puff_tex,
			Rect2(w * 0.76 + mist_shift * 0.8 - mw * 0.5, h * 0.88 - mh * 0.5, mw, mh),
			false,
			Color(0.06, 0.30, 0.24, 0.11 * alpha)
		)

	# 2. Front rolling mossy canopy hills (smooth sine-bell contours, open sunlit center clearing)
	var phase_near: float = _parallax_offset.x * 0.24 * 0.0028
	for i: int in range(FOREST_HILL_SAMPLES):
		var u: float = float(i) / float(FOREST_HILL_SAMPLES - 1)
		var x: float = lerpf(-24.0, w + 24.0, u)
		var edge_curve: float = pow(absf(u - 0.5) * 2.0, 2.2)
		var bell_a: float = 0.5 + 0.5 * sin(u * TAU * 1.75 + phase_near + 1.9)
		var bell_b: float = 0.5 + 0.5 * cos(u * TAU * 3.05 + phase_near * 1.20 + 0.4)
		var smooth_mound: float = bell_a * bell_a * 0.040 + bell_b * bell_b * 0.022
		var y: float = h * (0.935 - edge_curve * 0.130 - smooth_mound)
		_forest_near_pts[i] = Vector2(x, y)
	_forest_near_pts[FOREST_HILL_SAMPLES] = Vector2(w + 24.0, h + 24.0)
	_forest_near_pts[FOREST_HILL_SAMPLES + 1] = Vector2(-24.0, h + 24.0)
	canvas.draw_colored_polygon(_forest_near_pts, Color(0.015, 0.075, 0.065, 0.55 * alpha))

	# 3. Soft curved overhanging corner boughs + feathery translucent leaf tufts (alpha 0.30-0.38)
	var sway_l: float = sin(_time * 0.68) * (h * 0.009)
	var sway_r: float = cos(_time * 0.62 + 1.3) * (h * 0.009)
	var par_b: Vector2 = Vector2(
		clampf(-sin(_parallax_offset.x * 0.0008) * 14.0, -14.0, 14.0),
		clampf(-sin(_parallax_offset.y * 0.0008) * 8.0, -8.0, 8.0)
	)
	_draw_forest_corner_canopy(canvas, w, h, true, sway_l, par_b, alpha)
	_draw_forest_corner_canopy(canvas, w, h, false, sway_r, par_b, alpha)


func _bough_center_pos(t: float, w: float, h: float, is_left: bool, sway: float, par: Vector2) -> Vector2:
	var reach_x: float = w * 0.22
	var start_y: float = h * 0.015 + par.y
	var x_in: float = -20.0 + (reach_x + 20.0) * (t * 0.92 + 0.08 * sin(t * PI * 0.5)) + par.x * (0.4 if is_left else -0.4)
	var x: float = x_in if is_left else (w - x_in)
	# Botanical S-curve: sweeps smoothly out from upper corner, droops gently, lifts subtly at feathery tip
	var arch_y: float = start_y + h * 0.098 * sin(t * PI * 0.68) + h * 0.020 * sin(t * PI * 1.45) + sway * t * t
	return Vector2(x, arch_y)


func _draw_forest_corner_canopy(canvas: Node2D, w: float, h: float, is_left: bool, sway: float, par: Vector2, alpha: float) -> void:
	# Curved tapering primary overhanging bough (monotonic X = zero self-intersection, never a rigid stick)
	for i: int in range(BOUGH_SEGMENTS):
		var t: float = float(i) / float(BOUGH_SEGMENTS - 1)
		var c: Vector2 = _bough_center_pos(t, w, h, is_left, sway, par)
		var half_th: float = lerpf(h * 0.014, h * 0.0022, pow(t, 0.72))
		_bough_pts[i] = Vector2(c.x, c.y - half_th)
		_bough_pts[BOUGH_SEGMENTS * 2 - 1 - i] = Vector2(c.x, c.y + half_th)
	canvas.draw_colored_polygon(_bough_pts, Color(0.018, 0.085, 0.068, 0.35 * alpha))

	# Curved secondary twig branching organically downward-inward from t = 0.32
	var fork: Vector2 = _bough_center_pos(0.32, w, h, is_left, sway, par)
	var twig_dir: float = 1.0 if is_left else -1.0
	for i: int in range(TWIG_SEGMENTS):
		var t: float = float(i) / float(TWIG_SEGMENTS - 1)
		var tx: float = fork.x + twig_dir * (w * 0.085) * (t * 0.88 + 0.12 * sin(t * PI * 0.5))
		var ty: float = fork.y + h * 0.056 * sin(t * PI * 0.72) + sway * 0.6 * t * t
		var half_th: float = lerpf(h * 0.0068, h * 0.0016, pow(t, 0.75))
		_twig_pts[i] = Vector2(tx, ty - half_th)
		_twig_pts[TWIG_SEGMENTS * 2 - 1 - i] = Vector2(tx, ty + half_th)
	canvas.draw_colored_polygon(_twig_pts, Color(0.020, 0.095, 0.074, 0.31 * alpha))

	# Gentle feathery translucent leaf-tuft puffs tucked softly along the curved corner canopy
	if _leaf_puff_tex != null:
		var s: float = minf(w, h)
		var sign_x: float = 1.0 if is_left else -1.0
		var phase_off: float = 0.0 if is_left else 2.1
		for k: int in range(FOREST_TUFT_T.size()):
			var tk: float = FOREST_TUFT_T[k]
			var base_p: Vector2 = _bough_center_pos(tk, w, h, is_left, sway, par)
			var flutter: float = sin(_time * (0.85 + float(k) * 0.11) + phase_off + float(k) * 1.4)
			var pos: Vector2 = base_p + Vector2(flutter * 2.5 * sign_x, h * FOREST_TUFT_OFF_Y[k] + flutter * 1.8)
			var rx: float = s * FOREST_TUFT_RX[k]
			var ry: float = s * FOREST_TUFT_RY[k]
			var ang: float = FOREST_TUFT_ANG[k] * sign_x + flutter * 0.04
			var leaf_col: Color = (
				Color(0.022, 0.115, 0.086, 0.36 * alpha) if (k % 2 == 0)
				else Color(0.030, 0.145, 0.104, 0.31 * alpha)
			)
			canvas.draw_set_transform(pos, ang, Vector2.ONE)
			canvas.draw_texture_rect(_leaf_puff_tex, Rect2(-rx, -ry, rx * 2.0, ry * 2.0), false, leaf_col)
		# Soft corner crown tuft tucking the root seamlessly into the upper corner
		var crown_pos: Vector2 = Vector2(w * (0.035 if is_left else 0.965), h * 0.030 + par.y * 0.5)
		canvas.draw_set_transform(crown_pos, 0.24 * sign_x, Vector2.ONE)
		canvas.draw_texture_rect(
			_leaf_puff_tex,
			Rect2(-s * 0.105, -s * 0.068, s * 0.210, s * 0.136),
			false,
			Color(0.018, 0.095, 0.075, 0.38 * alpha)
		)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Scale 3: Ville Endormie (Two misty twilight-indigo skyline layers, warm glowing windows, Lava-Lamp Easter egg) ---
func _draw_mid_city(canvas: Node2D, w: float, h: float, alpha: float) -> void:
	var unit: float = h / 720.0

	# 1. Distant misty twilight-indigo skyline layer (parallax 0.13x, soft broad silhouettes, NO outline stroke)
	var far_slot_w: float = maxf(w / 8.0, 144.0)
	var scroll_far: float = _parallax_offset.x * 0.13
	var start_far: int = int(floor(scroll_far / far_slot_w)) - 1
	for i: int in range(VILLAGE_VISIBLE_SLOTS):
		var world_slot: int = start_far + i
		var s_idx: int = posmod(world_slot + 4, VILLAGE_SLOTS)
		var x0: float = float(world_slot) * far_slot_w - scroll_far
		var x1: float = x0 + far_slot_w
		var xm: float = (x0 + x1) * 0.5
		var wall_y: float = h * (1.0 - _city_far_wall_h[s_idx])
		var peak_y: float = wall_y - h * _city_far_peak_h[s_idx]
		var v_base: int = i * 5
		_city_far_poly_pts[v_base] = Vector2(x0 + 1.5, wall_y)
		if s_idx % 2 == 0:
			# Soft broad mansard silhouette
			_city_far_poly_pts[v_base + 1] = Vector2(x0 + far_slot_w * 0.18, peak_y)
			_city_far_poly_pts[v_base + 2] = Vector2(xm, peak_y - 1.5 * unit)
			_city_far_poly_pts[v_base + 3] = Vector2(x1 - far_slot_w * 0.18, peak_y)
		else:
			# Gentle wide storybook gable
			_city_far_poly_pts[v_base + 1] = Vector2(x0 + far_slot_w * 0.24, lerpf(wall_y, peak_y, 0.58))
			_city_far_poly_pts[v_base + 2] = Vector2(xm, peak_y)
			_city_far_poly_pts[v_base + 3] = Vector2(x1 - far_slot_w * 0.24, lerpf(wall_y, peak_y, 0.58))
		_city_far_poly_pts[v_base + 4] = Vector2(x1 - 1.5, wall_y)

	var far_rim_count: int = VILLAGE_VISIBLE_SLOTS * 5
	_city_far_poly_pts[far_rim_count] = Vector2(_city_far_poly_pts[far_rim_count - 1].x, h + 24.0)
	_city_far_poly_pts[far_rim_count + 1] = Vector2(_city_far_poly_pts[0].x, h + 24.0)
	canvas.draw_colored_polygon(_city_far_poly_pts, Color(0.04, 0.07, 0.15, 0.36 * alpha))

	# 2. Closer gentle Ghibli rooftops layer (parallax 0.22x, soft twilight-indigo fill, NO outline stroke!)
	var slot_w: float = maxf(w / 9.2, 128.0)
	var scroll: float = _parallax_offset.x * MID_PARALLAX
	var start_slot: int = int(floor(scroll / slot_w)) - 1
	var win_count: int = 0

	var lava_cx: float = -9999.0
	var lava_cy: float = -9999.0
	var lava_w: float = 20.0 * unit
	var lava_h: float = 27.0 * unit

	for i: int in range(VILLAGE_VISIBLE_SLOTS):
		var world_slot: int = start_slot + i
		var s_idx: int = posmod(world_slot, VILLAGE_SLOTS)
		var x0: float = float(world_slot) * slot_w - scroll
		var x1: float = x0 + slot_w
		var xm: float = (x0 + x1) * 0.5
		var wall_y: float = h * (1.0 - _village_wall_h[s_idx])
		var peak_y: float = wall_y - h * _village_peak_h[s_idx]
		var kind: int = _village_roof_kind[s_idx]

		var v_base: int = i * 5
		var p0: Vector2 = Vector2(x0 + 2.0, wall_y)
		var p1: Vector2
		var p2: Vector2
		var p3: Vector2
		var p4: Vector2 = Vector2(x1 - 2.0, wall_y)

		if kind == 1:
			# Cozy French mansard roof
			p1 = Vector2(x0 + slot_w * 0.16, peak_y)
			p2 = Vector2(xm, peak_y - 1.5 * unit)
			p3 = Vector2(x1 - slot_w * 0.16, peak_y)
		elif kind == 2:
			# Broad cozy cottage roof (smooth silhouette, zero harsh jagged notches)
			p1 = Vector2(x0 + slot_w * 0.18, peak_y + 2.5 * unit)
			p2 = Vector2(xm, peak_y)
			p3 = Vector2(x1 - slot_w * 0.18, peak_y + 2.5 * unit)
		elif kind == 4:
			# Soft rounded storybook belfry cupola
			p1 = Vector2(x0 + slot_w * 0.26, lerpf(wall_y, peak_y, 0.64))
			p2 = Vector2(xm, peak_y)
			p3 = Vector2(x1 - slot_w * 0.26, lerpf(wall_y, peak_y, 0.64))
		else:
			# Gentle pitched gable roof (including kind == 3: Charlie's cozy attic house!)
			p1 = Vector2(x0 + slot_w * 0.22, lerpf(wall_y, peak_y, 0.56))
			p2 = Vector2(xm, peak_y)
			p3 = Vector2(x1 - slot_w * 0.22, lerpf(wall_y, peak_y, 0.56))

		_roof_poly_pts[v_base] = p0
		_roof_poly_pts[v_base + 1] = p1
		_roof_poly_pts[v_base + 2] = p2
		_roof_poly_pts[v_base + 3] = p3
		_roof_poly_pts[v_base + 4] = p4

		# Anchor Charlie's special bedroom attic window with tiny orange lava-lamp Easter egg!
		if kind == 3 and xm > -40.0 and xm < w + 40.0:
			lava_cx = xm
			lava_cy = wall_y + h * 0.026
			_lava_window_screen_pos = Vector2(lava_cx, lava_cy)
			_lava_window_visible = true
		elif win_count < VILLAGE_WINDOW_MAX and xm > -30.0 and xm < w + 30.0:
			# Scatter cozy warm amber lit attic windows across sleeping rooftops
			var flicker: float = 0.88 + 0.12 * sin(_time * (1.2 + float(s_idx) * 0.27) + float(world_slot) * 2.1)
			var win_y: float = wall_y + h * (0.028 if (s_idx % 2 == 0) else 0.042)
			var half_ww: float = (4.4 if (s_idx % 3 != 0) else 5.6) * unit
			_window_pts[win_count * 2] = Vector2(xm - half_ww, win_y)
			_window_pts[win_count * 2 + 1] = Vector2(xm + half_ww, win_y)
			_window_centers[win_count] = Vector2(xm, win_y)
			_window_cols[win_count] = Color(1.08 * flicker, 0.74 * flicker, 0.34 * flicker, 0.84 * alpha)
			win_count += 1
			if win_count < VILLAGE_WINDOW_MAX and (s_idx == 1 or s_idx == 6 or s_idx == 9):
				var w2_y: float = wall_y + h * 0.058
				var w2_x: float = x0 + slot_w * 0.30
				_window_pts[win_count * 2] = Vector2(w2_x - 3.6 * unit, w2_y)
				_window_pts[win_count * 2 + 1] = Vector2(w2_x + 3.6 * unit, w2_y)
				_window_centers[win_count] = Vector2(w2_x, w2_y)
				_window_cols[win_count] = Color(1.02, 0.68, 0.30, 0.74 * alpha)
				win_count += 1

	_city_win_count = win_count
	var rim_count: int = VILLAGE_VISIBLE_SLOTS * 5
	_roof_poly_pts[rim_count] = Vector2(_roof_poly_pts[rim_count - 1].x, h + 24.0)
	_roof_poly_pts[rim_count + 1] = Vector2(_roof_poly_pts[0].x, h + 24.0)

	# Closer misty twilight-indigo rooftop silhouette (NO harsh outline stroke!)
	canvas.draw_colored_polygon(_roof_poly_pts, Color(0.025, 0.045, 0.10, 0.62 * alpha))

	# 3. Soft warm glowing attic window panes in ONE single batched draw_multiline_colors call
	for j: int in range(win_count, VILLAGE_WINDOW_MAX):
		_window_pts[j * 2] = Vector2(-200.0, -200.0)
		_window_pts[j * 2 + 1] = Vector2(-200.0, -200.0)
		_window_cols[j] = Color(0.0, 0.0, 0.0, 0.0)
	canvas.draw_multiline_colors(_window_pts, _window_cols, maxf(5.0 * unit, 3.8), false)

	# 4. Special Easter Egg: Charlie's cozy arched bedroom attic window + tiny orange lava-lamp silhouette!
	if _lava_window_visible:
		var hw: float = lava_w * 0.5
		var hh: float = lava_h * 0.5
		var top_y: float = lava_cy - hh
		var bot_y: float = lava_cy + hh
		# Arched glowing bedroom window (7-point polygon)
		_lava_window_pts[0] = Vector2(lava_cx - hw, bot_y)
		_lava_window_pts[1] = Vector2(lava_cx - hw, top_y + hh * 0.45)
		_lava_window_pts[2] = Vector2(lava_cx - hw * 0.62, top_y + hh * 0.12)
		_lava_window_pts[3] = Vector2(lava_cx, top_y)
		_lava_window_pts[4] = Vector2(lava_cx + hw * 0.62, top_y + hh * 0.12)
		_lava_window_pts[5] = Vector2(lava_cx + hw, top_y + hh * 0.45)
		_lava_window_pts[6] = Vector2(lava_cx + hw, bot_y)
		var warm_pulse: float = 0.94 + 0.06 * sin(_time * 2.1)
		canvas.draw_colored_polygon(_lava_window_pts, Color(1.18 * warm_pulse, 0.82 * warm_pulse, 0.42 * warm_pulse, 0.92 * alpha))

		# Tiny unmistakable lava-lamp silhouette standing on the bedroom windowsill!
		var lamp_x: float = lava_cx
		var sill_y: float = bot_y - 1.0 * unit
		# Tapered dark metallic pedestal base
		_lava_base_pts[0] = Vector2(lamp_x - 3.8 * unit, sill_y)
		_lava_base_pts[1] = Vector2(lamp_x + 3.8 * unit, sill_y)
		_lava_base_pts[2] = Vector2(lamp_x + 2.2 * unit, sill_y - 4.2 * unit)
		_lava_base_pts[3] = Vector2(lamp_x - 2.2 * unit, sill_y - 4.2 * unit)
		canvas.draw_colored_polygon(_lava_base_pts, Color(0.14, 0.07, 0.08, 0.92 * alpha))

		# Glowing molten orange glass chamber (tapered rocket/hourglass vessel)
		var bob: float = sin(_time * 1.9) * 1.4 * unit
		_lava_glass_pts[0] = Vector2(lamp_x - 2.2 * unit, sill_y - 4.2 * unit)
		_lava_glass_pts[1] = Vector2(lamp_x + 2.2 * unit, sill_y - 4.2 * unit)
		_lava_glass_pts[2] = Vector2(lamp_x + 3.6 * unit, sill_y - 8.8 * unit)
		_lava_glass_pts[3] = Vector2(lamp_x + 1.8 * unit, sill_y - 15.2 * unit)
		_lava_glass_pts[4] = Vector2(lamp_x - 1.8 * unit, sill_y - 15.2 * unit)
		_lava_glass_pts[5] = Vector2(lamp_x - 3.6 * unit, sill_y - 8.8 * unit)
		canvas.draw_colored_polygon(_lava_glass_pts, Color(1.26, 0.44, 0.16, 0.94 * alpha))

		# Tiny pointed cap + soft feathered bobbing molten wax glint (zero draw_circle)
		_lava_cap_pts[0] = Vector2(lamp_x - 1.9 * unit, sill_y - 15.1 * unit)
		_lava_cap_pts[1] = Vector2(lamp_x + 1.9 * unit, sill_y - 15.1 * unit)
		_lava_cap_pts[2] = Vector2(lamp_x, sill_y - 18.4 * unit)
		canvas.draw_colored_polygon(_lava_cap_pts, Color(0.16, 0.08, 0.09, 0.92 * alpha))
		if _glow_tex != null:
			var cr: float = 3.6 * unit
			var cy: float = sill_y - 9.4 * unit + bob
			canvas.draw_texture_rect(
				_glow_tex,
				Rect2(lamp_x - cr, cy - cr, cr * 2.0, cr * 2.0),
				false,
				Color(1.30, 0.84, 0.36, 0.92 * alpha)
			)

	# 5. 5 drifting distant warm paper sky-lanterns rendered with soft feathered GradientTexture2D glow
	if _glow_tex != null:
		var wrap_x: float = w + 160.0
		var wrap_y: float = h * 0.78
		for l: int in range(5):
			var lx: float = fposmod(float(l) * (wrap_x * 0.21) + 70.0 - _parallax_offset.x * 0.18 + sin(_time * 0.48 + float(l) * 1.9) * 20.0, wrap_x) - 80.0
			var ly: float = fposmod(float(l) * (wrap_y * 0.23) + 40.0 - _time * (10.5 + float(l) * 1.6) - _parallax_offset.y * 0.14, wrap_y) + h * 0.06
			var l_flick: float = 0.88 + 0.12 * sin(_time * 3.2 + float(l) * 2.4)
			var rx: float = (5.2 + float(l % 2) * 1.6) * unit
			var ry: float = rx * 1.24
			canvas.draw_texture_rect(
				_glow_tex,
				Rect2(lx - rx, ly - ry, rx * 2.0, ry * 2.0),
				false,
				Color(1.16 * l_flick, 0.72 * l_flick, 0.30 * l_flick, 0.76 * alpha)
			)


# --- Scale 4: Planetaire (Curved sapphire Earth horizon limb + 3 razor-crisp tilted orbital ellipses) ---
func _draw_mid_planetary(canvas: Node2D, w: float, h: float, alpha: float) -> void:
	# 1. Monumental curved Earth horizon limb along the lower arc
	var limb_y_center: float = h * 0.835 + clampf(-sin(_parallax_offset.y * 0.0005) * h * 0.014, -12.0, 12.0)
	var limb_drop: float = h * 0.145
	for i: int in range(EARTH_SAMPLES):
		var u: float = float(i) / float(EARTH_SAMPLES - 1)
		var x: float = lerpf(-24.0, w + 24.0, u)
		var c: float = (u - 0.5) * 2.0
		var y: float = limb_y_center + c * c * limb_drop
		_earth_arc_pts[i] = Vector2(x, y)
		_earth_poly_pts[i] = Vector2(x, y)
	_earth_poly_pts[EARTH_SAMPLES] = Vector2(w + 24.0, h + 24.0)
	_earth_poly_pts[EARTH_SAMPLES + 1] = Vector2(-24.0, h + 24.0)

	# Deep planetary night-side disc + sapphire atmospheric scattering band + crisp sunlit HDR rim
	canvas.draw_colored_polygon(_earth_poly_pts, Color(0.010, 0.026, 0.064, 0.92 * alpha))
	canvas.draw_polyline(_earth_arc_pts, Color(0.22, 0.62, 1.0, 0.42 * alpha), 11.0 * (h / 720.0), true)
	canvas.draw_polyline(_earth_arc_pts, Color(0.62, 1.15, 1.40, 0.76 * alpha), 2.4 * (h / 720.0), true)

	# 2. 3 razor-crisp tilted orbital ellipses sweeping across the cosmos
	var s: float = minf(w, h)
	var par: Vector2 = Vector2(
		clampf(-sin(_parallax_offset.x * 0.0006) * 26.0, -26.0, 26.0),
		clampf(-sin(_parallax_offset.y * 0.0006) * 18.0, -18.0, 18.0)
	)
	var center: Vector2 = Vector2(w * 0.5, h * 0.48) + par
	var tilt: float = -0.31
	var ca: float = cos(tilt)
	var sa: float = sin(tilt)

	for k: int in range(3):
		var rx: float = s * PLANET_RX_FRACS[k]
		var ry: float = s * PLANET_RY_FRACS[k]
		for i: int in range(ORBIT_SEGMENTS + 1):
			var theta: float = (float(i) / float(ORBIT_SEGMENTS)) * TAU
			var lx: float = cos(theta) * rx
			var ly: float = sin(theta) * ry
			_orbit_pts[i] = Vector2(center.x + lx * ca - ly * sa, center.y + lx * sa + ly * ca)
		canvas.draw_polyline(_orbit_pts, Color(0.62, 0.90, 1.0, PLANET_OPACITIES[k] * alpha), 1.35, true)


# --- Scale 5: Cosmique (Velvety translucent deep-space nebula mist puffs, zero lines/crosses) ---
func _draw_mid_cosmic(canvas: Node2D, w: float, h: float, alpha: float) -> void:
	if _nebula_puff_tex == null:
		return
	var s: float = minf(w, h)
	var par_x: float = -sin(_parallax_offset.x * 0.00045) * 26.0
	var par_y: float = -sin(_parallax_offset.y * 0.00045) * 18.0

	# 3 ultra-soft translucent deep nebula backdrop clouds (zero hard polygon edges)
	for k: int in range(3):
		var breath: float = 0.94 + 0.06 * sin(_time * (0.28 + float(k) * 0.09) + float(k) * 2.1)
		var drift_x: float = sin(_time * (0.16 + float(k) * 0.05) + float(k) * 1.7) * (w * 0.018)
		var drift_y: float = cos(_time * (0.14 + float(k) * 0.04) + float(k) * 2.4) * (h * 0.014)
		var cx: float = w * COSMIC_PUFF_X[k] + par_x * (0.65 + float(k) * 0.12) + drift_x
		var cy: float = h * COSMIC_PUFF_Y[k] + par_y * (0.65 + float(k) * 0.12) + drift_y
		var rx: float = s * COSMIC_PUFF_RX[k] * 1.08 * breath
		var ry: float = s * COSMIC_PUFF_RY[k] * 1.08 * breath
		var base_c: Color = COSMIC_PUFF_COLS[k]
		var mist_c: Color = Color(base_c.r * 0.55, base_c.g * 0.55, base_c.b * 0.62, 0.14 * alpha)
		canvas.draw_set_transform(Vector2(cx, cy), COSMIC_PUFF_ANG[k], Vector2.ONE)
		canvas.draw_texture_rect(_nebula_puff_tex, Rect2(-rx, -ry, rx * 2.0, ry * 2.0), false, mist_c)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ==============================================================================
# MIDGROUND ADDITIVE (Layer -5, BLEND_MODE_ADD — Light Shafts, Aurora, Nebulae)
# ==============================================================================

func _draw_midground_additive(canvas: Node2D) -> void:
	var w: float = _viewport_size.x
	var h: float = _viewport_size.y
	if w <= 1.0 or h <= 1.0:
		return

	# 1. Diagonal top-left volumetric light shafts (aligned with g_key_light_dir = (-0.52, -0.62))
	_draw_volumetric_light_shafts(canvas, w, h)

	# 2. Per-scale luminous additive depth accents
	if _weights[0] > 0.004 and _glow_tex != null:
		var a0: float = _weights[0]
		var r0: float = minf(w, h) * 0.24
		var p0: Vector2 = Vector2(w * 0.26 + sin(_time * 0.32) * 32.0, h * 0.36 + cos(_time * 0.28) * 20.0)
		var p1: Vector2 = Vector2(w * 0.76 + cos(_time * 0.27) * 30.0, h * 0.64 + sin(_time * 0.34) * 22.0)
		canvas.draw_texture_rect(_glow_tex, Rect2(p0 - Vector2(r0, r0), Vector2(r0 * 2.0, r0 * 2.0)), false, Color(0.28, 0.92, 1.0, 0.14 * a0))
		canvas.draw_texture_rect(_glow_tex, Rect2(p1 - Vector2(r0, r0), Vector2(r0 * 2.0, r0 * 2.0)), false, Color(1.0, 0.80, 0.36, 0.12 * a0))

	if _weights[1] > 0.004 and _glow_tex != null:
		# Luminous specular refraction glints along upper dewdrop meniscus
		var a1: float = _weights[1]
		var rg: Vector2 = Vector2(w * 0.28, h * 0.09)
		var g0: Vector2 = Vector2(w * 0.28 + sin(_time * 0.6) * 26.0, h * 0.085)
		var g1: Vector2 = Vector2(w * 0.62 + cos(_time * 0.5) * 22.0, h * 0.075)
		canvas.draw_texture_rect(_glow_tex, Rect2(g0 - rg * 0.5, rg), false, Color(0.56, 1.12, 1.04, 0.22 * a1))
		canvas.draw_texture_rect(_glow_tex, Rect2(g1 - rg * 0.4, rg * 0.8), false, Color(0.42, 1.02, 0.92, 0.16 * a1))

	if _weights[2] > 0.004 and _glow_tex != null:
		# Misty moonlit emerald clearing backlight + soft golden-emerald firefly bokeh blooms
		var a2: float = _weights[2]
		var s2: float = minf(w, h)
		var clear_r: Vector2 = Vector2(w * 0.52, h * 0.44)
		var clear_c: Vector2 = Vector2(w * 0.48, h * 0.44)
		canvas.draw_texture_rect(_glow_tex, Rect2(clear_c - clear_r * 0.5, clear_r), false, Color(0.18, 0.78, 0.46, 0.15 * a2))
		if _bokeh_tex != null:
			var par_f: Vector2 = Vector2(
				-sin(_parallax_offset.x * 0.0007) * 24.0,
				-sin(_parallax_offset.y * 0.0007) * 16.0
			)
			for f: int in range(4):
				var fx_frac: float = 0.16 if (f == 0) else (0.84 if (f == 1) else (0.24 if (f == 2) else 0.78))
				var fy_frac: float = 0.66 if (f == 0) else (0.62 if (f == 1) else (0.34 if (f == 2) else 0.74))
				var pulse: float = 0.62 + 0.38 * sin(_time * (1.25 + float(f) * 0.32) + float(f) * 2.1)
				var fpos: Vector2 = Vector2(
					w * fx_frac + par_f.x + sin(_time * (0.48 + float(f) * 0.12) + float(f) * 1.6) * (w * 0.025),
					h * fy_frac + par_f.y + cos(_time * (0.42 + float(f) * 0.14) + float(f) * 2.2) * (h * 0.022)
				)
				var fr: float = s2 * (0.038 + float(f % 2) * 0.014) * (0.90 + 0.10 * pulse)
				var fcol: Color = (
					Color(1.06, 0.88, 0.34, 0.22 * pulse * a2) if (f % 2 == 0)
					else Color(0.38, 0.98, 0.58, 0.20 * pulse * a2)
				)
				canvas.draw_texture_rect(_bokeh_tex, Rect2(fpos.x - fr, fpos.y - fr, fr * 2.0, fr * 2.0), false, fcol)

	if _weights[3] > 0.004 and _glow_tex != null:
		# Subtle warm radial glow halos around sleeping village windows + sky-lanterns + Charlie's lava-lamp attic
		var a3: float = _weights[3]
		var unit: float = h / 720.0
		var win_r: float = 19.0 * unit
		for wi: int in range(_city_win_count):
			var wp: Vector2 = _window_centers[wi]
			var wf: float = 0.88 + 0.12 * sin(_time * 1.5 + float(wi) * 1.9)
			canvas.draw_texture_rect(
				_glow_tex,
				Rect2(wp.x - win_r, wp.y - win_r, win_r * 2.0, win_r * 2.0),
				false,
				Color(1.08 * wf, 0.64 * wf, 0.24 * wf, 0.22 * a3)
			)
		var wrap_x: float = w + 160.0
		var wrap_y: float = h * 0.78
		for l: int in range(5):
			var lx: float = fposmod(float(l) * (wrap_x * 0.21) + 70.0 - _parallax_offset.x * 0.18 + sin(_time * 0.48 + float(l) * 1.9) * 20.0, wrap_x) - 80.0
			var ly: float = fposmod(float(l) * (wrap_y * 0.23) + 40.0 - _time * (10.5 + float(l) * 1.6) - _parallax_offset.y * 0.14, wrap_y) + h * 0.06
			var hr: float = (26.0 + float(l % 2) * 8.0) * unit
			canvas.draw_texture_rect(_glow_tex, Rect2(lx - hr, ly - hr, hr * 2.0, hr * 2.0), false, Color(1.12, 0.66, 0.24, 0.30 * a3))
		if _lava_window_visible:
			var wr: float = 52.0 * unit
			canvas.draw_texture_rect(
				_glow_tex,
				Rect2(_lava_window_screen_pos.x - wr, _lava_window_screen_pos.y - wr, wr * 2.0, wr * 2.0),
				false,
				Color(1.18, 0.62, 0.24, 0.34 * a3)
			)

	if _weights[4] > 0.004:
		_draw_mid_planetary_aurora(canvas, w, h, _weights[4])

	if _weights[5] > 0.004:
		_draw_mid_cosmic_nebula_veils(canvas, w, h, _weights[5])


func _draw_volumetric_light_shafts(canvas: Node2D, w: float, h: float) -> void:
	if _shaft_tex == null:
		return

	# Scale-specific shaft intensity & color harmoniously blended across crossfades
	var shaft_tint: Color = (
		Color(0.36, 0.94, 0.98, 0.08) * _weights[0]
		+ Color(0.42, 0.95, 0.86, 0.13) * _weights[1]
		+ Color(0.56, 0.94, 0.68, 0.14) * _weights[2]
		+ Color(0.62, 0.78, 1.00, 0.07) * _weights[3]
		+ Color(0.44, 0.80, 1.00, 0.05) * _weights[4]
		+ Color(1.00, 0.74, 0.82, 0.07) * _weights[5]
	)
	if shaft_tint.a <= 0.005:
		return

	var diag_len: float = sqrt(w * w + h * h) * 0.88
	var par_shift: float = -sin(_parallax_offset.x * 0.00055) * w * 0.045

	for i: int in range(3):
		var breath: float = 0.78 + 0.22 * sin(_time * (0.42 + float(i) * 0.15) + float(i) * 2.1)
		var sway_x: float = sin(_time * (0.28 + float(i) * 0.09) + float(i) * 1.4) * (w * 0.018)
		var origin: Vector2 = Vector2(w * SHAFT_ANCHOR_XS[i] + sway_x + par_shift, -h * 0.10)
		var bw: float = w * SHAFT_WIDTHS[i] * (0.94 + 0.06 * breath)
		var bl: float = diag_len * (0.92 + float(i % 2) * 0.12)
		var col: Color = Color(shaft_tint.r, shaft_tint.g, shaft_tint.b, shaft_tint.a * breath)

		canvas.draw_set_transform(origin, SHAFT_ROTATION, Vector2.ONE)
		canvas.draw_texture_rect(_shaft_tex, Rect2(-bw * 0.5, 0.0, bw, bl), false, col)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_mid_planetary_aurora(canvas: Node2D, w: float, h: float, alpha: float) -> void:
	# 1. Soft sapphire horizon atmospheric bloom along Earth limb
	if _glow_tex != null:
		var limb_r: Vector2 = Vector2(w * 1.18, h * 0.34)
		var limb_c: Vector2 = Vector2(w * 0.50, h * 0.88)
		canvas.draw_texture_rect(_glow_tex, Rect2(limb_c - limb_r * 0.5, limb_r), false, Color(0.24, 0.66, 1.18, 0.30 * alpha))

	# 2. Shimmering emerald-violet aurora veil dancing gracefully above Earth's curved limb
	var limb_base_y: float = h * 0.835 + clampf(-sin(_parallax_offset.y * 0.0005) * h * 0.014, -12.0, 12.0)
	var limb_drop: float = h * 0.145
	var par_ph: float = _parallax_offset.x * 0.0009
	for i: int in range(AURORA_STEPS):
		var u: float = float(i) / float(AURORA_STEPS - 1)
		var screen_u: float = lerpf(0.14, 0.88, u)
		var x: float = screen_u * w
		var c: float = (screen_u - 0.5) * 2.0
		var limb_y: float = limb_base_y + c * c * limb_drop
		var env: float = sin(u * PI)
		var curtain_wave: float = (sin(u * TAU * 1.8 + _time * 0.68 + par_ph) * (h * 0.018) + cos(u * TAU * 3.1 - _time * 0.44) * (h * 0.010)) * env
		var curtain_h: float = h * (0.022 + (0.115 + 0.042 * sin(u * PI * 2.0 + _time * 0.55)) * env)
		var shimmer: float = 0.72 + 0.28 * sin(u * 9.0 + _time * 1.35)

		var bot_y: float = limb_y - h * 0.006 + curtain_wave * 0.30
		var top_y: float = bot_y - curtain_h + curtain_wave * 0.70

		# Emerald-mint lower curtain blending upward into ethereal cosmic violet (strictly top_y < bot_y)
		var col_top: Color = Color(0.62, 0.38, 1.08, 0.0)
		var col_bot: Color = Color(
			lerpf(0.20, 0.56, u),
			lerpf(0.98, 0.52, u * 0.85),
			lerpf(0.68, 1.12, u),
			0.28 * alpha * env * shimmer
		)

		_aurora_pts[i] = Vector2(x, minf(top_y, bot_y - 4.0))
		_aurora_cols[i] = col_top
		var rev: int = AURORA_STEPS * 2 - 1 - i
		_aurora_pts[rev] = Vector2(x, bot_y)
		_aurora_cols[rev] = col_bot
	canvas.draw_polygon(_aurora_pts, _aurora_cols)


func _draw_mid_cosmic_nebula_veils(canvas: Node2D, w: float, h: float, alpha: float) -> void:
	# 7 large, ultra-soft feathered radial nebula mist puffs (rose-magenta, deep cyan, warm honey-gold, alpha 0.12-0.20)
	if _nebula_puff_tex == null:
		return
	var s: float = minf(w, h)
	var par_x: float = -sin(_parallax_offset.x * 0.0005) * 32.0
	var par_y: float = -sin(_parallax_offset.y * 0.0005) * 20.0

	for k: int in range(COSMIC_PUFF_X.size()):
		var breath: float = 0.90 + 0.10 * sin(_time * (0.24 + float(k) * 0.06) + float(k) * 1.9)
		var drift_x: float = sin(_time * (0.14 + float(k) * 0.03) + float(k) * 1.3) * (w * 0.022)
		var drift_y: float = cos(_time * (0.12 + float(k) * 0.035) + float(k) * 2.1) * (h * 0.018)
		var cx: float = w * COSMIC_PUFF_X[k] + par_x * (0.55 + float(k % 3) * 0.18) + drift_x
		var cy: float = h * COSMIC_PUFF_Y[k] + par_y * (0.55 + float(k % 3) * 0.18) + drift_y
		var rx: float = s * COSMIC_PUFF_RX[k] * (0.96 + 0.04 * breath)
		var ry: float = s * COSMIC_PUFF_RY[k] * (0.96 + 0.04 * breath)
		var ang: float = COSMIC_PUFF_ANG[k] + sin(_time * 0.08 + float(k)) * 0.05
		var base_c: Color = COSMIC_PUFF_COLS[k]
		var puff_col: Color = Color(base_c.r, base_c.g, base_c.b, base_c.a * breath * alpha)
		canvas.draw_set_transform(Vector2(cx, cy), ang, Vector2.ONE)
		canvas.draw_texture_rect(_nebula_puff_tex, Rect2(-rx, -ry, rx * 2.0, ry * 2.0), false, puff_col)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ==============================================================================
# FOREGROUND SILHOUETTES (Layer +4, Parallax 1.42x, Feathered Outer-Corner Bokeh ONLY)
# ==============================================================================

func _draw_foreground_silhouettes(canvas: Node2D) -> void:
	var w: float = _viewport_size.x
	var h: float = _viewport_size.y
	if w <= 1.0 or h <= 1.0:
		return

	# Scale 1 (Microscopique): soft feathered water-droplet bokeh tucked into the 4 outer corners
	if _weights[1] > 0.004:
		_draw_fg_micro_droplets(canvas, w, h, _weights[1])

	# Scale 2 (Sous-Bois): soft out-of-focus feathered foliage puffs tucked into the 4 outer corners
	if _weights[2] > 0.004:
		_draw_fg_forest_foliage(canvas, w, h, _weights[2])

	# Scale 3 (Ville Endormie): soft feathered radial sky-lantern bokeh strictly in the 4 outer corners
	if _weights[3] > 0.004:
		_draw_fg_city_lanterns(canvas, w, h, _weights[3])


func _draw_fg_micro_droplets(canvas: Node2D, w: float, h: float, alpha: float) -> void:
	# 4 soft feathered GradientTexture2D water droplets strictly confined to the 4 outer corners (zero draw_circle)
	if _bokeh_tex == null:
		return
	var s: float = minf(w, h)
	var par_x: float = -sin(_parallax_offset.x * 0.0010 * FG_PARALLAX) * (w * 0.022)
	var par_y: float = -sin(_parallax_offset.y * 0.0010 * FG_PARALLAX) * (h * 0.024)

	for i: int in range(4):
		var ph: float = float(i) * 1.9
		var px: float = w * FG_DROPLET_XS[i] + par_x + sin(_time * (0.62 + float(i) * 0.14) + ph) * (w * 0.014)
		var py: float = h * FG_DROPLET_YS[i] + par_y + cos(_time * (0.54 + float(i) * 0.12) + ph) * (h * 0.018)
		var r: float = s * FG_DROPLET_RADS[i] * (0.94 + 0.06 * sin(_time * 1.1 + ph))
		canvas.draw_texture_rect(
			_bokeh_tex,
			Rect2(px - r, py - r, r * 2.0, r * 2.0),
			false,
			Color(0.44, 0.96, 0.92, 0.18 * alpha)
		)
		if _glow_tex != null:
			var sr: float = r * 0.44
			var sx: float = px - r * 0.24
			var sy: float = py - r * 0.24
			canvas.draw_texture_rect(
				_glow_tex,
				Rect2(sx - sr, sy - sr, sr * 2.0, sr * 2.0),
				false,
				Color(0.84, 1.08, 1.04, 0.22 * alpha)
			)


func _draw_fg_forest_foliage(canvas: Node2D, w: float, h: float, alpha: float) -> void:
	# 4 ultra-soft out-of-focus feathered foliage puffs tucked softly in the 4 outer corners (zero spiky ferns)
	if _leaf_puff_tex == null:
		return
	var s: float = minf(w, h)
	var par_x: float = -sin(_parallax_offset.x * 0.00095 * FG_PARALLAX) * (w * 0.024)
	var par_y: float = -sin(_parallax_offset.y * 0.00095 * FG_PARALLAX) * (h * 0.020)

	for i: int in range(4):
		var ph: float = float(i) * 1.7
		var sway: float = sin(_time * (0.78 + float(i) * 0.16) + ph)
		var fx: float = w * FG_FOLIAGE_XS[i] + par_x + sway * (w * 0.012)
		var fy: float = h * FG_FOLIAGE_YS[i] + par_y + cos(_time * 0.66 + ph) * (h * 0.010)
		var rx: float = s * FG_FOLIAGE_RADS[i]
		var ry: float = rx * 0.62
		var ang: float = FG_FOLIAGE_ANGS[i] + sway * 0.06
		canvas.draw_set_transform(Vector2(fx, fy), ang, Vector2.ONE)
		canvas.draw_texture_rect(
			_leaf_puff_tex,
			Rect2(-rx, -ry, rx * 2.0, ry * 2.0),
			false,
			Color(0.018, 0.095, 0.072, 0.22 * alpha)
		)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_fg_city_lanterns(canvas: Node2D, w: float, h: float, alpha: float) -> void:
	# 4 soft feathered radial GradientTexture2D lantern bokeh orbs tucked strictly in outer corners (zero draw_circle)
	if _bokeh_tex == null:
		return
	var s: float = minf(w, h)
	var par_x: float = -sin(_parallax_offset.x * 0.0010 * FG_PARALLAX) * (w * 0.022)
	var par_y: float = -sin(_parallax_offset.y * 0.0010 * FG_PARALLAX) * (h * 0.024)

	for i: int in range(4):
		var ph: float = float(i) * 2.05
		var lx: float = w * FG_LANTERN_XS[i] + par_x + sin(_time * (0.58 + float(i) * 0.12) + ph) * (w * 0.015)
		var ly: float = h * FG_LANTERN_YS[i] + par_y + cos(_time * (0.50 + float(i) * 0.11) + ph) * (h * 0.022)
		var r: float = s * FG_LANTERN_RADS[i]
		var flick: float = 0.88 + 0.12 * sin(_time * (2.2 + float(i) * 0.4) + ph)
		canvas.draw_texture_rect(
			_bokeh_tex,
			Rect2(lx - r, ly - r, r * 2.0, r * 2.0),
			false,
			Color(1.04 * flick, 0.62 * flick, 0.24 * flick, 0.20 * alpha)
		)
		if _glow_tex != null:
			var hr: float = r * 0.56
			canvas.draw_texture_rect(
				_glow_tex,
				Rect2(lx - hr, ly - hr, hr * 2.0, hr * 2.0),
				false,
				Color(1.08 * flick, 0.78 * flick, 0.36 * flick, 0.18 * alpha)
			)


# ==============================================================================
# FOREGROUND ADDITIVE (Layer +4, Parallax 1.42x — Soft Outer-Corner Bokeh & Wisps)
# ==============================================================================

func _draw_foreground_additive(canvas: Node2D) -> void:
	var w: float = _viewport_size.x
	var h: float = _viewport_size.y
	if w <= 1.0 or h <= 1.0 or _bokeh_tex == null:
		return

	var s: float = minf(w, h)

	# Scale-responsive foreground bokeh palette (subtle translucent alpha 0.16-0.25)
	var primary_col: Color = (
		Color(0.36, 0.94, 1.00, 0.20) * _weights[0]
		+ Color(0.48, 1.02, 0.94, 0.20) * _weights[1]
		+ Color(1.04, 0.88, 0.34, 0.24) * _weights[2]
		+ Color(1.06, 0.66, 0.26, 0.24) * _weights[3]
		+ Color(0.54, 0.86, 1.04, 0.19) * _weights[4]
		+ Color(1.00, 0.52, 0.82, 0.21) * _weights[5]
	)
	var secondary_col: Color = (
		Color(1.02, 0.84, 0.42, 0.18) * _weights[0]
		+ Color(0.72, 1.04, 0.98, 0.18) * _weights[1]
		+ Color(0.38, 0.98, 0.58, 0.22) * _weights[2]
		+ Color(1.06, 0.80, 0.40, 0.22) * _weights[3]
		+ Color(1.02, 0.88, 0.54, 0.17) * _weights[4]
		+ Color(0.34, 0.90, 1.04, 0.20) * _weights[5]
	)
	# Subtle harmonious infusion from runtime palette
	primary_col = primary_col.lerp(Color(_col_mote.r, _col_mote.g, _col_mote.b, primary_col.a), 0.18)

	# 8 soft feathered GradientTexture2D bokeh orbs strictly confined to the 4 outer corners
	var par_x: float = -sin(_parallax_offset.x * 0.00105 * FG_PARALLAX) * (w * 0.028)
	var par_y: float = -sin(_parallax_offset.y * 0.00105 * FG_PARALLAX) * (h * 0.028)
	for i: int in range(FG_BOKEH_COUNT):
		var ph: float = _bokeh_phase[i]
		var px: float = w * _bokeh_corner_x[i] + par_x + sin(_time * (0.44 + float(i) * 0.07) + ph) * (w * 0.022)
		var py: float = h * _bokeh_corner_y[i] + par_y + cos(_time * (0.50 + float(i) * 0.06) + ph) * (h * 0.024)

		# Strict radial corner-clearance envelope: ensures foreground bokeh stays strictly in the outer corners
		var dx_c: float = absf(px / w - 0.5)
		var dy_c: float = absf(py / h - 0.5)
		var corner_r: float = sqrt(dx_c * dx_c + dy_c * dy_c)
		var corner_clear: float = clampf((corner_r - 0.40) / 0.14, 0.0, 1.0)
		if corner_clear <= 0.004:
			continue

		var pulse: float = 0.74 + 0.26 * sin(_time * (1.02 + float(i) * 0.14) + ph * 2.0)
		var r: float = s * _bokeh_size[i] * (0.94 + 0.06 * pulse)
		var col: Color = primary_col.lerp(secondary_col, _bokeh_hue_pick[i])
		col.a = clampf(col.a * pulse * corner_clear, 0.0, 0.26)
		canvas.draw_texture_rect(_bokeh_tex, Rect2(px - r, py - r, r * 2.0, r * 2.0), false, col)

	# Gossamer translucent nebula / high-altitude cloud wisps softly tucked into outer corners (Scales 0, 4, 5)
	var wisp_w: float = _weights[4] + _weights[5] + _weights[0] * 0.45
	if wisp_w > 0.008 and _wisp_tex != null:
		var wisp_col_a: Color = (
			Color(0.32, 0.88, 1.00, 0.12) * _weights[0]
			+ Color(0.42, 0.78, 1.04, 0.15) * _weights[4]
			+ Color(0.98, 0.46, 0.80, 0.16) * _weights[5]
		)
		var wisp_col_b: Color = (
			Color(1.00, 0.82, 0.40, 0.11) * _weights[0]
			+ Color(0.56, 0.92, 1.02, 0.14) * _weights[4]
			+ Color(0.32, 0.88, 1.02, 0.15) * _weights[5]
		)
		var ww: float = s * 0.56
		var wh: float = s * 0.16
		var x_tl: float = w * 0.14 + par_x * 0.9 + sin(_time * 0.24) * (w * 0.03)
		var x_br: float = w * 0.86 + par_x * 0.9 - cos(_time * 0.22) * (w * 0.03)
		canvas.draw_texture_rect(_wisp_tex, Rect2(x_tl - ww * 0.5, h * 0.06 - wh * 0.5, ww, wh), false, wisp_col_a)
		canvas.draw_texture_rect(_wisp_tex, Rect2(x_br - ww * 0.5, h * 0.94 - wh * 0.5, ww, wh), false, wisp_col_b)
