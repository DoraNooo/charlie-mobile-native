shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

// True 3D Soft-Body Translucent Honey-Coral Slime Shell for la petite Charlie.
// Custom optical shading guarantees identical Pixar/Ghibli translucency & glossy wet clearcoat
// on both Vulkan Mobile and OpenGL3 renderers.

uniform vec4 core_color : source_color = vec4(1.0, 0.71, 0.42, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.42, 0.34, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.50, 0.28, 1.0);
uniform vec4 flavor_tint : source_color = vec4(1.0, 0.71, 0.42, 0.0);

// Iconic honey-apricot-to-coral signature anchors (source_color guarantees identical gamma on Vulkan Mobile & OpenGL3)
uniform vec4 sig_core_color : source_color = vec4(1.0, 0.71, 0.42, 1.0);
uniform vec4 sig_edge_color : source_color = vec4(1.0, 0.42, 0.34, 1.0);
uniform vec4 sig_caustic_color : source_color = vec4(1.0, 0.68, 0.24, 1.0);

uniform float core_radius = 0.46;
uniform float wobble_amp = 0.0;
uniform float fear_ripple = 0.0;
uniform float vitality_ratio = 1.0;
uniform float invuln_flash = 0.0;
uniform float time_sec = 0.0;

uniform float gulp_phase = -1.0;
uniform float gulp_intensity = 0.0;
uniform vec2 facing_dir = vec2(1.0, 0.0);
uniform vec2 face_offset = vec2(0.0, 0.08);

// 5 viscous spring-mass lobes in 3D-aligned XY (Y already flipped to +Y up), z = dynamic radius
uniform vec3 lobe_0 = vec3(-0.24, 0.0, 0.30);
uniform vec3 lobe_1 = vec3(-0.04, 0.24, 0.29);
uniform vec3 lobe_2 = vec3(-0.04, -0.24, 0.29);
uniform vec3 lobe_3 = vec3(0.20, 0.15, 0.27);
uniform vec3 lobe_4 = vec3(0.20, -0.15, 0.27);

varying vec3 v_local_pos;

float lobe_displacement(vec3 u, vec3 lobe, float base_r) {
	vec2 lxy = lobe.xy;
	float llen = length(lxy);
	vec2 ldir2 = (llen > 0.0001) ? (lxy / llen) : vec2(1.0, 0.0);
	vec3 ldir = vec3(ldir2, 0.0);
	vec3 diff = u - ldir;
	// Smooth Gaussian angular kernel on unit sphere: C^inf smooth, zero pinching
	float w = exp(-dot(diff, diff) * 1.45);
	float stretch_delta = (llen - 0.244) * 0.70;
	float rad_delta = (lobe.z - base_r) * 2.40;
	return w * (stretch_delta + rad_delta);
}

