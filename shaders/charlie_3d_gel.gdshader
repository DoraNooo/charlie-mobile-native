shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

// Outer Glossy Studio Ghibli Translucent Clearcoat Gel Shell (sorting_offset = 2.0).
// Shares the EXACT same deform_shell() vertex sculpt as charlie_3d_inner.gdshader.
// Adds true 3D sculptural shading, iconic twin liquid-glass ivory forehead specular beads,
// glossy translucent coral Fresnel meniscus rim, and wet flipper/tail highlights over the
// opaque inner volumetric body + embedded 3D pearls & face rig.

uniform vec4 core_color : source_color = vec4(1.000, 0.560, 0.240, 1.0);
uniform vec4 edge_color : source_color = vec4(0.880, 0.290, 0.160, 1.0);
uniform vec4 glow_color : source_color = vec4(1.000, 0.480, 0.200, 1.0);
uniform vec4 flavor_tint : source_color = vec4(1.000, 0.560, 0.240, 0.0);

// Exact Studio Ghibli concept-sheet clearcoat colors
uniform vec4 sig_core_color : source_color = vec4(1.000, 0.590, 0.290, 1.0);    // #ff964a sunlit apricot-tangerine
uniform vec4 sig_mid_coral : source_color = vec4(0.920, 0.380, 0.195, 1.0);     // #eb6132 sunset coral
uniform vec4 sig_deep_coral : source_color = vec4(0.720, 0.215, 0.145, 1.0);    // #b83725 deep translucent coral
uniform vec4 sig_caustic_color : source_color = vec4(1.000, 0.720, 0.310, 1.0); // #ffb84f glowing honey caustic
uniform vec4 sig_rim_sheen : source_color = vec4(1.000, 0.790, 0.540, 1.0);     // #ffc98a glossy warm glass rim

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
uniform vec3 tail_dir = vec3(-0.96, -0.14, -0.16);
uniform float tail_strength = 0.72;
uniform vec3 fin_lag = vec3(0.0, 0.0, 0.0);

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
	float w = exp(-dot(diff, diff) * 1.65);
	float stretch_delta = (llen - 0.244) * 0.38;
	float rad_delta = (lobe.z - base_r) * 1.50;
	return w * (stretch_delta + rad_delta);
}

