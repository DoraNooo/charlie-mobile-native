class_name VirtualJoystick
extends Control
## Multi-touch translucent liquid-glass virtual joystick for mobile play.
## Tracks its own touch finger by event.index so a second finger can press
## power buttons simultaneously without interference.
## All visuals are pre-baked once at startup into silky anti-aliased RGBA8
## ImageTextures (zero per-frame allocations, 2-3 GPU quads total).

const DEADZONE: float = 0.08
const IDLE_ALPHA: float = 0.0
const ACTIVE_ALPHA: float = 0.88

@export var max_radius: float = 70.0
@export var knob_radius: float = 26.0
@export var touch_padding: float = 24.0

var output_vector: Vector2 = Vector2.ZERO
var is_active: bool = false

var _touch_index: int = -1
var _knob_offset: Vector2 = Vector2.ZERO
var _pulse_time: float = 0.0
var _visual_alpha: float = IDLE_ALPHA
var _preview_mode: bool = false

var _base_tex: ImageTexture = null
var _knob_tex: ImageTexture = null
var _dir_glow_tex: ImageTexture = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(max_radius * 2.0 + 44.0, max_radius * 2.0 + 44.0)
	size = custom_minimum_size
	_bake_liquid_glass_textures()
	queue_redraw()


func _bake_liquid_glass_textures() -> void:
	_base_tex = _bake_base_ring_texture(160)
	_knob_tex = _bake_knob_pearl_texture(112)
	_dir_glow_tex = _bake_soft_glow_texture(64)


func _bake_base_ring_texture(tex_size: int) -> ImageTexture:
	# Frosted Studio Ghibli liquid-glass ring with subtle moonlit meniscus rim
	# and ultra-delicate translucent interior mist (no muddy dark navy disc, no crude ticks).
	var img: Image = Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var half: float = float(tex_size) * 0.5
	var inv_r: float = 1.0 / (half * 0.84)

	for y: int in range(tex_size):
		var dy: float = (float(y) + 0.5 - half) * inv_r
		for x: int in range(tex_size):
			var dx: float = (float(x) + 0.5 - half) * inv_r
			var r: float = sqrt(dx * dx + dy * dy)
			if r > 1.18:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue

			# Directional top-left studio moonlight highlight along glass rim
			var nx: float = dx / maxf(r, 0.001)
			var ny: float = dy / maxf(r, 0.001)
			var top_lit: float = clampf((-nx * 0.58 - ny * 0.81) * 0.5 + 0.5, 0.0, 1.0)
			var rim_spec: float = pow(top_lit, 2.4)

			# Gossamer translucent interior mist (fades gently from center toward glass rim)
			var inside_mask: float = 1.0 - smoothstep(0.95, 1.01, r)
			var radial_mist: float = inside_mask * (0.045 + 0.085 * smoothstep(0.45, 0.96, r))

			# Crisp anti-aliased frosted glass outer ring (width ~3.5% of radius)
			var ring_dist: float = absf(r - 0.965)
			var ring_core: float = 1.0 - smoothstep(0.012, 0.044, ring_dist)
			var ring_halo: float = (1.0 - smoothstep(0.030, 0.160, ring_dist)) * 0.18

			# Subtle inner glass bevel line
			var inner_bevel: float = (1.0 - smoothstep(0.006, 0.026, absf(r - 0.915))) * 0.14 * top_lit

			# Subtle soft center dewdot guide
			var center_dot: float = (1.0 - smoothstep(0.045, 0.095, r)) * 0.18

			var mist_col: Color = Color(0.86, 0.93, 0.98, 1.0)
			var rim_col: Color = Color(0.76, 0.88, 0.96, 1.0).lerp(Color(1.0, 0.95, 0.86, 1.0), rim_spec * 0.82)

			var a_ring: float = clampf(ring_core * (0.44 + 0.36 * rim_spec) + ring_halo + inner_bevel, 0.0, 0.88)
			var out_a: float = clampf(radial_mist + a_ring + center_dot, 0.0, 0.92)
			if out_a <= 0.002:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue

			var w_ring: float = a_ring / maxf(out_a, 0.001)
			var rgb: Color = mist_col.lerp(rim_col, clampf(w_ring, 0.0, 1.0))
			img.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, out_a))

	return ImageTexture.create_from_image(img)


