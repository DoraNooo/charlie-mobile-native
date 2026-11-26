class_name Creature
extends Node2D
## World entity representing any of the 30 bioluminescent species across Charlie's 6 scales.

var species: Dictionary = {}
var scale_index: int = 0
var world_size: float = 20.0
var velocity: Vector2 = Vector2.ZERO
var facing_angle: float = 0.0
var phase: float = 0.0
var alive: bool = true
var burn_flash: float = 0.0
var alpha: float = 0.0

var show_danger_halo: bool = true
var is_edible: bool = true
var is_predator: bool = false
var proximity_ratio: float = 0.0

var wander_angle: float = 0.0
var behavior_timer: float = 0.0
var orbit_dir: float = 1.0


func setup(spec: Dictionary, p_scale_index: int, p_world_size: float, spawn_pos: Vector2) -> void:
	species = spec
	scale_index = p_scale_index
	world_size = maxf(p_world_size, 3.0)
	position = spawn_pos
	velocity = Vector2.ZERO
	facing_angle = randf_range(-PI, PI)
	wander_angle = facing_angle
	phase = randf_range(0.0, TAU)
	behavior_timer = randf_range(0.5, 2.2)
	orbit_dir = -1.0 if randf() < 0.5 else 1.0
	alive = true
	burn_flash = 0.0
	alpha = 0.0
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	queue_redraw()


func _draw() -> void:
	if not alive or world_size < 1.0:
		return

	var r: float = world_size
	var base_col: Color = species.get("color", Color("#67e8f9")) as Color
	var accent_col: Color = species.get("accent", Color("#ffffff")) as Color
	if burn_flash > 0.01:
		var flash_t: float = clampf(burn_flash, 0.0, 1.0)
		base_col = base_col.lerp(Color(1.0, 0.96, 0.82), flash_t * 0.85)
		accent_col = accent_col.lerp(Color.WHITE, flash_t * 0.9)

	# Subtle proximity halos (unrotated world space)
	if proximity_ratio > 0.02:
		if is_predator and show_danger_halo:
			var pulse: float = 0.5 + 0.5 * sin(phase * 5.0)
			var halo_a: float = proximity_ratio * (0.28 + 0.22 * pulse)
			draw_arc(
				Vector2.ZERO,
				r * (1.28 + 0.08 * pulse),
				0.0,
				TAU,
				32,
				Color(1.0, 0.32, 0.38, halo_a),
				maxf(1.8, r * 0.09),
				true
			)
		elif is_edible:
			var halo_a: float = proximity_ratio * 0.24
			draw_arc(
				Vector2.ZERO,
				r * 1.18,
				0.0,
				TAU,
				24,
				Color(0.55, 0.98, 0.82, halo_a),
				maxf(1.4, r * 0.065),
				true
			)

	var kind: String = str(species.get("kind", "quark"))
	var upright_kinds: PackedStringArray = PackedStringArray(["lantern", "moon", "planet", "ringed", "star", "nebula", "solar", "blackhole", "galaxy"])
	if upright_kinds.has(kind):
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_set_transform(Vector2.ZERO, facing_angle, Vector2.ONE)

	match kind:
		# Scale 0: Quantum
		"quark":
			_draw_quark(r, base_col, accent_col)
		"electron":
			_draw_electron(r, base_col, accent_col)
		"photon":
			_draw_photon(r, base_col, accent_col)
		"atom":
			_draw_atom(r, base_col, accent_col)
		"molecule":
			_draw_molecule(r, base_col, accent_col)
		# Scale 1: Micro
		"spore":
			_draw_spore(r, base_col, accent_col)
		"bacteria":
			_draw_bacteria(r, base_col, accent_col)
		"amoeba":
			_draw_amoeba(r, base_col, accent_col)
		"diatom":
			_draw_diatom(r, base_col, accent_col)
		"tardigrade":
			_draw_tardigrade(r, base_col, accent_col)
		# Scale 2: Forest
		"ant":
			_draw_ant(r, base_col, accent_col)
		"firefly":
			_draw_firefly(r, base_col, accent_col)
		"ladybug":
			_draw_ladybug(r, base_col, accent_col)
		"moth":
			_draw_moth(r, base_col, accent_col)
		"frog":
			_draw_frog(r, base_col, accent_col)
		# Scale 3: City
		"lantern":
			_draw_lantern(r, base_col, accent_col)
		"owl":
			_draw_owl(r, base_col, accent_col)
		"car":
			_draw_car(r, base_col, accent_col)
		"helicopter":
			_draw_helicopter(r, base_col, accent_col)
		"blimp":
			_draw_blimp(r, base_col, accent_col)
		# Scale 4: Planetary
		"asteroid":
			_draw_asteroid(r, base_col, accent_col)
		"comet":
			_draw_comet(r, base_col, accent_col)
		"moon":
			_draw_moon(r, base_col, accent_col)
		"planet":
			_draw_planet(r, base_col, accent_col)
		"ringed":
			_draw_ringed(r, base_col, accent_col)
		# Scale 5: Cosmic
		"star":
			_draw_star(r, base_col, accent_col)
		"nebula":
			_draw_nebula(r, base_col, accent_col)
		"solar":
			_draw_solar(r, base_col, accent_col)
		"blackhole":
			_draw_blackhole(r, base_col, accent_col)
		"galaxy":
			_draw_galaxy(r, base_col, accent_col)
		_:
			draw_circle(Vector2.ZERO, r * 0.8, base_col)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Geometry helpers ---

