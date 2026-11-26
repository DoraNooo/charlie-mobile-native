class_name Charlie
extends Node2D
## Player entity: la petite Charlie, a cohesive 2.5D translucent jiggly slime with two little white teeth.

const LAVA_SHADER_PATH: String = "res://shaders/lava_blob.gdshader"
const MAX_DROPLETS: int = 3
const BODY_QUAD_SCALE: float = 3.4
const BODY_HALF_SCALE: float = 1.7

const LOBE_COUNT: int = 5
const CORE_BASE_RADIUS: float = 0.46
const LOBE_MAX_OFFSET: float = 0.44
const PEARL_MAX_OFFSET: float = 0.34
const GULP_DURATION: float = 0.38

const LOBE_BASE_RADII: Array[float] = [0.30, 0.29, 0.29, 0.27, 0.27]
const LOBE_STIFFNESS: Array[float] = [95.0, 115.0, 115.0, 135.0, 135.0]
const LOBE_DAMPING: Array[float] = [8.5, 9.2, 9.2, 10.5, 10.5]
const LOBE_MASS: Array[float] = [0.42, 0.34, 0.34, 0.26, 0.26]
const LOBE_UNIFORM_NAMES: Array[StringName] = [&"lobe_0", &"lobe_1", &"lobe_2", &"lobe_3", &"lobe_4"]
const PEARL_UNIFORM_NAMES: Array[StringName] = [&"pearl_0", &"pearl_1", &"pearl_2"]

const COLOR_EYE_DARK: Color = Color("#2a1215")
const COLOR_IRIS_SHEEN: Color = Color(0.95, 0.56, 0.20, 0.68)
const COLOR_IRIS_GLOW: Color = Color(1.0, 0.74, 0.32, 0.42)
const COLOR_SCLERA: Color = Color(1.0, 0.985, 0.97, 0.98)
const COLOR_MOUTH_FILL: Color = Color(0.24, 0.06, 0.12, 1.0)
const COLOR_TONGUE: Color = Color("#ff7d9e")
const COLOR_CHEEK_OUTER: Color = Color(1.0, 0.46, 0.58, 0.24)
const COLOR_CHEEK_INNER: Color = Color(1.0, 0.44, 0.56, 0.36)
const COLOR_TEETH: Color = Color(1.0, 0.995, 0.97, 1.0)
const COLOR_CATCHLIGHT: Color = Color(1.0, 1.0, 1.0, 0.99)

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
var _danger_pulse: float = 0.0
var _invuln_flash: float = 0.0
var _core_radius: float = CORE_BASE_RADIUS
var _wobble_amp: float = 0.0
var _gulp_phase: float = -1.0
var _gulp_intensity: float = 0.0
var _blink_cooldown: float = 2.8
var _blink_phase: float = 0.0
var _dash_boost_mult: float = 1.0
var _face_tilt: float = 0.0
var _pop_scale: float = 0.0
var _pop_vel: float = 0.0
var _last_synced_size: float = -1.0
var _prev_velocity: Vector2 = Vector2.ZERO
var _prev_facing_angle: float = 0.0

var _palette_core: Color = Color(1.0, 0.78, 0.50, 1.0)
var _palette_edge: Color = Color(0.96, 0.38, 0.42, 1.0)
var _palette_glow: Color = Color(1.0, 0.50, 0.28, 1.0)

# 5 viscous spring-mass lobes in local shader space (0=rear tail, 1/2=flanks, 3/4=front lobes)
var _lobe_pos: Array[Vector2] = [
	Vector2(-0.24, 0.0),
	Vector2(-0.04, -0.24),
	Vector2(-0.04, 0.24),
	Vector2(0.20, -0.15),
	Vector2(0.20, 0.15),
]
var _lobe_vel: Array[Vector2] = [
	Vector2.ZERO,
	Vector2.ZERO,
	Vector2.ZERO,
	Vector2.ZERO,
	Vector2.ZERO,
]
var _lobe_rad: Array[float] = [0.30, 0.29, 0.29, 0.27, 0.27]