func _bake_knob_pearl_texture(tex_size: int) -> ImageTexture:
	# Miniature glossy honey-coral liquid-glass pearl matching Charlie's own warm palette!
	# Includes soft warm outer glow, sculpted 3D honey-tangerine body, curved ivory specular crescent,
	# and silky subpixel AA edge (zero muddy mauve, zero hard vector circles).
	var img: Image = Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var half: float = float(tex_size) * 0.5
	# Pearl occupies inner 62% of texture; outer 38% holds feathered warm amber glow
	var inv_r: float = 1.0 / (half * 0.62)

	for y: int in range(tex_size):
		var dy: float = (float(y) + 0.5 - half) * inv_r
		for x: int in range(tex_size):
			var dx: float = (float(x) + 0.5 - half) * inv_r
			var r: float = sqrt(dx * dx + dy * dy)
			if r > 1.60:
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue

			# Feathered warm golden-tangerine outer glow
			var glow_t: float = 1.0 - smoothstep(0.88, 1.58, r)
			var glow_a: float = glow_t * glow_t * 0.38
			var glow_col: Color = Color(1.0, 0.64, 0.30, 1.0)

			# Anti-aliased pearl body mask
			var body_a: float = 1.0 - smoothstep(0.95, 1.02, r)
			if body_a <= 0.002:
				img.set_pixel(x, y, Color(glow_col.r, glow_col.g, glow_col.b, glow_a))
				continue

			# 3D sphere normal on pearl dome
			var r_clamped: float = minf(r, 0.995)
			var nz: float = sqrt(maxf(0.001, 1.0 - r_clamped * r_clamped))
			var fres: float = pow(1.0 - nz, 1.85)

			# Sculpted warm honey-apricot -> sunset-coral translucent body
			var key_dot: float = clampf((-dx * 0.48 - dy * 0.66 + nz * 0.58), 0.0, 1.0)
			var caustic_dot: float = clampf((dx * 0.52 + dy * 0.64 + nz * 0.56), 0.0, 1.0)

			var core_col: Color = Color(1.0, 0.78, 0.48, 1.0)
			var mid_col: Color = Color(0.97, 0.54, 0.30, 1.0)
			var rim_col: Color = Color(0.90, 0.36, 0.24, 1.0)
			var col: Color = core_col.lerp(mid_col, smoothstep(0.08, 0.68, r_clamped))
			col = col.lerp(rim_col, fres * 0.58)
			col = Color(
				col.r * lerpf(0.84, 1.08, key_dot),
				col.g * lerpf(0.80, 1.08, key_dot),
				col.b * lerpf(0.78, 1.06, key_dot),
				1.0
			)
			# Subtle lower-right golden honey caustic bounce
			var caustic: float = pow(caustic_dot, 3.0) * (1.0 - fres * 0.65)
			col = col.lerp(Color(1.0, 0.86, 0.52, 1.0), caustic * 0.34)

			# Crisp curved liquid-glass ivory specular highlight (upper-left)
			var sx: float = (dx + 0.32) * 1.45
			var sy: float = (dy + 0.34) * 2.10
			var rot_x: float = sx * 0.82 - sy * 0.57
			var rot_y: float = sx * 0.57 + sy * 0.82
			var spec_arc: float = 1.0 - smoothstep(0.18, 0.42, sqrt(rot_x * rot_x + rot_y * rot_y))
			# Tiny companion glint bead
			var pin_d: float = sqrt((dx + 0.02) * (dx + 0.02) + (dy + 0.50) * (dy + 0.50))
			var spec_pin: float = 1.0 - smoothstep(0.04, 0.11, pin_d)
			var spec: float = clampf(spec_arc * 0.82 + spec_pin * 0.85, 0.0, 0.92)
			col = col.lerp(Color(1.0, 0.99, 0.95, 1.0), spec)

			# Crisp glossy outer meniscus rim
			var rim_glint: float = smoothstep(0.76, 0.98, r_clamped) * (0.35 + 0.45 * key_dot)
			col = col.lerp(Color(1.0, 0.92, 0.82, 1.0), rim_glint * 0.52)

			var pearl_alpha: float = body_a * lerpf(0.78, 0.95, maxf(fres, spec))
			var out_a: float = clampf(pearl_alpha + glow_a * (1.0 - pearl_alpha), 0.0, 1.0)
			var out_rgb: Color = glow_col.lerp(col, pearl_alpha / maxf(out_a, 0.001))
			img.set_pixel(x, y, Color(
				clampf(out_rgb.r, 0.0, 1.0),
				clampf(out_rgb.g, 0.0, 1.0),
				clampf(out_rgb.b, 0.0, 1.0),
				out_a
			))

	return ImageTexture.create_from_image(img)


func _bake_soft_glow_texture(tex_size: int) -> ImageTexture:
	var img: Image = Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
	var half: float = float(tex_size) * 0.5
	var inv_r: float = 1.0 / half
	for y: int in range(tex_size):
		var dy: float = (float(y) + 0.5 - half) * inv_r
		for x: int in range(tex_size):
			var dx: float = (float(x) + 0.5 - half) * inv_r
			var r: float = sqrt(dx * dx + dy * dy)
			var g: float = 1.0 - smoothstep(0.0, 1.0, r)
			img.set_pixel(x, y, Color(1.0, 0.86, 0.62, g * g * 0.55))
	return ImageTexture.create_from_image(img)


