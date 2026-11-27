shader_type spatial;
render_mode depth_draw_opaque, cull_front, unshaded;

// Inner Volumetric 3D Honey-Coral Jelly Core for la petite Charlie.
// OPAQUE interior back-wall (a = 1.0 with native MSAA_4X) completely eliminates Vulkan Mobile
// double-alpha sRGB washout! Renders deep sculpted Studio Ghibli molten coral -> sunset tangerine
// -> warm golden-honey belly glow BEHIND Charlie's embedded 3D pearls, micro-bubbles & face rig.

uniform vec4 core_color : source_color = vec4(1.000, 0.560, 0.240, 1.0);
uniform vec4 edge_color : source_color = vec4(0.880, 0.290, 0.160, 1.0);
uniform vec4 glow_color : source_color = vec4(1.000, 0.480, 0.200, 1.0);
uniform vec4 flavor_tint : source_color = vec4(1.000, 0.560, 0.240, 0.0);

// Exact deep Studio Ghibli concept-sheet volumetric colors (rich orange-coral-vermilion!)
uniform vec4 sig_deep_rim : source_color = vec4(0.680, 0.185, 0.125, 1.0);   // #ad2f20 deep molten coral shadow
uniform vec4 sig_coral_wall : source_color = vec4(0.910, 0.345, 0.175, 1.0); // #e8582d vibrant sunset coral
uniform vec4 sig_honey_mid : source_color = vec4(0.985, 0.495, 0.215, 1.0);  // #fb7e37 juicy molten tangerine
uniform vec4 sig_honey_core : source_color = vec4(1.000, 0.675, 0.305, 1.0); // #ffac4e glowing golden-honey belly

uniform float core_radius = 0.46;
uniform float wobble_amp = 0.0;
uniform float fear_ripple = 0.0;
uniform float vitality_ratio = 1.0;
uniform float invuln_flash = 0.0;
uniform float time_sec = 0.0;

uniform float gulp_phase = -1.0;
uniform float gulp_intensity = 0.0;
uniform vec2 facing_dir = vec2(1.0, 0.0);
uniform vec3 tail_dir = vec3(-0.96, -0.14, -0.16);
uniform float tail_strength = 0.72;
uniform vec3 fin_lag = vec3(0.0, 0.0, 0.0);

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
	float w = exp(-dot(diff, diff) * 1.65);
	float stretch_delta = (llen - 0.244) * 0.38;
	float rad_delta = (lobe.z - base_r) * 1.50;
	return w * (stretch_delta + rad_delta);
}

vec3 deform_shell(vec3 u) {
	float t = time_sec;

	// Living idle breathing (gentle volume-conserving liquid pulse)
	float breath_xy = sin(t * 2.7) * 0.022;
	float breath_y = cos(t * 2.7) * 0.020;

	// Core swell from dynamic core_radius (0.46 rest)
	float core_scale = clamp(core_radius / 0.46, 0.88, 1.15);

	// 5 spring-mass lobes for organic soft-body jiggle
	float d_lobes = 0.0;
	d_lobes += lobe_displacement(u, lobe_0, 0.30);
	d_lobes += lobe_displacement(u, lobe_1, 0.29);
	d_lobes += lobe_displacement(u, lobe_2, 0.29);
	d_lobes += lobe_displacement(u, lobe_3, 0.27);
	d_lobes += lobe_displacement(u, lobe_4, 0.27);
	d_lobes *= 0.40;

	// Travelling 3D chomp gulp bulge from mouth -> belly -> tail
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

	// Organic living jelly ripple + smooth fear shiver
	float jelly_wave = sin(u.x * 3.6 + t * 3.0) * cos(u.y * 3.6 - t * 2.4) * (0.008 + wobble_amp * 0.030);
	float shiver = sin(u.y * 9.5 + t * 26.0) * cos(u.x * 8.0 - t * 22.0) * fear_ripple * 0.014;

	// Adorable round plump baby-slime head & curved belly (zero flat gumdrop shelf!)
	float crown_round = smoothstep(0.30, 0.96, u.y) * 0.032;
	float belly_d = (u.y + 0.12) * 1.55;
	float belly_plump = exp(-(belly_d * belly_d)) * (1.0 - u.y * u.y * 0.50) * 0.064;

	float r = 0.84 * core_scale - crown_round + belly_plump + d_lobes + gulp_bulge + jelly_wave + shiver;
	r = clamp(r, 0.66, 1.08);

	// Volume conservation in Z
	float spread_now = length(lobe_0.xy) + length(lobe_1.xy) + length(lobe_2.xy) + length(lobe_3.xy) + length(lobe_4.xy);
	float spread_delta = clamp((spread_now - 1.226) * 0.42, -0.18, 0.22);
	float z_conserve = clamp(1.0 - spread_delta * 0.25 - breath_xy * 0.70 + gulp_bulge * 0.55, 0.88, 1.15);

	vec3 pos = vec3(
		u.x * r * (1.0 + breath_xy),
		u.y * r * (1.0 + breath_y),
		u.z * r * z_conserve
	);

	// Sleek, clearly visible flowing molten slime tail sweeping gracefully behind Charlie (mostly in XY plane!)
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

	// Two cute, distinct, tightly-sculpted stubby rounded gel flippers/nubs (like Ponyo/concept sheet, NOT a flat bar!)
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

	// Gentle inertial centroid follow-through
	vec2 centroid = (lobe_0.xy + lobe_1.xy + lobe_2.xy + lobe_3.xy + lobe_4.xy) * 0.2;
	pos.xy += centroid * 0.14;

	// Smooth viewport-safe outer reach guard
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

	// Tiny 0.5% inset so inner volumetric back-wall aligns seamlessly with outer glossy clearcoat shell
	VERTEX = p0 * 0.995;
	NORMAL = n_new;
	v_local_pos = p0;
}