func _draw_ellipse(center: Vector2, rx: float, ry: float, col: Color, segments: int = 20) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(segments)
	for i: int in range(segments):
		var ang: float = (float(i) / float(segments)) * TAU
		pts[i] = center + Vector2(cos(ang) * rx, sin(ang) * ry)
	draw_colored_polygon(pts, col)


func _draw_ellipse_outline(center: Vector2, rx: float, ry: float, col: Color, width: float, rot: float = 0.0, segments: int = 28) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(segments + 1)
	var c: float = cos(rot)
	var s: float = sin(rot)
	for i: int in range(segments + 1):
		var ang: float = (float(i) / float(segments)) * TAU
		var lx: float = cos(ang) * rx
		var ly: float = sin(ang) * ry
		pts[i] = center + Vector2(lx * c - ly * s, lx * s + ly * c)
	draw_polyline(pts, col, width, true)


func _draw_star_poly(center: Vector2, outer_r: float, inner_r: float, points: int, col: Color, rot: float = 0.0) -> void:
	var total: int = points * 2
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(total)
	for i: int in range(total):
		var ang: float = rot + (float(i) / float(total)) * TAU
		var rad: float = outer_r if (i % 2 == 0) else inner_r
		pts[i] = center + Vector2(cos(ang) * rad, sin(ang) * rad)
	draw_colored_polygon(pts, col)


# --- Scale 0: Quantum ---

func _draw_quark(r: float, col: Color, acc: Color) -> void:
	draw_circle(Vector2.ZERO, r * 1.05, Color(col.r, col.g, col.b, 0.22))
	for i: int in range(3):
		var ang: float = phase * 2.2 + float(i) * (TAU / 3.0)
		var pos: Vector2 = Vector2(cos(ang), sin(ang)) * (r * 0.42)
		draw_circle(pos, r * 0.42, col)
		draw_circle(pos - Vector2(r * 0.1, r * 0.1), r * 0.16, acc)


func _draw_electron(r: float, col: Color, acc: Color) -> void:
	draw_circle(Vector2.ZERO, r * 0.95, Color(col.r, col.g, col.b, 0.18))
	_draw_ellipse_outline(Vector2.ZERO, r * 0.95, r * 0.42, Color(acc.r, acc.g, acc.b, 0.55), maxf(1.2, r * 0.09), phase * 1.4)
	draw_circle(Vector2.ZERO, r * 0.52, col)
	draw_circle(Vector2(r * 0.12, -r * 0.12), r * 0.22, acc)
	var spark_ang: float = phase * 5.0
	draw_circle(Vector2(cos(spark_ang) * r * 0.95, sin(spark_ang) * r * 0.42).rotated(phase * 1.4), r * 0.16, acc)


func _draw_photon(r: float, col: Color, acc: Color) -> void:
	var wave_pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(12):
		var t: float = float(i) / 11.0
		var wx: float = -r * 1.35 * t
		var wy: float = sin(t * TAU * 1.6 - phase * 6.0) * r * 0.34 * (1.0 - t * 0.5)
		wave_pts.append(Vector2(wx, wy))
	draw_polyline(wave_pts, Color(col.r, col.g, col.b, 0.7), maxf(1.5, r * 0.14), true)
	draw_circle(Vector2.ZERO, r * 0.72, Color(col.r, col.g, col.b, 0.28))
	_draw_star_poly(Vector2.ZERO, r * 0.75, r * 0.28, 4, col, phase * 0.8)
	draw_circle(Vector2.ZERO, r * 0.3, acc)


func _draw_atom(r: float, col: Color, acc: Color) -> void:
	var ring_w: float = maxf(1.2, r * 0.08)
	var ring_col: Color = Color(acc.r, acc.g, acc.b, 0.52)
	for i: int in range(3):
		var rot: float = float(i) * (PI / 3.0) + phase * 0.35
		_draw_ellipse_outline(Vector2.ZERO, r * 1.0, r * 0.42, ring_col, ring_w, rot)
		var e_ang: float = phase * (2.6 + float(i) * 0.5) + float(i) * 2.1
		var e_pos: Vector2 = Vector2(cos(e_ang) * r * 1.0, sin(e_ang) * r * 0.42).rotated(rot)
		draw_circle(e_pos, r * 0.14, acc)
	draw_circle(Vector2.ZERO, r * 0.36, col)
	draw_circle(Vector2(-r * 0.08, -r * 0.08), r * 0.15, acc)