vec3 deform_shell(vec3 u) {
	float t = time_sec;

	// Living idle breathing (gentle volume-conserving mochi pulse)
	float breath_xy = sin(t * 2.7) * 0.026;
	float breath_y = cos(t * 2.7) * 0.020;

	// Core swell from dynamic core_radius (0.46 rest)
	float core_scale = clamp(core_radius / 0.46, 0.86, 1.18);

	// 5 spring-mass lobes driving smooth organic soft-body squash/stretch & turn slosh
	float d_lobes = 0.0;
	d_lobes += lobe_displacement(u, lobe_0, 0.30);
	d_lobes += lobe_displacement(u, lobe_1, 0.29);
	d_lobes += lobe_displacement(u, lobe_2, 0.29);
	d_lobes += lobe_displacement(u, lobe_3, 0.27);
	d_lobes += lobe_displacement(u, lobe_4, 0.27);

	// Travelling 3D chomp gulp bulge from front mouth -> belly -> rear tail
	float gulp_bulge = 0.0;
	if (gulp_phase >= 0.0) {
		float gp = clamp(gulp_phase, 0.0, 1.0);
		vec2 fdir = normalize(facing_dir + vec2(0.0001, 0.0));
		float axial = dot(u.xy, fdir);
		float wave_center = mix(0.82, -0.82, gp);
		float env = sin(gp * 3.14159265);
		float gulp_d = (axial - wave_center) * 2.35;
		gulp_bulge = exp(-(gulp_d * gulp_d)) * env * gulp_intensity * 0.125;
	}

	// Organic living jelly ripple + delicate smooth fear shiver (keeps wet highlights silky!)
	float jelly_wave = sin(u.x * 3.8 + t * 3.1) * cos(u.y * 3.8 - t * 2.5) * (0.011 + wobble_amp * 0.040);
	float shiver = sin(u.y * 9.5 + t * 26.0) * cos(u.x * 8.0 - t * 22.0) * fear_ripple * 0.015;

	// Subtly organic plump teardrop-slime resting silhouette:
	// - Slightly tapered adorable rounded forehead crown (y > 0.22)
	// - Fuller, wider huggable warm lower belly (peaking around y = -0.28)
	// - Soft cushioned mochi base + gentle organic breathing lobes even at rest
	float crown_taper = smoothstep(0.20, 0.94, u.y) * 0.064;
	float belly_d = (u.y + 0.28) * 1.90;
	float belly_plump = exp(-(belly_d * belly_d)) * (1.0 - u.y * u.y) * 0.092;
	float base_cushion = (1.0 - smoothstep(-0.94, -0.42, u.y)) * 0.032;
	float ang_xy = atan(u.y, u.x);
	float lower_weight = 0.35 + 0.65 * (1.0 - smoothstep(-0.15, 0.68, u.y));
	float rest_lobes = (
		sin(ang_xy * 2.0 + t * 2.05) * 0.014 +
		cos(ang_xy * 3.0 - t * 1.60) * 0.015
	) * lower_weight;

	float r = 0.90 * core_scale - crown_taper + belly_plump - base_cushion + rest_lobes + d_lobes + gulp_bulge + jelly_wave + shiver;
	r = clamp(r, 0.64, 1.15);

	// Volume conservation in Z: puff Z slightly when XY squashes, thin Z when XY stretches
	float spread_now = length(lobe_0.xy) + length(lobe_1.xy) + length(lobe_2.xy) + length(lobe_3.xy) + length(lobe_4.xy);
	float spread_delta = clamp((spread_now - 1.226) * 0.55, -0.22, 0.28);
	float z_conserve = clamp(1.0 - spread_delta * 0.36 - breath_xy * 0.8 + gulp_bulge * 0.7, 0.82, 1.20);

	// Gentle inertial centroid follow-through
	vec2 centroid = (lobe_0.xy + lobe_1.xy + lobe_2.xy + lobe_3.xy + lobe_4.xy) * 0.2;
	vec3 pos = vec3(
		u.x * r * (1.0 + breath_xy),
		u.y * r * (1.0 + breath_y),
		u.z * r * z_conserve
	);
	pos.xy += centroid * 0.36;
	return pos;
}

void vertex() {
	vec3 n0 = normalize(VERTEX);
	vec3 up_ref = (abs(n0.y) < 0.92) ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 t_vec = normalize(cross(up_ref, n0));
	vec3 b_vec = cross(n0, t_vec);

	const float EPS = 0.025;
	vec3 p0 = deform_shell(n0);
	vec3 pT = deform_shell(normalize(n0 + t_vec * EPS));
	vec3 pB = deform_shell(normalize(n0 + b_vec * EPS));

	vec3 n_new = normalize(cross(pT - p0, pB - p0));
	if (dot(n_new, n0) < 0.0) {
		n_new = -n_new;
	}

	VERTEX = p0;
	NORMAL = n_new;
	v_local_pos = p0;
}

