class_name Charlie
extends Node2D
## Player entity: la petite Charlie — Voie B True 3D Dual-Shell Studio Ghibli Translucent Slime.
## Sculpted single-mesh 3D honey-coral living jelly (baby-slime forehead dome, plump belly,
## graceful flowing molten tail, two stubby rounded gel flippers) with heroic 3/4 3D yaw/banking,
## inner volumetric shell + outer glossy clearcoat shell, 3 jewel-like golden amber vitality pearls,
## expressive Ghibli eyes/cheeks/tiny fangs, shimmering micro-bubbles, and Beer-Lambert 2D refraction.

const INNER_SHADER_PATH: String = "res://shaders/charlie_3d_inner.gdshader"
const GEL_SHADER_PATH: String = "res://shaders/charlie_3d_gel.gdshader"
const COMPOSITE_SHADER_PATH: String = "res://shaders/charlie_refract_composite.gdshader"

const MAX_DROPLETS: int = 3
const BODY_QUAD_SCALE: float = 4.8
const BODY_HALF_SCALE: float = 2.4
const SUBVIEWPORT_SIZE: int = 320

const LOBE_COUNT: int = 5
const CORE_BASE_RADIUS: float = 0.46
const LOBE_MAX_OFFSET: float = 0.46
const PEARL_MAX_OFFSET: float = 0.34
const GULP_DURATION: float = 0.38

const MAX_SWALLOWED_PREY: int = 3
const SWALLOW_SPIRAL_TIME: float = 0.16
const SWALLOW_DISSOLVE_TIME: float = 0.40
const SWALLOW_TOTAL_TIME: float = SWALLOW_SPIRAL_TIME + SWALLOW_DISSOLVE_TIME

const LOBE_BASE_RADII: Array[float] = [0.30, 0.29, 0.29, 0.27, 0.27]
const LOBE_STIFFNESS: Array[float] = [90.0, 110.0, 110.0, 130.0, 130.0]
const LOBE_DAMPING: Array[float] = [8.0, 8.8, 8.8, 10.0, 10.0]
const LOBE_MASS: Array[float] = [0.44, 0.36, 0.36, 0.28, 0.28]
const LOBE_UNIFORM_NAMES: Array[StringName] = [&"lobe_0", &"lobe_1", &"lobe_2", &"lobe_3", &"lobe_4"]

const PEARL_SIZE_VARIATION: Array[float] = [1.08, 0.94, 0.80]

const MICRO_BUBBLE_RADII: Array[float] = [0.036, 0.028, 0.032, 0.022, 0.026, 0.020]
const MICRO_BUBBLE_SEEDS: Array[Vector3] = [
	Vector3(-0.28, -0.22, 0.06),
	Vector3(0.24, -0.18, -0.06),
	Vector3(-0.16, -0.34, -0.10),
	Vector3(0.16, -0.30, 0.10),
	Vector3(-0.04, -0.16, -0.14),
	Vector3(-0.34, -0.26, -0.16),
]

const COLOR_EYE_DARK: Color = Color("#210c08")
const COLOR_SMILE_DARK: Color = Color("#3a1410")
const COLOR_IRIS_AMBER: Color = Color(0.98, 0.64, 0.20, 0.92)
const COLOR_SCLERA: Color = Color(1.0, 0.985, 0.96, 0.96)
const COLOR_MOUTH_FILL: Color = Color(0.26, 0.06, 0.10, 1.0)
const COLOR_TONGUE: Color = Color("#ff7c8e")
const COLOR_CHEEK_BLUSH: Color = Color("#ff4838")
const COLOR_TEETH: Color = Color(1.0, 0.996, 0.965, 1.0)
const COLOR_CATCHLIGHT: Color = Color(1.0, 0.996, 0.98, 1.0)

# Public API properties (preserved 100%)
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

# Scene hierarchy nodes (Voie B: BackBufferCopy -> SubViewport -> SwallowedLayer -> CompositeQuad)
var _back_buffer: BackBufferCopy = null
var _subviewport: SubViewport = null
var _swallowed_layer: _SwallowedLayer = null
var _composite_quad: Sprite2D = null

# Shaders & Materials
var _inner_mat: ShaderMaterial = null
var _gel_mat: ShaderMaterial = null
var _composite_mat: ShaderMaterial = null
var _spark_mat: ShaderMaterial = null

# 3D Scene Nodes inside SubViewport
var _camera_3d: Camera3D = null
var _slime_root: Node3D = null
var _inner_shell: MeshInstance3D = null
var _outer_shell: MeshInstance3D = null
var _pearl_nodes: Array[MeshInstance3D] = []
var _nascent_spark: MeshInstance3D = null
var _bubble_nodes: Array[MeshInstance3D] = []
var _face_rig: Node3D = null
var _left_eye_rig: Node3D = null
var _right_eye_rig: Node3D = null
var _left_eye_ball: Node3D = null
var _right_eye_ball: Node3D = null
var _left_eye_sclera: MeshInstance3D = null
var _right_eye_sclera: MeshInstance3D = null
var _left_eye_iris: MeshInstance3D = null
var _right_eye_iris: MeshInstance3D = null
var _left_eye_hi1: MeshInstance3D = null
var _right_eye_hi1: MeshInstance3D = null
var _left_eye_hi2: MeshInstance3D = null
var _right_eye_hi2: MeshInstance3D = null
var _left_eye_happy: MeshInstance3D = null
var _right_eye_happy: MeshInstance3D = null
var _left_cheek: MeshInstance3D = null
var _right_cheek: MeshInstance3D = null
var _mouth_rig: Node3D = null
var _mouth_smile: MeshInstance3D = null
var _mouth_cavity: MeshInstance3D = null
var _mouth_tongue: MeshInstance3D = null
var _tooth_left: MeshInstance3D = null
var _tooth_right: MeshInstance3D = null

# Motion, expression & soft-body simulation state
var _time: float = 0.0
var _invuln_flash: float = 0.0
var _core_radius: float = CORE_BASE_RADIUS
var _wobble_amp: float = 0.0
var _fear_ripple: float = 0.0
var _vitality_ratio: float = 1.0
var _regen_progress: float = 0.0
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

# Heroic 3/4 3D turn, banking, flowing molten tail & flipper lag state
var _last_horiz_sign: float = 1.0
var _rig_yaw: float = 0.22
var _rig_pitch: float = 0.0
var _rig_bank: float = 0.0
var _tail_dir_world: Vector3 = Vector3(-0.88, -0.24, -0.40)
var _tail_strength: float = 0.44
var _fin_lag_world: Vector3 = Vector3.ZERO

var _palette_core: Color = Color(1.0, 0.71, 0.42, 1.0)
var _palette_edge: Color = Color(1.0, 0.42, 0.34, 1.0)
var _palette_glow: Color = Color(1.0, 0.50, 0.28, 1.0)

# Flavor color wash from recently swallowed prey
var _flavor_color: Color = Color(1.0, 0.71, 0.42, 1.0)
var _flavor_intensity: float = 0.0

# 5 viscous spring-mass lobes in 2D local space (0=rear tail, 1/2=flanks, 3/4=front lobes)
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

# 3 internal 3D golden vitality pearls orbiting smoothly inside Charlie's lower belly (z in [-0.20, +0.20])
var _pearl_pos_3d: Array[Vector3] = [
	Vector3(-0.26, -0.38, 0.10),
	Vector3(0.02, -0.46, -0.08),
	Vector3(0.26, -0.36, 0.08),
]
var _pearl_vel_3d: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _pearl_scales: Array[float] = [1.0, 1.0, 1.0]
var _prev_droplets_alive: int = MAX_DROPLETS

# Suspended micro-bubble inertia offset
var _bubble_lag: Vector3 = Vector3.ZERO
var _bubble_lag_vel: Vector3 = Vector3.ZERO

# Swallowed prey currently spiraling into Charlie's belly and dissolving into golden bubbles
var _swallowed_prey: Array[Dictionary] = []
var _swallow_spin_toggle: float = 1.0


class _SwallowedLayer extends Node2D:
	var owner_charlie: Charlie = null

	func _draw() -> void:
		if owner_charlie != null:
			owner_charlie._draw_swallowed_prey(self)


func _ready() -> void:
	_setup_visuals()
	reset_charlie(position, world_size)


func _setup_visuals() -> void:
	if _subviewport != null:
		return

	# Child 1: BackBufferCopy (z_index = 1 so _SwallowedLayer at z_index = 0 renders BEFORE it
	# and is captured + refracted inside Charlie's translucent belly, while CompositeQuad at z_index = 1
	# added AFTER BackBufferCopy composites cleanly on top!)
	# Uses COPY_MODE_RECT on Vulkan Mobile/Forward+ and COPY_MODE_VIEWPORT on OpenGL3 Compatibility
	# to avoid Godot 4.3's GL3 COPY_MODE_RECT Y-flip artifact off screen center.
	_back_buffer = BackBufferCopy.new()
	_back_buffer.name = "BackBufferCopy"
	var is_gl_compat: bool = RenderingServer.get_rendering_device() == null
	_back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT if is_gl_compat else BackBufferCopy.COPY_MODE_RECT
	_back_buffer.z_index = 1
	add_child(_back_buffer)

	# Child 2: 3D SubViewport rendering Charlie's true 3D soft-body jelly + embedded anatomy
	_subviewport = SubViewport.new()
	_subviewport.name = "CharlieSubViewport"
	_subviewport.size = Vector2i(SUBVIEWPORT_SIZE, SUBVIEWPORT_SIZE)
	_subviewport.transparent_bg = true
	_subviewport.own_world_3d = true
	_subviewport.msaa_3d = Viewport.MSAA_4X
	_subviewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_subviewport.handle_input_locally = false
	_subviewport.gui_disable_input = true
	add_child(_subviewport)

	_build_3d_scene()

	# Child 3: _SwallowedLayer (z_index = 0, renders swallowed prey spiraling & dissolving in belly)
	_swallowed_layer = _SwallowedLayer.new()
	_swallowed_layer.name = "SwallowedLayer"
	_swallowed_layer.owner_charlie = self
	_swallowed_layer.z_index = 0
	add_child(_swallowed_layer)

	# Child 4: CompositeQuad (Sprite2D, z_index = 1, refracts 2D world + composites 3D SubViewport)
	_composite_quad = Sprite2D.new()
	_composite_quad.name = "CompositeQuad"
	_composite_quad.centered = true
	_composite_quad.z_index = 1
	_composite_quad.texture = _subviewport.get_texture()
	_composite_quad.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_composite_mat = ShaderMaterial.new()
	var comp_shader: Shader = load(COMPOSITE_SHADER_PATH) as Shader
	if comp_shader != null:
		_composite_mat.shader = comp_shader
	_composite_quad.material = _composite_mat
	add_child(_composite_quad)

	_last_synced_size = -1.0
	_sync_body_rect()


