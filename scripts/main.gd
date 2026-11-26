extends Node2D
## Main game orchestrator for CHARLIE — De l'atome au cosmos (Godot 4.3+ Mobile).
## Programmatically builds the GPU background, Camera2D, Charlie, Ecosystem,
## AudioEngine, CutscenePlayer, evolving lava spit & shockwave VFX, HUD,
## multi-touch controls, and all menus/settings.

const SETTINGS_PATH: String = "user://settings.cfg"
const BG_SHADER_PATH: String = "res://shaders/biolum_bg.gdshader"
const ART_TITLE_PATH: String = "res://assets/art/keyart-landscape.jpg"

enum GameState {
	TITLE,
	CUTSCENE,
	PLAYING,
	PAUSED,
	DEFEAT,
	VICTORY,
}

# Settings (persisted to user://settings.cfg)
var difficulty_mode: String = "chill"
var bites_per_scale: int = 15
var cinematic_mode: bool = true

# Runtime state
var state: GameState = GameState.TITLE
var _options_return_state: GameState = GameState.TITLE
var current_scale_index: int = 0
var bites_in_scale: int = 0
var total_eaten: int = 0
var _heal_bite_counter: int = 0
var _spit_cd_left: float = 0.0
var _dash_cd_left: float = 0.0
var _free_roam_after_victory: bool = false
var _current_zoom: float = 1.25

# Core nodes
var _bg_layer: CanvasLayer = null
var _bg_rect: ColorRect = null
var _bg_mat: ShaderMaterial = null
var _camera: Camera2D = null
var _ecosystem: Ecosystem = null
var _charlie: Charlie = null
var _vfx_layer: _WorldVfxLayer = null
var _audio: AudioEngine = null
var _cutscenes: CutscenePlayer = null

# World VFX state (lava spit projectiles, shockwaves, chomp bursts)
var _projectiles: Array[Dictionary] = []
var _shockwaves: Array[Dictionary] = []
var _bursts: Array[Dictionary] = []

# HUD nodes
var _hud_layer: CanvasLayer = null
var _hud_root: Control = null
var _scale_label: Label = null
var _size_label: Label = null
var _lives_label: Label = null
var _progress_bar: ProgressBar = null
var _progress_count_label: Label = null
var _mute_btn: Button = null
var _pause_btn: Button = null
var _joystick: VirtualJoystick = null
var _spit_btn: _TouchPowerButton = null
var _dash_btn: _TouchPowerButton = null

# Overlay menus
var _menu_layer: CanvasLayer = null
var _title_panel: Control = null
var _pause_panel: Control = null
var _options_panel: Control = null
var _defeat_panel: Control = null
var _victory_panel: Control = null

# Options widgets
var _diff_buttons: Dictionary = {}
var _diff_desc_label: Label = null
var _bites_slider: HSlider = null
var _bites_value_label: Label = null
var _cinematic_toggle: CheckButton = null


class _WorldVfxLayer:
	extends Node2D
	var owner_main: Node2D = null

	func _draw() -> void:
		if owner_main != null:
			owner_main._draw_world_vfx(self)


class _TouchPowerButton:
	extends Control
	## Multi-touch circular power button that tracks its own finger by event.index
	## so it can be tapped while the left thumb drags VirtualJoystick.
	signal activated

	var title_text: String = "Lave"
	var hotkey_text: String = "A"
	var level_text: String = "Nv.1"
	var accent_color: Color = Color(1.0, 0.55, 0.30, 1.0)
	var cooldown_ratio: float = 0.0 # 0.0 = ready, 1.0 = full cooldown

	var _pressed_index: int = -1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(94.0, 94.0)
		size = custom_minimum_size

	func _input(event: InputEvent) -> void:
		if not is_visible_in_tree():
			_pressed_index = -1
			return
		if event is InputEventScreenTouch:
			var tev: InputEventScreenTouch = event as InputEventScreenTouch
			if tev.pressed:
				if _pressed_index == -1 and get_global_rect().grow(14.0).has_point(tev.position):
					_pressed_index = tev.index
					queue_redraw()
					activated.emit()
					get_viewport().set_input_as_handled()
			else:
				if tev.index == _pressed_index:
					_pressed_index = -1
					queue_redraw()

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.45
		var is_ready: bool = cooldown_ratio <= 0.001
		var is_down: bool = _pressed_index != -1

		# Outer glow when ready
		if is_ready:
			draw_circle(center, r * (1.16 if is_down else 1.10), Color(accent_color.r, accent_color.g, accent_color.b, 0.24))

		# Button fill
		var fill_col: Color = Color(0.06, 0.14, 0.22, 0.78)
		if is_down:
			fill_col = Color(accent_color.r * 0.45, accent_color.g * 0.35, accent_color.b * 0.30, 0.90)
		draw_circle(center, r, fill_col)

		# Cooldown arc / ready ring
		var ring_col: Color = accent_color if is_ready else Color(0.55, 0.65, 0.72, 0.45)
		draw_arc(center, r, 0.0, TAU, 40, ring_col, 3.0 if is_ready else 2.0, true)
		if not is_ready:
			var ready_frac: float = clampf(1.0 - cooldown_ratio, 0.0, 1.0)
			draw_arc(center, r - 3.0, -PI * 0.5, -PI * 0.5 + TAU * ready_frac, 36, accent_color, 4.0, true)

		# Crisp text labels using default theme font
		var font: Font = ThemeDB.fallback_font
		if font != null:
			var title_size: Vector2 = font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
			draw_string(font, center + Vector2(-title_size.x * 0.5, -2.0), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.98, 0.96, 0.92, 1.0 if is_ready else 0.55))

			var sub_str: String = "%s · %s" % [level_text, hotkey_text]
			var sub_size: Vector2 = font.get_string_size(sub_str, HORIZONTAL_ALIGNMENT_CENTER, -1, 11)
			draw_string(font, center + Vector2(-sub_size.x * 0.5, 16.0), sub_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(accent_color.r, accent_color.g, accent_color.b, 0.95 if is_ready else 0.55))


