class_name Charlie
extends Node2D
## Player entity: la petite Charlie, a bioluminescent lava-lamp droplet with two little white teeth.

const LAVA_SHADER_PATH: String = "res://shaders/lava_blob.gdshader"
const MAX_DROPLETS: int = 3
const BODY_QUAD_SCALE: float = 5.2
const BODY_HALF_SCALE: float = 2.6

const COLOR_EYE_DARK: Color = Color("#2a1215")
const COLOR_IRIS_SHEEN: Color = Color(0.68, 0.34, 0.16, 0.56)
const COLOR_SCLERA: Color = Color(1.0, 0.985, 0.97, 0.98)
const COLOR_MOUTH_FILL: Color = Color(0.24, 0.06, 0.12, 1.0)
const COLOR_TONGUE: Color = Color("#ff7d9e")
const COLOR_CHEEK_OUTER: Color = Color(1.0, 0.44, 0.54, 0.26)
const COLOR_CHEEK_INNER: Color = Color(1.0, 0.42, 0.52, 0.38)
const COLOR_TEETH: Color = Color(1.0, 0.99, 0.96, 1.0)
const COLOR_CATCHLIGHT: Color = Color(1.0, 1.0, 1.0, 0.95)

var world_size: float = Scales.BASE_SIZE
var velocity: Vector2 = Vector2.ZERO
var facing_angle: float = 0.0
var invuln_timer: float = 0.0
var droplets_alive: int = MAX_DROPLETS

var look_angle: float = 0.0
var happy_timer: float = 0.0
var chomp_timer: float = 0.0
var dash_timer: float = 0.0
var scared_amount: float = 0.0
var danger_level: float = 0.0
var mouth_open: float = 0.0
var blink_amount: float = 0.0

var _body_rect: ColorRect = null
var _body_mat: ShaderMaterial = null
var _face_overlay: _CharlieFaceOverlay = null

var _time: float = 0.0
var _stretch: float = 0.0
var _gulp_wave: float = 0.0
var _danger_pulse: float = 0.0
var _blink_cooldown: float = 2.8
var _blink_phase: float = 0.0
var _dash_boost_mult: float = 1.0
var _face_tilt: float = 0.0
var _last_synced_size: float = -1.0

var _palette_core: Color = Color(1.0, 0.78, 0.50, 1.0)
var _palette_edge: Color = Color(0.96, 0.38, 0.42, 1.0)
var _palette_glow: Color = Color(1.0, 0.50, 0.28, 1.0)

var _drop_world_pos: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _drop_world_vel: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _drop_local_uv: Array[Vector2] = [
	Vector2(-0.55, -0.25),
	Vector2(-0.62, 0.0),
	Vector2(-0.55, 0.25),
]
var _drop_scales: Array[float] = [1.0, 1.0, 1.0]
var _prev_droplets_alive: int = MAX_DROPLETS


class _CharlieFaceOverlay extends Node2D:
	var owner_charlie: Charlie = null

	func _draw() -> void:
		if owner_charlie != null:
			owner_charlie._draw_face(self)


func _ready() -> void:
	_setup_visuals()
	reset_charlie(position, world_size)


func _setup_visuals() -> void:
	if _body_rect != null:
		return

	_body_rect = ColorRect.new()
	_body_rect.name = "LavaBody"
	_body_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_rect.color = Color.WHITE

	_body_mat = ShaderMaterial.new()
	var shader_res: Shader = load(LAVA_SHADER_PATH) as Shader
	if shader_res != null:
		_body_mat.shader = shader_res
	_body_rect.material = _body_mat
	add_child(_body_rect)

	_face_overlay = _CharlieFaceOverlay.new()
	_face_overlay.name = "FaceOverlay"
	_face_overlay.owner_charlie = self
	_face_overlay.z_index = 1
	add_child(_face_overlay)

	_last_synced_size = -1.0
	_sync_body_rect()


func set_palette(core: Color, edge: Color, glow: Color = Color(1.0, 0.50, 0.28, 1.0)) -> void:
	_palette_core = core
	_palette_edge = edge
	_palette_glow = glow
	if _body_mat != null:
		_body_mat.set_shader_parameter("core_color", _palette_core)
		_body_mat.set_shader_parameter("edge_color", _palette_edge)
		_body_mat.set_shader_parameter("glow_color", _palette_glow)


