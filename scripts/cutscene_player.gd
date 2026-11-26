class_name CutscenePlayer
extends CanvasLayer
## Studio-grade Miyazaki storybook cutscene player with 16 unique hand-painted
## scenes across 7 chapters, Fraunces & Outfit variable typography, bounded
## Ken Burns framing (16:9 to 21:9), smooth crossfades, and live 60 FPS
## procedural atmospheric overlays.

const FONT_DISPLAY_PATH: String = "res://assets/fonts/Fraunces.ttf"
const FONT_UI_PATH: String = "res://assets/fonts/Outfit.ttf"

const ART_INTRO_WINDOW: String = "res://assets/art/scene-intro-window.jpg"
const ART_CHARLIE: String = "res://assets/art/charlie-portrait.jpg"
const ART_INTRO_PLUNGE: String = "res://assets/art/scene-intro-plunge.jpg"
const ART_QUANTUM_BREAK: String = "res://assets/art/scene-quantum-break.jpg"
const ART_MICRO: String = "res://assets/art/cutscene-micro.jpg"
const ART_FOREST: String = "res://assets/art/cutscene-forest.jpg"
const ART_FOREST_FRIENDS: String = "res://assets/art/scene-forest-friends.jpg"
const ART_CITY_RISE: String = "res://assets/art/scene-city-rise.jpg"
const ART_CITY: String = "res://assets/art/cutscene-city.jpg"
const ART_PLANETS: String = "res://assets/art/cutscene-planets.jpg"
const ART_PLANETARY_DANCE: String = "res://assets/art/scene-planetary-dance.jpg"
const ART_NEBULA_GLIDE: String = "res://assets/art/scene-nebula-glide.jpg"
const ART_STAR_CALL: String = "res://assets/art/scene-star-call.jpg"
const ART_COSMOS: String = "res://assets/art/cutscene-cosmos.jpg"
const ART_LANDSCAPE: String = "res://assets/art/keyart-landscape.jpg"
const ART_GOODNIGHT_WINDOW: String = "res://assets/art/scene-goodnight-window.jpg"

const ALL_ART_PATHS: Array[String] = [
	ART_INTRO_WINDOW,
	ART_CHARLIE,
	ART_INTRO_PLUNGE,
	ART_QUANTUM_BREAK,
	ART_MICRO,
	ART_FOREST,
	ART_FOREST_FRIENDS,
	ART_CITY_RISE,
	ART_CITY,
	ART_PLANETS,
	ART_PLANETARY_DANCE,
	ART_NEBULA_GLIDE,
	ART_STAR_CALL,
	ART_COSMOS,
	ART_LANDSCAPE,
	ART_GOODNIGHT_WINDOW,
]

const TAP_GUARD_SECONDS: float = 0.35
const CROSSFADE_SECONDS: float = 0.55
const KEN_BURNS_DURATION: float = 7.5
const BG_MIDNIGHT: Color = Color(0.016, 0.031, 0.067, 1.0)
const BG_PORTRAIT_TEAL: Color = Color(0.004, 0.096, 0.135, 1.0)