func _ready() -> void:
	load_settings()
	_setup_background()
	_setup_world()
	_setup_audio_and_cutscenes()
	_setup_hud()
	_setup_menus()
	_apply_settings_to_systems()
	_enter_title_screen()


func _setup_background() -> void:
	_bg_layer = CanvasLayer.new()
	_bg_layer.name = "BackgroundLayer"
	_bg_layer.layer = -10
	add_child(_bg_layer)

	_bg_rect = ColorRect.new()
	_bg_rect.name = "BiolumBg"
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg_mat = ShaderMaterial.new()
	var bg_shader: Shader = load(BG_SHADER_PATH) as Shader
	if bg_shader != null:
		_bg_mat.shader = bg_shader
	_bg_rect.material = _bg_mat
	_bg_layer.add_child(_bg_rect)


func _setup_world() -> void:
	_ecosystem = Ecosystem.new()
	_ecosystem.name = "Ecosystem"
	add_child(_ecosystem)

	_vfx_layer = _WorldVfxLayer.new()
	_vfx_layer.name = "WorldVfxLayer"
	_vfx_layer.owner_main = self
	_vfx_layer.z_index = 4
	add_child(_vfx_layer)

	_charlie = Charlie.new()
	_charlie.name = "Charlie"
	_charlie.z_index = 5
	add_child(_charlie)

	_camera = Camera2D.new()
	_camera.name = "MainCamera"
	_camera.enabled = true
	_camera.position_smoothing_enabled = false
	add_child(_camera)


func _setup_audio_and_cutscenes() -> void:
	_audio = AudioEngine.new()
	_audio.name = "AudioEngine"
	add_child(_audio)

	_cutscenes = CutscenePlayer.new()
	_cutscenes.name = "CutscenePlayer"
	add_child(_cutscenes)


func _setup_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.name = "HudLayer"
	_hud_layer.layer = 10
	add_child(_hud_layer)

	_hud_root = Control.new()
	_hud_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(_hud_root)

	# Top bar container
	var top_margin: MarginContainer = MarginContainer.new()
	top_margin.anchor_left = 0.0
	top_margin.anchor_top = 0.0
	top_margin.anchor_right = 1.0
	top_margin.anchor_bottom = 0.0
	top_margin.offset_bottom = 96.0
	top_margin.add_theme_constant_override("margin_left", 20)
	top_margin.add_theme_constant_override("margin_right", 20)
	top_margin.add_theme_constant_override("margin_top", 16)
	top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(top_margin)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 16)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_margin.add_child(top_row)

	# Left info pill (Scale + Scientific Size + Lives)
	var left_panel: PanelContainer = PanelContainer.new()
	left_panel.add_theme_stylebox_override("panel", _make_glass_box(16))
	left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(left_panel)

	var left_col: VBoxContainer = VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 2)
	left_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_panel.add_child(left_col)

	_scale_label = Label.new()
	_scale_label.text = "I · Quantique"
	_scale_label.add_theme_font_size_override("font_size", 17)
	_scale_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.64, 1.0))
	left_col.add_child(_scale_label)

	var sub_row: HBoxContainer = HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 12)
	left_col.add_child(sub_row)

	_size_label = Label.new()
	_size_label.text = "0.1 nm"
	_size_label.add_theme_font_size_override("font_size", 13)
	_size_label.add_theme_color_override("font_color", Color(0.74, 0.94, 0.96, 0.92))
	sub_row.add_child(_size_label)

	_lives_label = Label.new()
	_lives_label.text = "●●●"
	_lives_label.add_theme_font_size_override("font_size", 14)
	_lives_label.add_theme_color_override("font_color", Color(1.0, 0.52, 0.44, 1.0))
	sub_row.add_child(_lives_label)

	# Center progress bar
	var center_col: VBoxContainer = VBoxContainer.new()
	center_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_col.alignment = BoxContainer.ALIGNMENT_CENTER
	center_col.add_theme_constant_override("separation", 4)
	center_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(center_col)

	_progress_bar = ProgressBar.new()
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(180.0, 14.0)
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_bg: StyleBoxFlat = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.04, 0.11, 0.18, 0.72)
	bar_bg.set_corner_radius_all(8)
	var bar_fill: StyleBoxFlat = StyleBoxFlat.new()
	bar_fill.bg_color = Color(1.0, 0.62, 0.36, 0.96)
	bar_fill.set_corner_radius_all(8)
	_progress_bar.add_theme_stylebox_override("background", bar_bg)
	_progress_bar.add_theme_stylebox_override("fill", bar_fill)
	center_col.add_child(_progress_bar)

	_progress_count_label = Label.new()
	_progress_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_count_label.text = "0 / 15"
	_progress_count_label.add_theme_font_size_override("font_size", 12)
	_progress_count_label.add_theme_color_override("font_color", Color(0.86, 0.94, 0.98, 0.85))
	center_col.add_child(_progress_count_label)

	# Right action buttons (Audio & Pause)
	var right_row: HBoxContainer = HBoxContainer.new()
	right_row.add_theme_constant_override("separation", 10)
	top_row.add_child(right_row)

	_mute_btn = _make_hud_icon_button("🔊")
	_mute_btn.pressed.connect(_on_toggle_mute)
	right_row.add_child(_mute_btn)

	_pause_btn = _make_hud_icon_button("⏸")
	_pause_btn.pressed.connect(_on_pause_pressed)
	right_row.add_child(_pause_btn)

	# Bottom-left VirtualJoystick
	_joystick = VirtualJoystick.new()
	_joystick.name = "VirtualJoystick"
	_joystick.anchor_left = 0.0
	_joystick.anchor_top = 1.0
	_joystick.anchor_right = 0.0
	_joystick.anchor_bottom = 1.0
	_joystick.offset_left = 26.0
	_joystick.offset_top = -208.0
	_joystick.offset_right = 206.0
	_joystick.offset_bottom = -28.0
	_hud_root.add_child(_joystick)

	# Bottom-right multi-touch power buttons (Lave / A & Onde / E)
	_spit_btn = _TouchPowerButton.new()
	_spit_btn.name = "SpitButton"
	_spit_btn.title_text = "Lave"
	_spit_btn.hotkey_text = "A"
	_spit_btn.accent_color = Color(1.0, 0.54, 0.30, 1.0)
	_spit_btn.anchor_left = 1.0
	_spit_btn.anchor_top = 1.0
	_spit_btn.anchor_right = 1.0
	_spit_btn.anchor_bottom = 1.0
	_spit_btn.offset_left = -224.0
	_spit_btn.offset_top = -126.0
	_spit_btn.offset_right = -130.0
	_spit_btn.offset_bottom = -32.0
	_spit_btn.activated.connect(_trigger_lava_spit)
	_hud_root.add_child(_spit_btn)

	_dash_btn = _TouchPowerButton.new()
	_dash_btn.name = "DashButton"
	_dash_btn.title_text = "Onde"
	_dash_btn.hotkey_text = "E"
	_dash_btn.accent_color = Color(0.42, 0.90, 0.95, 1.0)
	_dash_btn.anchor_left = 1.0
	_dash_btn.anchor_top = 1.0
	_dash_btn.anchor_right = 1.0
	_dash_btn.anchor_bottom = 1.0
	_dash_btn.offset_left = -118.0
	_dash_btn.offset_top = -148.0
	_dash_btn.offset_right = -24.0
	_dash_btn.offset_bottom = -54.0
	_dash_btn.activated.connect(_trigger_shockwave_dash)
	_hud_root.add_child(_dash_btn)