func reset_charlie(pos: Vector2, new_size: float) -> void:
	position = pos
	world_size = maxf(new_size, 4.0)
	velocity = Vector2.ZERO
	facing_angle = 0.0
	look_angle = 0.0
	invuln_timer = 0.0
	droplets_alive = MAX_DROPLETS
	_prev_droplets_alive = MAX_DROPLETS
	happy_timer = 0.0
	chomp_timer = 0.0
	dash_timer = 0.0
	scared_amount = 0.0
	danger_level = 0.0
	mouth_open = 0.0
	blink_amount = 0.0
	_stretch = 0.0
	_gulp_wave = 0.0
	_danger_pulse = 0.0
	_face_tilt = 0.0
	_blink_cooldown = randf_range(2.2, 4.4)
	_blink_phase = 0.0

	var rest_offsets: Array[Vector2] = _get_droplet_rest_offsets()
	for i: int in range(MAX_DROPLETS):
		_drop_local_uv[i] = rest_offsets[i]
		_drop_world_pos[i] = position + rest_offsets[i] * world_size
		_drop_world_vel[i] = Vector2.ZERO
		_drop_scales[i] = 1.0

	_sync_body_rect()
	_update_shader_uniforms({})
	if _face_overlay != null:
		_face_overlay.queue_redraw()


func trigger_chomp(prey_angle: float, intensity: float = 1.0) -> void:
	var clamped: float = clampf(intensity, 0.25, 1.5)
	look_angle = prey_angle
	chomp_timer = maxf(chomp_timer, 0.28 * clamped)
	happy_timer = maxf(happy_timer, 0.55 * minf(clamped, 1.2))
	_gulp_wave = maxf(_gulp_wave, 1.0 * clamped)
	mouth_open = 1.0


func trigger_dash(dir_angle: float, level: int = 1) -> void:
	var lvl: int = clampi(level, 1, 3)
	facing_angle = dir_angle
	look_angle = dir_angle
	dash_timer = 0.26 + 0.06 * float(lvl - 1)
	_dash_boost_mult = 2.0 + 0.35 * float(lvl - 1)
	var impulse_speed: float = world_size * (8.5 + 1.8 * float(lvl - 1))
	velocity = Vector2.from_angle(dir_angle) * impulse_speed
	_stretch = maxf(_stretch, 0.95)
	happy_timer = maxf(happy_timer, 0.25)


func trigger_hurt(away_angle: float) -> void:
	invuln_timer = 1.65
	scared_amount = 1.0
	danger_level = 1.0
	happy_timer = 0.0
	chomp_timer = 0.0
	_gulp_wave = 0.0
	_stretch = 0.8
	var knock_speed: float = world_size * 7.2
	velocity = Vector2.from_angle(away_angle) * knock_speed
	facing_angle = away_angle