# Exact 7-chapter / 16-slide Miyazaki storybook arc — 16 unique paintings, zero repeats.
const CUTSCENES: Dictionary = {
	"intro": {
		"chapter": "PROLOGUE · LA FENÊTRE",
		"slides": [
			{
				"chapter": "PROLOGUE · LA FENÊTRE",
				"art": ART_INTRO_WINDOW,
				"fx": "window",
				"text": "Une nuit calme, une vieille lampe à lave brillait doucement près de la fenêtre… Dehors, une étoile solitaire scintillait très haut.",
				"zoom_from": 1.02, "zoom_to": 1.065,
				"pan_from": Vector2(0.0, 0.008), "pan_to": Vector2(0.0, -0.012),
			},
			{
				"chapter": "PROLOGUE · LA PETITE CHARLIE",
				"art": ART_CHARLIE,
				"fx": "quantum",
				"text": "Tout au fond de la lampe, une minuscule goutte curieuse s'éveilla. C'était la petite Charlie. Elle voulut aller saluer l'étoile.",
				"zoom_from": 1.02, "zoom_to": 1.07,
				"pan_from": Vector2(0.0, 0.004), "pan_to": Vector2(0.0, -0.006),
			},
			{
				"chapter": "PROLOGUE · LE GRAND PLONGEON",
				"art": ART_INTRO_PLUNGE,
				"fx": "quantum",
				"text": "Mais Charlie était encore si petite… Pour grandir jusqu'au ciel, son voyage devait commencer dans l'infiniment petit.",
				"zoom_from": 1.02, "zoom_to": 1.07,
				"pan_from": Vector2(0.0, -0.008), "pan_to": Vector2(0.0, 0.012),
			},
		],
	},
	"scale_1": {
		"chapter": "CHAPITRE II · L'ÉVEIL",
		"slides": [
			{
				"chapter": "CHAPITRE II · L'ÉVEIL",
				"art": ART_QUANTUM_BREAK,
				"fx": "quantum",
				"text": "Les atomes s'effacent dans un frisson lumineux. La petite Charlie vient de grandir d'un coup !",
				"zoom_from": 1.02, "zoom_to": 1.065,
				"pan_from": Vector2(0.012, 0.0), "pan_to": Vector2(-0.012, 0.0),
			},
			{
				"chapter": "CHAPITRE II · LA GOUTTE D'EAU",
				"art": ART_MICRO,
				"fx": "micro",
				"text": "Autour d'elle s'ouvre tout un océan caché dans une goutte d'eau… Encore un peu, Charlie !",
				"zoom_from": 1.02, "zoom_to": 1.065,
				"pan_from": Vector2(0.010, 0.006), "pan_to": Vector2(-0.010, -0.008),
			},
		],
	},
	"scale_2": {
		"chapter": "CHAPITRE III · PLOUF !",
		"slides": [
			{
				"chapter": "CHAPITRE III · PLOUF !",
				"art": ART_FOREST,
				"fx": "forest",
				"text": "Plouf ! Charlie perce enfin la surface de la goutte de rosée et sent la brise fraîche de la nuit.",
				"zoom_from": 1.02, "zoom_to": 1.065,
				"pan_from": Vector2(0.0, 0.010), "pan_to": Vector2(0.0, -0.010),
			},
			{
				"chapter": "CHAPITRE III · LE SOUS-BOIS",
				"art": ART_FOREST_FRIENDS,
				"fx": "forest",
				"text": "Les lucioles et les coccinelles l'accompagnent. Tout là-haut, son étoile brille déjà plus fort !",
				"zoom_from": 1.02, "zoom_to": 1.065,
				"pan_from": Vector2(0.010, 0.006), "pan_to": Vector2(-0.010, -0.006),
			},
		],
	},
	"scale_3": {
		"chapter": "CHAPITRE IV · AU-DESSUS DES ARBRES",
		"slides": [
			{
				"chapter": "CHAPITRE IV · AU-DESSUS DES ARBRES",
				"art": ART_CITY_RISE,
				"fx": "city",
				"text": "Charlie s'élève au-dessus de la forêt. Des lanternes tièdes montent dans la nuit comme de petits amis.",
				"zoom_from": 1.02, "zoom_to": 1.07,
				"pan_from": Vector2(0.0, 0.012), "pan_to": Vector2(0.0, -0.012),
			},
			{
				"chapter": "CHAPITRE IV · LA VILLE ENDORMIE",
				"art": ART_CITY,
				"fx": "city",
				"text": "Chouettes, voitures et grands dirigeables croisent sa route… Le ciel devient immense !",
				"zoom_from": 1.02, "zoom_to": 1.065,
				"pan_from": Vector2(0.012, 0.004), "pan_to": Vector2(-0.012, -0.004),
			},
		],
	},
	"scale_4": {
		"chapter": "CHAPITRE V · LES NUAGES",
		"slides": [
			{
				"chapter": "CHAPITRE V · LES NUAGES",
				"art": ART_PLANETS,
				"fx": "planets",
				"text": "Charlie traverse les nuages et quitte doucement la Terre bleue. Tout devient silencieux et scintillant.",
				"zoom_from": 1.02, "zoom_to": 1.065,
				"pan_from": Vector2(0.0, 0.010), "pan_to": Vector2(0.0, -0.010),
			},
			{
				"chapter": "CHAPITRE V · LE BALLET ORBITAL",
				"art": ART_PLANETARY_DANCE,
				"fx": "planets",
				"text": "Les lunes et les planètes dansent autour d'elle. Charlie n'a jamais été aussi proche de son étoile.",
				"zoom_from": 1.02, "zoom_to": 1.07,
				"pan_from": Vector2(0.012, 0.0), "pan_to": Vector2(-0.012, 0.0),
			},
		],
	},
	"scale_5": {
		"chapter": "CHAPITRE VI · LES NÉBULEUSES",
		"slides": [
			{
				"chapter": "CHAPITRE VI · LES NÉBULEUSES",
				"art": ART_NEBULA_GLIDE,
				"fx": "cosmos",
				"text": "Charlie glisse au cœur des nébuleuses colorées, aussi lumineuse qu'un petit soleil.",
				"zoom_from": 1.02, "zoom_to": 1.07,
				"pan_from": Vector2(0.012, 0.0), "pan_to": Vector2(-0.012, 0.0),
			},
			{
				"chapter": "CHAPITRE VI · L'APPEL DE L'ÉTOILE",
				"art": ART_STAR_CALL,
				"fx": "cosmos",
				"text": "Tout au bout du ciel, l'étoile qui l'appelait depuis sa chambre l'attend enfin…",
				"zoom_from": 1.02, "zoom_to": 1.065,
				"pan_from": Vector2(0.010, 0.0), "pan_to": Vector2(-0.010, 0.0),
			},
		],
	},
	"victory": {
		"chapter": "FINALE · LES RETROUVAILLES",
		"slides": [
			{
				"chapter": "FINALE · LES RETROUVAILLES",
				"art": ART_COSMOS,
				"fx": "cosmos",
				"text": "La petite Charlie rejoint enfin l'étoile solitaire. Leurs deux lumières s'enlacent dans un tourbillon tout doux.",
				"zoom_from": 1.02, "zoom_to": 1.07,
				"pan_from": Vector2(0.0, 0.0), "pan_to": Vector2(0.0, 0.0),
			},
			{
				"chapter": "FINALE · UNE LUMIÈRE DANS LA NUIT",
				"art": ART_LANDSCAPE,
				"fx": "forest",
				"text": "Devenue immense et lumineuse, Charlie éclaire désormais toute la nuit comme une grande lampe à lave céleste.",
				"zoom_from": 1.02, "zoom_to": 1.07,
				"pan_from": Vector2(0.014, 0.0), "pan_to": Vector2(-0.014, 0.0),
			},
			{
				"chapter": "FINALE · BONNE NUIT, CHARLIE",
				"art": ART_GOODNIGHT_WINDOW,
				"fx": "goodnight",
				"text": "Et depuis la fenêtre de la chambre endormie, on peut toujours voir la petite Charlie cligner de l'œil parmi les étoiles.",
				"zoom_from": 1.07, "zoom_to": 1.02,
				"pan_from": Vector2(0.0, -0.008), "pan_to": Vector2(0.0, 0.006),
			},
		],
	},
}