func _setup_menus() -> void:
	_menu_layer = CanvasLayer.new()
	_menu_layer.name = "MenuLayer"
	_menu_layer.layer = 20
	add_child(_menu_layer)

	_build_title_panel()
	_build_pause_panel()
	_build_options_panel()
	_build_defeat_panel()
	_build_victory_panel()


func _build_title_panel() -> void:
	_title_panel = Control.new()
	_title_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_layer.add_child(_title_panel)

	if ResourceLoader.exists(ART_TITLE_PATH):
		var art: TextureRect = TextureRect.new()
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.texture = load(ART_TITLE_PATH) as Texture2D
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.modulate = Color(1.0, 1.0, 1.0, 0.34)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_title_panel.add_child(art)

	var scrim: ColorRect = ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.02, 0.06, 0.11, 0.62)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_panel.add_child(scrim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_panel.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(460.0, 0.0)
	card.add_theme_stylebox_override("panel", _make_glass_box(24))
	center.add_child(card)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	card.add_child(col)

	var title_lbl: Label = Label.new()
	title_lbl.text = "CHARLIE"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 52)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.80, 0.52, 1.0))
	col.add_child(title_lbl)

	var sub_lbl: Label = Label.new()
	sub_lbl.text = "De l'atome au cosmos"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 20)
	sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.94, 0.96, 0.92))
	col.add_child(sub_lbl)

	var desc_lbl: Label = Label.new()
	desc_lbl.text = "Guide la petite Charlie, une goutte de lave aux deux petites dents, à travers 6 mondes bioluminescents."
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 15)
	desc_lbl.add_theme_color_override("font_color", Color(0.88, 0.92, 0.96, 0.85))
	col.add_child(desc_lbl)

	var play_btn: Button = _make_menu_button("Plonger", true)
	play_btn.pressed.connect(_on_start_game)
	col.add_child(play_btn)

	var opt_btn: Button = _make_menu_button("⚙ Options", false)
	opt_btn.pressed.connect(func() -> void: _open_options(GameState.TITLE))
	col.add_child(opt_btn)


func _build_pause_panel() -> void:
	_pause_panel = _make_overlay_backdrop()
	_menu_layer.add_child(_pause_panel)

	var card: PanelContainer = _add_centered_card(_pause_panel, 400.0)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)

	var heading: Label = _make_heading("Pause")
	col.add_child(heading)

	var resume_btn: Button = _make_menu_button("Reprendre", true)
	resume_btn.pressed.connect(_resume_game)
	col.add_child(resume_btn)

	var opt_btn: Button = _make_menu_button("⚙ Options", false)
	opt_btn.pressed.connect(func() -> void: _open_options(GameState.PAUSED))
	col.add_child(opt_btn)

	var restart_btn: Button = _make_menu_button("Recommencer", false)
	restart_btn.pressed.connect(_on_start_game)
	col.add_child(restart_btn)

	var menu_btn: Button = _make_menu_button("Menu principal", false)
	menu_btn.pressed.connect(_enter_title_screen)
	col.add_child(menu_btn)