func step_motion(
	dt: float,
	move_dir: Vector2,
	has_input: bool,
	nearest_prey: Variant,
	nearest_pred: Variant,
	palette: Dictionary
) -> void:
	var step_dt: float = clampf(dt, 0.0, 0.05)
	_time += step_dt

	# Decay state timers
	invuln_timer = maxf(0.0, invuln_timer - step_dt)
	happy_timer = maxf(0.0, happy_timer - step_dt)
	chomp_timer = maxf(0.0, chomp_timer - step_dt)
	dash_timer = maxf(0.0, dash_timer - step_dt)
	_gulp_wave = maxf(0.0, _gulp_wave - step_dt * 3.4)

	# Scale-invariant swimming physics
	var base_max_speed: float = world_size * 5.6
	var active_max_speed: float = base_max_speed * (_dash_boost_mult if dash_timer > 0.0 else 1.0)

	if has_input and move_dir.length_squared() > 0.0004:
		var clamped_input: Vector2 = move_dir if move_dir.length_squared() <= 1.0 else move_dir.normalized()
		var desired_vel: Vector2 = clamped_input * active_max_speed
		var accel_rate: float = 11.5 if dash_timer > 0.0 else 8.8
		velocity = velocity.lerp(desired_vel, 1.0 - exp(-accel_rate * step_dt))
	else:
		var drag_rate: float = 4.6 if dash_timer > 0.0 else 5.8
		velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-drag_rate * step_dt))

	position += velocity * step_dt

	var speed: float = velocity.length()
	var speed_norm: float = clampf(speed / maxf(base_max_speed, 1.0), 0.0, 1.8)
	if speed > world_size * 0.25:
		facing_angle = lerp_angle(facing_angle, velocity.angle(), 1.0 - exp(-12.0 * step_dt))

	var target_stretch: float = clampf(speed_norm * 0.65, 0.0, 1.15)
	_stretch = lerpf(_stretch, target_stretch, 1.0 - exp(-10.0 * step_dt))

	# Gentle playful face tilt following swim direction
	var swim_x_sign: float = 1.0 if cos(facing_angle) >= 0.0 else -1.0
	var vel_y_norm: float = clampf(velocity.y / maxf(base_max_speed, 1.0), -1.0, 1.0)
	var target_tilt: float = clampf(vel_y_norm * 0.14 * swim_x_sign, -0.16, 0.16)
	_face_tilt = lerpf(_face_tilt, target_tilt, 1.0 - exp(-9.0 * step_dt))

	# Expressive reactions to nearest prey & predator
	var prey_proximity: float = 0.0
	var prey_angle: float = facing_angle
	var prey_pos: Vector2 = _extract_entity_pos(nearest_prey)
	if not is_nan(prey_pos.x):
		var to_prey: Vector2 = prey_pos - position
		var prey_dist: float = to_prey.length()
		var react_range: float = world_size * 4.2
		if prey_dist < react_range:
			prey_proximity = clampf(1.0 - (prey_dist / react_range), 0.0, 1.0)
			prey_angle = to_prey.angle()

	var pred_threat: float = 0.0
	var pred_angle: float = facing_angle
	var pred_pos: Vector2 = _extract_entity_pos(nearest_pred)
	if not is_nan(pred_pos.x):
		var to_pred: Vector2 = pred_pos - position
		var pred_dist: float = to_pred.length()
		var pred_size: float = _extract_entity_size(nearest_pred)
		var scare_range: float = maxf(world_size * 4.6, pred_size * 3.4)
		if pred_dist < scare_range:
			pred_threat = clampf(1.0 - (pred_dist / scare_range), 0.0, 1.0)
			pred_angle = to_pred.angle()

	# Smooth look_angle tracking
	var target_look: float = facing_angle
	if chomp_timer > 0.0:
		target_look = look_angle
	elif pred_threat > 0.35:
		target_look = pred_angle
	elif prey_proximity > 0.15:
		target_look = prey_angle
	look_angle = lerp_angle(look_angle, target_look, 1.0 - exp(-10.0 * step_dt))

	# Scared, danger_level & mouth-open interpolation
	var target_scared: float = pred_threat if invuln_timer <= 0.0 else maxf(pred_threat, 0.65)
	scared_amount = lerpf(scared_amount, target_scared, 1.0 - exp(-9.0 * step_dt))
	danger_level = scared_amount

	var target_mouth: float = 0.0
	if chomp_timer > 0.0:
		target_mouth = clampf(sin((chomp_timer / 0.28) * PI), 0.25, 1.0)
	elif prey_proximity > 0.12 and danger_level < 0.55:
		target_mouth = clampf((prey_proximity - 0.12) * 1.15, 0.0, 0.92)
	mouth_open = lerpf(mouth_open, target_mouth, 1.0 - exp(-14.0 * step_dt))

	# Danger pulse when vulnerable (0 droplets left) or predator very close
	var target_danger: float = 1.0 if droplets_alive <= 0 else clampf((pred_threat - 0.55) * 1.6, 0.0, 0.7)
	_danger_pulse = lerpf(_danger_pulse, target_danger, 1.0 - exp(-8.0 * step_dt))

	# Periodic cute blink
	_step_blink(step_dt)

	# Spring-lag physics & heal-bloom scaling for tethered lava droplets
	_step_droplets(step_dt)

	# Sync visuals & shader uniforms
	_sync_body_rect()
	_update_shader_uniforms(palette)
	if _face_overlay != null:
		_face_overlay.queue_redraw()