func _build_3d_scene() -> void:
	# Calibrated Perspective Camera3D (fov 30, z = 6.4 -> visible half-height 1.715 units)
	# Gives Charlie richer screen presence while ensuring her full sculpted molten tail NEVER clips!
	_camera_3d = Camera3D.new()
	_camera_3d.name = "CharlieCamera3D"
	_camera_3d.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera_3d.fov = 30.0
	_camera_3d.position = Vector3(0.0, 0.0, 6.4)
	_camera_3d.near = 0.5
	_camera_3d.far = 20.0
	_camera_3d.current = true
	_subviewport.add_child(_camera_3d)

	# SubViewport-isolated WorldEnvironment (linear tonemap for exact sRGB fidelity)
	var world_env := WorldEnvironment.new()
	world_env.name = "CharlieWorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.94, 0.88, 1.0)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world_env.environment = env
	_subviewport.add_child(world_env)

	# Key light from top-left-front (warm ivory)
	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.rotation_degrees = Vector3(-35.0, 32.0, 0.0)
	key_light.light_color = Color(1.0, 0.96, 0.90, 1.0)
	key_light.light_energy = 1.35
	key_light.shadow_enabled = false
	_subviewport.add_child(key_light)

	# Subtle cool rim light from bottom-right-back
	var rim_light := DirectionalLight3D.new()
	rim_light.name = "RimLight"
	rim_light.rotation_degrees = Vector3(28.0, -145.0, 0.0)
	rim_light.light_color = Color(0.76, 0.90, 1.0, 1.0)
	rim_light.light_energy = 0.55
	rim_light.shadow_enabled = false
	_subviewport.add_child(rim_light)

	# Parent 3D Slime Rig Root for heroic 3/4 yaw, pitch & banking turn
	_slime_root = Node3D.new()
	_slime_root.name = "SlimeRoot"
	_subviewport.add_child(_slime_root)

	# High-density smooth sphere shared by BOTH inner volumetric & outer clearcoat shells (56x34)
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.88
	shell_mesh.height = 1.76
	shell_mesh.radial_segments = 56
	shell_mesh.rings = 34

	# 1. Inner Volumetric 3D Honey-Coral Shell (cull_front, sorting_offset = -1.0, renders BEHIND anatomy!)
	_inner_shell = MeshInstance3D.new()
	_inner_shell.name = "InnerVolumetricShell"
	_inner_shell.mesh = shell_mesh
	_inner_shell.sorting_offset = -1.0
	_inner_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_inner_mat = ShaderMaterial.new()
	var inner_shader: Shader = load(INNER_SHADER_PATH) as Shader
	if inner_shader != null:
		_inner_mat.shader = inner_shader
	_inner_shell.material_override = _inner_mat
	_slime_root.add_child(_inner_shell)

	# 2. Embedded Internal 3D Anatomy (sorting_offset 0.24..0.75, suspended INSIDE the dual shells!)
	_build_internal_pearls()
	_build_internal_bubbles()
	_build_face_rig()

	# 3. Outer Glossy Clearcoat 3D Slime Shell (cull_back, sorting_offset = 2.0, renders OVER anatomy!)
	_outer_shell = MeshInstance3D.new()
	_outer_shell.name = "OuterGelShell"
	_outer_shell.mesh = shell_mesh
	_outer_shell.sorting_offset = 2.0
	_outer_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_gel_mat = ShaderMaterial.new()
	var gel_shader: Shader = load(GEL_SHADER_PATH) as Shader
	if gel_shader != null:
		_gel_mat.shader = gel_shader
	_outer_shell.material_override = _gel_mat
	_slime_root.add_child(_outer_shell)


func _build_internal_pearls() -> void:
	var pearls_root := Node3D.new()
	pearls_root.name = "VitalityPearls"
	_slime_root.add_child(pearls_root)

	var pearl_mesh := SphereMesh.new()
	pearl_mesh.radius = 0.102
	pearl_mesh.height = 0.204
	pearl_mesh.radial_segments = 24
	pearl_mesh.rings = 14

	var pearl_mat: ShaderMaterial = _create_pearl_material()

	_pearl_nodes.clear()
	for i: int in range(MAX_DROPLETS):
		var pearl := MeshInstance3D.new()
		pearl.name = "VitalityPearl_%d" % i
		pearl.mesh = pearl_mesh
		pearl.material_override = pearl_mat
		pearl.sorting_offset = 0.24 + float(i) * 0.02
		pearl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		pearls_root.add_child(pearl)
		_pearl_nodes.append(pearl)

	# Tiny nascent golden regeneration spark inside Charlie's lower belly
	_nascent_spark = MeshInstance3D.new()
	_nascent_spark.name = "NascentRegenSpark"
	var spark_mesh := SphereMesh.new()
	spark_mesh.radius = 0.105
	spark_mesh.height = 0.210
	spark_mesh.radial_segments = 18
	spark_mesh.rings = 12
	_nascent_spark.mesh = spark_mesh
	_spark_mat = _create_spark_material()
	_nascent_spark.material_override = _spark_mat
	_nascent_spark.sorting_offset = 0.30
	_nascent_spark.position = Vector3(0.0, -0.38, 0.06)
	_nascent_spark.visible = false
	_nascent_spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pearls_root.add_child(_nascent_spark)


func _build_internal_bubbles() -> void:
	var bubbles_root := Node3D.new()
	bubbles_root.name = "MicroBubbles"
	_slime_root.add_child(bubbles_root)

	var bubble_mat: ShaderMaterial = _create_micro_bubble_material()
	_bubble_nodes.clear()
	for i: int in range(MICRO_BUBBLE_RADII.size()):
		var r: float = MICRO_BUBBLE_RADII[i]
		var bm := SphereMesh.new()
		bm.radius = r
		bm.height = r * 2.0
		bm.radial_segments = 16
		bm.rings = 10
		var b_node := MeshInstance3D.new()
		b_node.name = "MicroBubble_%d" % i
		b_node.mesh = bm
		b_node.material_override = bubble_mat
		b_node.sorting_offset = 0.35
		b_node.position = MICRO_BUBBLE_SEEDS[i]
		b_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bubbles_root.add_child(b_node)
		_bubble_nodes.append(b_node)


