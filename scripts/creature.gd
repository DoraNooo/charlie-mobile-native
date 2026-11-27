class_name Creature
extends Node2D
## World entity representing any of the 30 bioluminescent species across Charlie's 6 scales.
## Renders pre-baked 4-frame Kurzgesagt/Ori storybook sprite sheets via GPU Sprite2D
## with the unified 2.5D lighting + live Charlie bounce light + selective HDR bloom shader.

const SPRITE_DIR: String = "res://assets/sprites/creatures/"
const CREATURE_SHADER_PATH: String = "res://shaders/creature_25d.gdshader"

const PARAM_WORLD_ROT: StringName = &"world_rot"
const PARAM_DANGER_RIM: StringName = &"danger_rim"
const PARAM_EDIBLE_RIM: StringName = &"edible_rim"
const PARAM_BURN_FLASH: StringName = &"burn_flash"
const PARAM_ANIM_TIME: StringName = &"anim_time"
const PARAM_SWAY_AMP: StringName = &"sway_amp"
const PARAM_WORLD_POS: StringName = &"world_pos"
const PARAM_WORLD_RADIUS: StringName = &"world_radius"
const PARAM_ALPHA_MULT: StringName = &"alpha_mult"

const DIRECTIONAL_KINDS: Dictionary = {
	"electron": true,
	"photon": true,
	"bacteria": true,
	"tardigrade": true,
	"ant": true,
	"firefly": true,
	"ladybug": true,
	"moth": true,
	"frog": true,
	"owl": true,
	"car": true,
	"helicopter": true,
	"blimp": true,
	"comet": true,
}

const FLOAT_ROTATE_KINDS: Dictionary = {
	"quark": true,
	"atom": true,
	"molecule": true,
	"galaxy": true,
	"asteroid": true,
	"spore": true,
	"nebula": true,
	"star": true,
}

const RIGID_KINDS: Dictionary = {
	"asteroid": true,
	"moon": true,
	"planet": true,
	"ringed": true,
	"car": true,
	"helicopter": true,
	"blimp": true,
}

const WIDE_KINDS: Dictionary = {
	"comet": true,
	"photon": true,
	"bacteria": true,
	"ringed": true,
	"car": true,
	"owl": true,
	"helicopter": true,
	"blimp": true,
}

static var _tex_cache: Dictionary = {}
static var _creature_shader: Shader = null

var species: Dictionary = {}
var scale_index: int = 0
var world_size: float = 20.0
var velocity: Vector2 = Vector2.ZERO
var facing_angle: float = 0.0
var phase: float = 0.0
var alive: bool = true
var retiring: bool = false
var retire_timer: float = 0.0
var burn_flash: float = 0.0
var stun_timer: float = 0.0
var alpha: float = 0.0

var show_danger_halo: bool = true
var is_edible: bool = true
var is_predator: bool = false
var proximity_ratio: float = 0.0

var wander_angle: float = 0.0
var behavior_timer: float = 0.0
var orbit_dir: float = 1.0

var _sprite: Sprite2D = null
var _mat: ShaderMaterial = null
var _kind: String = "quark"
var _is_directional: bool = false
var _is_float_rotate: bool = false
var _spin_offset: float = 0.0
var _spin_rate: float = 0.0
var _sway_amp: float = 0.025
var _sprite_radius: float = 42.5
var _base_color: Color = Color("#67e8f9")
var _accent_color: Color = Color("#ffffff")


static func _get_creature_shader() -> Shader:
	if _creature_shader == null:
		if ResourceLoader.exists(CREATURE_SHADER_PATH, "Shader"):
			_creature_shader = load(CREATURE_SHADER_PATH) as Shader
	return _creature_shader


static func _get_species_texture(kind: String) -> Texture2D:
	if _tex_cache.has(kind):
		return _tex_cache[kind] as Texture2D
	var path: String = SPRITE_DIR + kind + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path, "Texture2D"):
		tex = load(path) as Texture2D
	if tex == null:
		var img: Image = Image.load_from_file(path)
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	if tex != null:
		_tex_cache[kind] = tex
	return tex


static func preload_scale(p_scale_idx: int) -> void:
	var idx: int = clampi(p_scale_idx, 0, Scales.NUM_SCALES - 1)
	var scale_data: Dictionary = Scales.SCALES[idx]
	var species_list: Array = scale_data.get("species", []) as Array
	for item: Variant in species_list:
		var spec: Dictionary = item as Dictionary
		var kind: String = str(spec.get("kind", ""))
		if not kind.is_empty():
			_get_species_texture(kind)