vec3 deform_shell(vec3 u) {
	float t = time_sec;

	float breath_xy = sin(t * 2.7) * 0.022;
	float breath_y = cos(t * 2.7) * 0.020;
	float core_scale = clamp(core_radius / 0.46, 0.88, 1.15);

	float d_lobes = 0.0;
	d_lobes += lobe_displacement(u, lobe_0, 0.30);
	d_lobes += lobe_displacement(u, lobe_1, 0.29);
	d_lobes += lobe_displacement(u, lobe_2, 0.29);
	d_lobes += lobe_displacement(u, lobe_3, 0.27);
	d_lobes += lobe_displacement(u, lobe_4, 0.27);
	d_lobes *= 0.40;

	float gulp_bulge = 0.0;
	if (gulp_phase >= 0.0) {
		float gp = clamp(gulp_phase, 0.0, 1.0);
		vec2 fdir = normalize(facing_dir + vec2(0.0001, 0.0));
		float axial = dot(u.xy, fdir);
		float wave_center = mix(0.82, -0.82, gp);
		float env = sin(gp * 3.14159265);
		float gulp_d = (axial - wave_center) * 2.35;
		gulp_bulge = exp(-(gulp_d * gulp_d)) * env * gulp_intensity * 0.115;
	}

	float jelly_wave = sin(u.x * 3.6 + t * 3.0) * cos(u.y * 3.6 - t * 2.4) * (0.008 + wobble_amp * 0.030);
	float shiver = sin(u.y * 9.5 + t * 26.0) * cos(u.x * 8.0 - t * 22.0) * fear_ripple * 0.014;

	float crown_round = smoothstep(0.30, 0.96, u.y) * 0.032;
	float belly_d = (u.y + 0.12) * 1.55;
	float belly_plump = exp(-(belly_d * belly_d)) * (1.0 - u.y * u.y * 0.50) * 0.064;

	float r = 0.84 * core_scale - crown_round + belly_plump + d_lobes + gulp_bulge + jelly_wave + shiver;
	r = clamp(r, 0.66, 1.08);

	float spread_now = length(lobe_0.xy) + length(lobe_1.xy) + length(lobe_2.xy) + length(lobe_3.xy) + length(lobe_4.xy);
	float spread_delta = clamp((spread_now - 1.226) * 0.42, -0.18, 0.22);
	float z_conserve = clamp(1.0 - spread_delta * 0.25 - breath_xy * 0.70 + gulp_bulge * 0.55, 0.88, 1.15);

	vec3 pos = vec3(
		u.x * r * (1.0 + breath_xy),
		u.y * r * (1.0 + breath_y),
		u.z * r * z_conserve
	);

	// Sleek, clearly visible flowing molten slime tail sweeping gracefully behind Charlie
	vec3 td_raw = vec3(tail_dir.x, tail_dir.y, tail_dir.z * 0.42);
	vec3 td = normalize(td_raw + vec3(-0.001, 0.0, 0.0));
	vec3 t_diff = u - td;
	float td2 = dot(t_diff, t_diff);
	float tail_waist = exp(-td2 * 2.15);
	float tail_tip = exp(-td2 * 5.2);
	float ts = clamp(tail_strength, 0.64, 1.32);

	vec3 t_ref = (abs(td.y) < 0.90) ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 t_side = normalize(cross(t_ref, td));
	vec3 t_up = cross(td, t_side);
	float t_align = clamp(dot(u, td), 0.0, 1.0);
	float tail_sway = sin(t * 4.5 - t_align * 3.1) * (0.055 + 0.055 * ts) * tail_tip;
	float tail_lift = cos(t * 2.9 - t_align * 2.4) * 0.025 * tail_tip;
	vec3 tail_vec = td * (tail_waist * 0.24 + tail_tip * 0.58) * ts + t_up * tail_sway + t_side * tail_lift;
	pos += tail_vec;

	// Two cute, distinct, tightly-sculpted stubby rounded gel flippers/nubs
	float fin_bob_l = sin(t * 4.2) * 0.07;
	float fin_bob_r = sin(t * 4.2 + 2.4) * 0.07;
	vec3 fin_l_dir = normalize(vec3(-0.46, -0.82 + fin_bob_l, 0.34) + fin_lag * 0.24);
	vec3 fin_r_dir = normalize(vec3( 0.46, -0.82 + fin_bob_r, 0.34) + fin_lag * 0.24);
	vec3 dl = u - fin_l_dir;
	vec3 dr = u - fin_r_dir;
	float w_fin_l = exp(-dot(dl, dl) * 14.5);
	float w_fin_r = exp(-dot(dr, dr) * 14.5);
	vec3 fin_pull_l = normalize(vec3(-0.42, -0.88, 0.20) + fin_lag * 0.40) * (w_fin_l * 0.30);
	vec3 fin_pull_r = normalize(vec3( 0.42, -0.88, 0.20) + fin_lag * 0.40) * (w_fin_r * 0.30);
	pos += fin_pull_l + fin_pull_r;

	vec2 centroid = (lobe_0.xy + lobe_1.xy + lobe_2.xy + lobe_3.xy + lobe_4.xy) * 0.2;
	pos.xy += centroid * 0.14;

	float plen = length(pos);
	if (plen > 1.54) {
		float capped = 1.54 + 0.08 * (1.0 - exp(-(plen - 1.54) * 8.0));
		pos *= (capped / plen);
	}
	return pos;
}

