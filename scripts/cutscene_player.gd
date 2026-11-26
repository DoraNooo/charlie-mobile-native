class_name CutscenePlayer
extends CanvasLayer
## Full-screen illustrated cinema cutscene player with Ken Burns motion,
## French storybook captions starring la petite Charlie (feminine),
## progress dots, tap-to-advance, and skip button.

const ART_PORTRAIT: String = "res://assets/art/keyart-portrait.jpg"
const ART_LANDSCAPE: String = "res://assets/art/keyart-landscape.jpg"
const ART_CHARLIE: String = "res://assets/art/charlie-portrait.jpg"
const TAP_GUARD_SECONDS: float = 0.35

const CUTSCENES: Dictionary = {
	"intro": {
		"chapter": "PROLOGUE · L'ÉVEIL DE CHARLIE",
		"slides": [
			{
				"art": ART_CHARLIE,
				"text": "Dans le silence vibrant du vide quantique, la petite Charlie s'éveille — une goutte de lave aux deux petites dents lumineuses.",
				"zoom_from": 1.04, "zoom_to": 1.18, "pan_from": Vector2(0.0, 8.0), "pan_to": Vector2(0.0, -14.0),
			},
			{
				"art": ART_PORTRAIT,
				"text": "Curieuse et intrépide, elle rêve de goûter chaque monde — du plus minuscule quark jusqu'aux galaxies spirales.",
				"zoom_from": 1.12, "zoom_to": 1.02, "pan_from": Vector2(-12.0, 0.0), "pan_to": Vector2(12.0, -8.0),
			},
		],
	},
	"scale_1": {
		"chapter": "ÉCHELLE II · LA GOUTTE D'EAU",
		"slides": [
			{
				"art": ART_LANDSCAPE,
				"text": "Un voile d'eau s'ouvre devant la petite Charlie : la voilà plongée dans un océan miniature peuplé de spores, d'amibes et de tardigrades.",
				"zoom_from": 1.02, "zoom_to": 1.15, "pan_from": Vector2(-16.0, 4.0), "pan_to": Vector2(16.0, -6.0),
			},
			{
				"art": ART_CHARLIE,
				"text": "Ses joues rougeoient de chaleur : chaque bouchée la rend plus grande et plus vive !",
				"zoom_from": 1.06, "zoom_to": 1.16, "pan_from": Vector2(0.0, 6.0), "pan_to": Vector2(0.0, -10.0),
			},
		],
	},
	"scale_2": {
		"chapter": "ÉCHELLE III · LA ROSÉE NOCTURNE",
		"slides": [
			{
				"art": ART_PORTRAIT,
				"text": "La brume du sous-bois s'élève. La petite Charlie glisse parmi les fourmis, les lucioles dorées, les coccinelles et les grenouilles.",
				"zoom_from": 1.04, "zoom_to": 1.17, "pan_from": Vector2(10.0, 10.0), "pan_to": Vector2(-10.0, -12.0),
			},
			{
				"art": ART_LANDSCAPE,
				"text": "Sa flamme intérieure crépite : ses pouvoirs de lave s'éveillent au cœur de la forêt !",
				"zoom_from": 1.14, "zoom_to": 1.03, "pan_from": Vector2(-12.0, -6.0), "pan_to": Vector2(14.0, 6.0),
			},
		],
	},
	"scale_3": {
		"chapter": "ÉCHELLE IV · LA VILLE ENDORMIE",
		"slides": [
			{
				"art": ART_LANDSCAPE,
				"text": "Les feuilles cèdent la place aux lanternes célestes. Charlie plane désormais parmi les chouettes, les voitures et les grands dirigeables.",
				"zoom_from": 1.03, "zoom_to": 1.16, "pan_from": Vector2(-18.0, 0.0), "pan_to": Vector2(18.0, -8.0),
			},
			{
				"art": ART_CHARLIE,
				"text": "Rien n'arrête sa curiosité : la petite goutte de braise illumine toute la nuit !",
				"zoom_from": 1.05, "zoom_to": 1.15, "pan_from": Vector2(8.0, 6.0), "pan_to": Vector2(-8.0, -8.0),
			},
		],
	},
	"scale_4": {
		"chapter": "ÉCHELLE V · LE BALLET ORBITAL",
		"slides": [
			{
				"art": ART_PORTRAIT,
				"text": "La petite Charlie quitte la Terre pour la valse des comètes et des lunes. L'espace entier chante autour de son cœur de braise.",
				"zoom_from": 1.04, "zoom_to": 1.18, "pan_from": Vector2(0.0, 14.0), "pan_to": Vector2(0.0, -14.0),
			},
			{
				"art": ART_LANDSCAPE,
				"text": "Son énergie solaire rayonne : même les géantes à anneaux admirent son passage !",
				"zoom_from": 1.14, "zoom_to": 1.02, "pan_from": Vector2(16.0, -4.0), "pan_to": Vector2(-16.0, 6.0),
			},
		],
	},
	"scale_5": {
		"chapter": "ÉCHELLE VI · L'INFINIMENT GRAND",
		"slides": [
			{
				"art": ART_LANDSCAPE,
				"text": "Étoiles, nébuleuses et galaxies spirales gravitent à portée de la petite Charlie. La goutte d'autrefois embrasse tout l'univers.",
				"zoom_from": 1.02, "zoom_to": 1.18, "pan_from": Vector2(-14.0, 8.0), "pan_to": Vector2(14.0, -10.0),
			},
			{
				"art": ART_CHARLIE,
				"text": "Un dernier voyage lumineux l'attend au sommet du cosmos.",
				"zoom_from": 1.06, "zoom_to": 1.18, "pan_from": Vector2(0.0, 6.0), "pan_to": Vector2(0.0, -12.0),
			},
		],
	},
	"victory": {
		"chapter": "FINALE · UN AVEC LE COSMOS",
		"slides": [
			{
				"art": ART_PORTRAIT,
				"text": "D'un frisson quantique jusqu'aux galaxies spirales, la petite Charlie est devenue lumière infinie.",
				"zoom_from": 1.04, "zoom_to": 1.18, "pan_from": Vector2(0.0, 12.0), "pan_to": Vector2(0.0, -14.0),
			},
			{
				"art": ART_CHARLIE,
				"text": "Ses deux petites dents brillent comme des étoiles jumelles. Merci d'avoir guidé Charlie à travers tous les mondes !",
				"zoom_from": 1.12, "zoom_to": 1.02, "pan_from": Vector2(-10.0, 0.0), "pan_to": Vector2(10.0, -6.0),
			},
		],
	},
}