func debug_set_preview(active: bool, offset_norm: Vector2 = Vector2.ZERO) -> void:
	_preview_mode = active
	is_active = active
	_visual_alpha = ACTIVE_ALPHA if active else IDLE_ALPHA
	_knob_offset = offset_norm.limit_length(1.0) * max_radius
	output_vector = offset_norm.limit_length(1.0) if active else Vector2.ZERO
	queue_redraw()


func _process(delta: float) -> void:
	if _preview_mode:
		return
	var target_alpha: float = ACTIVE_ALPHA if is_active else IDLE_ALPHA
	var alpha_animating: bool = absf(_visual_alpha - target_alpha) > 0.005
	if is_active:
		_pulse_time += delta
		_visual_alpha = lerpf(_visual_alpha, target_alpha, 1.0 - exp(-delta * 14.0))
		queue_redraw()
	elif alpha_animating:
		_visual_alpha = lerpf(_visual_alpha, target_alpha, 1.0 - exp(-delta * 10.0))
		if absf(_visual_alpha - target_alpha) <= 0.005:
			_visual_alpha = target_alpha
		queue_redraw()


func reset_touch() -> void:
	var changed: bool = is_active or _touch_index != -1 or _knob_offset != Vector2.ZERO
	_preview_mode = false
	_touch_index = -1
	is_active = false
	_knob_offset = Vector2.ZERO
	output_vector = Vector2.ZERO
	if changed:
		queue_redraw()


func reset_stick() -> void:
	reset_touch()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		if is_active or _touch_index != -1:
			reset_touch()
		return

	if event is InputEventScreenTouch:
		var touch_ev: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_ev.pressed:
			if _touch_index == -1:
				var hit_rect: Rect2 = get_global_rect().grow(touch_padding)
				if hit_rect.has_point(touch_ev.position):
					_touch_index = touch_ev.index
					is_active = true
					_update_stick_from_global(touch_ev.position)
					get_viewport().set_input_as_handled()
		else:
			if touch_ev.index == _touch_index:
				reset_stick()
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag_ev: InputEventScreenDrag = event as InputEventScreenDrag
		if drag_ev.index == _touch_index:
			_update_stick_from_global(drag_ev.position)
			get_viewport().set_input_as_handled()


func _update_stick_from_global(global_pos: Vector2) -> void:
	var local_pos: Vector2 = global_pos - global_position
	var center: Vector2 = size * 0.5
	var delta_vec: Vector2 = local_pos - center
	var dist: float = delta_vec.length()

	if dist > max_radius and dist > 0.0001:
		delta_vec = delta_vec / dist * max_radius
		dist = max_radius

	_knob_offset = delta_vec
	var norm_mag: float = dist / max_radius if max_radius > 0.0 else 0.0
	if norm_mag <= DEADZONE:
		output_vector = Vector2.ZERO
	else:
		var rescaled: float = clampf((norm_mag - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)
		output_vector = delta_vec.normalized() * rescaled

	queue_redraw()


func _draw() -> void:
	var a: float = _visual_alpha
	if a <= 0.002:
		return
	var center: Vector2 = size * 0.5

	# 1. Pre-baked frosted liquid-glass base ring (1 crisp GPU quad)
	if _base_tex != null:
		var base_half: float = max_radius / 0.84
		draw_texture_rect(
			_base_tex,
			Rect2(center - Vector2(base_half, base_half), Vector2(base_half * 2.0, base_half * 2.0)),
			false,
			Color(1.0, 1.0, 1.0, a)
		)

	# 2. Subtle warm golden-amber directional shimmer on the ring rim when dragged
	var mag: float = output_vector.length()
	if _dir_glow_tex != null and mag > 0.08:
		var rim_pt: Vector2 = center + output_vector.normalized() * (max_radius * 0.96)
		var g_r: float = knob_radius * 1.15
		draw_texture_rect(
			_dir_glow_tex,
			Rect2(rim_pt - Vector2(g_r, g_r), Vector2(g_r * 2.0, g_r * 2.0)),
			false,
			Color(1.0, 0.92, 0.78, a * mag * 0.72)
		)

	# 3. Pre-baked glossy honey-coral liquid-glass pearl thumbstick knob (1 crisp GPU quad)
	var knob_pos: Vector2 = center + _knob_offset
	var pulse: float = 1.0 + (0.03 * sin(_pulse_time * 4.0) if is_active else 0.0)
	if _knob_tex != null:
		var knob_half: float = (knob_radius / 0.62) * pulse
		draw_texture_rect(
			_knob_tex,
			Rect2(knob_pos - Vector2(knob_half, knob_half), Vector2(knob_half * 2.0, knob_half * 2.0)),
			false,
			Color(1.0, 1.0, 1.0, a)
		)