func _draw_molecule(r: float, col: Color, acc: Color) -> void:
	var bond_w: float = maxf(2.0, r * 0.15)
	var nodes: Array[Vector2] = [
		Vector2(r * 0.56, 0.0),
		Vector2(-r * 0.45, -r * 0.52),
		Vector2(-r * 0.45, r * 0.52),
	]
	for n: Vector2 in nodes:
		draw_line(Vector2.ZERO, n, Color(acc.r, acc.g, acc.b, 0.78), bond_w, true)
	draw_circle(Vector2.ZERO, r * 0.48, col)
	for n: Vector2 in nodes:
		draw_circle(n, r * 0.34, col.darkened(0.08))
		draw_circle(n - Vector2(r * 0.08, r * 0.08), r * 0.12, acc)
	# Small expressive eyes on central hub
	draw_circle(Vector2(r * 0.16, -r * 0.14), r * 0.1, Color(0.18, 0.04, 0.1))
	draw_circle(Vector2(r * 0.16, r * 0.14), r * 0.1, Color(0.18, 0.04, 0.1))


# --- Scale 1: Micro ---

func _draw_spore(r: float, col: Color, acc: Color) -> void:
	for i: int in range(10):
		var ang: float = float(i) * (TAU / 10.0) + sin(phase * 2.0 + float(i)) * 0.1
		var p1: Vector2 = Vector2.from_angle(ang) * (r * 0.62)
		var p2: Vector2 = Vector2.from_angle(ang) * (r * 0.98)
		draw_line(p1, p2, Color(acc.r, acc.g, acc.b, 0.62), maxf(1.2, r * 0.08), true)
	draw_circle(Vector2.ZERO, r * 0.68, Color(col.r, col.g, col.b, 0.85))
	draw_circle(Vector2(-r * 0.12, -r * 0.12), r * 0.28, acc)


func _draw_bacteria(r: float, col: Color, acc: Color) -> void:
	# Wiggling flagellum tail
	var tail: PackedVector2Array = PackedVector2Array()
	for i: int in range(10):
		var t: float = float(i) / 9.0
		tail.append(Vector2(-r * (0.65 + t * 0.95), sin(phase * 7.5 + t * 6.0) * r * 0.28))
	draw_polyline(tail, Color(acc.r, acc.g, acc.b, 0.72), maxf(1.2, r * 0.09), true)
	# Capsule body
	_draw_ellipse(Vector2.ZERO, r * 0.82, r * 0.44, col)
	draw_circle(Vector2(r * 0.25, -r * 0.08), r * 0.13, acc)
	draw_circle(Vector2(-r * 0.18, r * 0.1), r * 0.11, acc)


func _draw_amoeba(r: float, col: Color, acc: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var count: int = 20
	pts.resize(count)
	for i: int in range(count):
		var ang: float = (float(i) / float(count)) * TAU
		var wobble: float = 0.76 + 0.18 * sin(ang * 3.0 + phase * 2.2) + 0.10 * cos(ang * 5.0 - phase * 1.7)
		pts[i] = Vector2(cos(ang), sin(ang)) * (r * wobble)
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.72))
	pts.append(pts[0])
	draw_polyline(pts, Color(acc.r, acc.g, acc.b, 0.85), maxf(1.3, r * 0.07), true)
	draw_circle(Vector2(r * 0.1, -r * 0.06), r * 0.26, col.darkened(0.15))
	draw_circle(Vector2(-r * 0.22, r * 0.18), r * 0.13, acc)


func _draw_diatom(r: float, col: Color, acc: Color) -> void:
	var diamond: PackedVector2Array = PackedVector2Array([
		Vector2(r * 1.05, 0.0),
		Vector2(0.0, r * 0.56),
		Vector2(-r * 1.05, 0.0),
		Vector2(0.0, -r * 0.56),
	])
	draw_colored_polygon(diamond, Color(col.r, col.g, col.b, 0.88))
	diamond.append(diamond[0])
	draw_polyline(diamond, acc, maxf(1.4, r * 0.08), true)
	draw_line(Vector2(-r * 0.85, 0.0), Vector2(r * 0.85, 0.0), acc, maxf(1.2, r * 0.07), true)
	for rib: float in [-0.45, 0.0, 0.45]:
		var rx: float = r * rib
		var ry: float = r * (0.48 - absf(rib) * 0.55)
		draw_line(Vector2(rx, -ry), Vector2(rx, ry), Color(acc.r, acc.g, acc.b, 0.65), maxf(1.0, r * 0.055), true)