func _build_options_panel() -> void:
	_options_panel = _make_overlay_backdrop()
	_menu_layer.add_child(_options_panel)

	var card: PanelContainer = _add_centered_card(_options_panel, 520.0)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)

	col.add_child(_make_heading("⚙ Options"))

	var diff_title: Label = Label.new()
	diff_title.text = "Difficulté"
	diff_title.add_theme_font_size_override("font_size", 16)
	diff_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.62, 1.0))
	col.add_child(diff_title)

	var diff_row: HBoxContainer = HBoxContainer.new()
	diff_row.add_theme_constant_override("separation", 8)
	col.add_child(diff_row)

	for mode_key: String in ["toddler", "chill", "wild"]:
		var preset: Dictionary = Scales.DIFFICULTY_PRESETS[mode_key] as Dictionary
		var btn: Button = _make_menu_button(String(preset["label"]), false)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(func() -> void: _set_difficulty_option(mode_key))
		diff_row.add_child(btn)
		_diff_buttons[mode_key] = btn

	_diff_desc_label = Label.new()
	_diff_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diff_desc_label.add_theme_font_size_override("font_size", 13)
	_diff_desc_label.add_theme_color_override("font_color", Color(0.76, 0.92, 0.95, 0.88))
	col.add_child(_diff_desc_label)

	# Bites per scale slider (3..50)
	var bites_header: HBoxContainer = HBoxContainer.new()
	col.add_child(bites_header)

	var bites_lbl: Label = Label.new()
	bites_lbl.text = "Bouchées par monde"
	bites_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bites_lbl.add_theme_font_size_override("font_size", 16)
	bites_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.62, 1.0))
	bites_header.add_child(bites_lbl)

	_bites_value_label = Label.new()
	_bites_value_label.text = str(bites_per_scale)
	_bites_value_label.add_theme_font_size_override("font_size", 16)
	_bites_value_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	bites_header.add_child(_bites_value_label)

	_bites_slider = HSlider.new()
	_bites_slider.min_value = 3.0
	_bites_slider.max_value = 50.0
	_bites_slider.step = 1.0
	_bites_slider.value = float(bites_per_scale)
	_bites_slider.value_changed.connect(_on_bites_slider_changed)
	col.add_child(_bites_slider)

	# Cinematic mode toggle
	_cinematic_toggle = CheckButton.new()
	_cinematic_toggle.text = "Mode cinématique (illustrations d'histoire)"
	_cinematic_toggle.button_pressed = cinematic_mode
	_cinematic_toggle.add_theme_font_size_override("font_size", 15)
	_cinematic_toggle.toggled.connect(_on_cinematic_toggled)
	col.add_child(_cinematic_toggle)

	var back_btn: Button = _make_menu_button("Retour", true)
	back_btn.pressed.connect(_close_options)
	col.add_child(back_btn)

	_refresh_options_ui()


func _build_defeat_panel() -> void:
	_defeat_panel = _make_overlay_backdrop()
	_menu_layer.add_child(_defeat_panel)

	var card: PanelContainer = _add_centered_card(_defeat_panel, 420.0)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)

	col.add_child(_make_heading("Oups ! Petite pause"))

	var txt: Label = Label.new()
	txt.text = "La petite Charlie a perdu ses trois bulles protectrices, mais sa flamme ne s'éteint jamais !"
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.add_theme_font_size_override("font_size", 15)
	col.add_child(txt)

	var retry_btn: Button = _make_menu_button("Réessayer ce monde", true)
	retry_btn.pressed.connect(_retry_current_scale)
	col.add_child(retry_btn)

	var menu_btn: Button = _make_menu_button("Menu principal", false)
	menu_btn.pressed.connect(_enter_title_screen)
	col.add_child(menu_btn)


func _build_victory_panel() -> void:
	_victory_panel = _make_overlay_backdrop()
	_menu_layer.add_child(_victory_panel)

	var card: PanelContainer = _add_centered_card(_victory_panel, 460.0)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	card.add_child(col)

	col.add_child(_make_heading("✨ Un avec le Cosmos ✨"))

	var txt: Label = Label.new()
	txt.text = "Bravo ! La petite Charlie a traversé les 6 mondes, du quark minuscule jusqu'aux galaxies spirales."
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.add_theme_font_size_override("font_size", 16)
	col.add_child(txt)

	var explore_btn: Button = _make_menu_button("Flotter librement", true)
	explore_btn.pressed.connect(_continue_free_roam)
	col.add_child(explore_btn)

	var replay_btn: Button = _make_menu_button("Rejouer depuis l'atome", false)
	replay_btn.pressed.connect(_on_start_game)
	col.add_child(replay_btn)

	var menu_btn: Button = _make_menu_button("Menu principal", false)
	menu_btn.pressed.connect(_enter_title_screen)
	col.add_child(menu_btn)


func _make_glass_box(radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.10, 0.17, 0.84)
	box.border_color = Color(0.58, 0.88, 0.94, 0.34)
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 22.0
	box.content_margin_right = 22.0
	box.content_margin_top = 18.0
	box.content_margin_bottom = 18.0
	return box


func _make_hud_icon_button(icon_txt: String) -> Button:
	var b: Button = Button.new()
	b.text = icon_txt
	b.custom_minimum_size = Vector2(46.0, 46.0)
	b.add_theme_font_size_override("font_size", 20)
	var st: StyleBoxFlat = StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.13, 0.21, 0.80)
	st.border_color = Color(0.60, 0.90, 0.95, 0.38)
	st.set_border_width_all(1)
	st.set_corner_radius_all(23)
	b.add_theme_stylebox_override("normal", st)
	var hover: StyleBoxFlat = st.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.11, 0.23, 0.34, 0.92)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	return b


func _make_menu_button(label_txt: String, is_primary: bool) -> Button:
	var b: Button = Button.new()
	b.text = label_txt
	b.custom_minimum_size = Vector2(0.0, 48.0)
	b.add_theme_font_size_override("font_size", 18)
	var st: StyleBoxFlat = StyleBoxFlat.new()
	if is_primary:
		st.bg_color = Color(0.95, 0.44, 0.32, 0.95)
		st.border_color = Color(1.0, 0.82, 0.56, 0.85)
		b.add_theme_color_override("font_color", Color(1.0, 0.99, 0.95, 1.0))
	else:
		st.bg_color = Color(0.08, 0.17, 0.26, 0.86)
		st.border_color = Color(0.58, 0.88, 0.94, 0.36)
		b.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0, 0.95))
	st.set_border_width_all(1)
	st.set_corner_radius_all(24)
	b.add_theme_stylebox_override("normal", st)
	var hover: StyleBoxFlat = st.duplicate() as StyleBoxFlat
	hover.bg_color = st.bg_color.lightened(0.14)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	return b


func _make_overlay_backdrop() -> Control:
	var panel: Control = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim: ColorRect = ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.01, 0.04, 0.08, 0.72)
	panel.add_child(scrim)
	return panel


func _add_centered_card(parent_ctrl: Control, min_w: float) -> PanelContainer:
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent_ctrl.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(min_w, 0.0)
	card.add_theme_stylebox_override("panel", _make_glass_box(24))
	center.add_child(card)
	return card


func _make_heading(text_val: String) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text_val
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.56, 1.0))
	return lbl