# 3 internal gelatinous vitality pearls orbiting inside Charlie's translucent belly
var _pearl_pos: Array[Vector2] = [
	Vector2(-0.14, -0.10),
	Vector2(-0.04, 0.16),
	Vector2(0.14, -0.05),
]
var _pearl_vel: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
var _pearl_scales: Array[float] = [1.0, 1.0, 1.0]
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
	_prev_velocity = Vector2.ZERO
	facing_angle = 0.0
	_prev_facing_angle = 0.0
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
	_danger_pulse = 0.0
	_invuln_flash = 0.0
	_core_radius = CORE_BASE_RADIUS
	_wobble_amp = 0.0
	_gulp_phase = -1.0
	_gulp_intensity = 0.0
	_face_tilt = 0.0
	_pop_scale = 0.0
	_pop_vel = 0.0
	scale = Vector2.ONE
	_blink_cooldown = randf_range(2.2, 4.4)
	_blink_phase = 0.0

	var rest_lobes: Array[Vector2] = _get_lobe_rest_offsets(0.0, 0.0, 0.0)
	for i: int in range(LOBE_COUNT):
		_lobe_pos[i] = rest_lobes[i]
		_lobe_vel[i] = Vector2.ZERO
		_lobe_rad[i] = LOBE_BASE_RADII[i]

	var rest_pearls: Array[Vector2] = _get_pearl_orbit_targets()
	for i: int in range(MAX_DROPLETS):
		_pearl_pos[i] = rest_pearls[i]
		_pearl_vel[i] = Vector2.ZERO
		_pearl_scales[i] = 1.0

	if _face_overlay != null:
		_face_overlay.modulate.a = 1.0

	_sync_body_rect()
	_update_shader_uniforms({})
	if _face_overlay != null:
		_face_overlay.queue_redraw()


func trigger_chomp(prey_angle: float, intensity: float = 1.0) -> void:
	var clamped: float = clampf(intensity, 0.25, 1.5)
	look_angle = prey_angle
	chomp_timer = maxf(chomp_timer, 0.28 * clamped)
	happy_timer = maxf(happy_timer, 0.55 * minf(clamped, 1.2))
	mouth_open = 1.0

	# Travelling chomp gulp bulge (0 -> 1 over GULP_DURATION)
	_gulp_phase = 0.0
	_gulp_intensity = maxf(_gulp_intensity, clamped)

	# Jelly impulse: front lobes snap forward/outward, flanks recoil slightly
	var chomp_fwd: Vector2 = Vector2.from_angle(prey_angle)
	var chomp_side: Vector2 = Vector2(-chomp_fwd.y, chomp_fwd.x)
	var imp: float = minf(clamped, 1.3)
	_lobe_vel[3] += (chomp_fwd * 1.65 - chomp_side * 1.15) * imp
	_lobe_vel[4] += (chomp_fwd * 1.65 + chomp_side * 1.15) * imp
	_lobe_vel[1] -= chomp_side * 0.75 * imp
	_lobe_vel[2] += chomp_side * 0.75 * imp
	_lobe_vel[0] -= chomp_fwd * 0.95 * imp
	_wobble_amp = maxf(_wobble_amp, 0.75 * imp)

	# Elastic chomp pop bounce
	var pop_boost: float = minf(clamped, 1.25)
	_pop_scale = maxf(_pop_scale, 0.16 * pop_boost)
	_pop_vel = maxf(_pop_vel, 0.45 * pop_boost)


func trigger_dash(dir_angle: float, level: int = 1) -> void:
	var lvl: int = clampi(level, 1, 3)
	facing_angle = dir_angle
	look_angle = dir_angle
	dash_timer = 0.26 + 0.06 * float(lvl - 1)
	_dash_boost_mult = 2.0 + 0.35 * float(lvl - 1)
	var impulse_speed: float = world_size * (10.8 + 2.2 * float(lvl - 1))
	velocity = Vector2.from_angle(dir_angle) * impulse_speed
	happy_timer = maxf(happy_timer, 0.25)

	# Viscous dash stretch impulse: front surges, rear trails, flanks pinch inward
	var d_fwd: Vector2 = Vector2.from_angle(dir_angle)
	var d_side: Vector2 = Vector2(-d_fwd.y, d_fwd.x)
	var lvl_scale: float = 1.0 + 0.22 * float(lvl - 1)
	_lobe_vel[0] -= d_fwd * (2.6 * lvl_scale)
	_lobe_vel[1] += (d_side * 1.25 - d_fwd * 0.95) * lvl_scale
	_lobe_vel[2] += (-d_side * 1.25 - d_fwd * 0.95) * lvl_scale
	_lobe_vel[3] += (d_fwd * 2.1 + d_side * 0.45) * lvl_scale
	_lobe_vel[4] += (d_fwd * 2.1 - d_side * 0.45) * lvl_scale
	_wobble_amp = maxf(_wobble_amp, 0.95)

	for i: int in range(MAX_DROPLETS):
		_pearl_vel[i] -= d_fwd * (1.35 * lvl_scale)