func _draw_tardigrade(r: float, col: Color, acc: Color) -> void:
	# 4 pairs of stubby little water-bear legs
	var leg_col: Color = col.darkened(0.16)
	for i: int in range(4):
		var lx: float = r * (0.42 - float(i) * 0.30)
		var kick: float = sin(phase * 5.0 + float(i) * 1.5) * r * 0.08
		draw_circle(Vector2(lx + kick, -r * 0.56), r * 0.17, leg_col)
		draw_circle(Vector2(lx - kick, r * 0.56), r * 0.17, leg_col)
	# Plump segmented body
	_draw_ellipse(Vector2(-r * 0.1, 0.0), r * 0.88, r * 0.56, col)
	for s: float in [-0.35, 0.0, 0.32]:
		draw_arc(Vector2(r * s, 0.0), r * 0.52, -0.75, 0.75, 10, Color(acc.r, acc.g, acc.b, 0.45), maxf(1.2, r * 0.06), true)
	# Round snout + eyes
	draw_circle(Vector2(r * 0.76, 0.0), r * 0.24, acc)
	draw_circle(Vector2(r * 0.84, 0.0), r * 0.10, Color(0.24, 0.08, 0.06))
	draw_circle(Vector2(r * 0.54, -r * 0.2), r * 0.09, Color(0.18, 0.05, 0.08))
	draw_circle(Vector2(r * 0.54, r * 0.2), r * 0.09, Color(0.18, 0.05, 0.08))


# --- Scale 2: Forest ---

func _draw_ant(r: float, col: Color, acc: Color) -> void:
	var leg_w: float = maxf(1.2, r * 0.075)
	for i: int in range(3):
		var lx: float = r * (0.22 - float(i) * 0.28)
		var step_v: float = sin(phase * 8.0 + float(i) * 2.0) * r * 0.12
		draw_line(Vector2(lx, 0.0), Vector2(lx + step_v, -r * 0.65), col.darkened(0.25), leg_w, true)
		draw_line(Vector2(lx, 0.0), Vector2(lx - step_v, r * 0.65), col.darkened(0.25), leg_w, true)
	# Antennae
	draw_line(Vector2(r * 0.62, -r * 0.12), Vector2(r * 1.0, -r * 0.38), acc, leg_w, true)
	draw_line(Vector2(r * 0.62, r * 0.12), Vector2(r * 1.0, r * 0.38), acc, leg_w, true)
	# Abdomen, thorax, head
	_draw_ellipse(Vector2(-r * 0.52, 0.0), r * 0.42, r * 0.32, col)
	_draw_ellipse(Vector2(0.0, 0.0), r * 0.28, r * 0.22, col.lightened(0.08))
	draw_circle(Vector2(r * 0.48, 0.0), r * 0.26, col)
	draw_circle(Vector2(r * 0.58, -r * 0.1), r * 0.06, acc)
	draw_circle(Vector2(r * 0.58, r * 0.1), r * 0.06, acc)


func _draw_firefly(r: float, col: Color, acc: Color) -> void:
	var glow_pulse: float = 0.65 + 0.35 * sin(phase * 4.5)
	# Bioluminescent tail lantern
	draw_circle(Vector2(-r * 0.42, 0.0), r * (0.68 + 0.16 * glow_pulse), Color(col.r, col.g, col.b, 0.26 * glow_pulse))
	draw_circle(Vector2(-r * 0.42, 0.0), r * 0.38, col)
	draw_circle(Vector2(-r * 0.42, 0.0), r * 0.2, acc)
	# Fluttering translucent wings
	var flap: float = sin(phase * 16.0) * 0.28
	var wing_col: Color = Color(acc.r, acc.g, acc.b, 0.48)
	_draw_ellipse(Vector2(-r * 0.05, -r * (0.38 + flap * 0.3)), r * 0.46, r * 0.22, wing_col)
	_draw_ellipse(Vector2(-r * 0.05, r * (0.38 + flap * 0.3)), r * 0.46, r * 0.22, wing_col)
	# Dark thorax & head
	_draw_ellipse(Vector2(r * 0.18, 0.0), r * 0.36, r * 0.24, Color(0.22, 0.18, 0.16))
	draw_circle(Vector2(r * 0.54, 0.0), r * 0.18, Color(0.16, 0.12, 0.12))


func _draw_ladybug(r: float, col: Color, acc: Color) -> void:
	# Dome red shell
	_draw_ellipse(Vector2(-r * 0.08, 0.0), r * 0.78, r * 0.68, col)
	# Dark head
	draw_circle(Vector2(r * 0.64, 0.0), r * 0.30, Color(0.12, 0.10, 0.14))
	# Center wing seam + polka dots
	draw_line(Vector2(-r * 0.84, 0.0), Vector2(r * 0.46, 0.0), Color(0.12, 0.10, 0.14), maxf(1.5, r * 0.08), true)
	var spots: Array[Vector2] = [
		Vector2(-r * 0.35, -r * 0.28), Vector2(-r * 0.35, r * 0.28),
		Vector2(r * 0.10, -r * 0.34), Vector2(r * 0.10, r * 0.34),
		Vector2(-r * 0.08, -r * 0.14), Vector2(-r * 0.08, r * 0.14),
	]
	for sp: Vector2 in spots:
		draw_circle(sp, r * 0.11, Color(0.12, 0.10, 0.14))
	draw_circle(Vector2(r * 0.72, -r * 0.12), r * 0.07, acc)
	draw_circle(Vector2(r * 0.72, r * 0.12), r * 0.07, acc)