func _step_blink(dt: float) -> void:
	if happy_timer > 0.0 or danger_level > 0.45:
		blink_amount = 0.0
		_blink_phase = 0.0
		return

	if _blink_phase > 0.0:
		_blink_phase += dt / 0.16
		if _blink_phase >= 1.0:
			_blink_phase = 0.0
			blink_amount = 0.0
			_blink_cooldown = randf_range(2.6, 5.2)
		else:
			blink_amount = sin(_blink_phase * PI)
	else:
		_blink_cooldown -= dt
		if _blink_cooldown <= 0.0:
			_blink_phase = 0.001


func _get_droplet_rest_offsets() -> Array[Vector2]:
	var back: Vector2 = Vector2(-cos(facing_angle), -sin(facing_angle))
	var perp: Vector2 = Vector2(-back.y, back.x)
	var bob0: float = sin(_time * 3.1) * 0.06
	var bob1: float = cos(_time * 2.5 + 1.4) * 0.07
	var bob2: float = sin(_time * 2.9 + 2.7) * 0.06
	return [
		back * (0.68 + bob0) + perp * (-0.32 + bob1 * 0.5),
		back * (0.86 + bob1) + perp * (bob0 * 0.4),
		back * (0.68 + bob2) + perp * (0.32 - bob1 * 0.5),
	]


func _step_droplets(dt: float) -> void:
	var rest_offsets: Array[Vector2] = _get_droplet_rest_offsets()
	var safe_size: float = maxf(world_size, 1.0)
	var stiffness_values: Array[float] = [95.0, 72.0, 90.0]
	var damping_values: Array[float] = [11.5, 9.8, 11.2]
	var alive_clamped: int = clampi(droplets_alive, 0, MAX_DROPLETS)

	# Detect regenerated droplets and trigger smooth heal-bloom (0.08 -> 1.0)
	if alive_clamped > _prev_droplets_alive:
		for i: int in range(maxi(_prev_droplets_alive, 0), alive_clamped):
			_drop_scales[i] = 0.08
			_drop_world_pos[i] = position + rest_offsets[i] * safe_size * 0.35
			_drop_world_vel[i] = Vector2.ZERO
	_prev_droplets_alive = alive_clamped

	for i: int in range(MAX_DROPLETS):
		if i < alive_clamped:
			if _drop_scales[i] < 0.999:
				_drop_scales[i] = lerpf(_drop_scales[i], 1.0, 1.0 - exp(-7.5 * dt))
				if _drop_scales[i] > 0.995:
					_drop_scales[i] = 1.0
		else:
			_drop_scales[i] = 0.0

		var target_world: Vector2 = position + rest_offsets[i] * safe_size
		var disp: Vector2 = target_world - _drop_world_pos[i]
		var accel: Vector2 = disp * stiffness_values[i] - _drop_world_vel[i] * damping_values[i]
		_drop_world_vel[i] += accel * dt
		_drop_world_pos[i] += _drop_world_vel[i] * dt

		# Convert back to local shader space (-2.6..2.6) and clamp within metaball quad
		var local_uv: Vector2 = (_drop_world_pos[i] - position) / safe_size
		var max_dist: float = 1.48
		if local_uv.length() > max_dist:
			local_uv = local_uv.normalized() * max_dist
			_drop_world_pos[i] = position + local_uv * safe_size
		_drop_local_uv[i] = local_uv


func _sync_body_rect() -> void:
	if _body_rect == null:
		return
	if is_equal_approx(world_size, _last_synced_size):
		return
	_last_synced_size = world_size
	var rect_len: float = world_size * BODY_QUAD_SCALE
	var half_len: float = world_size * BODY_HALF_SCALE
	_body_rect.size = Vector2(rect_len, rect_len)
	_body_rect.position = Vector2(-half_len, -half_len)