class _AtmosphereOverlay extends Control:
	## Lightweight 60 FPS procedural atmosphere painted directly over each
	## Miyazaki illustration using a single 64x64 radial glow texture and
	## crisp 4-point diamond stars (zero per-frame heap allocations).

	var fx_tag: String = "quantum"
	var elapsed: float = 0.0
	var glow_tex: GradientTexture2D = null

	var _star_pts: PackedVector2Array = PackedVector2Array()
	var _shaft_pts: PackedVector2Array = PackedVector2Array()
	var _shaft_cols: PackedColorArray = PackedColorArray()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_star_pts.resize(8)
		_shaft_pts.resize(4)
		_shaft_cols.resize(4)
		_glow_init()

	func _glow_init() -> void:
		var grad: Gradient = Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.26, 0.62, 1.0])
		grad.colors = PackedColorArray([
			Color(1.0, 1.0, 1.0, 1.0),
			Color(1.0, 1.0, 1.0, 0.58),
			Color(1.0, 1.0, 1.0, 0.14),
			Color(1.0, 1.0, 1.0, 0.0),
		])
		glow_tex = GradientTexture2D.new()
		glow_tex.width = 64
		glow_tex.height = 64
		glow_tex.fill = GradientTexture2D.FILL_RADIAL
		glow_tex.fill_from = Vector2(0.5, 0.5)
		glow_tex.fill_to = Vector2(1.0, 0.5)
		glow_tex.gradient = grad

	func set_fx(tag: String, start_time: float = 0.0) -> void:
		fx_tag = tag
		elapsed = start_time
		queue_redraw()

	func step(delta: float) -> void:
		elapsed += delta
		queue_redraw()

	func _hash(n: float) -> float:
		return fposmod(sin(n * 127.1 + 311.7) * 43758.5453, 1.0)

	func _draw_glow(pos: Vector2, radius: float, color: Color) -> void:
		if glow_tex == null or radius <= 0.5 or color.a <= 0.003:
			return
		var rect: Rect2 = Rect2(pos.x - radius, pos.y - radius, radius * 2.0, radius * 2.0)
		draw_texture_rect(glow_tex, rect, false, color)

	func _draw_sparkle4(pos: Vector2, radius: float, color: Color, halo_mult: float = 0.34) -> void:
		if radius <= 0.5 or color.a <= 0.005:
			return
		if halo_mult > 0.0:
			_draw_glow(pos, radius * 2.4, Color(color.r, color.g, color.b, color.a * halo_mult))
		var waist: float = radius * 0.19
		_star_pts[0] = Vector2(pos.x, pos.y - radius)
		_star_pts[1] = Vector2(pos.x + waist, pos.y - waist)
		_star_pts[2] = Vector2(pos.x + radius, pos.y)
		_star_pts[3] = Vector2(pos.x + waist, pos.y + waist)
		_star_pts[4] = Vector2(pos.x, pos.y + radius)
		_star_pts[5] = Vector2(pos.x - waist, pos.y + waist)
		_star_pts[6] = Vector2(pos.x - radius, pos.y)
		_star_pts[7] = Vector2(pos.x - waist, pos.y - waist)
		draw_colored_polygon(_star_pts, color)
		draw_circle(pos, maxf(0.8, radius * 0.16), Color(1.0, 0.99, 0.95, minf(1.0, color.a * 1.15)))

	func _draw_shooting_star(
		from_pt: Vector2,
		to_pt: Vector2,
		progress: float,
		tail_len: float,
		head_color: Color,
		tail_color: Color
	) -> void:
		var p: float = clampf(progress, 0.0, 1.0)
		var env: float = sin(p * PI)
		if env <= 0.01:
			return
		var head: Vector2 = from_pt.lerp(to_pt, p)
		var dir: Vector2 = (to_pt - from_pt).normalized()
		var segs: int = 6
		for s in range(segs):
			var t0: float = float(s) / float(segs)
			var t1: float = float(s + 1) / float(segs)
			var p0: Vector2 = head - dir * (tail_len * t0)
			var p1: Vector2 = head - dir * (tail_len * t1)
			var seg_col: Color = head_color.lerp(tail_color, t1)
			seg_col.a *= env * (1.0 - t0 * 0.78)
			var width: float = lerpf(2.8, 0.75, t0)
			draw_line(p0, p1, seg_col, width, true)
		var star_col: Color = Color(head_color.r, head_color.g, head_color.b, env * 0.98)
		_draw_sparkle4(head, 5.2 + env * 4.2, star_col, 0.58)

	func _draw() -> void:
		var sz: Vector2 = size
		if sz.x <= 4.0 or sz.y <= 4.0:
			return
		var w: float = sz.x
		var h: float = sz.y
		var min_dim: float = minf(w, h)
		var t: float = elapsed

		match fx_tag:
			"window", "goodnight":
				_draw_window_fx(w, h, min_dim, t, fx_tag == "goodnight")
			"quantum":
				_draw_quantum_fx(w, h, min_dim, t)
			"micro":
				_draw_micro_fx(w, h, min_dim, t)
			"forest":
				_draw_forest_fx(w, h, min_dim, t)
			"city":
				_draw_city_fx(w, h, min_dim, t)
			"planets", "cosmos":
				_draw_space_fx(w, h, min_dim, t, fx_tag == "cosmos")
			_:
				_draw_quantum_fx(w, h, min_dim, t)

	func _draw_window_fx(w: float, h: float, min_dim: float, t: float, is_goodnight: bool) -> void:
		# Warm breathing amber lava-lamp glow on the bedroom windowsill
		var pulse: float = 0.5 + 0.5 * sin(t * 2.05)
		var lamp_pos: Vector2 = Vector2(w * 0.50, h * 0.665)
		_draw_glow(
			lamp_pos,
			min_dim * (0.29 + pulse * 0.045),
			Color(1.0, 0.64, 0.34, 0.14 + pulse * 0.075)
		)
		_draw_glow(
			lamp_pos + Vector2(0.0, -min_dim * 0.02),
			min_dim * (0.14 + pulse * 0.025),
			Color(1.0, 0.84, 0.50, 0.17 + pulse * 0.085)
		)

		# Subtle warm golden shimmer echoing the Star / Twin Stars outside the open window
		if is_goodnight:
			var twin_beat: float = 0.5 + 0.5 * sin(t * 2.4 + 0.5)
			_draw_glow(
				Vector2(w * 0.47, h * 0.34),
				min_dim * (0.11 + twin_beat * 0.022),
				Color(1.0, 0.64, 0.56, 0.15 + twin_beat * 0.08)
			)
			_draw_glow(
				Vector2(w * 0.55, h * 0.30),
				min_dim * (0.11 + (1.0 - twin_beat) * 0.022),
				Color(1.0, 0.88, 0.52, 0.15 + (1.0 - twin_beat) * 0.08)
			)
		else:
			var star_beat: float = 0.5 + 0.5 * sin(t * 2.3)
			_draw_glow(
				Vector2(w * 0.57, h * 0.28),
				min_dim * (0.105 + star_beat * 0.022),
				Color(1.0, 0.90, 0.58, 0.16 + star_beat * 0.08)
			)

		# Twinkling 4-point diamond stars framed cleanly inside the night window sky
		for i in range(10):
			var sx: float = w * (0.35 + fposmod(float(i) * 0.137 + 0.03, 0.30))
			var sy: float = h * (0.13 + fposmod(float(i) * 0.191 + 0.02, 0.35))
			var tw: float = 0.25 + 0.75 * (0.5 + 0.5 * sin(t * (2.1 + float(i) * 0.35) + float(i) * 1.9))
			var col: Color = Color(1.0, 0.95, 0.76, 0.32 + tw * 0.56) if (i % 3 != 0) else Color(0.82, 0.95, 1.0, 0.30 + tw * 0.52)
			_draw_sparkle4(Vector2(sx, sy), 2.8 + tw * 4.8, col, 0.38)

		# Gentle periodic shooting star passing outside the bedroom window
		var cycle: float = fposmod(t, 5.2)
		if cycle < 0.82:
			var sp: float = cycle / 0.82
			var start_pt: Vector2 = Vector2(w * 0.365, h * 0.155)
			var end_pt: Vector2 = Vector2(w * 0.625, h * 0.325)
			_draw_shooting_star(
				start_pt,
				end_pt,
				sp,
				min_dim * 0.11,
				Color(1.0, 0.98, 0.86, 0.92),
				Color(0.65, 0.88, 1.0, 0.0)
			)

		# Soft moonlit bedroom dust motes floating lazily in the air
		for i in range(12):
			var mx: float = fposmod(float(i) * 0.193 + t * 0.007, 1.0) * w
			var my: float = fposmod(float(i) * 0.271 - t * 0.009 + 10.0, 1.0) * h
			var ma: float = (0.14 + 0.14 * (0.5 + 0.5 * sin(t * 1.6 + float(i) * 1.3)))
			draw_circle(Vector2(mx, my), 1.3 + float(i % 2) * 0.7, Color(0.92, 0.96, 1.0, ma))

	func _draw_quantum_fx(w: float, h: float, min_dim: float, t: float) -> void:
		# Soft luminous bokeh orbs (cyan & warm gold)
		for i in range(6):
			var ox: float = fposmod(_hash(31.0 + float(i)) + t * (0.009 + float(i % 2) * 0.004), 1.0) * w
			var oy: float = fposmod(_hash(59.0 + float(i)) - t * (0.011 + float(i % 3) * 0.003) + 10.0, 1.0) * h
			var pulse: float = 0.5 + 0.5 * sin(t * 1.5 + float(i) * 2.1)
			var rad: float = min_dim * (0.045 + float(i % 3) * 0.018)
			var col: Color = Color(0.36, 0.90, 0.98, 0.075 + pulse * 0.055) if (i % 2 == 0) else Color(1.0, 0.82, 0.48, 0.07 + pulse * 0.055)
			_draw_glow(Vector2(ox, oy), rad, col)

		# Shimmering cyan-gold quantum sparks drifting smoothly
		for i in range(22):
			var sx: float = fposmod(float(i) * 0.173 + t * (0.014 + float(i % 3) * 0.004), 1.0) * w
			var sy: float = fposmod(float(i) * 0.291 - t * (0.018 + float(i % 4) * 0.004) + 10.0, 1.0) * h
			var tw: float = 0.22 + 0.78 * (0.5 + 0.5 * sin(t * (2.6 + float(i % 3) * 0.5) + float(i) * 1.7))
			var col: Color = Color(0.42, 0.92, 0.99, 0.34 + tw * 0.54) if (i % 2 == 0) else Color(1.0, 0.89, 0.58, 0.34 + tw * 0.54)
			_draw_sparkle4(Vector2(sx, sy), 2.4 + tw * 4.4, col, 0.36)

	func _draw_micro_fx(w: float, h: float, _min_dim: float, t: float) -> void:
		# Delicate swaying turquoise caustic light shafts
		for i in range(3):
			var rx: float = w * (0.18 + float(i) * 0.31) + sin(t * 0.58 + float(i) * 1.4) * 32.0
			var shimmer: float = 0.78 + 0.22 * sin(t * 1.1 + float(i) * 2.0)
			_shaft_pts[0] = Vector2(rx - 28.0, 0.0)
			_shaft_pts[1] = Vector2(rx + 36.0, 0.0)
			_shaft_pts[2] = Vector2(rx + 125.0, h * 0.88)
			_shaft_pts[3] = Vector2(rx + 12.0, h * 0.88)
			var top_col: Color = Color(0.46, 0.96, 0.86, 0.068 * shimmer)
			var bot_col: Color = Color(0.32, 0.90, 0.84, 0.0)
			_shaft_cols[0] = top_col
			_shaft_cols[1] = top_col
			_shaft_cols[2] = bot_col
			_shaft_cols[3] = bot_col
			draw_polygon(_shaft_pts, _shaft_cols)

		# Rising translucent glowing bubbles with glossy specular highlights
		for i in range(18):
			var bx: float = fposmod(float(i) * 0.173 + 0.04, 0.92) * w + sin(t * 1.55 + float(i) * 1.4) * 15.0
			var by: float = (1.0 - fposmod(float(i) * 0.231 + t * (0.042 + float(i % 3) * 0.014), 1.0)) * h
			var br: float = 3.0 + float(i % 4) * 2.0
			var pos: Vector2 = Vector2(bx, by)
			_draw_glow(pos, br * 2.1, Color(0.55, 0.98, 0.92, 0.15))
			draw_arc(pos, br, 0.0, TAU, 20, Color(0.80, 0.99, 0.96, 0.44), 1.15, true)
			draw_circle(
				pos + Vector2(-br * 0.30, -br * 0.32),
				maxf(0.9, br * 0.25),
				Color(1.0, 1.0, 1.0, 0.68)
			)

		# Tiny bioluminescent turquoise micro-shimmer motes
		for i in range(10):
			var mx: float = fposmod(float(i) * 0.219 + t * 0.012, 1.0) * w
			var my: float = fposmod(float(i) * 0.317 - t * 0.016 + 10.0, 1.0) * h
			var tw: float = 0.3 + 0.7 * (0.5 + 0.5 * sin(t * 2.8 + float(i) * 1.9))
			_draw_glow(Vector2(mx, my), 6.0 + tw * 5.0, Color(0.52, 0.98, 0.88, 0.28 * tw))

	func _draw_forest_fx(w: float, h: float, _min_dim: float, t: float) -> void:
		# Warm weaving golden fireflies pulsing softly across the moss and trees
		for i in range(20):
			var base_x: float = fposmod(float(i) * 0.161 + 0.05, 0.90) * w
			var base_y: float = fposmod(float(i) * 0.247 + 0.08, 0.82) * h
			var fx_x: float = base_x + sin(t * (0.85 + float(i % 3) * 0.24) + float(i) * 2.1) * 30.0
			var fx_y: float = base_y + cos(t * (1.15 + float(i % 4) * 0.20) + float(i) * 1.3) * 22.0
			var glow: float = 0.18 + 0.82 * (0.5 + 0.5 * sin(t * (2.4 + float(i % 3) * 0.65) + float(i) * 1.7))
			var base_r: float = 2.1 + float(i % 3) * 0.95
			var pos: Vector2 = Vector2(fx_x, fx_y)
			_draw_glow(pos, base_r * 5.4, Color(1.0, 0.89, 0.42, 0.52 * glow))
			draw_circle(pos, base_r * 0.85, Color(1.0, 0.98, 0.78, 0.86 * glow))

		# Gentle woodland pollen drifting upward in the moonlit breeze
		for i in range(10):
			var px: float = fposmod(float(i) * 0.233 + sin(t * 0.5 + float(i)) * 0.02, 1.0) * w
			var py: float = (1.0 - fposmod(float(i) * 0.19 + t * 0.014, 1.0)) * h
			var a: float = 0.16 + 0.16 * (0.5 + 0.5 * sin(t * 1.9 + float(i)))
			draw_circle(Vector2(px, py), 1.4, Color(0.96, 1.0, 0.86, a))

	func _draw_city_fx(w: float, h: float, _min_dim: float, t: float) -> void:
		# Gentle rising warm amber paper sky-lantern motes
		for i in range(12):
			var lx: float = fposmod(float(i) * 0.193 + 0.06, 0.88) * w + sin(t * 0.85 + float(i) * 1.5) * 20.0
			var ly: float = (1.0 - fposmod(float(i) * 0.213 + t * (0.024 + float(i % 3) * 0.008), 1.0)) * h
			var lr: float = 3.2 + float(i % 3) * 1.5
			var flicker: float = 0.84 + 0.16 * sin(t * (3.6 + float(i % 3)) + float(i) * 2.2)
			var pos: Vector2 = Vector2(lx, ly)
			_draw_glow(pos, lr * 4.4, Color(1.0, 0.70, 0.34, 0.44 * flicker))
			draw_circle(pos + Vector2(0.0, -lr * 0.15), lr * 0.78, Color(1.0, 0.90, 0.66, 0.78 * flicker))
			draw_circle(pos + Vector2(0.0, lr * 0.22), lr * 0.58, Color(1.0, 0.78, 0.44, 0.72 * flicker))

		# Soft moonlight twinkle in the upper sky
		for i in range(10):
			var sx: float = fposmod(float(i) * 0.217 + 0.07, 0.86) * w
			var sy: float = fposmod(float(i) * 0.149 + 0.06, 0.42) * h
			var tw: float = 0.22 + 0.78 * (0.5 + 0.5 * sin(t * 2.6 + float(i) * 2.1))
			_draw_sparkle4(Vector2(sx, sy), 2.5 + tw * 3.8, Color(1.0, 0.98, 0.88, 0.30 + tw * 0.55), 0.34)

	func _draw_space_fx(w: float, h: float, min_dim: float, t: float, is_cosmos: bool) -> void:
		# Warm golden starlight halo breathing softly in the deep sky
		var halo_pulse: float = 0.5 + 0.5 * sin(t * 1.85)
		if is_cosmos:
			_draw_glow(
				Vector2(w * 0.66, h * 0.36),
				min_dim * (0.24 + halo_pulse * 0.04),
				Color(1.0, 0.85, 0.50, 0.11 + halo_pulse * 0.06)
			)
			_draw_glow(
				Vector2(w * 0.32, h * 0.44),
				min_dim * (0.20 + (1.0 - halo_pulse) * 0.03),
				Color(1.0, 0.56, 0.68, 0.075 + (1.0 - halo_pulse) * 0.04)
			)
		else:
			_draw_glow(
				Vector2(w * 0.70, h * 0.28),
				min_dim * (0.20 + halo_pulse * 0.035),
				Color(1.0, 0.88, 0.56, 0.10 + halo_pulse * 0.055)
			)

		# Fine twinkling pinpoint deep-space stars
		for i in range(22):
			var px: float = _hash(101.0 + float(i) * 1.7) * w
			var py: float = _hash(211.0 + float(i) * 2.3) * h * 0.88
			var tw: float = 0.30 + 0.70 * (0.5 + 0.5 * sin(t * (1.5 + float(i % 4) * 0.45) + float(i) * 2.7))
			var tint: Color = Color(1.0, 0.94, 0.78, 0.45 * tw) if (i % 3 == 0) else Color(0.84, 0.94, 1.0, 0.42 * tw)
			draw_circle(Vector2(px, py), 0.95 + float(i % 2) * 0.55, tint)

		# Crisp 4-point diamond stars
		for i in range(16):
			var sx: float = fposmod(float(i) * 0.179 + 0.04, 0.92) * w
			var sy: float = fposmod(float(i) * 0.263 + 0.06, 0.84) * h
			var tw: float = 0.22 + 0.78 * (0.5 + 0.5 * sin(t * (2.0 + float(i % 4) * 0.5) + float(i) * 2.3))
			var col: Color = Color(1.0, 0.93, 0.69, 0.34 + tw * 0.56) if (i % 3 == 0) else Color(0.82, 0.96, 1.0, 0.28 + tw * 0.52)
			_draw_sparkle4(Vector2(sx, sy), 2.6 + tw * 5.0, col, 0.38)

		# Occasional graceful shooting star alternating two high-sky trajectories
		var period: float = 4.6
		var cycle_idx: int = int(floor(t / period))
		var cycle: float = fposmod(t, period)
		if cycle < 0.78:
			var sp: float = cycle / 0.78
			var start_pt: Vector2 = Vector2(w * 0.14, h * 0.13) if (cycle_idx % 2 == 0) else Vector2(w * 0.84, h * 0.14)
			var end_pt: Vector2 = Vector2(w * 0.66, h * 0.36) if (cycle_idx % 2 == 0) else Vector2(w * 0.34, h * 0.35)
			_draw_shooting_star(
				start_pt,
				end_pt,
				sp,
				min_dim * 0.14,
				Color(1.0, 0.98, 0.86, 0.94),
				Color(0.50, 0.84, 1.0, 0.0)
			)