func _draw_moth(r: float, col: Color, acc: Color) -> void:
	var flap: float = 0.72 + 0.28 * sin(phase * 9.0)
	# Upper & lower patterned wings
	_draw_ellipse(Vector2(r * 0.08, -r * 0.55 * flap), r * 0.56, r * 0.42 * flap, col)
	_draw_ellipse(Vector2(r * 0.08, r * 0.55 * flap), r * 0.56, r * 0.42 * flap, col)
	_draw_ellipse(Vector2(-r * 0.32, -r * 0.38 * flap), r * 0.38, r * 0.28 * flap, col.darkened(0.14))
	_draw_ellipse(Vector2(-r * 0.32, r * 0.38 * flap), r * 0.38, r * 0.28 * flap, col.darkened(0.14))
	# Wing eyespots
	draw_circle(Vector2(r * 0.14, -r * 0.56 * flap), r * 0.14, acc)
	draw_circle(Vector2(r * 0.14, r * 0.56 * flap), r * 0.14, acc)
	# Fuzzy body & feathery antennae
	_draw_ellipse(Vector2(0.0, 0.0), r * 0.62, r * 0.20, Color(0.32, 0.20, 0.12))
	draw_line(Vector2(r * 0.55, -r * 0.08), Vector2(r * 0.92, -r * 0.32), acc, maxf(1.4, r * 0.07), true)
	draw_line(Vector2(r * 0.55, r * 0.08), Vector2(r * 0.92, r * 0.32), acc, maxf(1.4, r * 0.07), true)


func _draw_frog(r: float, col: Color, acc: Color) -> void:
	var kick: float = sin(phase * 4.5) * r * 0.12
	# Folded hind legs
	_draw_ellipse(Vector2(-r * 0.42 - kick, -r * 0.52), r * 0.42, r * 0.24, col.darkened(0.16))
	_draw_ellipse(Vector2(-r * 0.42 - kick, r * 0.52), r * 0.42, r * 0.24, col.darkened(0.16))
	# Plump body
	_draw_ellipse(Vector2(0.0, 0.0), r * 0.82, r * 0.62, col)
	_draw_ellipse(Vector2(r * 0.08, 0.0), r * 0.52, r * 0.38, Color(acc.r, acc.g, acc.b, 0.35))
	# Bulging frog eyes
	for sy: float in [-1.0, 1.0]:
		var ep: Vector2 = Vector2(r * 0.56, sy * r * 0.36)
		draw_circle(ep, r * 0.24, col.lightened(0.12))
		draw_circle(ep + Vector2(r * 0.04, 0.0), r * 0.16, Color(0.98, 0.92, 0.45))
		draw_circle(ep + Vector2(r * 0.08, 0.0), r * 0.09, Color(0.08, 0.10, 0.08))


# --- Scale 3: City ---

func _draw_lantern(r: float, col: Color, acc: Color) -> void:
	var flicker: float = 0.85 + 0.15 * sin(phase * 6.0)
	draw_circle(Vector2.ZERO, r * 1.15, Color(col.r, col.g, col.b, 0.20 * flicker))
	# Floating paper sky-lantern body
	var poly: PackedVector2Array = PackedVector2Array([
		Vector2(-r * 0.52, -r * 0.74),
		Vector2(r * 0.52, -r * 0.74),
		Vector2(r * 0.68, 0.0),
		Vector2(r * 0.42, r * 0.68),
		Vector2(-r * 0.42, r * 0.68),
		Vector2(-r * 0.68, 0.0),
	])
	draw_colored_polygon(poly, col)
	draw_circle(Vector2(0.0, r * 0.12), r * 0.34 * flicker, acc)
	# Paper ribs & bottom rim
	draw_line(Vector2(-r * 0.42, r * 0.68), Vector2(r * 0.42, r * 0.68), Color(0.45, 0.22, 0.12), maxf(1.8, r * 0.09), true)
	draw_line(Vector2(0.0, r * 0.68), Vector2(0.0, r * 1.02), acc, maxf(1.4, r * 0.07), true)