func _update_shader_uniforms(palette: Dictionary) -> void:
	if _body_mat == null:
		return

	var core_col: Color = palette.get("blob_core", _palette_core) as Color
	var edge_col: Color = palette.get("blob_edge", _palette_edge) as Color
	var glow_col: Color = palette.get("blob_glow", _palette_glow) as Color
	_palette_core = core_col
	_palette_edge = edge_col
	_palette_glow = glow_col

	var vel_dir: Vector2 = velocity.normalized() if velocity.length_squared() > 1.0 else Vector2.from_angle(facing_angle)
	var invuln_flash: float = 0.0
	if invuln_timer > 0.0:
		invuln_flash = 0.5 + 0.5 * sin(_time * 26.0)

	_body_mat.set_shader_parameter("core_color", core_col)
	_body_mat.set_shader_parameter("edge_color", edge_col)
	_body_mat.set_shader_parameter("glow_color", glow_col)
	_body_mat.set_shader_parameter("vel_dir", vel_dir)
	_body_mat.set_shader_parameter("stretch", _stretch)
	_body_mat.set_shader_parameter("gulp_wave", _gulp_wave)
	_body_mat.set_shader_parameter("danger_pulse", _danger_pulse)
	_body_mat.set_shader_parameter("invuln_flash", invuln_flash)
	_body_mat.set_shader_parameter("droplet_count", clampi(droplets_alive, 0, MAX_DROPLETS))
	_body_mat.set_shader_parameter("drop_pos_0", _drop_local_uv[0])
	_body_mat.set_shader_parameter("drop_pos_1", _drop_local_uv[1])
	_body_mat.set_shader_parameter("drop_pos_2", _drop_local_uv[2])
	_body_mat.set_shader_parameter("drop_scale_0", _drop_scales[0])
	_body_mat.set_shader_parameter("drop_scale_1", _drop_scales[1])
	_body_mat.set_shader_parameter("drop_scale_2", _drop_scales[2])


func _draw_ellipse(
	canvas: CanvasItem,
	center: Vector2,
	rx: float,
	ry: float,
	fill_color: Color,
	segments: int = 20,
	outline_color: Color = Color(0, 0, 0, 0),
	outline_width: float = 0.0
) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	pts.resize(segments)
	for i: int in range(segments):
		var a: float = (float(i) / float(segments)) * TAU
		pts[i] = center + Vector2(cos(a) * rx, sin(a) * ry)
	canvas.draw_colored_polygon(pts, fill_color)
	if outline_width > 0.0 and outline_color.a > 0.001:
		var loop_pts: PackedVector2Array = PackedVector2Array(pts)
		loop_pts.append(pts[0])
		canvas.draw_polyline(loop_pts, outline_color, outline_width, true)


func _draw_rounded_tooth(
	canvas: CanvasItem,
	top_center: Vector2,
	tooth_w: float,
	tooth_h: float,
	outline_w: float
) -> void:
	var hw: float = tooth_w * 0.5
	var tip_r: float = minf(hw * 0.72, tooth_h * 0.45)
	var pts: PackedVector2Array = PackedVector2Array([
		top_center + Vector2(-hw, 0.0),
		top_center + Vector2(hw, 0.0),
		top_center + Vector2(hw * 0.86, tooth_h - tip_r),
		top_center + Vector2(hw * 0.46, tooth_h - tip_r * 0.22),
		top_center + Vector2(0.0, tooth_h),
		top_center + Vector2(-hw * 0.46, tooth_h - tip_r * 0.22),
		top_center + Vector2(-hw * 0.86, tooth_h - tip_r),
	])
	canvas.draw_colored_polygon(pts, COLOR_TEETH)
	var border: PackedVector2Array = PackedVector2Array(pts)
	border.append(pts[0])
	canvas.draw_polyline(border, COLOR_EYE_DARK, outline_w, true)