var _root: Control = null
var _art_clip: Control = null
var _prev_layer: Control = null
var _prev_bg: ColorRect = null
var _prev_rect: TextureRect = null
var _curr_layer: Control = null
var _curr_bg: ColorRect = null
var _curr_rect: TextureRect = null
var _atmosphere: _AtmosphereOverlay = null
var _top_grad: TextureRect = null
var _top_margin: MarginContainer = null
var _bot_grad: TextureRect = null
var _bot_margin: MarginContainer = null
var _chapter_label: Label = null
var _skip_button: Button = null
var _caption_label: Label = null
var _dots_box: HBoxContainer = null
var _next_prompt: Label = null

var _font_caption: Font = null
var _font_chapter: Font = null
var _font_ui_btn: Font = null
var _font_ui_hint: Font = null
var _ui_theme: Theme = null

var _textures: Dictionary = {}
var _safe_insets: Rect2 = Rect2()
var _active: bool = false
var _current_cutscene_id: String = ""
var _slides: Array = []
var _slide_index: int = 0
var _slide_time: float = 0.0
var _guard_timer: float = 0.0
var _curr_is_landscape: bool = true
var _on_done: Callable = Callable()
var _fade_tween: Tween = null
var _text_tween: Tween = null
var _initialized: bool = false