func _init() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "BodySprite"
	_sprite.centered = true
	_sprite.hframes = 4
	_sprite.vframes = 1
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_mat = ShaderMaterial.new()
	var sh: Shader = _get_creature_shader()
	if sh != null:
		_mat.shader = sh
	_sprite.material = _mat
	add_child(_sprite)


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
	retiring = false
	retire_timer = 0.0
	burn_flash = 0.0
	stun_timer = 0.0
	alpha = 0.0
	is_edible = true
	is_predator = false
	proximity_ratio = 0.0
	visible = true
	modulate = Color.WHITE

	_kind = str(spec.get("kind", "quark"))
	_is_directional = DIRECTIONAL_KINDS.has(_kind)
	_is_float_rotate = FLOAT_ROTATE_KINDS.has(_kind)
	_spin_offset = randf_range(-PI, PI)
	_spin_rate = orbit_dir * randf_range(0.20, 0.36)
	if RIGID_KINDS.has(_kind):
		_sway_amp = 0.012
	elif _is_float_rotate:
		_sway_amp = 0.018
	else:
		_sway_amp = 0.026
	_sprite_radius = 30.0 if WIDE_KINDS.has(_kind) else 42.5
	_base_color = spec.get("color", Color("#67e8f9")) as Color
	_accent_color = spec.get("accent", Color("#ffffff")) as Color

	_sprite.texture = _get_species_texture(_kind)
	_sprite.frame = 0
	if _mat != null:
		_mat.set_shader_parameter(PARAM_SWAY_AMP, _sway_amp)
	update_visuals()


func get_visual_snapshot() -> Dictionary:
	return {
		"texture": _sprite.texture if _sprite != null else null,
		"frame": _sprite.frame if _sprite != null else 0,
		"hframes": _sprite.hframes if _sprite != null else 4,
		"color": _base_color,
		"accent": _accent_color,
	}


func update_visuals(ref_size: float = 0.0) -> void:
	if not alive or world_size < 1.0:
		visible = false
		return

	# Size-based depth sorting so small prey never draw over massive predators
	var norm_size: float = (world_size / maxf(ref_size, 1.0)) * Scales.BASE_SIZE if ref_size > 0.0 else world_size
	z_index = clampi(int(round((log(maxf(norm_size, 1.0)) / log(2.0)) * 2.0)) - 10, -4, 3)

	# Continuous smooth rotation for floating species; 4-frame sheet animation for articulated ones
	var rot: float = 0.0
	if _is_float_rotate:
		_sprite.frame = 0
		rot = wrapf(_spin_offset + phase * _spin_rate, -PI, PI)
	else:
		_sprite.frame = int(floor(phase * 1.6)) & 3
		rot = facing_angle if _is_directional else 0.0

	# Match baked sprite radius accurately to world_size hitbox
	var body_scale: float = world_size / _sprite_radius
	_sprite.scale = Vector2(body_scale, body_scale)

	if stun_timer > 0.01:
		rot += sin(phase * 14.0) * 0.16
		_sprite.self_modulate = Color(0.82, 0.90, 1.0, 1.0)
	elif burn_flash > 0.01:
		rot += sin(phase * 18.0) * (0.10 * clampf(burn_flash, 0.0, 1.0))
		_sprite.self_modulate = Color.WHITE
	else:
		_sprite.self_modulate = Color.WHITE
	_sprite.rotation = rot

	# Update unified 2.5D shader parameters (lighting, Charlie bounce, gameplay rims, smooth alpha)
	if _mat != null:
		var danger_val: float = 0.0
		var edible_val: float = 0.0
		if not retiring:
			if is_predator and show_danger_halo:
				danger_val = clampf(0.26 + proximity_ratio * 0.74, 0.0, 1.0)
			elif is_edible and proximity_ratio > 0.02:
				edible_val = clampf(proximity_ratio * 0.85, 0.0, 0.85)

		_mat.set_shader_parameter(PARAM_WORLD_ROT, rot)
		_mat.set_shader_parameter(PARAM_WORLD_POS, position)
		_mat.set_shader_parameter(PARAM_WORLD_RADIUS, world_size)
		_mat.set_shader_parameter(PARAM_DANGER_RIM, danger_val)
		_mat.set_shader_parameter(PARAM_EDIBLE_RIM, edible_val)
		_mat.set_shader_parameter(PARAM_BURN_FLASH, clampf(burn_flash, 0.0, 1.0))
		_mat.set_shader_parameter(PARAM_ANIM_TIME, phase)
		_mat.set_shader_parameter(PARAM_ALPHA_MULT, clampf(alpha, 0.0, 1.0))