void fragment() {
	vec3 V = normalize(VIEW);
	vec3 N = normalize(NORMAL);
	if (dot(N, V) < 0.0) {
		N = -N;
	}
	float NdotV = clamp(dot(N, V), 0.0, 1.0);
	float edge_thick = pow(max(1.0 - NdotV, 0.0), 1.35);
	float deep_rim = pow(max(1.0 - NdotV, 0.0), 2.15);

	// Studio Ghibli volumetric lighting gradient inside Charlie's translucent body:
	// Sunlit upper-left warm apricot -> juicy molten tangerine core -> deep rich sunset coral underside & tail!
	vec3 L_key = normalize(vec3(-0.45, 0.72, 0.52));
	float wrap_lit = clamp((dot(-N, L_key) + 0.65) / 1.65, 0.0, 1.0);

	vec3 deep_vermilion = mix(sig_deep_rim.rgb, edge_color.rgb * vec3(0.86, 0.65, 0.55), 0.14);
	vec3 sunset_coral = mix(sig_coral_wall.rgb, edge_color.rgb, 0.18);
	vec3 tangerine_mid = mix(sig_honey_mid.rgb, core_color.rgb, 0.18);
	vec3 honey_core = mix(sig_honey_core.rgb, core_color.rgb * vec3(1.04, 1.00, 0.92), 0.16);

	// Core-to-wall optical Beer-Lambert thickness color ramp
	float belly_y = 1.0 - smoothstep(-0.35, 0.60, v_local_pos.y);
	float center_clarity = smoothstep(0.12, 0.84, NdotV);
	vec3 interior_col = mix(sunset_coral, tangerine_mid, clamp(center_clarity * 0.78 + wrap_lit * 0.16, 0.0, 1.0));
	// Warm luminous golden-honey subsurface belly glow right where the 3 pearls float!
	interior_col = mix(interior_col, honey_core, pow(max(NdotV, 0.0), 1.55) * (0.28 + 0.36 * belly_y));

	// Deepen thick optical walls, underside & sweeping tail to rich translucent coral-vermilion
	float tail_dist = smoothstep(0.82, 1.35, length(v_local_pos));
	interior_col = mix(interior_col, sunset_coral, clamp(smoothstep(0.22, 0.72, edge_thick) * 0.65 + tail_dist * 0.35, 0.0, 0.85));
	interior_col = mix(interior_col, deep_vermilion, clamp(smoothstep(0.42, 0.92, deep_rim) * 0.62 + (1.0 - wrap_lit) * 0.24, 0.0, 0.72));

	// Warm lower-right subsurface caustic pocket (just like concept_charlie_slime_sheet.jpg!)
	vec3 L_sub = normalize(vec3(0.42, -0.58, 0.69));
	float sub_caustic = pow(max(dot(N, L_sub), 0.0), 2.4) * (1.0 - deep_rim * 0.55);
	interior_col = mix(interior_col, honey_core * vec3(1.02, 0.96, 0.86), sub_caustic * 0.34);

	// Jewel-like flavor tint wash inside Charlie's belly when digesting prey
	float belly_zone = (1.0 - smoothstep(0.18, 0.78, edge_thick)) * (1.0 - smoothstep(0.08, 0.68, v_local_pos.y));
	float flavor_amt = clamp(flavor_tint.a, 0.0, 1.0) * belly_zone;
	vec3 vivid_flavor = clamp(mix(flavor_tint.rgb, flavor_tint.rgb * 1.15, 0.50), vec3(0.0), vec3(1.0));
	interior_col = mix(interior_col, vivid_flavor, flavor_amt * 0.58);

	// Vitality 0: delicate opalescent frost-peach glass
	float vit = clamp(vitality_ratio, 0.0, 1.0);
	vec3 frost_core = vec3(0.92, 0.80, 0.74);
	vec3 frost_rim = vec3(0.76, 0.60, 0.55);
	vec3 frost_col = mix(frost_core, frost_rim, edge_thick * 0.75);
	interior_col = mix(frost_col, interior_col, smoothstep(0.0, 0.92, vit));

	ALBEDO = clamp(interior_col, vec3(0.0), vec3(1.0));
}