# --- Settings persistence (user://settings.cfg) ---

func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	var saved_diff: String = String(cfg.get_value("gameplay", "difficulty", "chill"))
	if Scales.DIFFICULTY_PRESETS.has(saved_diff):
		difficulty_mode = saved_diff
	bites_per_scale = clampi(int(cfg.get_value("gameplay", "bites_per_scale", 15)), 3, 50)
	cinematic_mode = bool(cfg.get_value("gameplay", "cinematic_mode", true))


func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("gameplay", "difficulty", difficulty_mode)
	cfg.set_value("gameplay", "bites_per_scale", bites_per_scale)
	cfg.set_value("gameplay", "cinematic_mode", cinematic_mode)
	cfg.save(SETTINGS_PATH)


func _apply_settings_to_systems() -> void:
	if _ecosystem != null:
		_ecosystem.set_difficulty(difficulty_mode)
	_refresh_options_ui()


func _refresh_options_ui() -> void:
	if _diff_desc_label == null:
		return
	var preset: Dictionary = Scales.DIFFICULTY_PRESETS[difficulty_mode] as Dictionary
	_diff_desc_label.text = String(preset["desc"])
	for mode_key: String in _diff_buttons.keys():
		var btn: Button = _diff_buttons[mode_key] as Button
		var selected: bool = (mode_key == difficulty_mode)
		btn.modulate = Color(1.0, 0.84, 0.58, 1.0) if selected else Color(0.72, 0.82, 0.88, 0.78)
	if _bites_slider != null:
		_bites_slider.set_value_no_signal(float(bites_per_scale))
	if _bites_value_label != null:
		_bites_value_label.text = str(bites_per_scale)
	if _cinematic_toggle != null:
		_cinematic_toggle.set_pressed_no_signal(cinematic_mode)


func _set_difficulty_option(mode_key: String) -> void:
	if not Scales.DIFFICULTY_PRESETS.has(mode_key):
		return
	difficulty_mode = mode_key
	save_settings()
	_apply_settings_to_systems()
	if _audio != null:
		_audio.play_chime(1.1)


func _on_bites_slider_changed(val: float) -> void:
	bites_per_scale = clampi(roundi(val), 3, 50)
	if _bites_value_label != null:
		_bites_value_label.text = str(bites_per_scale)
	save_settings()


func _on_cinematic_toggled(toggled_on: bool) -> void:
	cinematic_mode = toggled_on
	save_settings()
	if _audio != null:
		_audio.play_chime(1.2 if toggled_on else 0.85)


# --- State transitions & Menu actions ---

func _hide_all_overlays() -> void:
	_title_panel.visible = false
	_pause_panel.visible = false
	_options_panel.visible = false
	_defeat_panel.visible = false
	_victory_panel.visible = false


func _enter_title_screen() -> void:
	state = GameState.TITLE
	_free_roam_after_victory = false
	_hide_all_overlays()
	_title_panel.visible = true
	_hud_root.visible = false
	_joystick.reset_stick()
	_reset_world_to_scale(0)


func _open_options(return_to: GameState) -> void:
	_options_return_state = return_to
	_hide_all_overlays()
	_options_panel.visible = true
	_refresh_options_ui()
	if _audio != null:
		_audio.play_chime(1.0)


func _close_options() -> void:
	_hide_all_overlays()
	if _options_return_state == GameState.PAUSED:
		state = GameState.PAUSED
		_pause_panel.visible = true
	else:
		state = GameState.TITLE
		_title_panel.visible = true
	if _audio != null:
		_audio.play_chime(0.92)


func _on_start_game() -> void:
	_free_roam_after_victory = false
	total_eaten = 0
	_reset_world_to_scale(0)
	_hide_all_overlays()
	if _audio != null:
		_audio.play_chime(1.25)

	if cinematic_mode and _cutscenes != null:
		state = GameState.CUTSCENE
		_hud_root.visible = false
		_joystick.reset_stick()
		_cutscenes.play_cutscene("intro", _begin_playing)
	else:
		_begin_playing()


func _begin_playing() -> void:
	_hide_all_overlays()
	state = GameState.PLAYING
	_hud_root.visible = true
	_update_hud()


func _on_pause_pressed() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.PAUSED
	_joystick.reset_stick()
	_hide_all_overlays()
	_pause_panel.visible = true
	if _audio != null:
		_audio.play_chime(0.88)


func _resume_game() -> void:
	_hide_all_overlays()
	state = GameState.PLAYING
	_hud_root.visible = true
	if _audio != null:
		_audio.play_chime(1.12)


func _retry_current_scale() -> void:
	_reset_world_to_scale(current_scale_index)
	_begin_playing()


func _continue_free_roam() -> void:
	_free_roam_after_victory = true
	_begin_playing()


func _on_toggle_mute() -> void:
	if _audio == null:
		return
	var is_m: bool = _audio.toggle_mute()
	_mute_btn.text = "🔇" if is_m else "🔊"


func _reset_world_to_scale(scale_idx: int) -> void:
	current_scale_index = clampi(scale_idx, 0, Scales.NUM_SCALES - 1)
	bites_in_scale = 0
	_heal_bite_counter = 0
	_spit_cd_left = 0.0
	_dash_cd_left = 0.0
	_projectiles.clear()
	_shockwaves.clear()
	_bursts.clear()

	var start_size: float = Scales.scale_start_size(current_scale_index)
	_charlie.reset_charlie(Vector2.ZERO, start_size)
	_ecosystem.set_difficulty(difficulty_mode)
	_ecosystem.reset_for_scale(_charlie, current_scale_index)
	if _audio != null:
		_audio.set_scale_index(current_scale_index)

	_current_zoom = _compute_target_zoom(start_size)
	_camera.position = _charlie.position
	_camera.zoom = Vector2(_current_zoom, _current_zoom)
	_update_hud()


# --- Power helpers ---

func _get_power_level() -> int:
	if current_scale_index >= 4:
		return 3
	if current_scale_index >= 2:
		return 2
	return 1