var _root: Control = null
var _art_clip: Control = null
var _art_rect: TextureRect = null
var _chapter_label: Label = null
var _skip_button: Button = null
var _caption_label: Label = null
var _dots_box: HBoxContainer = null
var _next_prompt: Label = null

var _textures: Dictionary = {}
var _active: bool = false
var _slides: Array = []
var _slide_index: int = 0
var _slide_time: float = 0.0
var _guard_timer: float = 0.0
var _on_done: Callable = Callable()


func _ready() -> void:
	layer = 30
	_preload_art()
	_build_ui()
	visible = false


func _preload_art() -> void:
	for path: String in [ART_PORTRAIT, ART_LANDSCAPE, ART_CHARLIE]:
		if ResourceLoader.exists(path):
			var tex: Resource = load(path)
			if tex is Texture2D:
				_textures[path] = tex


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "CutsceneRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	# Deep dark cinema backdrop
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.04, 0.08, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	# Clipped full-bleed art container for Ken Burns zoom/pan
	_art_clip = Control.new()
	_art_clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_clip.clip_contents = true
	_art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_art_clip)

	_art_rect = TextureRect.new()
	_art_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_clip.add_child(_art_rect)

	# Subtle warm cinema scrim
	var scrim: ColorRect = ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.02, 0.05, 0.10, 0.24)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(scrim)

	# Top gradient bar
	var top_grad: TextureRect = TextureRect.new()
	top_grad.anchor_left = 0.0
	top_grad.anchor_top = 0.0
	top_grad.anchor_right = 1.0
	top_grad.anchor_bottom = 0.0
	top_grad.offset_bottom = 116.0
	top_grad.texture = _make_vertical_gradient(Color(0.02, 0.04, 0.08, 0.90), Color(0.02, 0.04, 0.08, 0.0))
	top_grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top_grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top_grad)

	var top_margin: MarginContainer = MarginContainer.new()
	top_margin.anchor_left = 0.0
	top_margin.anchor_top = 0.0
	top_margin.anchor_right = 1.0
	top_margin.anchor_bottom = 0.0
	top_margin.offset_bottom = 86.0
	top_margin.add_theme_constant_override("margin_left", 28)
	top_margin.add_theme_constant_override("margin_right", 28)
	top_margin.add_theme_constant_override("margin_top", 22)
	top_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	_root.add_child(top_margin)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_margin.add_child(top_row)

	_chapter_label = Label.new()
	_chapter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chapter_label.add_theme_font_size_override("font_size", 18)
	_chapter_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.62, 0.96))
	_chapter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(_chapter_label)

	_skip_button = Button.new()
	_skip_button.text = "Passer ›"
	_skip_button.custom_minimum_size = Vector2(118, 42)
	_skip_button.add_theme_font_size_override("font_size", 16)
	_skip_button.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0, 0.95))
	var skip_style: StyleBoxFlat = StyleBoxFlat.new()
	skip_style.bg_color = Color(0.07, 0.14, 0.22, 0.78)
	skip_style.border_color = Color(0.65, 0.90, 0.95, 0.45)
	skip_style.set_border_width_all(1)
	skip_style.set_corner_radius_all(20)
	_skip_button.add_theme_stylebox_override("normal", skip_style)
	var skip_hover: StyleBoxFlat = skip_style.duplicate() as StyleBoxFlat
	skip_hover.bg_color = Color(0.14, 0.24, 0.34, 0.90)
	_skip_button.add_theme_stylebox_override("hover", skip_hover)
	_skip_button.add_theme_stylebox_override("pressed", skip_hover)
	_skip_button.pressed.connect(skip_cutscene)
	top_row.add_child(_skip_button)

	# Bottom gradient bar
	var bot_grad: TextureRect = TextureRect.new()
	bot_grad.anchor_left = 0.0
	bot_grad.anchor_top = 1.0
	bot_grad.anchor_right = 1.0
	bot_grad.anchor_bottom = 1.0
	bot_grad.offset_top = -230.0
	bot_grad.texture = _make_vertical_gradient(Color(0.02, 0.04, 0.08, 0.0), Color(0.02, 0.04, 0.08, 0.94))
	bot_grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bot_grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bot_grad)

	var bot_margin: MarginContainer = MarginContainer.new()
	bot_margin.anchor_left = 0.0
	bot_margin.anchor_top = 1.0
	bot_margin.anchor_right = 1.0
	bot_margin.anchor_bottom = 1.0
	bot_margin.offset_top = -188.0
	bot_margin.add_theme_constant_override("margin_left", 42)
	bot_margin.add_theme_constant_override("margin_right", 42)
	bot_margin.add_theme_constant_override("margin_bottom", 26)
	bot_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bot_margin)

	var bot_col: VBoxContainer = VBoxContainer.new()
	bot_col.alignment = BoxContainer.ALIGNMENT_END
	bot_col.add_theme_constant_override("separation", 14)
	bot_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_margin.add_child(bot_col)

	_caption_label = Label.new()
	_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption_label.add_theme_font_size_override("font_size", 23)
	_caption_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92, 1.0))
	_caption_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	_caption_label.add_theme_constant_override("shadow_offset_y", 2)
	_caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_col.add_child(_caption_label)

	var footer_row: HBoxContainer = HBoxContainer.new()
	footer_row.alignment = BoxContainer.ALIGNMENT_CENTER
	footer_row.add_theme_constant_override("separation", 18)
	footer_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_col.add_child(footer_row)

	_dots_box = HBoxContainer.new()
	_dots_box.add_theme_constant_override("separation", 8)
	_dots_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_row.add_child(_dots_box)

	_next_prompt = Label.new()
	_next_prompt.text = "Touchez pour la suite ›"
	_next_prompt.add_theme_font_size_override("font_size", 15)
	_next_prompt.add_theme_color_override("font_color", Color(0.74, 0.93, 0.96, 0.88))
	_next_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer_row.add_child(_next_prompt)