func trigger_hurt(away_angle: float) -> void:
	invuln_timer = 1.65
	scared_amount = 1.0
	danger_level = 1.0
	happy_timer = 0.0
	chomp_timer = 0.0
	_gulp_phase = -1.0
	_gulp_intensity = 0.0
	var knock_speed: float = world_size * 7.2
	velocity = Vector2.from_angle(away_angle) * knock_speed
	facing_angle = away_angle

	# Radial jelly shockwave + pearl scatter on impact
	var k_fwd: Vector2 = Vector2.from_angle(away_angle)
	var k_side: Vector2 = Vector2(-k_fwd.y, k_fwd.x)
	_lobe_vel[0] -= k_fwd * 3.1
	_lobe_vel[1] -= k_side * 2.7
	_lobe_vel[2] += k_side * 2.7
	_lobe_vel[3] += k_fwd * 1.9 - k_side * 1.7
	_lobe_vel[4] += k_fwd * 1.9 + k_side * 1.7
	_wobble_amp = 1.0

	for i: int in range(MAX_DROPLETS):
		var scatter_ang: float = away_angle + PI + (float(i) - 1.0) * 1.1
		_pearl_vel[i] += Vector2.from_angle(scatter_ang) * 1.9


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

	# Advance travelling chomp gulp wave (0 -> 1 over 0.38s)
	if _gulp_phase >= 0.0:
		_gulp_phase += step_dt / GULP_DURATION
		if _gulp_phase >= 1.0:
			_gulp_phase = -1.0
			_gulp_intensity = 0.0

	# Elastic damped spring for chomp pop bounce
	if absf(_pop_scale) > 0.0004 or absf(_pop_vel) > 0.004:
		var spring_acc: float = -420.0 * _pop_scale - 14.5 * _pop_vel
		_pop_vel += spring_acc * step_dt
		_pop_scale += _pop_vel * step_dt
	else:
		_pop_scale = 0.0
		_pop_vel = 0.0
	var visual_scale: float = clampf(1.0 + _pop_scale, 0.86, 1.26)
	scale = Vector2(visual_scale, visual_scale)

	# Scale-invariant swimming physics (snappy thumb response)
	var prev_vel: Vector2 = _prev_velocity
	var prev_facing: float = _prev_facing_angle
	var base_max_speed: float = world_size * 7.4
	var active_max_speed: float = base_max_speed * (_dash_boost_mult if dash_timer > 0.0 else 1.0)

	if has_input and move_dir.length_squared() > 0.0004:
		var clamped_input: Vector2 = move_dir if move_dir.length_squared() <= 1.0 else move_dir.normalized()
		var desired_vel: Vector2 = clamped_input * active_max_speed
		var accel_rate: float = 16.0 if dash_timer > 0.0 else 13.5
		velocity = velocity.lerp(desired_vel, 1.0 - exp(-accel_rate * step_dt))
	else:
		var drag_rate: float = 4.8 if dash_timer > 0.0 else 6.2
		velocity = velocity.lerp(Vector2.ZERO, 1.0 - exp(-drag_rate * step_dt))

	position += velocity * step_dt

	var speed: float = velocity.length()
	var speed_norm: float = clampf(speed / maxf(base_max_speed, 1.0), 0.0, 1.8)
	if speed > world_size * 0.25:
		facing_angle = lerp_angle(facing_angle, velocity.angle(), 1.0 - exp(-16.0 * step_dt))

	var safe_dt: float = maxf(step_dt, 0.001)
	var accel_local_norm: Vector2 = ((velocity - prev_vel) / safe_dt / maxf(world_size, 1.0)).limit_length(24.0)
	var ang_vel: float = clampf(angle_difference(prev_facing, facing_angle) / safe_dt, -14.0, 14.0)
	_prev_velocity = velocity
	_prev_facing_angle = facing_angle

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

	# Danger pulse when vulnerable (0 vitality pearls left) or predator very close
	var target_danger: float = 1.0 if droplets_alive <= 0 else clampf((pred_threat - 0.55) * 1.6, 0.0, 0.7)
	_danger_pulse = lerpf(_danger_pulse, target_danger, 1.0 - exp(-8.0 * step_dt))

	# Periodic cute blink
	_step_blink(step_dt)

	# 5-lobe viscous spring-mass slime skeleton + 3 internal vitality pearls
	_step_slime_body(step_dt, speed_norm, accel_local_norm, ang_vel)
	_step_pearls(step_dt, accel_local_norm)

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