func _trigger_lava_spit() -> void:
	if state != GameState.PLAYING or _spit_cd_left > 0.0:
		return
	var preset: Dictionary = Scales.DIFFICULTY_PRESETS[difficulty_mode] as Dictionary
	_spit_cd_left = float(preset.get("spit_cd", 2.4))

	var lvl: int = _get_power_level()
	var base_angle: float = _charlie.facing_angle
	var speed: float = _charlie.world_size * (12.5 + float(lvl) * 1.6)
	var angles: Array[float] = [base_angle]
	if lvl == 2:
		angles = [base_angle - 0.24, base_angle, base_angle + 0.24]

	for ang: float in angles:
		var dir: Vector2 = Vector2.from_angle(ang)
		_projectiles.append({
			"pos": _charlie.position + dir * (_charlie.world_size * 1.05),
			"vel": dir * speed,
			"radius": _charlie.world_size * (0.42 if lvl == 3 else 0.26),
			"life": 1.35 if lvl == 3 else 1.05,
			"max_life": 1.35 if lvl == 3 else 1.05,
			"level": lvl,
		})

	if _audio != null:
		_audio.play_spit(lvl)


func _trigger_shockwave_dash() -> void:
	if state != GameState.PLAYING or _dash_cd_left > 0.0:
		return
	var preset: Dictionary = Scales.DIFFICULTY_PRESETS[difficulty_mode] as Dictionary
	_dash_cd_left = float(preset.get("dash_cd", 2.8))

	var lvl: int = _get_power_level()
	var input_dir: Vector2 = _read_move_input()
	var dash_angle: float = input_dir.angle() if input_dir.length_squared() > 0.04 else _charlie.facing_angle
	_charlie.trigger_dash(dash_angle, lvl)

	var wave_radius: float = _charlie.world_size * (4.2 + float(lvl) * 1.4)
	_shockwaves.append({
		"pos": _charlie.position,
		"radius": _charlie.world_size * 0.6,
		"max_radius": wave_radius,
		"life": 0.42,
		"max_life": 0.42,
		"color": Color(1.0, 0.78, 0.44, 1.0) if lvl == 3 else Color(0.45, 0.92, 0.98, 1.0),
	})

	# Repel nearby predators (and slightly shrink them at Nv.3 supernova!)
	var creatures: Array[Creature] = _ecosystem.get_creatures()
	for c: Creature in creatures:
		if not is_instance_valid(c) or not c.alive:
			continue
		var delta_v: Vector2 = c.position - _charlie.position
		var dist: float = delta_v.length()
		if dist > 0.001 and dist < wave_radius and c.world_size >= _charlie.world_size * 0.90:
			var push_dir: Vector2 = delta_v / dist
			c.velocity = push_dir * (_charlie.world_size * (7.0 + float(lvl) * 2.5))
			c.burn_flash = 0.85
			if lvl >= 3:
				c.world_size = maxf(_charlie.world_size * 0.72, c.world_size * 0.76)

	if _audio != null:
		_audio.play_dash(lvl)


# --- Input & Main Loop ---

func _unhandled_input(event: InputEvent) -> void:
	if state != GameState.PLAYING:
		if event is InputEventKey:
			var kev: InputEventKey = event as InputEventKey
			if kev.pressed and not kev.echo and kev.keycode == KEY_ESCAPE and state == GameState.PAUSED:
				_resume_game()
		return

	if event is InputEventKey:
		var kev: InputEventKey = event as InputEventKey
		if kev.pressed and not kev.echo:
			if kev.keycode == KEY_A or kev.keycode == KEY_J:
				_trigger_lava_spit()
			elif kev.keycode == KEY_E or kev.keycode == KEY_K or kev.keycode == KEY_SPACE:
				_trigger_shockwave_dash()
			elif kev.keycode == KEY_ESCAPE:
				_on_pause_pressed()


func _read_move_input() -> Vector2:
	var vec: Vector2 = Vector2.ZERO
	if _joystick != null and _joystick.is_active:
		vec = _joystick.output_vector
	else:
		var kb: Vector2 = Vector2.ZERO
		if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
			kb.x += 1.0
		if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_Q):
			kb.x -= 1.0
		if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
			kb.y += 1.0
		if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z):
			kb.y -= 1.0
		if kb.length_squared() > 0.0:
			vec = kb.normalized()
	return vec


func _process(delta: float) -> void:
	var dt: float = clampf(delta, 0.0, 0.05)
	var progress: float = Scales.size_to_progress(_charlie.world_size)
	var palette: Dictionary = Scales.get_blended_palette(progress)

	_update_background_shader(palette)

	if state == GameState.PLAYING:
		_step_playing(dt, palette)
	elif state == GameState.TITLE:
		# Gentle idle breathing on title screen
		_charlie.step_motion(dt, Vector2.ZERO, false, null, null, palette)


func _step_playing(dt: float, palette: Dictionary) -> void:
	_spit_cd_left = maxf(0.0, _spit_cd_left - dt)
	_dash_cd_left = maxf(0.0, _dash_cd_left - dt)

	var move_dir: Vector2 = _read_move_input()
	var has_input: bool = move_dir.length_squared() > 0.0025

	var view_px: Vector2 = get_viewport_rect().size
	var view_world: Vector2 = view_px / maxf(_current_zoom, 0.0001)

	var eco_info: Dictionary = _ecosystem.step_ecosystem(dt, _charlie, view_world, current_scale_index)
	var creatures: Array[Creature] = _ecosystem.get_creatures()

	var nearest_prey: Variant = eco_info.get("nearest_prey", null)
	var nearest_pred: Variant = eco_info.get("nearest_predator", null)

	_charlie.step_motion(dt, move_dir, has_input, nearest_prey, nearest_pred, palette)
	_step_projectiles_and_vfx(dt, creatures)
	_resolve_creature_collisions(creatures)

	# Smooth logarithmic Camera2D zoom & follow
	var target_zoom: float = _compute_target_zoom(_charlie.world_size)
	var zoom_t: float = 1.0 - exp(-dt * 4.5)
	_current_zoom = exp(lerpf(log(maxf(_current_zoom, 0.0001)), log(maxf(target_zoom, 0.0001)), zoom_t))
	_camera.zoom = Vector2(_current_zoom, _current_zoom)
	_camera.position = _camera.position.lerp(_charlie.position, 1.0 - exp(-dt * 9.0))

	_update_hud()
	_vfx_layer.queue_redraw()