func _ready() -> void:
	_ensure_initialized()
	if get_viewport() != null and not get_viewport().size_changed.is_connected(_on_viewport_resized):
		get_viewport().size_changed.connect(_on_viewport_resized)
	if not _active:
		visible = false


func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
	layer = 30
	_setup_fonts()
	_preload_art()
	_build_ui()


func _make_font_variation(base: Font, weight: int, glyph_spacing: int = 0) -> Font:
	if base == null:
		return null
	var fv: FontVariation = FontVariation.new()
	fv.base_font = base
	var ts: TextServer = TextServerManager.get_primary_interface()
	if ts != null:
		fv.variation_opentype = {ts.name_to_tag("wght"): weight}
	if glyph_spacing != 0:
		fv.spacing_glyph = glyph_spacing
	return fv


func _setup_fonts() -> void:
	if ResourceLoader.exists(FONT_DISPLAY_PATH):
		var display_base: Font = load(FONT_DISPLAY_PATH) as Font
		_font_caption = _make_font_variation(display_base, 520, 0)
		_font_chapter = _make_font_variation(display_base, 650, 3)
	if ResourceLoader.exists(FONT_UI_PATH):
		var ui_base: Font = load(FONT_UI_PATH) as Font
		_font_ui_btn = _make_font_variation(ui_base, 550, 1)
		_font_ui_hint = _make_font_variation(ui_base, 500, 2)

	_ui_theme = Theme.new()
	if _font_ui_btn != null:
		_ui_theme.default_font = _font_ui_btn
		_ui_theme.default_font_size = 15
	elif _font_caption != null:
		_ui_theme.default_font = _font_caption
		_ui_theme.default_font_size = 15


func _load_art_texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path] as Texture2D
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			tex = res as Texture2D
	if tex == null:
		var abs_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(abs_path):
			var img: Image = Image.load_from_file(abs_path)
			if img != null and not img.is_empty():
				tex = ImageTexture.create_from_image(img)
	if tex != null:
		_textures[path] = tex
	return tex