func _make_vertical_gradient(top_col: Color, bot_col: Color) -> GradientTexture2D:
	var grad: Gradient = Gradient.new()
	grad.set_color(0, top_col)
	grad.set_color(1, bot_col)
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 4
	tex.height = 64
	return tex


func is_playing() -> bool:
	return _active


func play_cutscene(cutscene_id: String, on_done: Callable) -> void:
	if not CUTSCENES.has(cutscene_id):
		if on_done.is_valid():
			on_done.call()
		return

	var data: Dictionary = CUTSCENES[cutscene_id]
	_slides = data["slides"] as Array
	if _slides.is_empty():
		if on_done.is_valid():
			on_done.call()
		return

	_on_done = on_done
	_chapter_label.text = String(data["chapter"])
	_slide_index = 0
	_active = true
	visible = true
	_apply_slide(0)


func skip_cutscene() -> void:
	if not _active:
		return
	_finish()


func _finish() -> void:
	_active = false
	visible = false
	var cb: Callable = _on_done
	_on_done = Callable()
	if cb.is_valid():
		cb.call()


func _apply_slide(index: int) -> void:
	_slide_index = index
	_slide_time = 0.0
	_guard_timer = TAP_GUARD_SECONDS

	var slide: Dictionary = _slides[index] as Dictionary
	var art_path: String = String(slide.get("art", ART_PORTRAIT))
	if _textures.has(art_path):
		_art_rect.texture = _textures[art_path] as Texture2D
	else:
		_art_rect.texture = null

	_caption_label.text = String(slide.get("text", ""))
	_rebuild_dots()
	_update_ken_burns(0.0)