void fragment() {
	vec3 N = normalize(NORMAL);
	vec3 V = normalize(VIEW);
	float NdotV = clamp(dot(N, V), 0.0, 1.0);
	float fresnel = pow(1.0 - NdotV, 2.05);
	float soft_fres = pow(1.0 - NdotV, 1.25);

	// Lighting vectors:
	// - L_key: soft warm diffuse from upper-left-front
	// - L_coat: sleek glossy crown highlight positioned HIGH on upper-left dome crown (ABOVE brow, y > 0.36!)
	// - L_pin: cute crisp tiny secondary round glint beside the crown arc on upper dome
	// - L_caustic: warm internal subsurface honey-gold bounce on lower-right belly
	// - L_rim: subtle warm coral-apricot Fresnel edge lift
	vec3 L_key = normalize(vec3(-0.36, 0.80, 0.48));
	vec3 L_coat = normalize(vec3(-0.46, 1.54, -0.08));
	vec3 L_pin = normalize(vec3(0.10, 1.62, -0.14));
	vec3 L_caustic = normalize(vec3(0.54, -0.64, 0.54));
	vec3 L_rim = normalize(vec3(0.52, -0.44, 0.72));

	vec3 H_key = normalize(L_key + V);
	vec3 H_coat = normalize(L_coat + V);
	vec3 H_pin = normalize(L_pin + V);

	float wrap_diff = clamp((dot(N, L_key) + 0.62) / 1.62, 0.0, 1.0);
	float NdotH_broad = max(dot(N, H_key), 0.0);
	float NdotH_pin = max(dot(N, H_pin), 0.0);

	// Sleek, tight elliptical curved crown specular high on upper-left dome
	vec3 coat_t = normalize(cross(vec3(0.0, 0.0, 1.0), H_coat));
	vec3 coat_b = cross(H_coat, coat_t);
	vec3 n_diff = N - H_coat;
	float u_aniso = dot(n_diff, coat_t) * 1.16;
	float v_aniso = dot(n_diff, coat_b) * 2.72;
	float ellip_d2 = u_aniso * u_aniso + v_aniso * v_aniso;
	float NdotH_coat = clamp(1.0 - ellip_d2 * 0.5, 0.0, 1.0);
	float crown_front = smoothstep(0.55, 0.86, dot(N, H_coat));

	// Lush Pixar/Ghibli honey-apricot-to-coral saturation (#ffb56b inner -> #ff6b57 rich coral rim)
	// Anchored to Charlie's iconic palette so bright worlds (like World VI Cosmic) NEVER wash her out!
	vec3 rich_core = mix(sig_core_color.rgb, core_color.rgb, 0.36);
	vec3 rich_edge = mix(sig_edge_color.rgb, edge_color.rgb, 0.38);
	vec3 mid_gel = mix(rich_core, rich_edge, 0.44);
	vec3 rim_gel = mix(rich_edge, sig_edge_color.rgb * vec3(1.02, 0.90, 0.88), 0.32);

	vec3 gel_col = mix(rich_core, mid_gel, smoothstep(0.06, 0.56, soft_fres));
	gel_col = mix(gel_col, rim_gel, smoothstep(0.34, 0.90, fresnel));
	gel_col *= mix(0.84, 1.02, wrap_diff);

	// Warm bottom-right internal subsurface honey-gold caustic bounce
	float caustic_dot = max(dot(N, L_caustic), 0.0);
	float caustic = pow(caustic_dot, 2.5) * (1.0 - smoothstep(0.46, 0.92, fresnel));
	vec3 caustic_col = mix(sig_caustic_color.rgb, glow_color.rgb, 0.30);
	gel_col = mix(gel_col, caustic_col, caustic * 0.28);

	// Warm coral-apricot Fresnel rim sheen (keeps rich coral saturation, never chalky white!)
	float rim_lit = fresnel * (0.24 + 0.48 * max(dot(N, L_rim), 0.0));
	vec3 rim_sheen_col = mix(rich_edge, rich_core, 0.45);
	gel_col = mix(gel_col, rim_sheen_col, clamp(rim_lit * 0.30, 0.0, 0.34));

	// Vibrant jewel-like flavor tint wash inside Charlie's lower/mid belly when digesting prey
	float belly_zone = (1.0 - smoothstep(0.12, 0.68, fresnel)) * (1.0 - smoothstep(0.12, 0.72, v_local_pos.y));
	float flavor_amt = clamp(flavor_tint.a, 0.0, 1.0) * belly_zone;
	vec3 vivid_flavor = clamp(mix(flavor_tint.rgb, flavor_tint.rgb * 1.16, 0.50), vec3(0.0), vec3(1.0));
	gel_col = mix(gel_col, vivid_flavor, flavor_amt * 0.48);

	// Vitality pale-out: 1.0 = lush honey-coral -> 0.0 = delicate opalescent frost-peach
	float vit = clamp(vitality_ratio, 0.0, 1.0);
	gel_col = mix(gel_col, vec3(0.96, 0.84, 0.78), (1.0 - vit) * 0.52);

	// Tightly fitted clear gel windows over embedded 3D eyeballs & mouth (zero dark gap ring between eyes!)
	vec2 eye_l_pos = face_offset + vec2(-0.265, 0.055);
	vec2 eye_r_pos = face_offset + vec2(0.265, 0.055);
	vec2 mouth_pos = face_offset + vec2(0.0, -0.115);
	float d_el = length((v_local_pos.xy - eye_l_pos) * vec2(1.06, 0.96));
	float d_er = length((v_local_pos.xy - eye_r_pos) * vec2(1.06, 0.96));
	float d_m = length((v_local_pos.xy - mouth_pos) * vec2(1.05, 1.22));
	float eye_clear = max(1.0 - smoothstep(0.10, 0.175, d_el), 1.0 - smoothstep(0.10, 0.175, d_er));
	float mouth_clear = 1.0 - smoothstep(0.06, 0.135, d_m);
	float feature_clear = max(eye_clear, mouth_clear * 0.90) * smoothstep(0.35, 0.75, NdotV);

	// Wider protective specular guard over both eyes so glossy specular NEVER clouds dark chocolate eyes or amber iris!
	float eye_spec_guard = max(1.0 - smoothstep(0.16, 0.27, d_el), 1.0 - smoothstep(0.16, 0.27, d_er));
	float eye_spec_atten = 1.0 - eye_spec_guard * 0.96;

	// Vertical brow gate: glossy crown highlight stays strictly HIGH on upper dome (y > 0.36), never descending into eye zone!
	float crown_zone = smoothstep(0.36, 0.48, v_local_pos.y);

	// Glossy Wet Clearcoat Specular ON THE OUTER CROWN SHELL:
	// 1. Subtle wet clearcoat sheen confined softly above midline and strongly attenuated over eyes
	float wet_sheen = pow(NdotH_broad, 18.0) * 0.10 * smoothstep(0.18, 0.50, v_local_pos.y) * eye_spec_atten;
	// 2. Sleek tight curved crown highlight arc high on upper-left dome (y > 0.36)
	float crown_core = smoothstep(0.952, 0.980, NdotH_coat) * crown_front;
	float crown_soft = smoothstep(0.905, 0.965, NdotH_coat) * 0.18 * crown_front;
	float crown_ribbon = clamp(crown_core * 0.88 + crown_soft, 0.0, 1.0) * crown_zone * eye_spec_atten;
	// 3. Cute crisp tiny round secondary glint beside the crown ribbon
	float crown_pin = smoothstep(0.990, 0.9965, NdotH_pin) * 0.88 * crown_zone * eye_spec_atten;

	vec3 spec_col = vec3(1.0, 0.992, 0.975);
	gel_col = mix(gel_col, spec_col, clamp(crown_ribbon * 0.80 + crown_pin * 0.86 + wet_sheen * 0.35, 0.0, 0.85));

	// Semi-translucent honey belly (lets pearls, delicate bubbles & attenuated refracted world shine cleanly)
	// with silky subpixel grazing edge AA feathering at the outermost rim!
	float center_alpha = mix(0.46, 0.56, vit);
	float rim_alpha = mix(0.86, 0.95, vit);
	float base_alpha = mix(center_alpha, rim_alpha, fresnel);
	float gel_alpha = mix(base_alpha, 0.06, feature_clear);
	float spec_alpha_boost = (crown_ribbon * 0.84 + crown_pin * 0.90 + wet_sheen * 0.14) * eye_spec_atten;
	float final_alpha = clamp(max(gel_alpha, spec_alpha_boost), 0.0, 0.96);
	// Smooth grazing silhouette feathering eliminates jagged polygon rim stepping
	float edge_aa = smoothstep(0.0, 0.22, NdotV);
	final_alpha *= edge_aa;
	final_alpha *= (1.0 - clamp(invuln_flash, 0.0, 1.0) * 0.34);

	ALBEDO = clamp(gel_col, vec3(0.0), vec3(1.0));
	ALPHA = final_alpha;
}