func _preload_art() -> void:
	for path: String in ALL_ART_PATHS:
		_load_art_texture(path)


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "CutsceneRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	if _ui_theme != null:
		_root.theme = _ui_theme
	add_child(_root)

	# Deep nocturnal storybook backdrop
	var bg: ColorRect = ColorRect.new()
	bg.name = "Backdrop"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_MIDNIGHT
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	# Clipped full-bleed art viewport for bounded Ken Burns motion & crossfade
	_art_clip = Control.new()
	_art_clip.name = "ArtClip"
	_art_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_clip.clip_contents = true
	_art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_art_clip)

	# Previous slide layer (stays beneath during smooth crossfade)
	_prev_layer = Control.new()
	_prev_layer.name = "PrevArtLayer"
	_prev_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prev_layer.clip_contents = true
	_prev_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prev_layer.visible = false
	_art_clip.add_child(_prev_layer)

	_prev_bg = ColorRect.new()
	_prev_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prev_bg.color = BG_MIDNIGHT
	_prev_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prev_layer.add_child(_prev_bg)

	_prev_rect = TextureRect.new()
	_prev_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_prev_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_prev_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_prev_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prev_layer.add_child(_prev_rect)

	# Current slide layer
	_curr_layer = Control.new()
	_curr_layer.name = "CurrArtLayer"
	_curr_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curr_layer.clip_contents = true
	_curr_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_clip.add_child(_curr_layer)

	_curr_bg = ColorRect.new()
	_curr_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curr_bg.color = BG_MIDNIGHT
	_curr_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curr_layer.add_child(_curr_bg)

	_curr_rect = TextureRect.new()
	_curr_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curr_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_curr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_curr_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_curr_layer.add_child(_curr_rect)

	# Live 60 FPS animated Miyazaki atmospheric overlay on top of the painting
	_atmosphere = _AtmosphereOverlay.new()
	_atmosphere.name = "AtmosphereOverlay"
	_atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_atmosphere)

	# Soft cinema top gradient (never dulls the heart of the painting)
	_top_grad = TextureRect.new()
	_top_grad.anchor_left = 0.0
	_top_grad.anchor_top = 0.0
	_top_grad.anchor_right = 1.0
	_top_grad.anchor_bottom = 0.0
	_top_grad.offset_bottom = 100.0
	_top_grad.texture = _make_multi_stop_gradient(
		PackedFloat32Array([0.0, 0.56, 1.0]),
		PackedColorArray([
			Color(0.015, 0.032, 0.068, 0.84),
			Color(0.015, 0.032, 0.068, 0.34),
			Color(0.015, 0.032, 0.068, 0.0),
		])
	)
	_top_grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_top_grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_top_grad)

	_top_margin = MarginContainer.new()
	_top_margin.anchor_left = 0.0
	_top_margin.anchor_top = 0.0
	_top_margin.anchor_right = 1.0
	_top_margin.anchor_bottom = 0.0
	_top_margin.offset_bottom = 78.0
	_top_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(_top_margin)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_top_margin.add_child(top_row)

	_chapter_label = Label.new()
	_chapter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chapter_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _font_chapter != null:
		_chapter_label.add_theme_font_override("font", _font_chapter)
	_chapter_label.add_theme_font_size_override("font_size", 16)
	_chapter_label.add_theme_color_override("font_color", Color(1.0, 0.87, 0.64, 0.98))
	_chapter_label.add_theme_color_override("font_shadow_color", Color(0.01, 0.02, 0.05, 0.78))
	_chapter_label.add_theme_constant_override("shadow_offset_y", 2)
	_chapter_label.add_theme_constant_override("shadow_outline_size", 3)
	_chapter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(_chapter_label)

	_skip_button = Button.new()
	_skip_button.text = "Passer ›"
	_skip_button.custom_minimum_size = Vector2(114, 40)
	if _font_ui_btn != null:
		_skip_button.add_theme_font_override("font", _font_ui_btn)
	_skip_button.add_theme_font_size_override("font_size", 15)
	_skip_button.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0, 0.94))
	_skip_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	_skip_button.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.78, 1.0))
	var skip_style: StyleBoxFlat = StyleBoxFlat.new()
	skip_style.bg_color = Color(0.05, 0.11, 0.20, 0.72)
	skip_style.border_color = Color(0.82, 0.92, 0.98, 0.34)
	skip_style.set_border_width_all(1)
	skip_style.set_corner_radius_all(20)
	skip_style.content_margin_left = 16
	skip_style.content_margin_right = 14
	skip_style.content_margin_top = 6
	skip_style.content_margin_bottom = 6
	_skip_button.add_theme_stylebox_override("normal", skip_style)
	var skip_hover: StyleBoxFlat = skip_style.duplicate() as StyleBoxFlat
	skip_hover.bg_color = Color(0.11, 0.20, 0.32, 0.88)
	skip_hover.border_color = Color(1.0, 0.87, 0.64, 0.62)
	_skip_button.add_theme_stylebox_override("hover", skip_hover)
	_skip_button.add_theme_stylebox_override("pressed", skip_hover)
	_skip_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_skip_button.pressed.connect(skip_cutscene)
	top_row.add_child(_skip_button)

	# Soft cinema bottom gradient for effortless storybook legibility
	_bot_grad = TextureRect.new()
	_bot_grad.anchor_left = 0.0
	_bot_grad.anchor_top = 1.0
	_bot_grad.anchor_right = 1.0
	_bot_grad.anchor_bottom = 1.0
	_bot_grad.offset_top = -206.0
	_bot_grad.texture = _make_multi_stop_gradient(
		PackedFloat32Array([0.0, 0.34, 0.76, 1.0]),
		PackedColorArray([
			Color(0.015, 0.032, 0.068, 0.0),
			Color(0.015, 0.032, 0.068, 0.56),
			Color(0.015, 0.032, 0.068, 0.86),
			Color(0.015, 0.032, 0.068, 0.94),
		])
	)
	_bot_grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bot_grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bot_grad)

	_bot_margin = MarginContainer.new()
	_bot_margin.anchor_left = 0.0
	_bot_margin.anchor_top = 1.0
	_bot_margin.anchor_right = 1.0
	_bot_margin.anchor_bottom = 1.0
	_bot_margin.offset_top = -156.0
	_bot_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bot_margin)

	var bot_col: VBoxContainer = VBoxContainer.new()
	bot_col.alignment = BoxContainer.ALIGNMENT_END
	bot_col.add_theme_constant_override("separation", 12)
	bot_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bot_margin.add_child(bot_col)

	_caption_label = Label.new()
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _font_caption != null:
		_caption_label.add_theme_font_override("font", _font_caption)
	_caption_label.add_theme_font_size_override("font_size", 22)
	_caption_label.add_theme_constant_override("line_spacing", 4)
	_caption_label.add_theme_color_override("font_color", Color(0.99, 0.97, 0.93, 1.0))
	_caption_label.add_theme_color_override("font_shadow_color", Color(0.01, 0.02, 0.06, 0.86))
	_caption_label.add_theme_constant_override("shadow_offset_y", 2)
	_caption_label.add_theme_constant_override("shadow_outline_size", 4)
	_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_col.add_child(_caption_label)

	var footer_row: HBoxContainer = HBoxContainer.new()
	footer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_row.add_theme_constant_override("separation", 16)
	footer_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_col.add_child(footer_row)

	_dots_box = HBoxContainer.new()
	_dots_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_dots_box.add_theme_constant_override("separation", 8)
	_dots_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_row.add_child(_dots_box)

	_next_prompt = Label.new()
	_next_prompt.text = "Touchez pour la suite ›"
	if _font_ui_hint != null:
		_next_prompt.add_theme_font_override("font", _font_ui_hint)
	_next_prompt.add_theme_font_size_override("font_size", 14)
	_next_prompt.add_theme_color_override("font_color", Color(0.82, 0.94, 0.98, 0.90))
	_next_prompt.add_theme_color_override("font_shadow_color", Color(0.01, 0.02, 0.05, 0.72))
	_next_prompt.add_theme_constant_override("shadow_offset_y", 1)
	_next_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_row.add_child(_next_prompt)

	apply_safe_area(_safe_insets)