func _step_projectiles_and_vfx(dt: float, creatures: Array[Creature]) -> void:
	var p_idx: int = _projectiles.size() - 1
	while p_idx >= 0:
		var p: Dictionary = _projectiles[p_idx]
		p["life"] = float(p["life"]) - dt
		p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * dt

		var hit: bool = false
		var p_pos: Vector2 = p["pos"] as Vector2
		var p_rad: float = float(p["radius"])
		var lvl: int = int(p["level"])

		for c: Creature in creatures:
			if not is_instance_valid(c) or not c.alive:
				continue
			if p_pos.distance_to(c.position) <= p_rad + c.world_size * 0.85:
				hit = true
				if lvl >= 3:
					# Nv.3 AoE plasma explosion shrinks all nearby predators
					var blast_r: float = _charlie.world_size * 3.6
					_shockwaves.append({
						"pos": p_pos,
						"radius": p_rad,
						"max_radius": blast_r,
						"life": 0.34,
						"max_life": 0.34,
						"color": Color(1.0, 0.62, 0.32, 1.0),
					})
					for other: Creature in creatures:
						if is_instance_valid(other) and other.alive and other.position.distance_to(p_pos) <= blast_r:
							_shrink_creature(other, 0.64)
				else:
					_shrink_creature(c, 0.68)
				_spawn_burst(p_pos, Color(1.0, 0.65, 0.32, 1.0), _charlie.world_size * 0.9)
				if _audio != null:
					_audio.play_shrink()
				break

		if hit or float(p["life"]) <= 0.0:
			_projectiles.remove_at(p_idx)
		p_idx -= 1

	var w_idx: int = _shockwaves.size() - 1
	while w_idx >= 0:
		var w: Dictionary = _shockwaves[w_idx]
		w["life"] = float(w["life"]) - dt
		var frac: float = 1.0 - clampf(float(w["life"]) / maxf(0.01, float(w["max_life"])), 0.0, 1.0)
		w["radius"] = lerpf(_charlie.world_size * 0.5, float(w["max_radius"]), frac)
		if float(w["life"]) <= 0.0:
			_shockwaves.remove_at(w_idx)
		w_idx -= 1

	var b_idx: int = _bursts.size() - 1
	while b_idx >= 0:
		var b: Dictionary = _bursts[b_idx]
		b["life"] = float(b["life"]) - dt
		if float(b["life"]) <= 0.0:
			_bursts.remove_at(b_idx)
		b_idx -= 1


func _shrink_creature(c: Creature, factor: float) -> void:
	var min_s: float = _charlie.world_size * 0.45
	c.world_size = maxf(min_s, c.world_size * factor)
	c.burn_flash = 1.0


func _resolve_creature_collisions(creatures: Array[Creature]) -> void:
	for c: Creature in creatures:
		if not is_instance_valid(c) or not c.alive:
			continue
		var dist: float = _charlie.position.distance_to(c.position)
		var touch_dist: float = _charlie.world_size * 0.88 + c.world_size * 0.72
		if dist > touch_dist:
			continue

		if c.world_size < _charlie.world_size * Ecosystem.EDIBLE_RATIO:
			# Edible prey!
			c.alive = false
			var prey_angle: float = (c.position - _charlie.position).angle()
			_charlie.trigger_chomp(prey_angle, 1.0)
			_spawn_burst(c.position, Color(1.0, 0.85, 0.52, 1.0), c.world_size * 1.4)
			if _audio != null:
				_audio.play_chomp(randf_range(0.92, 1.18))
			_on_prey_eaten()
			if state != GameState.PLAYING:
				return
		elif c.world_size >= _charlie.world_size * Ecosystem.PREDATOR_RATIO:
			# Larger predator!
			if _charlie.invuln_timer > 0.0:
				continue
			var away_angle: float = (_charlie.position - c.position).angle()
			_charlie.trigger_hurt(away_angle)
			if difficulty_mode == "toddler":
				# Gentle harmless bounce in 3-year-old Toddler mode
				if _audio != null:
					_audio.play_shrink()
			else:
				_charlie.droplets_alive = maxi(0, _charlie.droplets_alive - 1)
				if _audio != null:
					_audio.play_hurt()
				if _charlie.droplets_alive <= 0:
					_trigger_defeat()
					return


func _on_prey_eaten() -> void:
	total_eaten += 1
	bites_in_scale += 1
	_heal_bite_counter += 1

	# Regenerate 1 missing droplet every 5 bites
	if _heal_bite_counter >= 5 and _charlie.droplets_alive < Charlie.MAX_DROPLETS:
		_heal_bite_counter = 0
		_charlie.droplets_alive += 1
		if _audio != null:
			_audio.play_heal()

	if _free_roam_after_victory:
		_charlie.world_size = minf(Scales.MAX_SIZE * 1.25, _charlie.world_size * 1.015)
		return

	var frac: float = clampf(float(bites_in_scale) / float(maxi(1, bites_per_scale)), 0.0, 1.0)
	var scale_base: float = Scales.scale_start_size(current_scale_index)
	_charlie.world_size = scale_base * pow(Scales.SCALE_FACTOR, frac)

	if bites_in_scale >= bites_per_scale:
		_advance_scale()