func _draw_face(canvas: CanvasItem) -> void:
	var r: float = world_size * 0.66
	if r < 2.0:
		return

	var look_vec: Vector2 = Vector2.from_angle(look_angle)
	var face_center: Vector2 = look_vec * (r * 0.22)

	# Apply gentle playful face tilt around face_center
	canvas.draw_set_transform(face_center, _face_tilt, Vector2.ONE)

	var eye_sep: float = r * 0.34
	var eye_y: float = -r * 0.07
	var left_eye: Vector2 = Vector2(-eye_sep, eye_y)
	var right_eye: Vector2 = Vector2(eye_sep, eye_y)
	var stroke_w: float = maxf(1.4, r * 0.055)

	# Soft layered elliptical rosy cheeks (2 concentric translucent ellipses each)
	var cheek_y: float = eye_y + r * 0.23
	for side_sign: float in [-1.0, 1.0]:
		var cheek_pos: Vector2 = Vector2(side_sign * eye_sep * 1.28, cheek_y)
		_draw_ellipse(canvas, cheek_pos, r * 0.21, r * 0.135, COLOR_CHEEK_OUTER, 18)
		_draw_ellipse(canvas, cheek_pos, r * 0.13, r * 0.082, COLOR_CHEEK_INNER, 16)

	# Eyes: happy ^ ^ crescents, white-sclera alarmed state, or storybook glossy oval eyes
	var eye_r: float = r * (0.195 + danger_level * 0.04)
	var alarmed: bool = danger_level > 0.45
	if happy_timer > 0.0:
		var arc_w: float = maxf(2.0, r * 0.092)
		canvas.draw_arc(left_eye + Vector2(0.0, eye_r * 0.24), eye_r * 0.86, PI * 1.14, PI * 1.86, 16, COLOR_EYE_DARK, arc_w, true)
		canvas.draw_arc(right_eye + Vector2(0.0, eye_r * 0.24), eye_r * 0.86, PI * 1.14, PI * 1.86, 16, COLOR_EYE_DARK, arc_w, true)
	elif alarmed:
		var pupil_shift: Vector2 = look_vec * (eye_r * 0.26)
		var sclera_rx: float = eye_r * 1.02
		var sclera_ry: float = eye_r * 1.22
		for eye_pos: Vector2 in [left_eye, right_eye]:
			_draw_ellipse(canvas, eye_pos, sclera_rx, sclera_ry, COLOR_SCLERA, 22, COLOR_EYE_DARK, stroke_w)
			var pupil_pos: Vector2 = eye_pos + pupil_shift
			_draw_ellipse(canvas, pupil_pos, eye_r * 0.56, eye_r * 0.66, COLOR_EYE_DARK, 18)
			canvas.draw_circle(pupil_pos + Vector2(-eye_r * 0.20, -eye_r * 0.24), eye_r * 0.22, COLOR_CATCHLIGHT)
	else:
		# Smooth continuous vertical-squash blink
		var open_y: float = clampf(1.0 - blink_amount * 0.92, 0.08, 1.0)
		var eye_rx: float = eye_r * 0.90
		var eye_ry: float = eye_r * 1.12 * open_y
		if open_y <= 0.14:
			var lid_w: float = maxf(1.8, r * 0.082)
			for eye_pos: Vector2 in [left_eye, right_eye]:
				canvas.draw_arc(eye_pos - Vector2(0.0, eye_r * 0.22), eye_rx * 0.95, PI * 0.18, PI * 0.82, 12, COLOR_EYE_DARK, lid_w, true)
		else:
			var pupil_shift: Vector2 = look_vec * (eye_r * 0.18)
			for eye_pos: Vector2 in [left_eye, right_eye]:
				# Vertically oval deep dark-chocolate eye
				_draw_ellipse(canvas, eye_pos, eye_rx, eye_ry, COLOR_EYE_DARK, 22)
				# Warm amber-chestnut lower iris sheen
				var sheen_pos: Vector2 = eye_pos + Vector2(pupil_shift.x * 0.35, eye_ry * 0.30)
				_draw_ellipse(canvas, sheen_pos, eye_rx * 0.64, eye_ry * 0.42, COLOR_IRIS_SHEEN, 16)
				# Crisp top-left primary catchlight + bottom-right secondary sparkle
				var hi_pos: Vector2 = eye_pos + pupil_shift * 0.40 + Vector2(-eye_rx * 0.32, -eye_ry * 0.34)
				_draw_ellipse(canvas, hi_pos, eye_r * 0.31, eye_r * 0.31 * open_y, COLOR_CATCHLIGHT, 14)
				var hi2_pos: Vector2 = eye_pos + Vector2(eye_rx * 0.30, eye_ry * 0.28)
				_draw_ellipse(canvas, hi2_pos, eye_r * 0.13, eye_r * 0.13 * open_y, COLOR_CATCHLIGHT, 10)

	# Expressive mouth with Charlie's two rounded dark-outlined white teeth
	var mouth_center: Vector2 = Vector2(0.0, r * 0.24)
	var tooth_outline: float = maxf(1.0, r * 0.036)
	if alarmed and mouth_open < 0.22:
		# Worried 'o' mouth with tiny peeking teeth
		var o_rx: float = r * 0.145
		var o_ry: float = r * 0.165
		var o_pos: Vector2 = mouth_center + Vector2(0.0, r * 0.04)
		_draw_ellipse(canvas, o_pos, o_rx, o_ry, COLOR_MOUTH_FILL, 18, COLOR_EYE_DARK, stroke_w)
		_draw_ellipse(canvas, o_pos + Vector2(0.0, o_ry * 0.42), o_rx * 0.56, o_ry * 0.34, COLOR_TONGUE, 12)
		var tiny_tw: float = o_rx * 0.48
		var tiny_th: float = o_ry * 0.44
		var lip_y: float = o_pos.y - o_ry * 0.72
		for side_sign: float in [-1.0, 1.0]:
			_draw_rounded_tooth(canvas, Vector2(side_sign * o_rx * 0.34, lip_y), tiny_tw, tiny_th, tooth_outline)
	elif mouth_open > 0.16:
		# Dark-berry outlined open mouth with bright pink tongue and rounded white teeth
		var mw: float = r * lerpf(0.25, 0.39, mouth_open)
		var mh: float = r * lerpf(0.11, 0.35, mouth_open)
		var top_y: float = mouth_center.y - mh * 0.28
		var mouth_pts: PackedVector2Array = PackedVector2Array()
		mouth_pts.append(Vector2(-mw, top_y))
		mouth_pts.append(Vector2(mw, top_y))
		var steps: int = 16
		for s: int in range(1, steps):
			var t_ang: float = (float(s) / float(steps)) * PI
			mouth_pts.append(Vector2(cos(t_ang) * mw, top_y + sin(t_ang) * mh * 1.15))
		canvas.draw_colored_polygon(mouth_pts, COLOR_MOUTH_FILL)

		# Bright pink tongue nestled in the lower cavity
		if mouth_open > 0.32:
			var tongue_rx: float = mw * 0.54
			var tongue_ry: float = mh * 0.36
			_draw_ellipse(canvas, Vector2(0.0, top_y + mh * 0.76), tongue_rx, tongue_ry, COLOR_TONGUE, 14)

		# Crisp dark-berry mouth outline
		var mouth_outline: PackedVector2Array = PackedVector2Array(mouth_pts)
		mouth_outline.append(mouth_pts[0])
		canvas.draw_polyline(mouth_outline, COLOR_EYE_DARK, stroke_w, true)

		# Two rounded dark-outlined white teeth anchored at the upper lip
		var tooth_w: float = mw * 0.30
		var tooth_h: float = maxf(mh * 0.44, r * 0.11)
		var tooth_gap: float = mw * 0.33
		for side_sign: float in [-1.0, 1.0]:
			_draw_rounded_tooth(canvas, Vector2(side_sign * tooth_gap, top_y), tooth_w, tooth_h, tooth_outline)
	else:
		# Relaxed cute smile with two rounded peeking white teeth
		var smile_w: float = r * 0.27
		var smile_h: float = r * 0.16
		var smile_lw: float = maxf(1.8, r * 0.08)
		canvas.draw_arc(
			mouth_center - Vector2(0.0, smile_h * 0.35),
			smile_w * 0.92,
			PI * 0.16,
			PI * 0.84,
			16,
			COLOR_EYE_DARK,
			smile_lw,
			true
		)
		var tooth_w: float = r * 0.088
		var tooth_h: float = r * 0.092
		var smile_top: float = mouth_center.y + smile_h * 0.14
		for side_sign: float in [-1.0, 1.0]:
			_draw_rounded_tooth(canvas, Vector2(side_sign * (smile_w * 0.36), smile_top), tooth_w, tooth_h, tooth_outline)

	# Reset transform so parent canvas state stays clean
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _extract_entity_pos(entity: Variant) -> Vector2:
	if entity == null:
		return Vector2(NAN, NAN)
	if entity is Node2D:
		var node: Node2D = entity as Node2D
		if is_instance_valid(node):
			return node.position
	elif entity is Dictionary:
		var dict: Dictionary = entity as Dictionary
		if dict.has("position") and dict["position"] is Vector2:
			return dict["position"] as Vector2
	return Vector2(NAN, NAN)


func _extract_entity_size(entity: Variant) -> float:
	if entity == null:
		return world_size
	if entity is Creature:
		return (entity as Creature).world_size
	if entity is Dictionary:
		var dict: Dictionary = entity as Dictionary
		if dict.has("world_size"):
			return float(dict["world_size"])
	return world_size