func _make_multi_stop_gradient(offsets: PackedFloat32Array, colors: PackedColorArray) -> GradientTexture2D:
	var grad: Gradient = Gradient.new()
	grad.offsets = offsets
	grad.colors = colors
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 4
	tex.height = 64
	return tex


func _on_viewport_resized() -> void:
	apply_safe_area(_safe_insets)
	if _active:
		_update_ken_burns(_slide_time)


func apply_safe_area(insets: Rect2) -> void:
	_safe_insets = insets
	var left_in: int = maxi(0, roundi(insets.position.x))
	var top_in: int = maxi(0, roundi(insets.position.y))
	var right_in: int = maxi(0, roundi(insets.size.x))
	var bottom_in: int = maxi(0, roundi(insets.size.y))

	var vp_w: float = 1280.0
	if get_viewport() != null:
		var vr: Rect2 = get_viewport().get_visible_rect()
		if vr.size.x > 0.0:
			vp_w = vr.size.x
	# Keep poetic caption measure comfortably balanced from 16:9 to 21:9
	var ideal_side: int = maxi(48, roundi((vp_w - 960.0) * 0.5))
	var cap_left: int = maxi(ideal_side, 40 + left_in)
	var cap_right: int = maxi(ideal_side, 40 + right_in)

	if _top_grad != null:
		_top_grad.offset_bottom = 96.0 + float(top_in)
	if _top_margin != null:
		_top_margin.offset_bottom = 74.0 + float(top_in)
		_top_margin.add_theme_constant_override("margin_left", 28 + left_in)
		_top_margin.add_theme_constant_override("margin_right", 28 + right_in)
		_top_margin.add_theme_constant_override("margin_top", 16 + top_in)
	if _bot_grad != null:
		_bot_grad.offset_top = -(206.0 + float(bottom_in))
	if _bot_margin != null:
		_bot_margin.offset_top = -(156.0 + float(bottom_in))
		_bot_margin.add_theme_constant_override("margin_left", cap_left)
		_bot_margin.add_theme_constant_override("margin_right", cap_right)
		_bot_margin.add_theme_constant_override("margin_bottom", 18 + bottom_in)


func is_playing() -> bool:
	return _active


func get_slide_count() -> int:
	if _active and not _slides.is_empty():
		return _slides.size()
	var total: int = 0
	for cid: Variant in CUTSCENES.keys():
		var data: Dictionary = CUTSCENES[cid] as Dictionary
		var arr: Array = data.get("slides", []) as Array
		total += arr.size()
	return total


func play_cutscene(cutscene_id: String, on_done: Callable) -> void:
	_ensure_initialized()
	if not CUTSCENES.has(cutscene_id):
		if on_done.is_valid():
			on_done.call()
		return

	var data: Dictionary = CUTSCENES[cutscene_id] as Dictionary
	var slides_arr: Array = data.get("slides", []) as Array
	if slides_arr.is_empty():
		if on_done.is_valid():
			on_done.call()
		return

	_current_cutscene_id = cutscene_id
	_slides = slides_arr
	_on_done = on_done
	_slide_index = 0
	_active = true
	visible = true
	if _prev_layer != null:
		_prev_layer.visible = false
	_apply_slide(0, false, false)


func debug_show_cutscene(cutscene_id: String, slide_idx: int = 0) -> void:
	_ensure_initialized()
	if not CUTSCENES.has(cutscene_id):
		return
	var data: Dictionary = CUTSCENES[cutscene_id] as Dictionary
	var slides_arr: Array = data.get("slides", []) as Array
	if slides_arr.is_empty():
		return

	_current_cutscene_id = cutscene_id
	_slides = slides_arr
	_on_done = Callable()
	var clamped_idx: int = clampi(slide_idx, 0, _slides.size() - 1)
	_slide_index = clamped_idx
	_active = true
	visible = true
	_guard_timer = 0.0
	_apply_slide(clamped_idx, true, false)


func skip_cutscene() -> void:
	if not _active:
		return
	_finish()


func _kill_tweens() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	if _text_tween != null and _text_tween.is_valid():
		_text_tween.kill()
	_text_tween = null


func _finish() -> void:
	_kill_tweens()
	_active = false
	_current_cutscene_id = ""
	_slides = []
	visible = false
	if _prev_layer != null:
		_prev_layer.visible = false
	var cb: Callable = _on_done
	_on_done = Callable()
	if cb.is_valid():
		cb.call()


func _snapshot_curr_to_prev() -> void:
	if _prev_layer == null or _curr_rect == null or _curr_rect.texture == null:
		return
	_prev_bg.color = _curr_bg.color
	_prev_rect.texture = _curr_rect.texture
	_prev_rect.stretch_mode = _curr_rect.stretch_mode
	_prev_rect.pivot_offset = _curr_rect.pivot_offset
	_prev_rect.scale = _curr_rect.scale
	_prev_rect.position = _curr_rect.position
	_prev_layer.modulate.a = 1.0
	_prev_layer.visible = true