func _rebuild_dots() -> void:
	for child: Node in _dots_box.get_children():
		child.queue_free()

	for i in range(_slides.size()):
		var dot: ColorRect = ColorRect.new()
		var is_cur: bool = (i == _slide_index)
		dot.custom_minimum_size = Vector2(22.0 if is_cur else 8.0, 8.0)
		dot.color = Color(1.0, 0.78, 0.50, 1.0) if is_cur else Color(0.75, 0.90, 0.95, 0.35)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots_box.add_child(dot)


func _advance_slide() -> void:
	if _slide_index + 1 < _slides.size():
		_apply_slide(_slide_index + 1)
	else:
		_finish()


func _process(delta: float) -> void:
	if not _active:
		return

	_slide_time += delta
	if _guard_timer > 0.0:
		_guard_timer = maxf(0.0, _guard_timer - delta)

	_update_ken_burns(_slide_time)
	if _next_prompt != null:
		_next_prompt.modulate.a = 0.60 + 0.38 * sin(_slide_time * 3.2)


func _update_ken_burns(t_sec: float) -> void:
	if _art_rect == null or _slides.is_empty():
		return
	var slide: Dictionary = _slides[_slide_index] as Dictionary
	var frac: float = clampf(t_sec / 6.5, 0.0, 1.0)
	var ease_frac: float = frac * frac * (3.0 - 2.0 * frac)

	var z_from: float = float(slide.get("zoom_from", 1.04))
	var z_to: float = float(slide.get("zoom_to", 1.16))
	var p_from: Vector2 = slide.get("pan_from", Vector2.ZERO) as Vector2
	var p_to: Vector2 = slide.get("pan_to", Vector2.ZERO) as Vector2

	var zoom_val: float = lerpf(z_from, z_to, ease_frac)
	var pan_val: Vector2 = p_from.lerp(p_to, ease_frac)

	_art_rect.pivot_offset = _art_rect.size * 0.5
	_art_rect.scale = Vector2(zoom_val, zoom_val)
	_art_rect.position = pan_val


func _input(event: InputEvent) -> void:
	if not _active:
		return

	if event is InputEventKey:
		var key_ev: InputEventKey = event as InputEventKey
		if key_ev.pressed and not key_ev.echo:
			if key_ev.keycode == KEY_ESCAPE:
				skip_cutscene()
				get_viewport().set_input_as_handled()
			elif key_ev.keycode == KEY_SPACE or key_ev.keycode == KEY_ENTER:
				if _guard_timer <= 0.0:
					_advance_slide()
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch_ev: InputEventScreenTouch = event as InputEventScreenTouch
		if touch_ev.pressed:
			# Let the Skip button handle its own clicks
			if _skip_button != null and _skip_button.get_global_rect().grow(8.0).has_point(touch_ev.position):
				return
			if _guard_timer <= 0.0:
				_advance_slide()
			get_viewport().set_input_as_handled()
