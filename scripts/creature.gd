class_name Creature
extends Node2D
## World entity representing any of the 30 bioluminescent species across Charlie's 6 scales.
## Renders pre-baked 4-frame Kurzgesagt/Ori storybook sprite sheets via GPU Sprite2D
## with a shared additive radial glow halo — zero per-frame CanvasItem _draw() calls.

const SPRITE_DIR: String = "res://assets/sprites/creatures/"
const GLOW_TEX_SIZE: int = 128

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
static var _glow_tex: GradientTexture2D = null
static var _glow_mat: CanvasItemMaterial = null

var species: Dictionary = {}
var scale_index: int = 0
var world_size: float = 20.0
var velocity: Vector2 = Vector2.ZERO
var facing_angle: float = 0.0
var phase: float = 0.0
var alive: bool = true
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

var _glow_sprite: Sprite2D = null
var _sprite: Sprite2D = null
var _kind: String = "quark"
var _is_directional: bool = false
var _sprite_radius: float = 42.5
var _base_color: Color = Color("#67e8f9")
var _accent_color: Color = Color("#ffffff")


static func _get_glow_texture() -> GradientTexture2D:
	if _glow_tex == null:
		var grad: Gradient = Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.35, 0.72, 1.0])
		grad.colors = PackedColorArray([
			Color(1.0, 1.0, 1.0, 0.95),
			Color(1.0, 1.0, 1.0, 0.45),
			Color(1.0, 1.0, 1.0, 0.12),
			Color(1.0, 1.0, 1.0, 0.0),
		])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.width = GLOW_TEX_SIZE
		_glow_tex.height = GLOW_TEX_SIZE
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(0.5, 0.0)
		_glow_tex.gradient = grad
	return _glow_tex


static func _get_glow_material() -> CanvasItemMaterial:
	if _glow_mat == null:
		_glow_mat = CanvasItemMaterial.new()
		_glow_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _glow_mat


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
	_glow_sprite = Sprite2D.new()
	_glow_sprite.name = "GlowHalo"
	_glow_sprite.centered = true
	_glow_sprite.texture = _get_glow_texture()
	_glow_sprite.material = _get_glow_material()
	_glow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_glow_sprite)

	_sprite = Sprite2D.new()
	_sprite.name = "BodySprite"
	_sprite.centered = true
	_sprite.hframes = 4
	_sprite.vframes = 1
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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
	burn_flash = 0.0
	stun_timer = 0.0
	alpha = 0.0
	modulate = Color(1.0, 1.0, 1.0, 0.0)

	_kind = str(spec.get("kind", "quark"))
	_is_directional = DIRECTIONAL_KINDS.has(_kind)
	_sprite_radius = 30.0 if WIDE_KINDS.has(_kind) else 42.5
	_base_color = spec.get("color", Color("#67e8f9")) as Color
	_accent_color = spec.get("accent", Color("#ffffff")) as Color

	_sprite.texture = _get_species_texture(_kind)
	_sprite.frame = 0
	update_visuals()


func update_visuals() -> void:
	if not alive or world_size < 1.0:
		visible = false
		return

	# Cheap 4-frame sprite sheet animation (zero redraws!)
	_sprite.frame = int(floor(phase * 1.6)) & 3

	# Match baked sprite radius accurately to world_size hitbox
	var body_scale: float = world_size / _sprite_radius
	_sprite.scale = Vector2(body_scale, body_scale)

	# Orientation: directional creatures rotate toward velocity; upright species stay level
	var rot: float = facing_angle if _is_directional else 0.0
	if stun_timer > 0.01:
		rot += sin(phase * 14.0) * 0.16
		_sprite.self_modulate = Color(0.82, 0.90, 1.0, 1.0)
	elif burn_flash > 0.01:
		var flash_t: float = clampf(burn_flash, 0.0, 1.0)
		rot += sin(phase * 18.0) * (0.10 * flash_t)
		_sprite.self_modulate = Color(
			1.0 + flash_t * 0.55,
			1.0 + flash_t * 0.38,
			1.0 + flash_t * 0.12,
			1.0
		)
	else:
		_sprite.self_modulate = Color.WHITE
	_sprite.rotation = rot

	# Soft additive GPU radial glow halo (ambient bioluminescence + proximity/predator feedback)
	var glow_col: Color = _base_color.lerp(_accent_color, 0.35)
	var glow_alpha: float = 0.22 + 0.04 * sin(phase * 2.2)
	var glow_mult: float = 2.65

	if proximity_ratio > 0.02:
		if is_predator and show_danger_halo:
			var pulse: float = 0.5 + 0.5 * sin(phase * 5.0)
			glow_col = glow_col.lerp(Color(1.0, 0.24, 0.30), clampf(0.55 + proximity_ratio * 0.45, 0.0, 1.0))
			glow_alpha = maxf(glow_alpha, proximity_ratio * (0.38 + 0.26 * pulse))
			glow_mult = 3.05 + 0.32 * pulse
		elif is_edible:
			glow_col = glow_col.lerp(Color(0.52, 0.98, 0.82), proximity_ratio * 0.65)
			glow_alpha = maxf(glow_alpha, 0.24 + proximity_ratio * 0.22)
			glow_mult = 2.75 + proximity_ratio * 0.20

	if burn_flash > 0.01:
		var ft: float = clampf(burn_flash, 0.0, 1.0)
		glow_col = glow_col.lerp(Color(1.0, 0.88, 0.55), ft * 0.9)
		glow_alpha = maxf(glow_alpha, 0.42 + ft * 0.38)
		glow_mult += ft * 0.45

	glow_col.a = clampf(glow_alpha, 0.0, 0.88)
	_glow_sprite.modulate = glow_col
	var glow_scale: float = (world_size * glow_mult) / float(GLOW_TEX_SIZE)
	_glow_sprite.scale = Vector2(glow_scale, glow_scale)