func _draw_owl(r: float, col: Color, acc: Color) -> void:
	var flap: float = sin(phase * 7.0) * r * 0.16
	# Wings
	_draw_ellipse(Vector2(-r * 0.12, -r * 0.58 - flap * 0.4), r * 0.58, r * 0.26, col.darkened(0.15))
	_draw_ellipse(Vector2(-r * 0.12, r * 0.58 + flap * 0.4), r * 0.58, r * 0.26, col.darkened(0.15))
	# Body & head
	_draw_ellipse(Vector2(0.0, 0.0), r * 0.72, r * 0.48, col)
	# Big golden nocturnal eyes
	for sy: float in [-1.0, 1.0]:
		var ep: Vector2 = Vector2(r * 0.42, sy * r * 0.22)
		draw_circle(ep, r * 0.20, acc)
		draw_circle(ep + Vector2(r * 0.04, 0.0), r * 0.10, Color(0.10, 0.08, 0.12))
	# Small beak
	var beak: PackedVector2Array = PackedVector2Array([
		Vector2(r * 0.62, -r * 0.10),
		Vector2(r * 0.88, 0.0),
		Vector2(r * 0.62, r * 0.10),
	])
	draw_colored_polygon(beak, Color(0.96, 0.74, 0.25))


func _draw_car(r: float, col: Color, acc: Color) -> void:
	# Glowing headlight beams
	var beam_col: Color = Color(acc.r, acc.g, acc.b, 0.26)
	for sy: float in [-1.0, 1.0]:
		var beam: PackedVector2Array = PackedVector2Array([
			Vector2(r * 0.88, sy * r * 0.28),
			Vector2(r * 1.75, sy * r * 0.62),
			Vector2(r * 1.75, sy * r * 0.06),
		])
		draw_colored_polygon(beam, beam_col)
	# Chassis
	var chassis: Rect2 = Rect2(Vector2(-r * 0.90, -r * 0.48), Vector2(r * 1.80, r * 0.96))
	draw_rect(chassis, col, true)
	# Cabin / windshield
	var cabin: Rect2 = Rect2(Vector2(-r * 0.35, -r * 0.36), Vector2(r * 0.76, r * 0.72))
	draw_rect(cabin, Color(0.82, 0.94, 1.0, 0.88), true)
	# Headlights & taillights
	draw_circle(Vector2(r * 0.88, -r * 0.30), r * 0.11, acc)
	draw_circle(Vector2(r * 0.88, r * 0.30), r * 0.11, acc)
	draw_circle(Vector2(-r * 0.88, -r * 0.30), r * 0.09, Color(0.98, 0.30, 0.32))
	draw_circle(Vector2(-r * 0.88, r * 0.30), r * 0.09, Color(0.98, 0.30, 0.32))


func _draw_helicopter(r: float, col: Color, acc: Color) -> void:
	# Tail boom & stabilizer
	draw_line(Vector2(-r * 0.3, 0.0), Vector2(-r * 1.15, 0.0), col.darkened(0.15), maxf(2.4, r * 0.18), true)
	draw_line(Vector2(-r * 1.12, -r * 0.24), Vector2(-r * 1.12, r * 0.24), acc, maxf(1.8, r * 0.10), true)
	# Fuselage + glowing cockpit
	_draw_ellipse(Vector2(r * 0.12, 0.0), r * 0.68, r * 0.40, col)
	_draw_ellipse(Vector2(r * 0.46, 0.0), r * 0.30, r * 0.26, acc)
	# Spinning top rotor disc + blades
	draw_circle(Vector2(r * 0.10, 0.0), r * 0.92, Color(acc.r, acc.g, acc.b, 0.14))
	var rotor_ang: float = phase * 18.0
	for i: int in range(2):
		var a: float = rotor_ang + float(i) * (PI * 0.5)
		var tip: Vector2 = Vector2.from_angle(a) * (r * 0.92)
		draw_line(Vector2(r * 0.10, 0.0) - tip, Vector2(r * 0.10, 0.0) + tip, Color(0.92, 0.96, 1.0, 0.78), maxf(1.8, r * 0.09), true)
	draw_circle(Vector2(r * 0.10, 0.0), r * 0.12, Color(0.20, 0.24, 0.30))


func _draw_blimp(r: float, col: Color, acc: Color) -> void:
	# Tail fins
	var fin_top: PackedVector2Array = PackedVector2Array([
		Vector2(-r * 0.65, -r * 0.25),
		Vector2(-r * 1.08, -r * 0.62),
		Vector2(-r * 0.98, -r * 0.12),
	])
	var fin_bot: PackedVector2Array = PackedVector2Array([
		Vector2(-r * 0.65, r * 0.25),
		Vector2(-r * 1.08, r * 0.62),
		Vector2(-r * 0.98, r * 0.12),
	])
	draw_colored_polygon(fin_top, col.darkened(0.22))
	draw_colored_polygon(fin_bot, col.darkened(0.22))
	# Grand dirigible hull
	_draw_ellipse(Vector2(0.0, 0.0), r * 1.02, r * 0.56, col)
	_draw_ellipse(Vector2(0.0, 0.0), r * 0.94, r * 0.16, Color(acc.r, acc.g, acc.b, 0.38))
	# Glowing porthole lights
	for i: int in range(3):
		var px: float = r * (0.45 - float(i) * 0.42)
		draw_circle(Vector2(px, 0.0), r * 0.09, acc)