func _build_face_rig() -> void:
	_face_rig = Node3D.new()
	_face_rig.name = "FaceRig"
	_face_rig.position = Vector3(0.0, 0.15, 0.50)
	_slime_root.add_child(_face_rig)

	# Soft subsurface rosy-vermilion cheeks (#ff4838) tucked warmly beneath the eyes inside the gel
	var cheek_mesh := SphereMesh.new()
	cheek_mesh.radius = 1.0
	cheek_mesh.height = 2.0
	cheek_mesh.radial_segments = 20
	cheek_mesh.rings = 12
	var cheek_mat: ShaderMaterial = _create_cheek_material()

	_left_cheek = MeshInstance3D.new()
	_left_cheek.name = "LeftCheek"
	_left_cheek.mesh = cheek_mesh
	_left_cheek.material_override = cheek_mat
	_left_cheek.scale = Vector3(0.155, 0.088, 0.042)
	_left_cheek.position = Vector3(-0.36, -0.095, 0.015)
	_left_cheek.sorting_offset = 0.55
	_left_cheek.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_face_rig.add_child(_left_cheek)

	_right_cheek = MeshInstance3D.new()
	_right_cheek.name = "RightCheek"
	_right_cheek.mesh = cheek_mesh
	_right_cheek.material_override = cheek_mat
	_right_cheek.scale = Vector3(0.155, 0.088, 0.042)
	_right_cheek.position = Vector3(0.36, -0.095, 0.015)
	_right_cheek.sorting_offset = 0.55
	_right_cheek.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_face_rig.add_child(_right_cheek)

	# Shared expressive Studio Ghibli eye materials & meshes
	var eye_mat: ShaderMaterial = _create_eyeball_material()
	var iris_mat: ShaderMaterial = _create_iris_amber_material()
	var white_mat: StandardMaterial3D = _create_unshaded_color_material(COLOR_CATCHLIGHT, false)
	var sclera_mat: ShaderMaterial = _create_sclera_material()
	var happy_arc_mesh: ArrayMesh = _build_curved_tube_mesh(0.26, 0.084, 0.028, 14, 8)
	var happy_mat: StandardMaterial3D = _create_unshaded_color_material(COLOR_EYE_DARK, false)
	happy_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var smile_mat: StandardMaterial3D = _create_unshaded_color_material(COLOR_SMILE_DARK, false)
	smile_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var eyeball_mesh := SphereMesh.new()
	eyeball_mesh.radius = 0.188
	eyeball_mesh.height = 0.376
	eyeball_mesh.radial_segments = 24
	eyeball_mesh.rings = 16

	var sclera_mesh := SphereMesh.new()
	sclera_mesh.radius = 0.200
	sclera_mesh.height = 0.400
	sclera_mesh.radial_segments = 22
	sclera_mesh.rings = 14

	var iris_mesh := SphereMesh.new()
	iris_mesh.radius = 0.124
	iris_mesh.height = 0.248
	iris_mesh.radial_segments = 20
	iris_mesh.rings = 12

	var hi1_mesh := SphereMesh.new()
	hi1_mesh.radius = 0.064
	hi1_mesh.height = 0.128
	hi1_mesh.radial_segments = 16
	hi1_mesh.rings = 10

	var hi2_mesh := SphereMesh.new()
	hi2_mesh.radius = 0.029
	hi2_mesh.height = 0.058
	hi2_mesh.radial_segments = 12
	hi2_mesh.rings = 8

	# Build Left & Right 3D Soulful Ghibli Eye Rigs
	var left_parts: Dictionary = _create_eye_rig(
		"LeftEye", Vector3(-0.275, 0.065, 0.0),
		eyeball_mesh, sclera_mesh, iris_mesh, hi1_mesh, hi2_mesh, happy_arc_mesh,
		eye_mat, sclera_mat, iris_mat, white_mat, happy_mat
	)
	_left_eye_rig = left_parts["rig"] as Node3D
	_left_eye_ball = left_parts["ball"] as Node3D
	_left_eye_sclera = left_parts["sclera"] as MeshInstance3D
	_left_eye_iris = left_parts["iris"] as MeshInstance3D
	_left_eye_hi1 = left_parts["hi1"] as MeshInstance3D
	_left_eye_hi2 = left_parts["hi2"] as MeshInstance3D
	_left_eye_happy = left_parts["happy"] as MeshInstance3D
	_face_rig.add_child(_left_eye_rig)

	var right_parts: Dictionary = _create_eye_rig(
		"RightEye", Vector3(0.275, 0.065, 0.0),
		eyeball_mesh, sclera_mesh, iris_mesh, hi1_mesh, hi2_mesh, happy_arc_mesh,
		eye_mat, sclera_mat, iris_mat, white_mat, happy_mat
	)
	_right_eye_rig = right_parts["rig"] as Node3D
	_right_eye_ball = right_parts["ball"] as Node3D
	_right_eye_sclera = right_parts["sclera"] as MeshInstance3D
	_right_eye_iris = right_parts["iris"] as MeshInstance3D
	_right_eye_hi1 = right_parts["hi1"] as MeshInstance3D
	_right_eye_hi2 = right_parts["hi2"] as MeshInstance3D
	_right_eye_happy = right_parts["happy"] as MeshInstance3D
	_face_rig.add_child(_right_eye_rig)

	# Expressive 3D Mouth Rig & 2 Cute Tiny White Fang Tips
	_mouth_rig = Node3D.new()
	_mouth_rig.name = "MouthRig"
	_mouth_rig.position = Vector3(0.0, -0.125, 0.055)
	_face_rig.add_child(_mouth_rig)

	# Sweet curved 3D smile arc (flips softly into fragile pout at vitality 0!)
	_mouth_smile = MeshInstance3D.new()
	_mouth_smile.name = "SmileArc"
	_mouth_smile.mesh = _build_curved_tube_mesh(0.24, -0.062, 0.019, 16, 8)
	_mouth_smile.material_override = smile_mat
	_mouth_smile.position = Vector3(0.0, 0.024, 0.022)
	_mouth_smile.sorting_offset = 0.66
	_mouth_smile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mouth_rig.add_child(_mouth_smile)

	# Dark-berry 3D mouth cavity dome (scales smoothly with mouth_open / scared_amount)
	_mouth_cavity = MeshInstance3D.new()
	_mouth_cavity.name = "MouthCavity"
	var cav_mesh := SphereMesh.new()
	cav_mesh.radius = 0.148
	cav_mesh.height = 0.296
	cav_mesh.radial_segments = 22
	cav_mesh.rings = 14
	_mouth_cavity.mesh = cav_mesh
	_mouth_cavity.material_override = _create_mouth_cavity_material()
	_mouth_cavity.scale = Vector3(1.0, 0.85, 0.42)
	_mouth_cavity.position = Vector3(0.0, -0.012, 0.0)
	_mouth_cavity.sorting_offset = 0.64
	_mouth_cavity.visible = false
	_mouth_cavity.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mouth_rig.add_child(_mouth_cavity)

	# Warm rosy-pink 3D tongue nestled inside the mouth cavity
	_mouth_tongue = MeshInstance3D.new()
	_mouth_tongue.name = "MouthTongue"
	var tongue_mesh := SphereMesh.new()
	tongue_mesh.radius = 0.090
	tongue_mesh.height = 0.180
	tongue_mesh.radial_segments = 18
	tongue_mesh.rings = 12
	_mouth_tongue.mesh = tongue_mesh
	_mouth_tongue.material_override = _create_tongue_material()
	_mouth_tongue.scale = Vector3(1.12, 0.72, 0.56)
	_mouth_tongue.position = Vector3(0.0, -0.056, 0.028)
	_mouth_tongue.sorting_offset = 0.69
	_mouth_tongue.visible = false
	_mouth_tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mouth_rig.add_child(_mouth_tongue)

	# Two adorable cute tiny white fang tips anchored at the upper smile corners!
	var fang_mesh: ArrayMesh = _build_fang_mesh(0.032, 0.072, 12, 7)
	var tooth_mat: ShaderMaterial = _create_tooth_material()

	_tooth_left = MeshInstance3D.new()
	_tooth_left.name = "LeftTooth"
	_tooth_left.mesh = fang_mesh
	_tooth_left.material_override = tooth_mat
	_tooth_left.scale = Vector3(1.0, 1.0, 0.78)
	_tooth_left.position = Vector3(-0.076, -0.010, 0.028)
	_tooth_left.rotation_degrees = Vector3(0.0, 0.0, 10.0)
	_tooth_left.sorting_offset = 0.75
	_tooth_left.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mouth_rig.add_child(_tooth_left)

	_tooth_right = MeshInstance3D.new()
	_tooth_right.name = "RightTooth"
	_tooth_right.mesh = fang_mesh
	_tooth_right.material_override = tooth_mat
	_tooth_right.scale = Vector3(1.0, 1.0, 0.78)
	_tooth_right.position = Vector3(0.076, -0.010, 0.028)
	_tooth_right.rotation_degrees = Vector3(0.0, 0.0, -10.0)
	_tooth_right.sorting_offset = 0.75
	_tooth_right.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mouth_rig.add_child(_tooth_right)


func _create_eye_rig(
	eye_name: String,
	pos: Vector3,
	eyeball_mesh: SphereMesh,
	sclera_mesh: SphereMesh,
	iris_mesh: SphereMesh,
	hi1_mesh: SphereMesh,
	hi2_mesh: SphereMesh,
	happy_arc_mesh: ArrayMesh,
	eye_mat: Material,
	sclera_mat: Material,
	iris_mat: Material,
	white_mat: Material,
	happy_mat: Material
) -> Dictionary:
	var rig := Node3D.new()
	rig.name = eye_name
	rig.position = pos

	var sclera := MeshInstance3D.new()
	sclera.name = "Sclera"
	sclera.mesh = sclera_mesh
	sclera.material_override = sclera_mat
	sclera.scale = Vector3(1.0, 1.12, 0.58)
	sclera.position = Vector3(0.0, 0.0, -0.036)
	sclera.sorting_offset = 0.59
	sclera.visible = true
	sclera.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(sclera)

	var ball_root := Node3D.new()
	ball_root.name = "EyeballRoot"
	rig.add_child(ball_root)

	var eyeball := MeshInstance3D.new()
	eyeball.name = "Eyeball"
	eyeball.mesh = eyeball_mesh
	eyeball.material_override = eye_mat
	eyeball.scale = Vector3(0.95, 1.08, 0.80)
	eyeball.sorting_offset = 0.63
	eyeball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball_root.add_child(eyeball)

	var iris := MeshInstance3D.new()
	iris.name = "AmberIris"
	iris.mesh = iris_mesh
	iris.material_override = iris_mat
	iris.scale = Vector3(1.10, 0.68, 0.44)
	iris.position = Vector3(0.0, -0.062, 0.118)
	iris.sorting_offset = 0.67
	iris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball_root.add_child(iris)

	var hi1 := MeshInstance3D.new()
	hi1.name = "CatchlightPrimary"
	hi1.mesh = hi1_mesh
	hi1.material_override = white_mat
	hi1.scale = Vector3(1.0, 1.0, 0.52)
	hi1.position = Vector3(-0.062, 0.072, 0.136)
	hi1.sorting_offset = 0.73
	hi1.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball_root.add_child(hi1)

	var hi2 := MeshInstance3D.new()
	hi2.name = "CatchlightSecondary"
	hi2.mesh = hi2_mesh
	hi2.material_override = white_mat
	hi2.scale = Vector3(1.0, 1.0, 0.52)
	hi2.position = Vector3(0.060, -0.052, 0.136)
	hi2.sorting_offset = 0.73
	hi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ball_root.add_child(hi2)

	var happy_arc := MeshInstance3D.new()
	happy_arc.name = "HappyArc"
	happy_arc.mesh = happy_arc_mesh
	happy_arc.material_override = happy_mat
	happy_arc.position = Vector3(0.0, -0.025, 0.06)
	happy_arc.sorting_offset = 0.72
	happy_arc.visible = false
	happy_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(happy_arc)

	return {
		"rig": rig,
		"ball": ball_root,
		"sclera": sclera,
		"iris": iris,
		"hi1": hi1,
		"hi2": hi2,
		"happy": happy_arc,
	}


func _build_fang_mesh(base_radius: float, length: float, radial: int, rings: int) -> ArrayMesh:
	# Cute smoothly-rounded tiny baby fang tip (widest at upper gum root, tapering gracefully to a soft tip!)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var ring_pts: Array[PackedVector3Array] = []
	var ring_nrms: Array[PackedVector3Array] = []
	for i: int in range(rings + 1):
		var t: float = float(i) / float(rings) # 0 = top gum root, 1 = rounded lower tip
		var y: float = (0.35 - t) * length
		var r: float = 0.0008
		if i > 0 and i < rings:
			# Rounded top cap blending smoothly into a tapered cute fang tip
			var top_round: float = sin(clampf(t * 4.2, 0.0, 1.0) * PI * 0.5)
			var tip_taper: float = pow(maxf(1.0 - t, 0.0), 0.78)
			r = maxf(base_radius * top_round * tip_taper, 0.001)
		var pts := PackedVector3Array()
		var nrms := PackedVector3Array()
		pts.resize(radial)
		nrms.resize(radial)
		for j: int in range(radial):
			var ang: float = (float(j) / float(radial)) * TAU
			var cx: float = cos(ang)
			var cz: float = sin(ang)
			pts[j] = Vector3(cx * r, y, cz * r)
			var ny: float = 0.55 if i == 0 else (-0.85 if i == rings else -0.22)
			nrms[j] = Vector3(cx, ny, cz).normalized()
		ring_pts.append(pts)
		ring_nrms.append(nrms)

	for i: int in range(rings):
		var r0: PackedVector3Array = ring_pts[i]
		var r1: PackedVector3Array = ring_pts[i + 1]
		var n0: PackedVector3Array = ring_nrms[i]
		var n1: PackedVector3Array = ring_nrms[i + 1]
		for j: int in range(radial):
			var jn: int = (j + 1) % radial
			st.set_normal(n0[j])
			st.add_vertex(r0[j])
			st.set_normal(n1[j])
			st.add_vertex(r1[j])
			st.set_normal(n1[jn])
			st.add_vertex(r1[jn])

			st.set_normal(n0[j])
			st.add_vertex(r0[j])
			st.set_normal(n1[jn])
			st.add_vertex(r1[jn])
			st.set_normal(n0[jn])
			st.add_vertex(r0[jn])

	return st.commit()