func _get_lobe_rest_offsets(speed_norm: float, fwd_acc: float, ang_vel: float) -> Array[Vector2]:
	var fwd: Vector2 = Vector2.from_angle(facing_angle)
	var side: Vector2 = Vector2(-fwd.y, fwd.x)

	# Living breathing + volume-conserving acceleration stretch & braking squash
	var breath: float = sin(_time * 2.7) * 0.022
	var breath_lat: float = cos(_time * 2.7) * 0.018
	var elong: float = clampf(speed_norm * 0.14 + fwd_acc * 0.014, -0.18, 0.32)
	var fwd_scale: float = 1.0 + elong + breath
	var side_scale: float = (1.0 / (1.0 + elong * 0.65)) + breath_lat

	# Turn slosh from angular velocity (tail swings outward, front leads into turn)
	var turn_slosh: float = clampf(ang_vel * 0.016, -0.14, 0.14)

	# 0: rear tail, 1/2: left/right squishy flanks, 3/4: front-left/front-right chomp lobes
	var rear: Vector2 = fwd * (-0.24 * fwd_scale) - side * (turn_slosh * 1.15)
	var flank_l: Vector2 = fwd * (-0.04 * fwd_scale) - side * (0.24 * side_scale + turn_slosh * 0.35)
	var flank_r: Vector2 = fwd * (-0.04 * fwd_scale) + side * (0.24 * side_scale - turn_slosh * 0.35)
	var front_l: Vector2 = fwd * (0.20 * fwd_scale) - side * (0.15 * side_scale - turn_slosh * 0.45)
	var front_r: Vector2 = fwd * (0.20 * fwd_scale) + side * (0.15 * side_scale + turn_slosh * 0.45)
	return [rear, flank_l, flank_r, front_l, front_r]