void vertex() {
	vec3 n0 = normalize(VERTEX);
	vec3 up_ref = (abs(n0.y) < 0.92) ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 t_vec = normalize(cross(up_ref, n0));
	vec3 b_vec = cross(n0, t_vec);

	const float EPS = 0.020;
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
	float fresnel = pow(max(1.0 - NdotV, 0.0), 2.05);
	float soft_fres = pow(max(1.0 - NdotV, 0.0), 1.30);

	// Studio Ghibli Optical Lighting Rig
	vec3 L_key = normalize(vec3(-0.44, 0.74, 0.50));
	vec3 L_coat = normalize(vec3(-0.44, 1.24, 0.18));
	vec3 L_pin = normalize(vec3(-0.02, 1.38, 0.14));
	vec3 L_caustic = normalize(vec3(0.50, -0.64, 0.58));
	vec3 L_rim = normalize(vec3(0.46, -0.40, 0.79));

	vec3 H_key = normalize(L_key + V);
	vec3 H_coat = normalize(L_coat + V);
	vec3 H_pin = normalize(L_pin + V);

	// Rich sculptural 3D volume contrast (deep coral shadow 0.68 -> sunlit apricot crown 1.12)
	float wrap_diff = clamp((dot(N, L_key) + 0.44) / 1.44, 0.0, 1.0);
	float NdotH_broad = max(dot(N, H_key), 0.0);
	float NdotH_pin = max(dot(N, H_pin), 0.0);

	// Anisotropic sleek curved liquid-glass crescent high on upper-left forehead dome
	vec3 coat_t = normalize(cross(vec3(0.0, 0.0, 1.0), H_coat));
	vec3 coat_b = cross(H_coat, coat_t);
	vec3 n_diff = N - H_coat;
	float u_aniso = dot(n_diff, coat_t) * 1.12;
	float v_aniso = dot(n_diff, coat_b) * 2.65;
	float ellip_d2 = u_aniso * u_aniso + v_aniso * v_aniso;
	float NdotH_coat = clamp(1.0 - ellip_d2 * 0.5, 0.0, 1.0);
	float crown_front = smoothstep(0.50, 0.84, dot(N, H_coat));

	// Lush Studio Ghibli honey-to-tangerine-coral outer gel surface
	vec3 rich_core = mix(sig_core_color.rgb, core_color.rgb, 0.18);
	vec3 mid_coral = mix(sig_mid_coral.rgb, edge_color.rgb, 0.20);
	vec3 deep_coral = mix(sig_deep_coral.rgb, edge_color.rgb * vec3(0.84, 0.62, 0.52), 0.16);

	vec3 gel_col = mix(rich_core, mid_coral, smoothstep(0.08, 0.58, soft_fres));
	gel_col = mix(gel_col, deep_coral, smoothstep(0.42, 0.92, fresnel) * 0.52);
	gel_col *= mix(0.68, 1.12, wrap_diff);

	// Luminous bottom-right internal honey-gold caustic bounce (lights lower belly & flipper undersides!)
	float caustic_dot = max(dot(N, L_caustic), 0.0);
	float caustic = pow(caustic_dot, 2.2) * (1.0 - smoothstep(0.48, 0.94, fresnel));
	vec3 caustic_col = mix(sig_caustic_color.rgb, glow_color.rgb, 0.20);
	gel_col = mix(gel_col, caustic_col, caustic * 0.44);

	// Glossy translucent peach-gold Fresnel rim sheen (defines curved body, flippers & sweeping tail!)
	float rim_lit = fresnel * (0.48 + 0.52 * max(dot(N, L_rim), 0.0));
	vec3 rim_sheen_col = mix(sig_rim_sheen.rgb, rich_core, 0.26);
	gel_col = mix(gel_col, rim_sheen_col, clamp(rim_lit * 0.60, 0.0, 0.66));

	// Vibrant jewel-like flavor wash inside lower belly when digesting prey
	float belly_zone = (1.0 - smoothstep(0.14, 0.72, fresnel)) * (1.0 - smoothstep(0.10, 0.68, v_local_pos.y));
	float flavor_amt = clamp(flavor_tint.a, 0.0, 1.0) * belly_zone;
	vec3 vivid_flavor = clamp(mix(flavor_tint.rgb, flavor_tint.rgb * 1.16, 0.50), vec3(0.0), vec3(1.0));
	gel_col = mix(gel_col, vivid_flavor, flavor_amt * 0.42);

	// Vitality 0: delicate opalescent frost-peach glass
	float vit = clamp(vitality_ratio, 0.0, 1.0);
	vec3 frost_glass = mix(vec3(0.92, 0.80, 0.75), vec3(0.76, 0.62, 0.58), soft_fres * 0.65) * mix(0.76, 1.06, wrap_diff);
	frost_glass = mix(frost_glass, vec3(1.0, 0.96, 0.94), clamp(rim_lit * 0.55, 0.0, 0.58));
	gel_col = mix(frost_glass, gel_col, smoothstep(0.0, 0.92, vit));

	// Crystal-clear front gel windows over embedded 3D eyeballs & mouth
	float front_face = smoothstep(0.10, 0.36, v_local_pos.z);
	vec2 eye_l_pos = face_offset + vec2(-0.275, 0.065);
	vec2 eye_r_pos = face_offset + vec2(0.275, 0.065);
	vec2 mouth_pos = face_offset + vec2(0.0, -0.125);
	float d_el = length((v_local_pos.xy - eye_l_pos) * vec2(1.04, 0.94));
	float d_er = length((v_local_pos.xy - eye_r_pos) * vec2(1.04, 0.94));
	float d_m = length((v_local_pos.xy - mouth_pos) * vec2(1.02, 1.18));
	float eye_clear = max(1.0 - smoothstep(0.11, 0.20, d_el), 1.0 - smoothstep(0.11, 0.20, d_er));
	float mouth_clear = 1.0 - smoothstep(0.065, 0.155, d_m);
	float feature_clear = max(eye_clear, mouth_clear * 0.92) * smoothstep(0.32, 0.72, NdotV) * front_face;

	// Protective specular guard over both eyes
	float eye_spec_guard = max(1.0 - smoothstep(0.18, 0.30, d_el), 1.0 - smoothstep(0.18, 0.30, d_er)) * front_face;
	float eye_spec_atten = 1.0 - eye_spec_guard * 0.98;

	// Iconic Ghibli twin forehead highlight beads stay high on upper forehead dome
	float crown_zone = smoothstep(0.30, 0.44, v_local_pos.y);

	// Iconic Studio Ghibli Liquid-Glass Speculars:
	float wet_sheen = pow(NdotH_broad, 14.0) * 0.16 * smoothstep(0.14, 0.48, v_local_pos.y) * eye_spec_atten;
	float crown_core = smoothstep(0.946, 0.976, NdotH_coat) * crown_front;
	float crown_soft = smoothstep(0.896, 0.960, NdotH_coat) * 0.20 * crown_front;
	float crown_ribbon = clamp(crown_core * 0.95 + crown_soft, 0.0, 1.0) * crown_zone * eye_spec_atten;
	float crown_pin = smoothstep(0.986, 0.9950, NdotH_pin) * 0.96 * crown_zone * eye_spec_atten;
	float lower_appendage = (1.0 - smoothstep(-0.08, 0.24, v_local_pos.y)) * smoothstep(0.70, 1.05, length(v_local_pos));
	float limb_glint = pow(NdotH_broad, 12.0) * 0.50 * lower_appendage * eye_spec_atten;

	vec3 spec_col = vec3(1.0, 0.995, 0.960);
	float total_spec = clamp(crown_ribbon * 0.94 + crown_pin * 0.96 + wet_sheen * 0.42 + limb_glint * 0.74, 0.0, 0.97);
	gel_col = mix(gel_col, spec_col, total_spec);

	// Outer glossy clearcoat overlay alpha: subtle wet tint over center, rich meniscus rim on silhouette
	float center_alpha = mix(0.18, 0.24, vit);
	float rim_alpha = mix(0.78, 0.88, vit);
	float base_alpha = mix(center_alpha, rim_alpha, pow(max(1.0 - NdotV, 0.0), 1.65));
	float gel_alpha = mix(base_alpha, 0.03, feature_clear);
	float spec_alpha_boost = (crown_ribbon * 0.94 + crown_pin * 0.96 + wet_sheen * 0.16 + limb_glint * 0.50) * eye_spec_atten;
	float final_alpha = clamp(max(gel_alpha, spec_alpha_boost), 0.0, 0.96);

	float edge_aa = smoothstep(0.0, 0.14, NdotV);
	final_alpha *= edge_aa;
	final_alpha *= (1.0 - clamp(invuln_flash, 0.0, 1.0) * 0.34);

	ALBEDO = clamp(gel_col, vec3(0.0), vec3(1.0));
	ALPHA = final_alpha;
}