func _advance_scale() -> void:
	if current_scale_index + 1 < Scales.NUM_SCALES:
		current_scale_index += 1
		bites_in_scale = 0
		_charlie.droplets_alive = Charlie.MAX_DROPLETS
		_ecosystem.reset_for_scale(_charlie, current_scale_index)
		if _audio != null:
			_audio.set_scale_index(current_scale_index)
			_audio.play_scale_up()

		if cinematic_mode and _cutscenes != null:
			state = GameState.CUTSCENE
			_hud_root.visible = false
			_joystick.reset_stick()
			var cid: String = "scale_%d" % current_scale_index
			_cutscenes.play_cutscene(cid, _begin_playing)
	else:
		if _audio != null:
			_audio.play_victory()
		if cinematic_mode and _cutscenes != null:
			state = GameState.CUTSCENE
			_hud_root.visible = false
			_joystick.reset_stick()
			_cutscenes.play_cutscene("victory", _show_victory_overlay)
		else:
			_show_victory_overlay()


func _trigger_defeat() -> void:
	state = GameState.DEFEAT
	_joystick.reset_stick()
	_hud_root.visible = false
	_hide_all_overlays()
	_defeat_panel.visible = true


func _show_victory_overlay() -> void:
	state = GameState.VICTORY
	_joystick.reset_stick()
	_hud_root.visible = false
	_hide_all_overlays()
	_victory_panel.visible = true


func _compute_target_zoom(charlie_size: float) -> float:
	# Keep Charlie at ~36 screen pixels radius across all 6 logarithmic scales
	return clampf(36.0 / maxf(charlie_size, 1.0), 0.0001, 4.0)


func _update_background_shader(palette: Dictionary) -> void:
	if _bg_mat == null:
		return
	_bg_mat.set_shader_parameter("bg_inner", palette["bg_inner"])
	_bg_mat.set_shader_parameter("bg_outer", palette["bg_outer"])
	_bg_mat.set_shader_parameter("mote_color", palette["mote_color"])
	_bg_mat.set_shader_parameter("cam_offset", _camera.position * _current_zoom)


func _update_hud() -> void:
	if _scale_label == null:
		return
	var sc: Dictionary = Scales.SCALES[current_scale_index] as Dictionary
	_scale_label.text = "%s · %s" % [String(sc["roman"]), String(sc["name"])]

	var prog: float = Scales.size_to_progress(_charlie.world_size)
	_size_label.text = Scales.format_scientific_size(prog)

	if difficulty_mode == "toddler":
		_lives_label.text = "Tout-petit · ∞"
	else:
		var dots: String = ""
		for i in range(Charlie.MAX_DROPLETS):
			dots += "●" if i < _charlie.droplets_alive else "○"
		_lives_label.text = dots

	if _free_roam_after_victory:
		_progress_bar.value = 100.0
		_progress_count_label.text = "Cosmos infini · %d bouchées" % total_eaten
	else:
		var pct: float = clampf(float(bites_in_scale) / float(maxi(1, bites_per_scale)) * 100.0, 0.0, 100.0)
		_progress_bar.value = pct
		_progress_count_label.text = "%d / %d" % [bites_in_scale, bites_per_scale]

	var preset: Dictionary = Scales.DIFFICULTY_PRESETS[difficulty_mode] as Dictionary
	var spit_max: float = maxf(0.1, float(preset.get("spit_cd", 2.4)))
	var dash_max: float = maxf(0.1, float(preset.get("dash_cd", 2.8)))
	var lvl_str: String = "Nv.%d" % _get_power_level()

	_spit_btn.level_text = lvl_str
	_spit_btn.cooldown_ratio = clampf(_spit_cd_left / spit_max, 0.0, 1.0)
	_spit_btn.queue_redraw()

	_dash_btn.level_text = lvl_str
	_dash_btn.cooldown_ratio = clampf(_dash_cd_left / dash_max, 0.0, 1.0)
	_dash_btn.queue_redraw()


func _spawn_burst(pos: Vector2, col: Color, radius: float) -> void:
	_bursts.append({
		"pos": pos,
		"color": col,
		"radius": radius,
		"life": 0.30,
		"max_life": 0.30,
	})


func _draw_world_vfx(canvas: Node2D) -> void:
	# Shockwaves
	for w: Dictionary in _shockwaves:
		var frac: float = clampf(float(w["life"]) / maxf(0.01, float(w["max_life"])), 0.0, 1.0)
		var col: Color = w["color"] as Color
		col.a = frac * 0.85
		var rad: float = float(w["radius"])
		canvas.draw_arc(w["pos"] as Vector2, rad, 0.0, TAU, 48, col, maxf(2.0, _charlie.world_size * 0.12 * frac), true)

	# Lava spit projectiles
	for p: Dictionary in _projectiles:
		var pos: Vector2 = p["pos"] as Vector2
		var r: float = float(p["radius"])
		var lvl: int = int(p["level"])
		var outer_col: Color = Color(1.0, 0.44, 0.22, 0.42) if lvl < 3 else Color(1.0, 0.72, 0.25, 0.48)
		var core_col: Color = Color(1.0, 0.82, 0.45, 0.96)
		canvas.draw_circle(pos, r * 1.55, outer_col)
		canvas.draw_circle(pos, r, Color(0.98, 0.38, 0.28, 0.94))
		canvas.draw_circle(pos, r * 0.56, core_col)

	# Chomp / impact bursts
	for b: Dictionary in _bursts:
		var frac: float = clampf(float(b["life"]) / maxf(0.01, float(b["max_life"])), 0.0, 1.0)
		var inv_f: float = 1.0 - frac
		var pos: Vector2 = b["pos"] as Vector2
		var col: Color = b["color"] as Color
		col.a = frac * 0.80
		var max_r: float = float(b["radius"])
		canvas.draw_arc(pos, max_r * (0.35 + inv_f * 0.85), 0.0, TAU, 24, col, maxf(1.5, max_r * 0.08 * frac), true)
		for i in range(6):
			var ang: float = float(i) * TAU / 6.0 + inv_f * 0.6
			var p_off: Vector2 = Vector2.from_angle(ang) * (max_r * (0.25 + inv_f * 0.95))
			canvas.draw_circle(pos + p_off, maxf(1.0, max_r * 0.14 * frac), col)