func _step_slime_body(dt: float, speed_norm: float, accel_local_norm: Vector2, ang_vel: float) -> void:
	var fwd: Vector2 = Vector2.from_angle(facing_angle)
	var fwd_acc: float = accel_local_norm.dot(fwd)
	var targets: Array[Vector2] = _get_lobe_rest_offsets(speed_norm, fwd_acc, ang_vel)

	# Travelling chomp gulp wave modulates core & lobe radii from front -> center -> rear
	var wave_front: float = 0.0
	var wave_mid: float = 0.0
	var wave_rear: float = 0.0
	if _gulp_phase >= 0.0:
		wave_front = sin(clampf(_gulp_phase / 0.45, 0.0, 1.0) * PI) * _gulp_intensity
		wave_mid = sin(clampf((_gulp_phase - 0.18) / 0.52, 0.0, 1.0) * PI) * _gulp_intensity
		wave_rear = sin(clampf((_gulp_phase - 0.42) / 0.58, 0.0, 1.0) * PI) * _gulp_intensity

	var breath_r: float = sin(_time * 2.7) * 0.014
	var squash_r: float = clampf(-fwd_acc * 0.0022, -0.025, 0.032)
	_core_radius = CORE_BASE_RADIUS + breath_r + squash_r * 0.65 + wave_mid * 0.042
	_lobe_rad[0] = LOBE_BASE_RADII[0] + breath_r * 0.7 + wave_rear * 0.052
	_lobe_rad[1] = LOBE_BASE_RADII[1] + breath_r * 0.6 + squash_r + wave_mid * 0.038
	_lobe_rad[2] = LOBE_BASE_RADII[2] + breath_r * 0.6 + squash_r + wave_mid * 0.038
	_lobe_rad[3] = LOBE_BASE_RADII[3] + breath_r * 0.5 + wave_front * 0.056
	_lobe_rad[4] = LOBE_BASE_RADII[4] + breath_r * 0.5 + wave_front * 0.056

	# Sub-stepped viscous spring-mass integration
	var sub_steps: int = 2 if dt > 0.025 else 1
	var sub_dt: float = dt / float(sub_steps)
	for _s: int in range(sub_steps):
		for i: int in range(LOBE_COUNT):
			var disp: Vector2 = targets[i] - _lobe_pos[i]
			var spring_acc: Vector2 = disp * LOBE_STIFFNESS[i] - _lobe_vel[i] * LOBE_DAMPING[i]
			var inertia_acc: Vector2 = -accel_local_norm * (LOBE_MASS[i] * 0.095)
			_lobe_vel[i] += (spring_acc + inertia_acc) * sub_dt
			_lobe_pos[i] += _lobe_vel[i] * sub_dt

			var offset_len: float = _lobe_pos[i].length()
			if offset_len > LOBE_MAX_OFFSET:
				var dir: Vector2 = _lobe_pos[i] / offset_len
				_lobe_pos[i] = dir * LOBE_MAX_OFFSET
				var radial_v: float = _lobe_vel[i].dot(dir)
				if radial_v > 0.0:
					_lobe_vel[i] -= dir * radial_v * 0.75

	# Surface jelly ripple energy driven by live lobe jiggle velocity
	var vel_energy: float = 0.0
	for i: int in range(LOBE_COUNT):
		vel_energy += _lobe_vel[i].length()
	var target_wobble: float = clampf((vel_energy / float(LOBE_COUNT)) * 0.42, 0.0, 1.0)
	_wobble_amp = lerpf(_wobble_amp, target_wobble, 1.0 - exp(-7.5 * dt))


func _get_pearl_orbit_targets() -> Array[Vector2]:
	var orbit_speeds: Array[float] = [0.72, -0.58, 0.65]
	var orbit_radii: Array[float] = [0.18, 0.16, 0.19]
	var targets: Array[Vector2] = []
	for i: int in range(MAX_DROPLETS):
		var phase: float = _time * orbit_speeds[i] + float(i) * (TAU / float(MAX_DROPLETS)) + facing_angle * 0.35
		var rad: float = orbit_radii[i] + sin(_time * 1.45 + float(i) * 2.1) * 0.035
		targets.append(Vector2(cos(phase) * rad, sin(phase) * rad))
	return targets