func _apply_slide(index: int, instant: bool = false, crossfade_from_prev: bool = true) -> void:
	_kill_tweens()

	if crossfade_from_prev and not instant and _curr_rect != null and _curr_rect.texture != null:
		_snapshot_curr_to_prev()
	elif _prev_layer != null:
		_prev_layer.visible = false

	_slide_index = index
	_slide_time = 1.6 if instant else 0.0
	_guard_timer = 0.0 if instant else TAP_GUARD_SECONDS

	var slide: Dictionary = _slides[index] as Dictionary
	var art_path: String = String(slide.get("art", ART_INTRO_WINDOW))
	var tex: Texture2D = _load_art_texture(art_path)
	_curr_rect.texture = tex

	if tex != null:
		var tex_sz: Vector2 = tex.get_size()
		var tex_aspect: float = tex_sz.x / maxf(tex_sz.y, 1.0)
		_curr_is_landscape = tex_aspect >= 1.35
		if _curr_is_landscape:
			_curr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			_curr_bg.color = BG_MIDNIGHT
		else:
			# Seamless cosmic-teal canvas for square Charlie portrait (uncropped on 16:9 to 21:9)
			_curr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_curr_bg.color = BG_PORTRAIT_TEAL
	else:
		_curr_is_landscape = true
		_curr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		_curr_bg.color = BG_MIDNIGHT

	var fallback_chapter: String = ""
	if CUTSCENES.has(_current_cutscene_id):
		fallback_chapter = String((CUTSCENES[_current_cutscene_id] as Dictionary).get("chapter", ""))
	var new_chapter: String = String(slide.get("chapter", fallback_chapter))
	var chapter_changed: bool = (_chapter_label.text != new_chapter)
	_chapter_label.text = new_chapter
	_caption_label.text = String(slide.get("text", ""))

	var fx_tag: String = String(slide.get("fx", "quantum"))
	if _atmosphere != null:
		_atmosphere.set_fx(fx_tag, 0.38 if instant else 0.0)

	_rebuild_dots()
	_update_ken_burns(_slide_time)

	if instant:
		_curr_layer.modulate.a = 1.0
		_caption_label.modulate.a = 1.0
		_chapter_label.modulate.a = 1.0
		if _next_prompt != null:
			_next_prompt.modulate.a = 0.88
		return

	# Smooth cinema crossfade between paintings
	_curr_layer.modulate.a = 0.0
	_fade_tween = create_tween()
	_fade_tween.tween_property(_curr_layer, "modulate:a", 1.0, CROSSFADE_SECONDS).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	if _prev_layer != null and _prev_layer.visible:
		_fade_tween.tween_callback(_hide_prev_layer)

	# Gentle storybook caption & chapter reveal
	_caption_label.modulate.a = 0.0
	_text_tween = create_tween()
	_text_tween.set_parallel(true)
	_text_tween.tween_property(_caption_label, "modulate:a", 1.0, 0.42).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	if chapter_changed:
		_chapter_label.modulate.a = 0.0
		_text_tween.tween_property(_chapter_label, "modulate:a", 1.0, 0.38).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


func _hide_prev_layer() -> void:
	if _prev_layer != null:
		_prev_layer.visible = false


func _rebuild_dots() -> void:
	for child: Node in _dots_box.get_children():
		child.queue_free()

	for i in range(_slides.size()):
		var dot: Panel = Panel.new()
		var is_cur: bool = (i == _slide_index)
		var is_past: bool = (i < _slide_index)
		dot.custom_minimum_size = Vector2(24.0 if is_cur else 7.0, 7.0)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var style: StyleBoxFlat = StyleBoxFlat.new()
		if is_cur:
			style.bg_color = Color(1.0, 0.83, 0.52, 1.0)
			style.shadow_color = Color(1.0, 0.72, 0.35, 0.45)
			style.shadow_size = 4
		elif is_past:
			style.bg_color = Color(1.0, 0.86, 0.64, 0.58)
		else:
			style.bg_color = Color(0.84, 0.93, 0.98, 0.38)
		style.set_corner_radius_all(4)
		dot.add_theme_stylebox_override("panel", style)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots_box.add_child(dot)


func _advance_slide() -> void:
	if _slide_index + 1 < _slides.size():
		_apply_slide(_slide_index + 1, false, true)
	else:
		_finish()


func _process(delta: float) -> void:
	if not _active:
		return

	var step_dt: float = minf(delta, 0.1)
	_slide_time += step_dt
	if _guard_timer > 0.0:
		_guard_timer = maxf(0.0, _guard_timer - step_dt)

	_update_ken_burns(_slide_time)
	if _atmosphere != null:
		_atmosphere.step(step_dt)
	if _next_prompt != null:
		_next_prompt.modulate.a = 0.81 + 0.15 * sin(_slide_time * 2.6)


func _update_ken_burns(t_sec: float) -> void:
	if _curr_rect == null or _slides.is_empty():
		return
	var slide: Dictionary = _slides[_slide_index] as Dictionary
	var frac: float = clampf(t_sec / KEN_BURNS_DURATION, 0.0, 1.0)
	var ease_frac: float = frac * frac * (3.0 - 2.0 * frac)

	var rect_sz: Vector2 = _curr_rect.size
	if rect_sz.x <= 1.0 or rect_sz.y <= 1.0:
		if _art_clip != null and _art_clip.size.x > 1.0:
			rect_sz = _art_clip.size
		elif get_viewport() != null:
			rect_sz = get_viewport().get_visible_rect().size
		else:
			rect_sz = Vector2(1280.0, 720.0)

	_curr_rect.pivot_offset = rect_sz * 0.5

	# Subtle bounded zoom [1.02, 1.07] — never crops focal subjects or exposes borders
	var z_from: float = clampf(float(slide.get("zoom_from", 1.02)), 1.02, 1.07)
	var z_to: float = clampf(float(slide.get("zoom_to", 1.07)), 1.02, 1.07)
	var zoom_val: float = lerpf(z_from, z_to, ease_frac)
	_curr_rect.scale = Vector2(zoom_val, zoom_val)

	if _curr_is_landscape:
		var p_from: Vector2 = slide.get("pan_from", Vector2.ZERO) as Vector2
		var p_to: Vector2 = slide.get("pan_to", Vector2.ZERO) as Vector2
		var pan_norm: Vector2 = p_from.lerp(p_to, ease_frac)
		var raw_pan: Vector2 = Vector2(pan_norm.x * rect_sz.x, pan_norm.y * rect_sz.y)
		# Guarantee scaled image always covers the full viewport with safety margin
		var max_pan: Vector2 = rect_sz * maxf(0.0, zoom_val - 1.0) * 0.48
		_curr_rect.position = Vector2(
			clampf(raw_pan.x, -max_pan.x, max_pan.x),
			clampf(raw_pan.y, -max_pan.y, max_pan.y)
		)
	else:
		# Centered gentle breathing drift for square portrait artwork
		var drift_y: float = lerpf(4.0, -6.0, ease_frac)
		_curr_rect.position = Vector2(0.0, drift_y)


func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event is InputEventKey:
		var key_ev: InputEventKey = event as InputEventKey
		if key_ev.pressed and not key_ev.echo:
			if key_ev.keycode == KEY_ESCAPE:
				skip_cutscene()
				get_viewport().set_input_as_handled()
			elif key_ev.keycode == KEY_SPACE or key_ev.keycode == KEY_ENTER or key_ev.keycode == KEY_RIGHT:
				if _guard_timer <= 0.0:
					_advance_slide()
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch_ev: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_ev.pressed:
			# Let the Skip button handle its own press cleanly
			if _skip_button != null and _skip_button.get_global_rect().grow(10.0).has_point(touch_ev.position):
				return
			if _guard_timer <= 0.0:
				_advance_slide()
			get_viewport().set_input_as_handled()