# --- Scale 4: Planetary ---

func _draw_asteroid(r: float, col: Color, acc: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var sides: int = 9
	pts.resize(sides)
	for i: int in range(sides):
		var ang: float = (float(i) / float(sides)) * TAU + phase * 0.35
		var rad: float = r * (0.76 + 0.20 * sin(float(i) * 2.7))
		pts[i] = Vector2(cos(ang) * rad, sin(ang) * rad)
	draw_colored_polygon(pts, col)
	draw_circle(Vector2(-r * 0.22, -r * 0.15), r * 0.22, col.darkened(0.26))
	draw_circle(Vector2(r * 0.24, r * 0.20), r * 0.15, col.darkened(0.22))
	draw_circle(Vector2(r * 0.16, -r * 0.26), r * 0.10, acc)


func _draw_comet(r: float, col: Color, acc: Color) -> void:
	# Twin glowing sweeping tails opposite heading
	var dust_tail: PackedVector2Array = PackedVector2Array([
		Vector2(r * 0.15, -r * 0.36),
		Vector2(-r * 1.95, -r * 0.18 + sin(phase * 4.0) * r * 0.10),
		Vector2(-r * 1.75, r * 0.26),
		Vector2(r * 0.15, r * 0.36),
	])
	draw_colored_polygon(dust_tail, Color(col.r, col.g, col.b, 0.32))
	var ion_tail: PackedVector2Array = PackedVector2Array([
		Vector2(r * 0.15, -r * 0.18),
		Vector2(-r * 2.25, 0.0),
		Vector2(r * 0.15, r * 0.18),
	])
	draw_colored_polygon(ion_tail, Color(acc.r, acc.g, acc.b, 0.50))
	draw_circle(Vector2.ZERO, r * 0.56, col)
	draw_circle(Vector2(r * 0.10, -r * 0.08), r * 0.28, acc)


func _draw_moon(r: float, col: Color, acc: Color) -> void:
	draw_circle(Vector2.ZERO, r * 0.94, Color(col.r, col.g, col.b, 0.18))
	draw_circle(Vector2.ZERO, r * 0.80, col)
	draw_circle(Vector2(-r * 0.24, -r * 0.18), r * 0.18, col.darkened(0.20))
	draw_circle(Vector2(r * 0.20, r * 0.24), r * 0.14, col.darkened(0.18))
	draw_circle(Vector2(r * 0.18, -r * 0.26), r * 0.10, col.darkened(0.15))
	# Soft luminous rim
	draw_arc(Vector2.ZERO, r * 0.78, -PI * 0.85, -PI * 0.15, 16, Color(acc.r, acc.g, acc.b, 0.65), maxf(1.5, r * 0.08), true)


func _draw_planet(r: float, col: Color, acc: Color) -> void:
	draw_circle(Vector2.ZERO, r * 0.98, Color(col.r, col.g, col.b, 0.20))
	draw_circle(Vector2.ZERO, r * 0.84, col)
	# Continents
	_draw_ellipse(Vector2(-r * 0.22, -r * 0.16), r * 0.34, r * 0.22, acc)
	_draw_ellipse(Vector2(r * 0.26, r * 0.22), r * 0.28, r * 0.20, acc)
	# Wispy cloud band
	_draw_ellipse(Vector2(r * 0.06, -r * 0.36), r * 0.44, r * 0.10, Color(1.0, 1.0, 1.0, 0.52))
	_draw_ellipse(Vector2(-r * 0.14, r * 0.36), r * 0.36, r * 0.09, Color(1.0, 1.0, 1.0, 0.42))


func _draw_ringed(r: float, col: Color, acc: Color) -> void:
	var tilt: float = -0.32
	# Back ring
	_draw_ellipse_outline(Vector2.ZERO, r * 1.48, r * 0.42, Color(acc.r, acc.g, acc.b, 0.65), maxf(2.4, r * 0.14), tilt)
	# Banded gas giant sphere
	draw_circle(Vector2.ZERO, r * 0.78, col)
	_draw_ellipse(Vector2(0.0, -r * 0.18), r * 0.72, r * 0.12, Color(acc.r, acc.g, acc.b, 0.42))
	_draw_ellipse(Vector2(0.0, r * 0.20), r * 0.68, r * 0.12, col.darkened(0.20))
	# Front ring arc
	var pts: PackedVector2Array = PackedVector2Array()
	var c: float = cos(tilt)
	var s: float = sin(tilt)
	for i: int in range(15):
		var ang: float = (float(i) / 14.0) * PI
		var lx: float = cos(ang) * r * 1.48
		var ly: float = sin(ang) * r * 0.42
		pts.append(Vector2(lx * c - ly * s, lx * s + ly * c))
	draw_polyline(pts, acc, maxf(2.4, r * 0.14), true)


# --- Scale 5: Cosmic ---

func _draw_star(r: float, col: Color, acc: Color) -> void:
	var pulse: float = 0.92 + 0.10 * sin(phase * 3.8)
	draw_circle(Vector2.ZERO, r * 1.15 * pulse, Color(col.r, col.g, col.b, 0.22))
	_draw_star_poly(Vector2.ZERO, r * 1.05 * pulse, r * 0.46, 8, col, phase * 0.4)
	draw_circle(Vector2.ZERO, r * 0.46, acc)


func _draw_nebula(r: float, col: Color, acc: Color) -> void:
	var puffs: Array[Vector2] = [
		Vector2(-r * 0.34, -r * 0.18),
		Vector2(r * 0.30, -r * 0.22),
		Vector2(r * 0.18, r * 0.28),
		Vector2(-r * 0.26, r * 0.24),
		Vector2.ZERO,
	]
	for i: int in range(puffs.size()):
		var p: Vector2 = puffs[i] + Vector2(cos(phase + float(i)), sin(phase * 0.8 + float(i))) * (r * 0.06)
		var puff_col: Color = col if (i % 2 == 0) else acc
		draw_circle(p, r * (0.58 if i == 4 else 0.46), Color(puff_col.r, puff_col.g, puff_col.b, 0.34))
	# Embedded twinkling stars
	_draw_star_poly(Vector2(-r * 0.22, -r * 0.12), r * 0.16, r * 0.06, 4, Color.WHITE, phase)
	_draw_star_poly(Vector2(r * 0.26, r * 0.14), r * 0.12, r * 0.05, 4, Color.WHITE, -phase)


func _draw_solar(r: float, col: Color, acc: Color) -> void:
	var orbit_col: Color = Color(acc.r, acc.g, acc.b, 0.36)
	draw_arc(Vector2.ZERO, r * 0.62, 0.0, TAU, 24, orbit_col, maxf(1.2, r * 0.05), true)
	draw_arc(Vector2.ZERO, r * 0.98, 0.0, TAU, 28, orbit_col, maxf(1.2, r * 0.05), true)
	# Central sun
	draw_circle(Vector2.ZERO, r * 0.36, col)
	draw_circle(Vector2.ZERO, r * 0.20, Color.WHITE)
	# Orbiting planets
	var p1: Vector2 = Vector2.from_angle(phase * 1.9) * (r * 0.62)
	var p2: Vector2 = Vector2.from_angle(-phase * 1.1 + 1.4) * (r * 0.98)
	draw_circle(p1, r * 0.12, acc)
	draw_circle(p2, r * 0.16, col.lerp(acc, 0.5))


func _draw_blackhole(r: float, col: Color, acc: Color) -> void:
	# Fiery swirling accretion disk
	draw_circle(Vector2.ZERO, r * 1.12, Color(col.r, col.g, col.b, 0.22))
	_draw_ellipse_outline(Vector2.ZERO, r * 1.24, r * 0.44, col, maxf(2.6, r * 0.18), -0.25 + sin(phase) * 0.05)
	_draw_ellipse_outline(Vector2.ZERO, r * 1.02, r * 0.34, acc, maxf(1.6, r * 0.09), -0.25)
	# Photon ring + pitch-black event horizon
	draw_circle(Vector2.ZERO, r * 0.64, acc)
	draw_circle(Vector2.ZERO, r * 0.56, Color(0.02, 0.02, 0.04, 1.0))


func _draw_galaxy(r: float, col: Color, acc: Color) -> void:
	draw_circle(Vector2.ZERO, r * 1.05, Color(col.r, col.g, col.b, 0.18))
	# Two sweeping starry spiral arms
	for arm: int in range(2):
		var base_ang: float = float(arm) * PI + phase * 0.45
		var arm_pts: PackedVector2Array = PackedVector2Array()
		for i: int in range(14):
			var t: float = float(i) / 13.0
			var ang: float = base_ang + t * 2.8
			var rad: float = r * (0.15 + t * 0.98)
			arm_pts.append(Vector2(cos(ang) * rad, sin(ang) * rad * 0.72))
		draw_polyline(arm_pts, Color(col.r, col.g, col.b, 0.72), maxf(2.0, r * 0.16), true)
		for s_idx: int in [4, 8, 12]:
			draw_circle(arm_pts[s_idx], r * 0.08, acc)
	# Bright golden galactic core
	draw_circle(Vector2.ZERO, r * 0.34, acc)
	draw_circle(Vector2.ZERO, r * 0.18, Color.WHITE)