func _step_pearls(dt: float, accel_local_norm: Vector2) -> void:
	var alive_clamped: int = clampi(droplets_alive, 0, MAX_DROPLETS)
	var orbit_targets: Array[Vector2] = _get_pearl_orbit_targets()

	# Detect regenerated vitality pearls and trigger smooth heal-bloom (0.08 -> 1.0)
	if alive_clamped > _prev_droplets_alive:
		for i: int in range(maxi(_prev_droplets_alive, 0), alive_clamped):
			_pearl_scales[i] = 0.08
			_pearl_pos[i] = orbit_targets[i] * 0.25
			_pearl_vel[i] = Vector2.ZERO
	_prev_droplets_alive = alive_clamped

	for i: int in range(MAX_DROPLETS):
		if i < alive_clamped:
			if _pearl_scales[i] < 0.999:
				_pearl_scales[i] = lerpf(_pearl_scales[i], 1.0, 1.0 - exp(-6.4 * dt))
				if _pearl_scales[i] > 0.995:
					_pearl_scales[i] = 1.0
		else:
			# Juicy hurt-pop shrink to 0.0
			if _pearl_scales[i] > 0.0:
				_pearl_scales[i] = lerpf(_pearl_scales[i], 0.0, 1.0 - exp(-18.0 * dt))
				if _pearl_scales[i] < 0.02:
					_pearl_scales[i] = 0.0

		var disp: Vector2 = orbit_targets[i] - _pearl_pos[i]
		var fluid_acc: Vector2 = disp * 26.0 - _pearl_vel[i] * 6.0 - accel_local_norm * 0.032
		_pearl_vel[i] += fluid_acc * dt
		_pearl_pos[i] += _pearl_vel[i] * dt

		var dist: float = _pearl_pos[i].length()
		if dist > PEARL_MAX_OFFSET:
			var dir: Vector2 = _pearl_pos[i] / dist
			_pearl_pos[i] = dir * PEARL_MAX_OFFSET
			var radial_v: float = _pearl_vel[i].dot(dir)
			if radial_v > 0.0:
				_pearl_vel[i] -= dir * radial_v * 0.8


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

	_invuln_flash = 0.0
	if invuln_timer > 0.0:
		_invuln_flash = 0.5 + 0.5 * sin(_time * 26.0)

	if _face_overlay != null:
		_face_overlay.modulate.a = 1.0 - _invuln_flash * 0.30

	_body_mat.set_shader_parameter("core_color", core_col)
	_body_mat.set_shader_parameter("edge_color", edge_col)
	_body_mat.set_shader_parameter("glow_color", glow_col)
	_body_mat.set_shader_parameter("danger_pulse", _danger_pulse)
	_body_mat.set_shader_parameter("invuln_flash", _invuln_flash)
	_body_mat.set_shader_parameter("core_radius", _core_radius)
	_body_mat.set_shader_parameter("wobble_amp", _wobble_amp)

	for i: int in range(LOBE_COUNT):
		var lp: Vector2 = _lobe_pos[i]
		_body_mat.set_shader_parameter(LOBE_UNIFORM_NAMES[i], Vector3(lp.x, lp.y, _lobe_rad[i]))

	for i: int in range(MAX_DROPLETS):
		var pp: Vector2 = _pearl_pos[i]
		_body_mat.set_shader_parameter(PEARL_UNIFORM_NAMES[i], Vector3(pp.x, pp.y, _pearl_scales[i]))


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

	# Couple face to live 5-lobe skeleton: inertial center shift + bbox squash/stretch + rear-tail jiggle tilt
	var all_centroid: Vector2 = (_lobe_pos[0] + _lobe_pos[1] + _lobe_pos[2] + _lobe_pos[3] + _lobe_pos[4]) * 0.2
	var front_centroid: Vector2 = (_lobe_pos[3] + _lobe_pos[4]) * 0.5
	var lobe_shift: Vector2 = all_centroid * 0.55 + front_centroid * 0.25

	var min_x: float = -_core_radius
	var max_x: float = _core_radius
	var min_y: float = -_core_radius
	var max_y: float = _core_radius
	for i: int in range(LOBE_COUNT):
		var lp: Vector2 = _lobe_pos[i]
		var lr: float = _lobe_rad[i]
		min_x = minf(min_x, lp.x - lr)
		max_x = maxf(max_x, lp.x + lr)
		min_y = minf(min_y, lp.y - lr)
		max_y = maxf(max_y, lp.y + lr)
	var rest_span: float = 1.04
	var raw_sx: float = (max_x - min_x) / rest_span
	var raw_sy: float = (max_y - min_y) / rest_span
	var face_scale: Vector2 = Vector2(
		clampf(lerpf(1.0, raw_sx, 0.42), 0.85, 1.18),
		clampf(lerpf(1.0, raw_sy, 0.42), 0.85, 1.18)
	)

	var fwd: Vector2 = Vector2.from_angle(facing_angle)
	var side: Vector2 = Vector2(-fwd.y, fwd.x)
	var tail_jiggle_tilt: float = _lobe_pos[0].dot(side) * 0.26
	var total_tilt: float = clampf(_face_tilt + tail_jiggle_tilt, -0.24, 0.24)

	var look_vec: Vector2 = Vector2.from_angle(look_angle)
	var face_center: Vector2 = look_vec * (r * 0.20) + lobe_shift * (world_size * 0.52)

	# Apply coupled inertial transform around face_center
	canvas.draw_set_transform(face_center, total_tilt, face_scale)

	var eye_sep: float = r * 0.355
	var eye_y: float = -r * 0.075
	var left_eye: Vector2 = Vector2(-eye_sep, eye_y)
	var right_eye: Vector2 = Vector2(eye_sep, eye_y)
	var stroke_w: float = maxf(1.4, r * 0.055)
	var aa_edge_w: float = maxf(1.0, r * 0.024)

	# Soft layered elliptical rosy cheeks (2 concentric translucent ellipses each)
	var cheek_y: float = eye_y + r * 0.245
	for side_sign: float in [-1.0, 1.0]:
		var cheek_pos: Vector2 = Vector2(side_sign * eye_sep * 1.26, cheek_y)
		_draw_ellipse(canvas, cheek_pos, r * 0.23, r * 0.145, COLOR_CHEEK_OUTER, 20)
		_draw_ellipse(canvas, cheek_pos, r * 0.14, r * 0.088, COLOR_CHEEK_INNER, 18)

	# Eyes (~10% larger & cuter): happy ^ ^ crescents, white-sclera alarmed state, or glossy oval eyes
	var eye_r: float = r * (0.215 + danger_level * 0.044)
	var alarmed: bool = danger_level > 0.45
	if happy_timer > 0.0:
		var arc_w: float = maxf(2.2, r * 0.098)
		canvas.draw_arc(left_eye + Vector2(0.0, eye_r * 0.24), eye_r * 0.88, PI * 1.13, PI * 1.87, 18, COLOR_EYE_DARK, arc_w, true)
		canvas.draw_arc(right_eye + Vector2(0.0, eye_r * 0.24), eye_r * 0.88, PI * 1.13, PI * 1.87, 18, COLOR_EYE_DARK, arc_w, true)
	elif alarmed:
		var pupil_shift: Vector2 = look_vec * (eye_r * 0.26)
		var sclera_rx: float = eye_r * 1.02
		var sclera_ry: float = eye_r * 1.22
		for eye_pos: Vector2 in [left_eye, right_eye]:
			_draw_ellipse(canvas, eye_pos, sclera_rx, sclera_ry, COLOR_SCLERA, 24, COLOR_EYE_DARK, stroke_w)
			var pupil_pos: Vector2 = eye_pos + pupil_shift
			_draw_ellipse(canvas, pupil_pos, eye_r * 0.56, eye_r * 0.66, COLOR_EYE_DARK, 20, COLOR_EYE_DARK, aa_edge_w)
			_draw_ellipse(canvas, pupil_pos + Vector2(-eye_r * 0.20, -eye_r * 0.24), eye_r * 0.25, eye_r * 0.25, COLOR_CATCHLIGHT, 14)
	else:
		# Smooth continuous vertical-squash blink
		var open_y: float = clampf(1.0 - blink_amount * 0.92, 0.08, 1.0)
		var eye_rx: float = eye_r * 0.92
		var eye_ry: float = eye_r * 1.13 * open_y
		if open_y <= 0.14:
			var lid_w: float = maxf(1.9, r * 0.086)
			for eye_pos: Vector2 in [left_eye, right_eye]:
				canvas.draw_arc(eye_pos - Vector2(0.0, eye_r * 0.22), eye_rx * 0.96, PI * 0.17, PI * 0.83, 14, COLOR_EYE_DARK, lid_w, true)
		else:
			var pupil_shift: Vector2 = look_vec * (eye_r * 0.18)
			for eye_pos: Vector2 in [left_eye, right_eye]:
				# Vertically oval deep dark-chocolate eye with smooth anti-aliased rim
				_draw_ellipse(canvas, eye_pos, eye_rx, eye_ry, COLOR_EYE_DARK, 24, COLOR_EYE_DARK, aa_edge_w)
				# Warm amber lower iris glow (2 soft layered pools)
				var sheen_pos: Vector2 = eye_pos + Vector2(pupil_shift.x * 0.35, eye_ry * 0.30)
				_draw_ellipse(canvas, sheen_pos, eye_rx * 0.68, eye_ry * 0.44, COLOR_IRIS_SHEEN, 18)
				_draw_ellipse(canvas, sheen_pos + Vector2(0.0, eye_ry * 0.08), eye_rx * 0.44, eye_ry * 0.26, COLOR_IRIS_GLOW, 14)
				# Crisp top-left primary catchlight + bright bottom-right secondary sparkle
				var hi_pos: Vector2 = eye_pos + pupil_shift * 0.40 + Vector2(-eye_rx * 0.31, -eye_ry * 0.33)
				_draw_ellipse(canvas, hi_pos, eye_r * 0.34, eye_r * 0.34 * open_y, COLOR_CATCHLIGHT, 16)
				var hi2_pos: Vector2 = eye_pos + Vector2(eye_rx * 0.30, eye_ry * 0.28)
				_draw_ellipse(canvas, hi2_pos, eye_r * 0.145, eye_r * 0.145 * open_y, COLOR_CATCHLIGHT, 12)

	# Expressive joyful mouth with Charlie's two rounded dark-outlined white teeth
	var mouth_center: Vector2 = Vector2(0.0, r * 0.25)
	var tooth_outline: float = maxf(1.0, r * 0.036)
	if alarmed and mouth_open < 0.22:
		# Worried 'o' mouth with tiny peeking teeth
		var o_rx: float = r * 0.145
		var o_ry: float = r * 0.165
		var o_pos: Vector2 = mouth_center + Vector2(0.0, r * 0.04)
		_draw_ellipse(canvas, o_pos, o_rx, o_ry, COLOR_MOUTH_FILL, 20, COLOR_EYE_DARK, stroke_w)
		_draw_ellipse(canvas, o_pos + Vector2(0.0, o_ry * 0.42), o_rx * 0.56, o_ry * 0.34, COLOR_TONGUE, 14)
		var tiny_tw: float = o_rx * 0.48
		var tiny_th: float = o_ry * 0.44
		var lip_y: float = o_pos.y - o_ry * 0.72
		for side_sign: float in [-1.0, 1.0]:
			_draw_rounded_tooth(canvas, Vector2(side_sign * o_rx * 0.34, lip_y), tiny_tw, tiny_th, tooth_outline)
	elif mouth_open > 0.16:
		# Dark-berry outlined open mouth with bright pink tongue and rounded white teeth
		var mw: float = r * lerpf(0.26, 0.40, mouth_open)
		var mh: float = r * lerpf(0.12, 0.36, mouth_open)
		var top_y: float = mouth_center.y - mh * 0.28
		var mouth_pts: PackedVector2Array = PackedVector2Array()
		mouth_pts.append(Vector2(-mw, top_y))
		mouth_pts.append(Vector2(mw, top_y))
		var steps: int = 18
		for s: int in range(1, steps):
			var t_ang: float = (float(s) / float(steps)) * PI
			mouth_pts.append(Vector2(cos(t_ang) * mw, top_y + sin(t_ang) * mh * 1.15))
		canvas.draw_colored_polygon(mouth_pts, COLOR_MOUTH_FILL)

		# Bright pink tongue nestled in the lower cavity
		if mouth_open > 0.32:
			var tongue_rx: float = mw * 0.55
			var tongue_ry: float = mh * 0.37
			_draw_ellipse(canvas, Vector2(0.0, top_y + mh * 0.76), tongue_rx, tongue_ry, COLOR_TONGUE, 16)

		# Crisp dark-berry mouth outline
		var mouth_outline: PackedVector2Array = PackedVector2Array(mouth_pts)
		mouth_outline.append(mouth_pts[0])
		canvas.draw_polyline(mouth_outline, COLOR_EYE_DARK, stroke_w, true)

		# Two rounded dark-outlined white teeth anchored at the upper lip
		var tooth_w: float = mw * 0.31
		var tooth_h: float = maxf(mh * 0.45, r * 0.115)
		var tooth_gap: float = mw * 0.33
		for side_sign: float in [-1.0, 1.0]:
			_draw_rounded_tooth(canvas, Vector2(side_sign * tooth_gap, top_y), tooth_w, tooth_h, tooth_outline)
	else:
		# Joyful expressive smile with two cute rounded peeking white teeth
		var joy_boost: float = 1.12 if happy_timer > 0.0 else 1.0
		var smile_w: float = r * 0.29 * joy_boost
		var smile_h: float = r * 0.175 * joy_boost
		var smile_lw: float = maxf(1.9, r * 0.084)
		canvas.draw_arc(
			mouth_center - Vector2(0.0, smile_h * 0.36),
			smile_w * 0.94,
			PI * 0.14,
			PI * 0.86,
			18,
			COLOR_EYE_DARK,
			smile_lw,
			true
		)
		var tooth_w: float = r * 0.095
		var tooth_h: float = r * 0.098
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
