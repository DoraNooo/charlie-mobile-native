class_name VirtualJoystick
extends Control
## Multi-touch translucent virtual joystick for mobile play.
## Tracks its own touch finger by event.index so a second finger can press
## power buttons simultaneously without interference.

const DEADZONE: float = 0.08

@export var max_radius: float = 72.0
@export var knob_radius: float = 30.0
@export var touch_padding: float = 40.0

var output_vector: Vector2 = Vector2.ZERO
var is_active: bool = false

var _touch_index: int = -1
var _knob_offset: Vector2 = Vector2.ZERO
var _pulse_time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(max_radius * 2.0 + 36.0, max_radius * 2.0 + 36.0)
	size = custom_minimum_size
	queue_redraw()


func _process(delta: float) -> void:
	_pulse_time += delta
	if is_active:
		queue_redraw()


func reset_touch() -> void:
	_touch_index = -1
	is_active = false
	_knob_offset = Vector2.ZERO
	output_vector = Vector2.ZERO
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
	var center: Vector2 = size * 0.5
	var active_alpha: float = 1.0 if is_active else 0.62

	# Translucent base disc
	draw_circle(center, max_radius + 6.0, Color(0.03, 0.09, 0.14, 0.28 * active_alpha))
	draw_circle(center, max_radius, Color(0.05, 0.15, 0.22, 0.34 * active_alpha))

	# Outer bioluminescent ring
	var ring_col: Color = Color(0.55, 0.90, 0.92, 0.45 * active_alpha)
	if is_active:
		ring_col = Color(1.0, 0.72, 0.48, 0.62)
	draw_arc(center, max_radius, 0.0, TAU, 48, ring_col, 2.5, true)

	# Subtle cardinal guide ticks
	var tick_col: Color = Color(0.75, 0.95, 0.96, 0.24 * active_alpha)
	for i in range(4):
		var ang: float = float(i) * PI * 0.5
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		draw_line(center + dir * (max_radius - 10.0), center + dir * (max_radius - 3.0), tick_col, 2.0, true)

	# Warm glowing lava thumbstick knob
	var knob_pos: Vector2 = center + _knob_offset
	var glow_pulse: float = 1.0 + (0.08 * sin(_pulse_time * 5.0) if is_active else 0.0)
	draw_circle(knob_pos, knob_radius * 1.48 * glow_pulse, Color(1.0, 0.46, 0.28, 0.18 * active_alpha))
	draw_circle(knob_pos, knob_radius * 1.18 * glow_pulse, Color(1.0, 0.56, 0.32, 0.34 * active_alpha))
	draw_circle(knob_pos, knob_radius, Color(0.96, 0.40, 0.34, 0.88 * active_alpha))
	draw_circle(knob_pos, knob_radius * 0.72, Color(1.0, 0.74, 0.46, 0.92 * active_alpha))
	draw_circle(knob_pos + Vector2(-knob_radius * 0.24, -knob_radius * 0.24), knob_radius * 0.24, Color(1.0, 0.95, 0.84, 0.78 * active_alpha))
	draw_arc(knob_pos, knob_radius, 0.0, TAU, 32, Color(1.0, 0.86, 0.66, 0.65 * active_alpha), 1.8, true)