func _build_curved_tube_mesh(span_x: float, arch_y: float, radius: float, segs: int, radial: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rings: Array[PackedVector3Array] = []
	var ring_normals: Array[PackedVector3Array] = []
	var total_steps: int = segs + 2

	for i: int in range(total_steps + 1):
		var u: float = float(i) / float(total_steps)
		var t: float = clampf((u - 0.06) / 0.88, 0.0, 1.0)
		var cap_r: float = radius
		if i == 0 or i == total_steps:
			cap_r = 0.001
		elif i == 1 or i == total_steps - 1:
			cap_r = radius * 0.76

		var x: float = (t - 0.5) * span_x
		var y: float = sin(t * PI) * arch_y
		var dx: float = span_x
		var dy: float = cos(t * PI) * PI * arch_y
		var tang: Vector3 = Vector3(dx, dy, 0.0).normalized()
		var n_in: Vector3 = Vector3(-tang.y, tang.x, 0.0)
		var b_out: Vector3 = Vector3(0.0, 0.0, 1.0)

		var end_push: float = 0.0
		if i == 0:
			end_push = -radius * 0.85
		elif i == total_steps:
			end_push = radius * 0.85
		var center: Vector3 = Vector3(x, y, 0.0) + tang * end_push

		var pts := PackedVector3Array()
		var nrms := PackedVector3Array()
		pts.resize(radial)
		nrms.resize(radial)
		for j: int in range(radial):
			var ang: float = (float(j) / float(radial)) * TAU
			var dir: Vector3 = n_in * cos(ang) + b_out * sin(ang)
			pts[j] = center + dir * cap_r
			nrms[j] = dir.normalized()
		rings.append(pts)
		ring_normals.append(nrms)

	for i: int in range(total_steps):
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		var n0: PackedVector3Array = ring_normals[i]
		var n1: PackedVector3Array = ring_normals[i + 1]
		for j: int in range(radial):
			var jn: int = (j + 1) % radial
			st.set_normal(n0[j])
			st.add_vertex(r0[j])
			st.set_normal(n1[j])
			st.add_vertex(r1[j])
			st.set_normal(n1[jn])
			st.add_vertex(r1[jn])

			st.set_normal(n0[j])
			st.add_vertex(r0[j])
			st.set_normal(n1[jn])
			st.add_vertex(r1[jn])
			st.set_normal(n0[jn])
			st.add_vertex(r0[jn])

	return st.commit()


func _create_unshaded_color_material(col: Color, alpha_blend: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	if alpha_blend:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _create_pearl_material() -> ShaderMaterial:
	# Jewel-like translucent golden amber vitality pearl:
	# Deep warm orange-gold rim (#ff8c1a) -> radiant honey-gold body (#ffd24c) ->
	# luminous lower-right internal glow -> crisp bright cream-white center specular dot!
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode depth_draw_opaque, cull_back, unshaded;

uniform vec4 rim_col : source_color = vec4(1.000, 0.549, 0.102, 1.0);  // #ff8c1a warm orange-gold rim
uniform vec4 body_col : source_color = vec4(1.000, 0.824, 0.298, 1.0); // #ffd24c radiant honey-gold
uniform vec4 glow_col : source_color = vec4(1.000, 0.935, 0.620, 1.0); // #ffee9e luminous amber core

void fragment() {
	vec3 N = normalize(NORMAL);
	vec3 V = normalize(VIEW);
	float ndv = clamp(dot(N, V), 0.0, 1.0);
	vec3 L_key = normalize(vec3(-0.46, 0.64, 0.62));
	vec3 L_bot = normalize(vec3(0.42, -0.60, 0.68));
	vec3 H = normalize(L_key + V);

	float core_grad = smoothstep(0.18, 0.88, ndv);
	vec3 col = mix(rim_col.rgb, body_col.rgb, core_grad);
	float inner_caustic = pow(max(dot(N, L_bot), 0.0), 2.0) * smoothstep(0.15, 0.78, ndv);
	col = mix(col, glow_col.rgb, clamp(inner_caustic * 0.65 + pow(max(ndv, 0.0), 2.4) * 0.34, 0.0, 0.82));

	float spec_dot = smoothstep(0.915, 0.980, max(dot(N, H), 0.0));
	col = mix(col, vec3(1.0, 0.992, 0.945), spec_dot * 0.96);
	ALBEDO = clamp(col, vec3(0.0), vec3(1.0));
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


func _create_spark_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

uniform float spark_intensity = 0.0;
uniform vec4 spark_col : source_color = vec4(1.0, 0.88, 0.42, 1.0);

void fragment() {
	vec3 N = normalize(NORMAL);
	vec3 V = normalize(VIEW);
	float ndv = clamp(dot(N, V), 0.0, 1.0);
	vec3 col = mix(spark_col.rgb, vec3(1.0, 0.99, 0.88), smoothstep(0.32, 0.90, ndv));
	ALBEDO = col;
	ALPHA = clamp(pow(max(ndv, 0.0), 1.35) * spark_intensity, 0.0, 0.95);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


func _create_micro_bubble_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

uniform vec4 tint_col : source_color = vec4(1.0, 0.92, 0.72, 1.0);

void fragment() {
	vec3 N = normalize(NORMAL);
	vec3 V = normalize(VIEW);
	float ndv = clamp(dot(N, V), 0.0, 1.0);
	float fres = pow(max(1.0 - ndv, 0.0), 2.0);
	vec3 L = normalize(vec3(-0.5, 0.65, 0.58));
	vec3 H = normalize(L + V);
	float spec = smoothstep(0.92, 0.985, max(dot(N, H), 0.0));

	vec3 col = mix(tint_col.rgb, vec3(1.0, 0.995, 0.96), spec * 0.95);
	float alpha = clamp(0.08 + fres * 0.40 + spec * 0.72, 0.0, 0.86);
	ALBEDO = col;
	ALPHA = alpha;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


func _create_eyeball_material() -> ShaderMaterial:
	# Glossy dark-espresso (#210c08) Studio Ghibli eye with subtle warm chestnut curved depth
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform vec4 dark_col : source_color = vec4(0.129, 0.047, 0.031, 1.0);  // #210c08 glossy dark espresso
uniform vec4 sheen_col : source_color = vec4(0.320, 0.125, 0.075, 1.0); // warm espresso-chestnut gloss

void fragment() {
	vec3 N = normalize(NORMAL);
	vec3 V = normalize(VIEW);
	float ndv = clamp(dot(N, V), 0.0, 1.0);
	vec3 L = normalize(vec3(-0.45, 0.55, 0.70));
	float wrap = clamp((dot(N, L) + 0.30) / 1.30, 0.0, 1.0);
	float rim_sheen = pow(max(1.0 - ndv, 0.0), 2.4) * 0.44 + wrap * 0.14;
	vec3 col = mix(dark_col.rgb * 0.86, sheen_col.rgb, clamp(rim_sheen, 0.0, 0.65));
	ALBEDO = col;
	ALPHA = 1.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


func _create_sclera_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform vec4 sclera_col : source_color = vec4(1.0, 0.985, 0.96, 1.0);
uniform vec4 outline_col : source_color = vec4(0.16, 0.06, 0.05, 1.0);

void fragment() {
	vec3 N = normalize(NORMAL);
	vec3 V = normalize(VIEW);
	float ndv = clamp(dot(N, V), 0.0, 1.0);
	float edge = 1.0 - smoothstep(0.22, 0.50, ndv);
	ALBEDO = mix(sclera_col.rgb, outline_col.rgb, edge * 0.88);
	ALPHA = 1.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


func _create_iris_amber_material() -> ShaderMaterial:
	# Glowing warm amber-gold lower iris crescent inside Charlie's glossy espresso eyes
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

uniform vec4 iris_outer : source_color = vec4(0.92, 0.48, 0.12, 1.0);
uniform vec4 iris_inner : source_color = vec4(1.00, 0.84, 0.36, 1.0);

void fragment() {
	vec3 N = normalize(NORMAL);
	vec3 V = normalize(VIEW);
	float ndv = clamp(dot(N, V), 0.0, 1.0);
	vec3 col = mix(iris_outer.rgb, iris_inner.rgb, smoothstep(0.26, 0.88, ndv));
	ALBEDO = col;
	ALPHA = clamp(pow(max(ndv, 0.0), 1.40) * 0.92, 0.0, 0.94);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


func _create_cheek_material() -> ShaderMaterial:
	# Soft rosy-vermilion (#ff4838) subsurface blush tucked under Charlie's eyes
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

uniform vec4 cheek_col : source_color = vec4(1.000, 0.282, 0.220, 1.0); // #ff4838 rosy-vermilion

void fragment() {
	vec3 N = normalize(NORMAL);
	vec3 V = normalize(VIEW);
	float ndv = clamp(dot(N, V), 0.0, 1.0);
	ALBEDO = cheek_col.rgb;
	ALPHA = clamp(pow(max(ndv, 0.0), 1.75) * 0.66, 0.0, 0.70);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


func _create_mouth_cavity_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform vec4 mouth_col : source_color = vec4(0.26, 0.06, 0.10, 1.0);

void fragment() {
	vec3 N = normalize(NORMAL);
	vec3 V = normalize(VIEW);
	float ndv = clamp(dot(N, V), 0.0, 1.0);
	vec3 col = mouth_col.rgb * mix(0.68, 1.08, ndv);
	ALBEDO = col;
	ALPHA = 1.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


func _create_tongue_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform vec4 tongue_col : source_color = vec4(1.0, 0.49, 0.56, 1.0);

void fragment() {
	vec3 N = normalize(NORMAL);
	vec3 L = normalize(vec3(-0.35, 0.65, 0.68));
	float diff = clamp((dot(N, L) + 0.5) / 1.5, 0.0, 1.0);
	ALBEDO = clamp(tongue_col.rgb * mix(0.84, 1.12, diff), vec3(0.0), vec3(1.0));
	ALPHA = 1.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


func _create_tooth_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform vec4 tooth_col : source_color = vec4(1.0, 0.996, 0.965, 1.0);
uniform vec4 edge_col : source_color = vec4(0.36, 0.14, 0.12, 1.0);

void fragment() {
	vec3 N = normalize(NORMAL);
	vec3 V = normalize(VIEW);
	float ndv = clamp(dot(N, V), 0.0, 1.0);
	float rim = pow(max(1.0 - ndv, 0.0), 3.0);
	ALBEDO = mix(tooth_col.rgb, edge_col.rgb, rim * 0.44);
	ALPHA = 1.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


# ------------------------------------------------------------------------------
# Public API (100% preserved + 2 new methods: swallow_prey & set_regen_progress)
# ------------------------------------------------------------------------------

func set_palette(core: Color, edge: Color, glow: Color = Color(1.0, 0.50, 0.28, 1.0)) -> void:
	_palette_core = core
	_palette_edge = edge
	_palette_glow = glow
	if _inner_mat != null:
		_inner_mat.set_shader_parameter("core_color", _palette_core)
		_inner_mat.set_shader_parameter("edge_color", _palette_edge)
		_inner_mat.set_shader_parameter("glow_color", _palette_glow)
	if _gel_mat != null:
		_gel_mat.set_shader_parameter("core_color", _palette_core)
		_gel_mat.set_shader_parameter("edge_color", _palette_edge)
		_gel_mat.set_shader_parameter("glow_color", _palette_glow)
	if _composite_mat != null:
		_composite_mat.set_shader_parameter("core_color", _palette_core)
		_composite_mat.set_shader_parameter("edge_color", _palette_edge)
		_composite_mat.set_shader_parameter("glow_color", _palette_glow)


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
	_invuln_flash = 0.0
	_core_radius = CORE_BASE_RADIUS
	_wobble_amp = 0.0
	_fear_ripple = 0.0
	_vitality_ratio = 1.0
	_regen_progress = 0.0
	_gulp_phase = -1.0
	_gulp_intensity = 0.0
	_face_tilt = 0.0
	_pop_scale = 0.0
	_pop_vel = 0.0
	_last_horiz_sign = 1.0
	_rig_yaw = 0.22
	_rig_pitch = 0.0
	_rig_bank = 0.0
	_tail_dir_world = Vector3(-0.88, -0.24, -0.40).normalized()
	_tail_strength = 0.44
	_fin_lag_world = Vector3.ZERO
	_flavor_intensity = 0.0
	_flavor_color = _palette_core
	_swallowed_prey.clear()
	_bubble_lag = Vector3.ZERO
	_bubble_lag_vel = Vector3.ZERO
	scale = Vector2.ONE
	_blink_cooldown = randf_range(2.2, 4.4)
	_blink_phase = 0.0

	var rest_lobes: Array[Vector2] = _get_lobe_rest_offsets(0.0, 0.0, 0.0)
	for i: int in range(LOBE_COUNT):
		_lobe_pos[i] = rest_lobes[i]
		_lobe_vel[i] = Vector2.ZERO
		_lobe_rad[i] = LOBE_BASE_RADII[i]

	var rest_pearls: Array[Vector3] = _get_pearl_orbit_targets_3d()
	for i: int in range(MAX_DROPLETS):
		_pearl_pos_3d[i] = rest_pearls[i]
		_pearl_vel_3d[i] = Vector3.ZERO
		_pearl_scales[i] = 1.0

	_sync_body_rect()
	_update_3d_rig_and_uniforms({})
	if _swallowed_layer != null:
		_swallowed_layer.queue_redraw()


func swallow_prey(
	tex: Texture2D,
	frame_idx: int,
	hframes: int,
	tint: Color,
	world_offset: Vector2,
	prey_size_ratio: float
) -> void:
	var safe_hframes: int = maxi(hframes, 1)
	var clamped_frame: int = clampi(frame_idx, 0, safe_hframes - 1)
	var ratio: float = clampf(prey_size_ratio, 0.20, 0.95)
	var norm_off: Vector2 = (world_offset / maxf(world_size, 1.0)).limit_length(0.92)

	# Blend warm flavor color wash through Charlie's translucent belly
	var wash_col: Color = Color(tint.r, tint.g, tint.b, 1.0)
	if _flavor_intensity > 0.12:
		_flavor_color = _flavor_color.lerp(wash_col, 0.65)
	else:
		_flavor_color = wash_col
	_flavor_intensity = clampf(maxf(_flavor_intensity * 0.55, 0.58 + ratio * 0.36), 0.55, 0.95)

	if _swallowed_prey.size() >= MAX_SWALLOWED_PREY:
		_swallowed_prey.remove_at(0)

	_swallow_spin_toggle = -_swallow_spin_toggle
	_swallowed_prey.append({
		"tex": tex,
		"frame_idx": clamped_frame,
		"hframes": safe_hframes,
		"tint": wash_col,
		"start_offset": norm_off,
		"ratio": ratio,
		"age": 0.0,
		"spin_dir": _swallow_spin_toggle,
		"seed": randf_range(0.0, TAU),
	})

	if _swallowed_layer != null:
		_swallowed_layer.queue_redraw()


func set_regen_progress(p: float) -> void:
	_regen_progress = clampf(p, 0.0, 1.0)
	_sync_nascent_spark()


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

	var d_fwd_3d := Vector3(d_fwd.x, -d_fwd.y, 0.0)
	for i: int in range(MAX_DROPLETS):
		_pearl_vel_3d[i] -= d_fwd_3d * (1.35 * lvl_scale)


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

	# Radial jelly shockwave + 3D pearl scatter on impact
	var k_fwd: Vector2 = Vector2.from_angle(away_angle)
	var k_side: Vector2 = Vector2(-k_fwd.y, k_fwd.x)
	_lobe_vel[0] -= k_fwd * 3.1
	_lobe_vel[1] -= k_side * 2.7
	_lobe_vel[2] += k_side * 2.7
	_lobe_vel[3] += k_fwd * 1.9 - k_side * 1.7
	_lobe_vel[4] += k_fwd * 1.9 + k_side * 1.7
	_wobble_amp = 1.0
	_fear_ripple = 1.0

	for i: int in range(MAX_DROPLETS):
		var scatter_ang: float = away_angle + PI + (float(i) - 1.0) * 1.1
		var sv2: Vector2 = Vector2.from_angle(scatter_ang) * 1.9
		var z_kick: float = (float(i) - 1.0) * 0.85
		_pearl_vel_3d[i] += Vector3(sv2.x, -sv2.y, z_kick)


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

	# Decay flavor belly wash smoothly
	if _flavor_intensity > 0.001:
		_flavor_intensity = maxf(0.0, _flavor_intensity - step_dt * 0.72)

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

	# Scale-invariant swimming physics (snappy 7.4x speed, 13.5 accel)
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

	# Gentle playful face tilt & heroic 3/4 3D yaw/pitch/bank following swim direction
	var vel_x_norm: float = clampf(velocity.x / maxf(base_max_speed, 1.0), -1.0, 1.0)
	var vel_y_norm: float = clampf(velocity.y / maxf(base_max_speed, 1.0), -1.0, 1.0)
	if absf(velocity.x) > world_size * 0.35:
		_last_horiz_sign = 1.0 if velocity.x >= 0.0 else -1.0
	elif speed > world_size * 0.25 and absf(cos(facing_angle)) > 0.25:
		_last_horiz_sign = 1.0 if cos(facing_angle) >= 0.0 else -1.0

	var target_tilt: float = clampf(vel_y_norm * 0.14 * _last_horiz_sign, -0.16, 0.16)
	_face_tilt = lerpf(_face_tilt, target_tilt, 1.0 - exp(-9.0 * step_dt))

	# Smooth 3D heroic 3/4 rig yaw (±0.34 rad), pitch (±0.16 rad) & bank (±0.18 rad)
	var rest_yaw: float = _last_horiz_sign * 0.22
	var swim_blend: float = clampf(speed_norm * 1.15, 0.0, 1.0)
	var target_yaw: float = clampf(lerpf(rest_yaw, vel_x_norm * 0.34, swim_blend), -0.34, 0.34)
	var target_pitch: float = clampf(vel_y_norm * 0.16, -0.16, 0.16)
	var target_bank: float = clampf(-vel_y_norm * 0.14 * _last_horiz_sign - clampf(ang_vel * 0.014, -0.10, 0.10), -0.18, 0.18)
	var rig_rate: float = 1.0 - exp(-7.8 * step_dt)
	_rig_yaw = lerpf(_rig_yaw, target_yaw, rig_rate)
	_rig_pitch = lerpf(_rig_pitch, target_pitch, rig_rate)
	_rig_bank = lerpf(_rig_bank, target_bank, rig_rate)

	# Flowing sculpted molten tail direction (smoothly trails opposite 3D swim velocity + graceful resting sweep)
	var rest_tail := Vector3(-_last_horiz_sign * 0.88, -0.24, -0.40).normalized()
	var target_tail_world: Vector3 = rest_tail
	var target_fin_lag := Vector3.ZERO
	if speed_norm > 0.08 and speed > 0.001:
		var swim_dir_3d := Vector3(velocity.x, -velocity.y, 0.0).normalized()
		var move_tail := Vector3(-swim_dir_3d.x * 0.92, -swim_dir_3d.y * 0.86 - 0.14, -0.38).normalized()
		target_tail_world = rest_tail.lerp(move_tail, clampf(speed_norm * 1.4, 0.0, 1.0)).normalized()
		target_fin_lag = (-swim_dir_3d * minf(speed_norm * 0.40, 0.45)) + Vector3(0.0, 0.0, -0.12 * minf(speed_norm, 1.0))
	_tail_dir_world = _tail_dir_world.lerp(target_tail_world, 1.0 - exp(-8.0 * step_dt))
	if _tail_dir_world.length_squared() > 0.0001:
		_tail_dir_world = _tail_dir_world.normalized()
	else:
		_tail_dir_world = rest_tail
	var target_tail_str: float = clampf(0.44 + speed_norm * 0.50 + (0.20 if dash_timer > 0.0 else 0.0), 0.42, 1.18)
	_tail_strength = lerpf(_tail_strength, target_tail_str, 1.0 - exp(-7.2 * step_dt))
	_fin_lag_world = _fin_lag_world.lerp(target_fin_lag, 1.0 - exp(-8.5 * step_dt))

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

	# Scared, danger_level, fear ripple & mouth-open interpolation
	var target_scared: float = pred_threat if invuln_timer <= 0.0 else maxf(pred_threat, 0.65)
	scared_amount = lerpf(scared_amount, target_scared, 1.0 - exp(-9.0 * step_dt))
	danger_level = scared_amount

	var target_fear: float = clampf(scared_amount * 0.85 + (0.35 if droplets_alive <= 0 else 0.0), 0.0, 1.0)
	_fear_ripple = lerpf(_fear_ripple, target_fear, 1.0 - exp(-8.0 * step_dt))

	var target_vitality: float = float(clampi(droplets_alive, 0, MAX_DROPLETS)) / float(MAX_DROPLETS)
	_vitality_ratio = lerpf(_vitality_ratio, target_vitality, 1.0 - exp(-6.5 * step_dt))

	var target_mouth: float = 0.0
	if chomp_timer > 0.0:
		target_mouth = clampf(sin((chomp_timer / 0.28) * PI), 0.25, 1.0)
	elif prey_proximity > 0.12 and danger_level < 0.55:
		target_mouth = clampf((prey_proximity - 0.12) * 1.15, 0.0, 0.92)
	mouth_open = lerpf(mouth_open, target_mouth, 1.0 - exp(-14.0 * step_dt))

	# Periodic cute blink
	_step_blink(step_dt)

	# 5-lobe viscous spring-mass slime skeleton + 3D vitality pearls + micro-bubbles + swallowed prey
	_step_slime_body(step_dt, speed_norm, accel_local_norm, ang_vel)
	_step_pearls(step_dt, accel_local_norm)
	_step_bubbles(step_dt, accel_local_norm)
	_step_swallowed_prey(step_dt)

	# Sync BackBufferCopy, CompositeQuad, 3D rig transforms & shader uniforms
	_sync_body_rect()
	_update_3d_rig_and_uniforms(palette)


# ------------------------------------------------------------------------------
# Soft-Body, 3D Pearls, Bubbles & Swallowed Prey Simulation
# ------------------------------------------------------------------------------

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


func _get_pearl_orbit_targets_3d() -> Array[Vector3]:
	# True 3D XYZ orbital paths suspended cleanly inside Charlie's LOWER translucent belly (z in [-0.25, +0.25])
	# Well below the mouth & 2 cute white teeth!
	var orbit_speeds: Array[float] = [0.76, -0.60, 0.66]
	var orbit_radii_x: Array[float] = [0.27, 0.24, 0.28]
	var orbit_radii_y: Array[float] = [0.06, 0.07, 0.05]
	var targets: Array[Vector3] = []
	for i: int in range(MAX_DROPLETS):
		var phase: float = _time * orbit_speeds[i] + float(i) * (TAU / float(MAX_DROPLETS)) + 0.45 + facing_angle * 0.22
		var rx: float = orbit_radii_x[i] + sin(_time * 1.45 + float(i) * 2.1) * 0.028
		var ry: float = orbit_radii_y[i] + cos(_time * 1.20 + float(i) * 1.7) * 0.020
		var px: float = cos(phase) * rx
		var py: float = -0.44 + sin(phase * 1.25 + float(i) * 1.1) * ry
		var pz: float = -0.06 + sin(phase) * 0.16
		targets.append(Vector3(px, py, pz))
	return targets


func _step_pearls(dt: float, accel_local_norm: Vector2) -> void:
	var alive_clamped: int = clampi(droplets_alive, 0, MAX_DROPLETS)
	var orbit_targets: Array[Vector3] = _get_pearl_orbit_targets_3d()

	# Detect regenerated vitality pearls and trigger smooth heal-bloom (0.05 -> 1.0)
	if alive_clamped > _prev_droplets_alive:
		for i: int in range(maxi(_prev_droplets_alive, 0), alive_clamped):
			_pearl_scales[i] = 0.05
			_pearl_pos_3d[i] = Vector3(0.0, -0.42, -0.02)
			_pearl_vel_3d[i] = Vector3.ZERO
	_prev_droplets_alive = alive_clamped

	var accel_3d := Vector3(accel_local_norm.x, -accel_local_norm.y, 0.0)
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
				if _pearl_scales[i] < 0.015:
					_pearl_scales[i] = 0.0

		var disp: Vector3 = orbit_targets[i] - _pearl_pos_3d[i]
		var fluid_acc: Vector3 = disp * 26.0 - _pearl_vel_3d[i] * 6.0 - accel_3d * 0.036
		_pearl_vel_3d[i] += fluid_acc * dt
		_pearl_pos_3d[i] += _pearl_vel_3d[i] * dt

		# Keep pearls suspended cleanly inside Charlie's lower belly sphere
		var belly_center := Vector3(0.0, -0.44, -0.04)
		var rel: Vector3 = _pearl_pos_3d[i] - belly_center
		var max_r: float = PEARL_MAX_OFFSET + 0.05
		var dist: float = rel.length()
		if dist > max_r:
			var dir: Vector3 = rel / dist
			_pearl_pos_3d[i] = belly_center + dir * max_r
			var radial_v: float = _pearl_vel_3d[i].dot(dir)
			if radial_v > 0.0:
				_pearl_vel_3d[i] -= dir * radial_v * 0.8
		_pearl_pos_3d[i].y = clampf(_pearl_pos_3d[i].y, -0.58, -0.30)
		_pearl_pos_3d[i].z = clampf(_pearl_pos_3d[i].z, -0.25, 0.25)


func _step_bubbles(dt: float, accel_local_norm: Vector2) -> void:
	var accel_3d := Vector3(accel_local_norm.x, -accel_local_norm.y, 0.0)
	var lag_acc: Vector3 = -_bubble_lag * 22.0 - _bubble_lag_vel * 5.8 - accel_3d * 0.025
	_bubble_lag_vel += lag_acc * dt
	_bubble_lag += _bubble_lag_vel * dt
	if _bubble_lag.length() > 0.14:
		_bubble_lag = _bubble_lag.normalized() * 0.14


func _step_swallowed_prey(dt: float) -> void:
	if _swallowed_prey.is_empty():
		return
	var idx: int = _swallowed_prey.size() - 1
	while idx >= 0:
		var entry: Dictionary = _swallowed_prey[idx]
		var new_age: float = float(entry["age"]) + dt
		if new_age >= SWALLOW_TOTAL_TIME:
			_swallowed_prey.remove_at(idx)
		else:
			entry["age"] = new_age
		idx -= 1
	if _swallowed_layer != null:
		_swallowed_layer.queue_redraw()


# ------------------------------------------------------------------------------
# Visual Synchronization (BackBufferCopy, CompositeQuad, 3D Rig & Shaders)
# ------------------------------------------------------------------------------

func _sync_body_rect() -> void:
	if is_equal_approx(world_size, _last_synced_size):
		return
	_last_synced_size = world_size
	var quad_len: float = world_size * BODY_QUAD_SCALE
	var half_len: float = world_size * BODY_HALF_SCALE

	if _back_buffer != null:
		_back_buffer.rect = Rect2(-half_len, -half_len, quad_len, quad_len)

	if _composite_quad != null:
		var quad_scale: float = quad_len / float(SUBVIEWPORT_SIZE)
		_composite_quad.scale = Vector2(quad_scale, quad_scale)


func _sync_nascent_spark() -> void:
	if _nascent_spark == null or _spark_mat == null:
		return
	var show_spark: bool = droplets_alive < MAX_DROPLETS and _regen_progress > 0.01
	_nascent_spark.visible = show_spark
	if not show_spark:
		return
	var pulse: float = 0.90 + 0.10 * sin(_time * 6.5)
	var sc: float = lerpf(0.24, 0.92, _regen_progress) * pulse
	_nascent_spark.scale = Vector3(sc, sc, sc)
	_nascent_spark.position = Vector3(
		sin(_time * 2.2) * 0.035,
		-0.32 + cos(_time * 2.6) * 0.025,
		0.06
	)
	_spark_mat.set_shader_parameter("spark_intensity", clampf(0.40 + _regen_progress * 0.60, 0.0, 1.0))


func _update_3d_rig_and_uniforms(palette: Dictionary) -> void:
	var core_col: Color = palette.get("blob_core", _palette_core) as Color
	var edge_col: Color = palette.get("blob_edge", _palette_edge) as Color
	var glow_col: Color = palette.get("blob_glow", _palette_glow) as Color
	_palette_core = core_col
	_palette_edge = edge_col
	_palette_glow = glow_col

	_invuln_flash = 0.0
	if invuln_timer > 0.0:
		_invuln_flash = 0.5 + 0.5 * sin(_time * 26.0)

	# Apply smooth heroic 3/4 3D turn (yaw ±0.34, pitch ±0.16, bank ±0.18) to parent _slime_root
	var inv_basis := Basis.IDENTITY
	if _slime_root != null:
		_slime_root.rotation = Vector3(_rig_pitch, _rig_yaw, _rig_bank)
		inv_basis = _slime_root.basis.inverse()

	var tail_dir_local: Vector3 = inv_basis * _tail_dir_world
	if tail_dir_local.length_squared() > 0.0001:
		tail_dir_local = tail_dir_local.normalized()
	else:
		tail_dir_local = Vector3(-0.88, -0.24, -0.40).normalized()
	var fin_lag_local: Vector3 = inv_basis * _fin_lag_world

	# Compute soft-body inertial centroid & stretch for embedded 3D anatomy
	var all_centroid: Vector2 = (_lobe_pos[0] + _lobe_pos[1] + _lobe_pos[2] + _lobe_pos[3] + _lobe_pos[4]) * 0.2
	var front_centroid: Vector2 = (_lobe_pos[3] + _lobe_pos[4]) * 0.5
	var lobe_shift_2d: Vector2 = all_centroid * 0.35 + front_centroid * 0.14
	var lobe_shift_3d := Vector3(lobe_shift_2d.x, -lobe_shift_2d.y, 0.0)

	# 1. Update 3 Jewel-Like Golden Amber Vitality Pearls suspended inside lower belly
	for i: int in range(mini(_pearl_nodes.size(), MAX_DROPLETS)):
		var pearl_node: MeshInstance3D = _pearl_nodes[i]
		var sc: float = _pearl_scales[i]
		if sc <= 0.015:
			pearl_node.visible = false
		else:
			pearl_node.visible = true
			var breathe: float = 1.0 + 0.06 * sin(_time * 3.2 + float(i) * 1.9)
			var size_var: float = PEARL_SIZE_VARIATION[i] if i < PEARL_SIZE_VARIATION.size() else 1.0
			var final_sc: float = sc * breathe * size_var
			pearl_node.scale = Vector3(final_sc, final_sc, final_sc)
			pearl_node.position = _pearl_pos_3d[i] + lobe_shift_3d * 0.38

	_sync_nascent_spark()

	# 2. Update 6 Shimmering 3D Micro-Bubbles near lower belly & molten tail root
	for i: int in range(_bubble_nodes.size()):
		var b_node: MeshInstance3D = _bubble_nodes[i]
		var base_p: Vector3 = MICRO_BUBBLE_SEEDS[i]
		if i == _bubble_nodes.size() - 1:
			base_p = tail_dir_local * 0.52 + Vector3(0.0, -0.10, 0.0)
		var drift := Vector3(
			sin(_time * (0.72 + float(i) * 0.14) + float(i) * 2.1) * 0.065,
			cos(_time * (0.64 + float(i) * 0.11) + float(i) * 1.6) * 0.075,
			sin(_time * (0.55 + float(i) * 0.13) + float(i) * 2.7) * 0.065
		)
		var b_pos: Vector3 = base_p + drift + _bubble_lag + lobe_shift_3d * 0.30
		if b_pos.length() > 0.72:
			b_pos = b_pos.normalized() * 0.72
		b_node.position = b_pos

	# 3. Update Embedded 3D Face Rig (at z = +0.50 in _slime_root local space)
	var face_offset_3d := Vector2(0.0, 0.15)
	if _face_rig != null:
		var look_2d: Vector2 = Vector2.from_angle(look_angle)
		var look_3d := Vector2(look_2d.x, -look_2d.y)
		var fwd: Vector2 = Vector2.from_angle(facing_angle)
		var side: Vector2 = Vector2(-fwd.y, fwd.x)
		var tail_jiggle_tilt: float = _lobe_pos[0].dot(side) * 0.16
		var total_tilt: float = clampf(_face_tilt * 0.55 + tail_jiggle_tilt, -0.16, 0.16)

		var breath_y: float = cos(_time * 2.7) * 0.012
		var fx: float = clampf(look_3d.x * 0.065 + lobe_shift_3d.x * 0.25, -0.11, 0.11)
		var fy: float = clampf(0.15 + look_3d.y * 0.055 + lobe_shift_3d.y * 0.24 + breath_y, 0.02, 0.25)
		face_offset_3d = Vector2(fx, fy)
		_face_rig.position = Vector3(fx, fy, 0.50)
		_face_rig.rotation = Vector3(-look_3d.y * 0.09, look_3d.x * 0.11, -total_tilt)

		_update_3d_eyes_and_mouth(look_3d)

	# 4. Sync BOTH Inner Volumetric Shell & Outer Glossy Clearcoat Shell with IDENTICAL deformation uniforms!
	var flavor_vec := Color(_flavor_color.r, _flavor_color.g, _flavor_color.b, _flavor_intensity)
	var facing_vec := Vector2(cos(facing_angle), -sin(facing_angle))
	_apply_shell_uniforms(_inner_mat, core_col, edge_col, glow_col, flavor_vec, facing_vec, face_offset_3d, tail_dir_local, fin_lag_local, false)
	_apply_shell_uniforms(_gel_mat, core_col, edge_col, glow_col, flavor_vec, facing_vec, face_offset_3d, tail_dir_local, fin_lag_local, true)

	# 5. Update 2D Refractive Composite Shader Uniforms
	if _composite_mat != null:
		_composite_mat.set_shader_parameter("core_color", core_col)
		_composite_mat.set_shader_parameter("edge_color", edge_col)
		_composite_mat.set_shader_parameter("glow_color", glow_col)
		_composite_mat.set_shader_parameter("flavor_tint", flavor_vec)
		_composite_mat.set_shader_parameter("vitality_ratio", _vitality_ratio)
		_composite_mat.set_shader_parameter("invuln_flash", _invuln_flash)
		_composite_mat.set_shader_parameter("time_sec", _time)


func _apply_shell_uniforms(
	mat: ShaderMaterial,
	core_col: Color,
	edge_col: Color,
	glow_col: Color,
	flavor_vec: Color,
	facing_vec: Vector2,
	face_offset_3d: Vector2,
	tail_dir_local: Vector3,
	fin_lag_local: Vector3,
	include_face_offset: bool
) -> void:
	if mat == null:
		return
	mat.set_shader_parameter("core_color", core_col)
	mat.set_shader_parameter("edge_color", edge_col)
	mat.set_shader_parameter("glow_color", glow_col)
	mat.set_shader_parameter("flavor_tint", flavor_vec)
	mat.set_shader_parameter("core_radius", _core_radius)
	mat.set_shader_parameter("wobble_amp", _wobble_amp)
	mat.set_shader_parameter("fear_ripple", _fear_ripple)
	mat.set_shader_parameter("vitality_ratio", _vitality_ratio)
	mat.set_shader_parameter("invuln_flash", _invuln_flash)
	mat.set_shader_parameter("time_sec", _time)
	mat.set_shader_parameter("gulp_phase", _gulp_phase)
	mat.set_shader_parameter("gulp_intensity", _gulp_intensity)
	mat.set_shader_parameter("facing_dir", facing_vec)
	mat.set_shader_parameter("tail_dir", tail_dir_local)
	mat.set_shader_parameter("tail_strength", _tail_strength)
	mat.set_shader_parameter("fin_lag", fin_lag_local)
	if include_face_offset:
		mat.set_shader_parameter("face_offset", face_offset_3d)
	for i: int in range(LOBE_COUNT):
		var lp: Vector2 = _lobe_pos[i]
		mat.set_shader_parameter(LOBE_UNIFORM_NAMES[i], Vector3(lp.x, -lp.y, _lobe_rad[i]))


func _update_3d_eyes_and_mouth(look_3d: Vector2) -> void:
	var alarmed: bool = danger_level > 0.45
	var is_happy: bool = happy_timer > 0.0 and not alarmed
	var is_fragile: bool = droplets_alive <= 0 and not is_happy and not alarmed

	# Expressive widening when scared or excited, smooth vertical squash on blink
	var open_y: float = clampf(1.0 - blink_amount * 0.90, 0.10, 1.0)
	var eye_scale_mult: float = 1.0 + danger_level * 0.11 + (0.06 if mouth_open > 0.35 else 0.0)
	var gaze_shift := Vector3(look_3d.x * 0.024, look_3d.y * 0.020, 0.0)

	# Rosy-vermilion cheeks glow fuller when happy, soften slightly when fragile
	var cheek_boost: float = 1.18 if is_happy else (0.82 if (alarmed or is_fragile) else 1.0)
	var cheek_sc := Vector3(0.155 * cheek_boost, 0.088 * cheek_boost, 0.042)
	if _left_cheek != null:
		_left_cheek.scale = cheek_sc
	if _right_cheek != null:
		_right_cheek.scale = cheek_sc

	var eye_balls: Array[Node3D] = [_left_eye_ball, _right_eye_ball]
	var eye_scleras: Array[MeshInstance3D] = [_left_eye_sclera, _right_eye_sclera]
	var eye_irises: Array[MeshInstance3D] = [_left_eye_iris, _right_eye_iris]
	var eye_hi1s: Array[MeshInstance3D] = [_left_eye_hi1, _right_eye_hi1]
	var eye_hi2s: Array[MeshInstance3D] = [_left_eye_hi2, _right_eye_hi2]
	var eye_happys: Array[MeshInstance3D] = [_left_eye_happy, _right_eye_happy]

	for i: int in range(2):
		var ball: Node3D = eye_balls[i]
		var sclera: MeshInstance3D = eye_scleras[i]
		var iris: MeshInstance3D = eye_irises[i]
		var hi1: MeshInstance3D = eye_hi1s[i]
		var hi2: MeshInstance3D = eye_hi2s[i]
		var happy_arc: MeshInstance3D = eye_happys[i]
		var side_sign: float = -1.0 if i == 0 else 1.0

		if is_happy:
			ball.visible = false
			sclera.visible = false
			happy_arc.visible = true
			var h_pulse: float = 1.0 + 0.06 * sin(_time * 12.0)
			happy_arc.scale = Vector3(h_pulse, h_pulse, 1.0)
		else:
			happy_arc.visible = false
			ball.visible = true
			if alarmed:
				sclera.visible = true
				sclera.position = Vector3(0.0, 0.0, -0.036)
				sclera.scale = Vector3(0.98 * eye_scale_mult, 1.08 * eye_scale_mult, 0.58)
				ball.scale = Vector3(0.70 * eye_scale_mult, 0.74 * eye_scale_mult, 0.85)
				ball.position = gaze_shift * 1.35 + Vector3(0.0, 0.0, 0.024)
				iris.visible = true
				iris.position = Vector3(0.0, -0.062, 0.118)
				hi1.visible = true
				hi1.position = Vector3(-0.052, 0.062, 0.138)
				hi2.visible = false
			else:
				# Subtle warm-cream Studio Ghibli sclera crescent peeking along outer eye rim
				var show_details: bool = open_y > 0.28
				sclera.visible = show_details
				sclera.scale = Vector3(0.96 * eye_scale_mult, 1.04 * eye_scale_mult * open_y, 0.54)
				sclera.position = Vector3(side_sign * 0.014 - gaze_shift.x * 0.28, -0.008, -0.038)
				ball.scale = Vector3(eye_scale_mult, eye_scale_mult * open_y, 1.0)
				ball.position = gaze_shift * 0.55
				iris.visible = show_details
				hi1.visible = show_details
				hi2.visible = show_details
				iris.position = Vector3(gaze_shift.x * 0.45, -0.062 + gaze_shift.y * 0.25, 0.118)
				hi1.position = Vector3(-0.062 + gaze_shift.x * 0.55, 0.072 + gaze_shift.y * 0.45, 0.136)
				hi2.position = Vector3(0.060, -0.052, 0.136)

	# Expressive 3D Mouth & 2 Cute Tiny White Fang Tips
	if _mouth_rig == null:
		return

	if alarmed and mouth_open < 0.22:
		# Worried little 'o' mouth with tiny peeking white fang tips
		_mouth_smile.visible = false
		_mouth_cavity.visible = true
		_mouth_tongue.visible = true
		_mouth_cavity.scale = Vector3(0.56, 0.68, 0.48)
		_mouth_cavity.position = Vector3(0.0, -0.015, 0.0)
		_mouth_tongue.scale = Vector3(0.55, 0.42, 0.50)
		_mouth_tongue.position = Vector3(0.0, -0.056, 0.028)
		_tooth_left.visible = true
		_tooth_right.visible = true
		_tooth_left.scale = Vector3(0.76, 0.78, 0.70)
		_tooth_right.scale = Vector3(0.76, 0.78, 0.70)
		_tooth_left.position = Vector3(-0.036, 0.044, 0.032)
		_tooth_right.position = Vector3(0.036, 0.044, 0.032)
	elif mouth_open > 0.16:
		# Open chomp / joyful anticipation mouth with rosy tongue & 2 cute tiny white fangs
		_mouth_smile.visible = false
		_mouth_cavity.visible = true
		var mw: float = lerpf(0.76, 1.32, mouth_open)
		var mh: float = lerpf(0.42, 1.12, mouth_open)
		_mouth_cavity.scale = Vector3(mw, mh, 0.52)
		_mouth_cavity.position = Vector3(0.0, -0.020 * mouth_open, 0.0)

		_mouth_tongue.visible = mouth_open > 0.28
		_mouth_tongue.scale = Vector3(mw * 0.78, mh * 0.52, 0.54)
		_mouth_tongue.position = Vector3(0.0, -0.020 * mouth_open - mh * 0.068, 0.032)

		_tooth_left.visible = true
		_tooth_right.visible = true
		var t_sc: float = lerpf(0.95, 1.22, mouth_open)
		_tooth_left.scale = Vector3(t_sc, t_sc * 1.08, 0.78)
		_tooth_right.scale = Vector3(t_sc, t_sc * 1.08, 0.78)
		var tooth_x: float = lerpf(0.064, 0.090, mouth_open)
		var tooth_y: float = -0.020 * mouth_open + mh * 0.094
		_tooth_left.position = Vector3(-tooth_x, tooth_y, 0.040)
		_tooth_right.position = Vector3(tooth_x, tooth_y, 0.040)
	elif is_fragile:
		# Fragile opalescent vitality-0 state: tiny sweet worried pout (matching concept sheet!)
		_mouth_smile.visible = true
		_mouth_cavity.visible = false
		_mouth_tongue.visible = false
		_mouth_smile.scale = Vector3(0.74, -0.78, 1.0)
		_mouth_smile.position = Vector3(0.0, -0.020, 0.022)
		_tooth_left.visible = false
		_tooth_right.visible = false
	else:
		# Sweet warm curved Ghibli smile with 2 adorable tiny white fang tips!
		_mouth_smile.visible = true
		_mouth_cavity.visible = false
		_mouth_tongue.visible = false
		var joy_boost: float = 1.14 if is_happy else 1.0
		_mouth_smile.scale = Vector3(joy_boost, joy_boost, 1.0)
		_mouth_smile.position = Vector3(0.0, 0.024, 0.022)
		_tooth_left.visible = true
		_tooth_right.visible = true
		var ts: float = 1.06 if is_happy else 1.0
		_tooth_left.scale = Vector3(ts, ts, 0.78)
		_tooth_right.scale = Vector3(ts, ts, 0.78)
		_tooth_left.position = Vector3(-0.076 * joy_boost, -0.010, 0.028)
		_tooth_right.position = Vector3(0.076 * joy_boost, -0.010, 0.028)


# ------------------------------------------------------------------------------
# Swallowed Prey Rendering inside Charlie's Translucent Belly (_SwallowedLayer)
# ------------------------------------------------------------------------------

func _draw_swallowed_prey(canvas: CanvasItem) -> void:
	if _swallowed_prey.is_empty():
		return

	var belly_target := Vector2(0.0, world_size * 0.24)
	for entry: Dictionary in _swallowed_prey:
		var age: float = float(entry["age"])
		var start_off: Vector2 = (entry["start_offset"] as Vector2) * world_size
		var ratio: float = float(entry["ratio"])
		var tint: Color = entry["tint"] as Color
		var spin_dir: float = float(entry["spin_dir"])
		var seed_val: float = float(entry["seed"])
		var tex: Texture2D = entry["tex"] as Texture2D
		var frame_idx: int = int(entry["frame_idx"])
		var hframes: int = maxi(int(entry["hframes"]), 1)

		var coral_tint: Color = tint.lerp(Color(1.0, 0.78, 0.58, 1.0), 0.24)

		if age < SWALLOW_SPIRAL_TIME:
			# Phase 1 (0 -> 0.16s): prey spirals smoothly into Charlie's center belly
			var t1: float = clampf(age / SWALLOW_SPIRAL_TIME, 0.0, 1.0)
			var ease_t: float = t1 * t1 * (3.0 - 2.0 * t1)
			var swirl_ang: float = spin_dir * (1.0 - ease_t) * 1.15
			var pos: Vector2 = belly_target + (start_off - belly_target).rotated(swirl_ang) * (1.0 - ease_t)
			var sc: float = lerpf(0.84, 0.56, ease_t)
			var alpha: float = lerpf(0.95, 0.88, ease_t)
			var rot: float = spin_dir * ease_t * 1.9
			canvas.draw_circle(pos, world_size * ratio * sc * 0.85, Color(coral_tint.r, coral_tint.g, coral_tint.b, alpha * 0.38))
			_draw_prey_sprite(canvas, tex, frame_idx, hframes, pos, ratio * sc, rot, Color(coral_tint.r, coral_tint.g, coral_tint.b, alpha))
		else:
			# Phase 2 (0.16s -> 0.56s): dissolves inside belly into rising golden bubbles!
			var t2: float = clampf((age - SWALLOW_SPIRAL_TIME) / SWALLOW_DISSOLVE_TIME, 0.0, 1.0)
			var prey_fade: float = clampf(1.0 - t2 / 0.72, 0.0, 1.0)
			var swirl_pos: Vector2 = belly_target + Vector2(
				cos(seed_val + t2 * 5.2 * spin_dir) * world_size * 0.12 * (1.0 - t2),
				sin(seed_val + t2 * 4.4 * spin_dir) * world_size * 0.09 * (1.0 - t2)
			)
			if prey_fade > 0.02:
				var sc2: float = lerpf(0.56, 0.12, t2)
				var rot2: float = spin_dir * (1.9 + t2 * 3.4)
				canvas.draw_circle(swirl_pos, world_size * ratio * sc2 * 0.90, Color(coral_tint.r, coral_tint.g, coral_tint.b, prey_fade * 0.35))
				_draw_prey_sprite(canvas, tex, frame_idx, hframes, swirl_pos, ratio * sc2, rot2, Color(coral_tint.r, coral_tint.g, coral_tint.b, prey_fade * 0.88))

			# 6 rising golden bubbles effervescing upward inside Charlie's belly
			var bubble_count: int = 6
			for b: int in range(bubble_count):
				var bf: float = float(b) / float(bubble_count)
				var bt: float = clampf((t2 - bf * 0.22) / 0.78, 0.0, 1.0)
				if bt <= 0.0 or bt >= 1.0:
					continue
				var b_ang: float = seed_val + float(b) * 1.45
				var bx: float = swirl_pos.x + cos(b_ang) * world_size * (0.10 + 0.18 * bt) + sin(bt * 8.0 + float(b)) * world_size * 0.04
				var by: float = swirl_pos.y - bt * world_size * 0.44
				var b_env: float = sin(bt * PI)
				var br: float = world_size * (0.045 + 0.042 * ratio) * b_env
				if br < 0.8:
					continue
				var gold_col := Color(1.0, 0.88, 0.48, b_env * 0.78).lerp(coral_tint, 0.22)
				gold_col.a = b_env * 0.78
				canvas.draw_circle(Vector2(bx, by), br, gold_col)
				canvas.draw_circle(Vector2(bx - br * 0.28, by - br * 0.28), br * 0.34, Color(1.0, 0.99, 0.92, b_env * 0.88))

	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_prey_sprite(
	canvas: CanvasItem,
	tex: Texture2D,
	frame_idx: int,
	hframes: int,
	pos: Vector2,
	size_ratio: float,
	rot: float,
	mod_col: Color
) -> void:
	canvas.draw_set_transform(pos, rot, Vector2.ONE)
	if tex != null:
		var tw: float = float(tex.get_width())
		var th: float = float(tex.get_height())
		var fw: float = tw / float(hframes)
		var src_rect := Rect2(fw * float(frame_idx), 0.0, fw, th)
		var draw_len: float = maxf(world_size * size_ratio * 2.55, 6.0)
		var dst_rect := Rect2(-draw_len * 0.5, -draw_len * 0.5, draw_len, draw_len)
		canvas.draw_texture_rect_region(tex, dst_rect, src_rect, mod_col)
	else:
		var orb_r: float = maxf(world_size * size_ratio * 0.55, 3.0)
		canvas.draw_circle(Vector2.ZERO, orb_r, mod_col)
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
