class_name VirtualJoystick
extends Control
## Multi-touch translucent virtual joystick for mobile play.
## Tracks its own touch finger by event.index so a second finger can press
## power buttons simultaneously without interference.

const DEADZONE: float = 0.08
const IDLE_ALPHA: float = 0.0
const ACTIVE_ALPHA: float = 0.78

@export var max_radius: float = 72.0
@export var knob_radius: float = 30.0
@export var touch_padding: float = 24.0

var output_vector: Vector2 = Vector2.ZERO
var is_active: bool = false

var _touch_index: int = -1
var _knob_offset: Vector2 = Vector2.ZERO
var _pulse_time: float = 0.0
var _visual_alpha: float = IDLE_ALPHA
var _knob_glow_tex: GradientTexture2D = null
var _knob_body_tex: GradientTexture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(max_radius * 2.0 + 36.0, max_radius * 2.0 + 36.0)
	size = custom_minimum_size
	_build_knob_textures()
	queue_redraw()


func _build_knob_textures() -> void:
	# Soft translucent pearlescent wax halo (no harsh fiery orange)
	var glow_grad: Gradient = Gradient.new()
	glow_grad.offsets = PackedFloat32Array([0.0, 0.45, 0.80, 1.0])
	glow_grad.colors = PackedColorArray([
		Color(0.95, 0.84, 0.76, 0.42),
		Color(0.84, 0.60, 0.56, 0.20),
		Color(0.68, 0.44, 0.50, 0.06),
		Color(0.64, 0.40, 0.48, 0.0),
	])
	_knob_glow_tex = GradientTexture2D.new()
	_knob_glow_tex.width = 64
	_knob_glow_tex.height = 64
	_knob_glow_tex.fill = GradientTexture2D.FILL_RADIAL
	_knob_glow_tex.fill_from = Vector2(0.5, 0.5)
	_knob_glow_tex.fill_to = Vector2(1.0, 0.5)
	_knob_glow_tex.gradient = glow_grad

	# Soft glossy liquid-wax sphere gradient
	var body_grad: Gradient = Gradient.new()
	body_grad.offsets = PackedFloat32Array([0.0, 0.28, 0.68, 0.93, 1.0])
	body_grad.colors = PackedColorArray([
		Color(0.99, 0.95, 0.90, 0.92),
		Color(0.92, 0.74, 0.66, 0.88),
		Color(0.76, 0.46, 0.50, 0.84),
		Color(0.54, 0.30, 0.42, 0.76),
		Color(0.54, 0.30, 0.42, 0.0),
	])
	_knob_body_tex = GradientTexture2D.new()
	_knob_body_tex.width = 64
	_knob_body_tex.height = 64
	_knob_body_tex.fill = GradientTexture2D.FILL_RADIAL
	_knob_body_tex.fill_from = Vector2(0.36, 0.34)
	_knob_body_tex.fill_to = Vector2(0.92, 0.88)
	_knob_body_tex.gradient = body_grad


func _process(delta: float) -> void:
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

	# Translucent glassmorphic base disc
	draw_circle(center, max_radius + 5.0, Color(0.02, 0.07, 0.12, 0.24 * a))
	draw_circle(center, max_radius, Color(0.04, 0.12, 0.20, 0.34 * a))

	# Outer bioluminescent ring
	var ring_col: Color = Color(0.68, 0.88, 0.92, 0.36 * a)
	if is_active:
		ring_col = Color(0.95, 0.82, 0.72, 0.56 * a)
	draw_arc(center, max_radius, 0.0, TAU, 48, ring_col, 2.0, true)

	# Subtle cardinal guide ticks
	var tick_col: Color = Color(0.80, 0.94, 0.96, 0.20 * a)
	for i in range(4):
		var ang: float = float(i) * PI * 0.5
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		draw_line(center + dir * (max_radius - 10.0), center + dir * (max_radius - 3.0), tick_col, 1.6, true)

	# Soft radial-gradient glossy liquid-wax thumbstick knob
	var knob_pos: Vector2 = center + _knob_offset
	var glow_pulse: float = 1.0 + (0.05 * sin(_pulse_time * 4.2) if is_active else 0.0)
	var glow_r: float = knob_radius * 1.62 * glow_pulse
	if _knob_glow_tex != null:
		draw_texture_rect(
			_knob_glow_tex,
			Rect2(knob_pos - Vector2(glow_r, glow_r), Vector2(glow_r * 2.0, glow_r * 2.0)),
			false,
			Color(1.0, 1.0, 1.0, a * (0.85 if is_active else 0.50))
		)
	if _knob_body_tex != null:
		var body_r: float = knob_radius * 1.04
		draw_texture_rect(
			_knob_body_tex,
			Rect2(knob_pos - Vector2(body_r, body_r), Vector2(body_r * 2.0, body_r * 2.0)),
			false,
			Color(1.0, 1.0, 1.0, a)
		)
	else:
		draw_circle(knob_pos, knob_radius, Color(0.82, 0.56, 0.58, 0.82 * a))
	# Delicate liquid-wax specular highlight & meniscus rim
	draw_circle(knob_pos + Vector2(-knob_radius * 0.30, -knob_radius * 0.30), knob_radius * 0.24, Color(1.0, 0.98, 0.95, 0.44 * a))
	draw_arc(knob_pos, knob_radius, 0.0, TAU, 36, Color(0.98, 0.90, 0.84, 0.48 * a), 1.4, true)
