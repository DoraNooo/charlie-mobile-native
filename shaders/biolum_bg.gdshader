shader_type canvas_item;

// Bioluminescent 6-scale atmospheric backdrop (Ori x Ghibli aesthetic, crisp native res, 60-120 FPS mobile)
// Supports HDR peaks (1.18-1.45) for WorldEnvironment AgX Bloom + OLED triangular dithering.
uniform vec4 bg_inner : source_color = vec4(0.055, 0.153, 0.200, 1.0);
uniform vec4 bg_outer : source_color = vec4(0.024, 0.067, 0.098, 1.0);
uniform vec4 mote_color : source_color = vec4(0.431, 0.906, 0.855, 1.0);
uniform vec4 accent : source_color = vec4(0.431, 0.906, 0.855, 1.0);
uniform vec2 cam_offset = vec2(0.0, 0.0);
uniform float time_sec = 0.0;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform float scale_progress = 0.0;

// Fast 2-instruction mobile-friendly hash
vec2 hash22(vec2 p) {
	vec2 q = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(q) * 43758.5453);
}

// Organic rotated & domain-jittered parallax star/mote layer (zero polka-dot grid artifacts).
// Returns vec3(soft_halo, crisp_core, hdr_glint_sparkle).
vec3 organic_mote_layer(
	vec2 uv_asp,
	vec2 parallax_shift,
	mat2 rot_m,
	float density,
	float t,
	float speed,
	float threshold,
	float halo_r,
	float core_r,
	float seed,
	float glint_chance
) {
	vec2 warped = rot_m * (uv_asp + parallax_shift);
	vec2 grid = warped * density;
	vec2 id = floor(grid);
	vec2 gv = fract(grid) - vec2(0.5);

	vec2 rnd_a = hash22(id + vec2(seed, seed * 1.73));
	vec2 rnd_b = hash22(id * 1.37 + vec2(seed * 2.11 + 19.7, seed * 0.63 + 41.3));
	float active = step(threshold, rnd_a.x);

	// Power-law size variance: many crisp pinpoints, rare luminous jewels
	float size_var = mix(0.42, 1.38, rnd_b.x * rnd_b.x);
	float r_halo = min(halo_r * size_var, 0.24);
	float r_core = min(core_r * size_var, r_halo * 0.52);

	// Wide static per-cell jitter + gentle organic drift, strictly bounded inside cell
	float max_off = max(0.03, 0.46 - r_halo);
	vec2 base_off = (rnd_b - vec2(0.5)) * (max_off * 1.42);
	vec2 drift = vec2(
		sin(rnd_a.x * 6.28318 + t * speed * (0.55 + rnd_a.y * 0.65)),
		cos(rnd_a.y * 6.28318 + t * speed * (0.48 + rnd_b.y * 0.62))
	) * (max_off * 0.28);
	vec2 pos = clamp(base_off + drift, vec2(-max_off), vec2(max_off));

	vec2 delta = gv - pos;
	float dist = length(delta);

	float twinkle = 0.50 + 0.50 * sin(t * (0.95 + rnd_a.y * 1.95) + rnd_b.y * 25.13);
	float bright_var = mix(0.54, 1.28, rnd_b.y);

	float halo = (1.0 - smoothstep(r_core * 0.45, r_halo, dist)) * (0.62 + 0.38 * twinkle) * bright_var * active;
	float core = (1.0 - smoothstep(r_core * 0.08, r_core, dist)) * (0.64 + 0.36 * twinkle) * bright_var * active;

	// Crisp 4-point diamond star glint on rarest bright stars
	float glint_on = step(1.0 - glint_chance, rnd_a.y) * active;
	float g_len = max(r_halo * 1.22, 0.035);
	float g_w = max(0.0028, r_core * 0.40);
	vec2 ad = abs(delta);
	float tx = clamp(ad.x / g_len, 0.0, 1.0);
	float ty = clamp(ad.y / g_len, 0.0, 1.0);
	float wh = mix(g_w, g_w * 0.16, tx);
	float wv = mix(g_w, g_w * 0.16, ty);
	float ray_h = (1.0 - smoothstep(wh * 0.12, wh, ad.y)) * (1.0 - smoothstep(0.0, 1.0, tx));
	float ray_v = (1.0 - smoothstep(wv * 0.12, wv, ad.x)) * (1.0 - smoothstep(0.0, 1.0, ty));
	float rays = max(ray_h, ray_v);
	float sparkle = (core * 0.72 + rays * 0.56) * (0.58 + 0.42 * twinkle) * glint_on;

	return vec3(halo, core, sparkle);
}

// Organic rotated rising bubble layer for Scale 1 (Microscopique)
vec3 micro_bubble_layer(vec2 uv_asp, vec2 shift, mat2 rot_m, float density, float t, float seed) {
	vec2 grid = rot_m * (uv_asp + shift) * density;
	vec2 id = floor(grid);
	vec2 gv = fract(grid) - vec2(0.5);

	vec2 rnd_a = hash22(id + vec2(seed, seed * 1.41));
	vec2 rnd_b = hash22(id * 1.29 + vec2(seed * 0.83 + 27.4, seed * 1.91 + 11.2));
	float on = step(0.54, rnd_a.x);

	float rad = mix(0.048, 0.135, rnd_b.x * rnd_b.x);
	float max_off = max(0.04, 0.46 - rad * 1.18);
	vec2 off = clamp(
		(rnd_b - vec2(0.5)) * (max_off * 1.45) + vec2(sin(t * (0.52 + rnd_a.y * 0.4) + rnd_a.x * 6.28318) * 0.08, 0.0),
		vec2(-max_off),
		vec2(max_off)
	);

	vec2 delta = gv - off;
	float d = length(delta);

	// Crisp thin translucent meniscus rim + delicate interior fill + top-left wet specular pinpoint
	float rim = smoothstep(rad * 0.72, rad * 0.95, d) * (1.0 - smoothstep(rad * 0.95, rad * 1.12, d));
	float fill = (1.0 - smoothstep(0.0, rad * 0.98, d)) * 0.22;
	// Key light comes from top-left (-0.52, -0.62)
	float spec = 1.0 - smoothstep(0.002, max(0.008, rad * 0.30), length(delta + vec2(rad * 0.34, rad * 0.36)));
	return vec3(rim * 0.34 + fill, spec * 0.42, spec * 0.22) * on;
}

// Organic rotated pulsing firefly layer for Scale 2 (Sous-Bois)
// Returns vec3(r, g, b) additive firefly radiance with subtle HDR core peak
vec3 forest_firefly_layer(vec2 uv_asp, vec2 shift, mat2 rot_m, float density, float t, float seed) {
	vec2 grid = rot_m * (uv_asp + shift) * density;
	vec2 id = floor(grid);
	vec2 gv = fract(grid) - vec2(0.5);

	vec2 rnd_a = hash22(id + vec2(seed, seed * 1.57));
	vec2 rnd_b = hash22(id * 1.43 + vec2(seed * 1.71 + 13.5, seed * 0.91 + 37.9));
	float on = step(0.48, rnd_a.x);

	float size_s = mix(0.58, 1.28, rnd_b.x);
	float max_off = 0.26;
	vec2 off = clamp(
		(rnd_b - vec2(0.5)) * 0.36 + vec2(
			sin(t * (0.38 + rnd_a.y * 0.28) + rnd_a.x * 6.28318),
			cos(t * (0.32 + rnd_b.y * 0.26) + rnd_b.x * 6.28318)
		) * 0.12,
		vec2(-max_off),
		vec2(max_off)
	);

	float d = length(gv - off);
	float pulse_raw = 0.5 + 0.5 * sin(t * (1.25 + rnd_a.y * 1.45) + rnd_b.y * 18.84);
	float pulse = pulse_raw * pulse_raw * (0.35 + 0.65 * pulse_raw);

	float r_halo = 0.175 * size_s;
	float r_core = 0.040 * size_s;
	float halo = (1.0 - smoothstep(r_core * 0.45, r_halo, d)) * 0.44;
	float core = (1.0 - smoothstep(r_core * 0.10, r_core, d)) * 1.18;

	vec3 warm_col = mix(vec3(1.0, 0.84, 0.28), vec3(0.36, 0.98, 0.58), step(0.74, rnd_b.y));
	vec3 heart_col = mix(warm_col, vec3(1.0, 0.98, 0.82), 0.65);
	return (warm_col * halo + heart_col * core) * pulse * 0.52 * on;
}

// Organic rotated creamy bokeh orb layer for Scale 3 (Ville Endormie)
vec3 city_bokeh_layer(vec2 uv_asp, vec2 shift, mat2 rot_m, float density, float t, float seed, float vertical_mask) {
	vec2 grid = rot_m * (uv_asp + shift) * density;
	vec2 id = floor(grid);
	vec2 gv = fract(grid) - vec2(0.5);

	vec2 rnd_a = hash22(id + vec2(seed, seed * 1.63));
	vec2 rnd_b = hash22(id * 1.31 + vec2(seed * 2.07 + 7.1, seed * 0.77 + 53.3));
	float on = step(0.46, rnd_a.x) * vertical_mask;

	float rad = mix(0.048, 0.142, rnd_b.x * rnd_b.x);
	float max_off = max(0.03, 0.45 - rad * 1.15);
	vec2 off = clamp((rnd_b - vec2(0.5)) * (max_off * 1.65), vec2(-max_off), vec2(max_off));

	float d = length(gv - off);
	// True optical bokeh: soft creamy disc + subtle luminous cat's-eye aperture rim
	float disc = (1.0 - smoothstep(rad * 0.52, rad * 1.02, d)) * 0.68;
	float rim = smoothstep(rad * 0.64, rad * 0.88, d) * (1.0 - smoothstep(rad * 0.88, rad * 1.10, d)) * 0.46;
	float heart = (1.0 - smoothstep(0.0, rad * 0.46, d)) * 0.34;
	float twinkle = 0.70 + 0.30 * sin(t * (0.78 + rnd_a.y * 1.35) + rnd_b.y * 12.56);

	vec3 warm_amber = mix(vec3(1.0, 0.66, 0.24), vec3(1.0, 0.84, 0.42), rnd_a.y);
	vec3 cool_twilight = vec3(0.42, 0.80, 1.0);
	vec3 tint = mix(warm_amber, cool_twilight, step(0.68, rnd_b.y));
	return tint * (disc + rim + heart * 1.25) * twinkle * 0.28 * on;
}

// Analytical crisp orbital ellipse arc on pre-rotated coordinates for Scale 4 (Planetaire)
float orbit_arc_rot(vec2 rp, vec2 radii, float thickness) {
	float len_q = length(rp / radii);
	float dist = abs(len_q - 1.0) * min(radii.x, radii.y);
	return 1.0 - smoothstep(thickness * 0.14, thickness, dist);
}

// Distant Solitary Golden Star shining subtly in the upper-right/center sky across ALL 6 worlds
// Connects Charlie's entire journey from Quantum to Cosmic with a warm honey-gold HDR diamond glint.
vec3 distant_golden_star(vec2 p, vec2 star_pos, float t, float sp) {
	float star_t = clamp(sp * 0.2, 0.0, 1.0);
	float prog = smoothstep(0.0, 1.0, star_t);
	float prominence = mix(0.54, 0.82, prog);
	float s = mix(0.68, 1.02, prog);
	float breath = 0.92 + 0.08 * sin(t * 1.42) + 0.03 * sin(t * 3.08 + 0.75);

	vec2 d_vec = p - star_pos;
	float d = length(d_vec);
	if (d > 0.26 * s) {
		return vec3(0.0);
	}

	// Clean, tight golden aura + focused honey corona + jewel-crisp HDR pinpoint heart (no blown-out wash)
	float aura = 1.0 - smoothstep(0.006 * s, 0.145 * s, d);
	aura = aura * aura * 0.14;
	float corona = 1.0 - smoothstep(0.0025 * s, 0.036 * s, d);
	corona = corona * corona * 0.26;
	float core = 1.0 - smoothstep(0.0010 * s, 0.0090 * s, d);

	// Tapered 4-point cardinal diamond star glint (sharp pointed tips, clean intersection)
	vec2 ad = abs(d_vec);
	float len_h = 0.070 * s * breath;
	float len_v = 0.084 * s * breath;
	float tx = clamp(ad.x / max(len_h, 0.001), 0.0, 1.0);
	float ty = clamp(ad.y / max(len_v, 0.001), 0.0, 1.0);
	float wh = mix(0.0044 * s, 0.00050 * s, smoothstep(0.0, 1.0, tx));
	float wv = mix(0.0044 * s, 0.00050 * s, smoothstep(0.0, 1.0, ty));
	float ray_h = (1.0 - smoothstep(wh * 0.12, wh, ad.y)) * (1.0 - smoothstep(0.0, 1.0, tx));
	float ray_v = (1.0 - smoothstep(wv * 0.12, wv, ad.x)) * (1.0 - smoothstep(0.0, 1.0, ty));
	float main_rays = max(ray_h, ray_v);

	// Subtle 45-degree secondary diamond micro-glint
	vec2 d45 = abs(vec2(d_vec.x + d_vec.y, d_vec.y - d_vec.x) * 0.70710678);
	float len_d = 0.028 * s * breath;
	float t45x = clamp(d45.x / max(len_d, 0.001), 0.0, 1.0);
	float t45y = clamp(d45.y / max(len_d, 0.001), 0.0, 1.0);
	float wd = mix(0.0026 * s, 0.00038 * s, smoothstep(0.0, 1.0, t45x));
	float wd2 = mix(0.0026 * s, 0.00038 * s, smoothstep(0.0, 1.0, t45y));
	float ray_d = max(
		(1.0 - smoothstep(wd * 0.15, wd, d45.y)) * (1.0 - smoothstep(0.0, 1.0, t45x)),
		(1.0 - smoothstep(wd2 * 0.15, wd2, d45.x)) * (1.0 - smoothstep(0.0, 1.0, t45y))
	);
	float diamond = max(main_rays, ray_d * 0.42);

	vec3 aura_col = vec3(1.0, 0.64, 0.20);
	vec3 glint_col = vec3(1.0, 0.85, 0.44);
	// Warm honey-gold HDR core growing cleanly into a tight jewel beacon without washing the sky white
	vec3 core_col = vec3(1.0, 0.93, 0.70) * mix(0.52, 0.64, prog);

	vec3 star_rgb = aura_col * aura
		+ glint_col * (corona + diamond * 0.36)
		+ core_col * core;

	return star_rgb * prominence * breath;
}

void fragment() {
	float t = (time_sec > 0.0) ? time_sec : TIME;
	float aspect = viewport_size.x / max(viewport_size.y, 1.0);

	vec2 uv = UV;
	// Aspect-corrected centered coordinates: circles stay 100% circular on 20:9 screens
	vec2 p = (uv - vec2(0.5)) * vec2(aspect, 1.0);
	vec2 uv_asp = uv * vec2(aspect, 1.0);
	vec2 cam_norm = cam_offset * 0.00055;

	// Deep painterly radial backdrop with rich contrast + gentle top-left key-light lift (-0.52, -0.62)
	vec2 bg_center = vec2(-0.08, -0.07) + vec2(sin(t * 0.16) * 0.035, cos(t * 0.13) * 0.025);
	vec2 bg_v = (p - bg_center) * vec2(0.84, 1.06);
	float bg_d2 = dot(bg_v, bg_v);
	float velvet_wave = sin(p.x * 2.4 + t * 0.11) * cos(p.y * 2.8 - t * 0.09) * 0.032;
	vec3 col = mix(bg_inner.rgb * 0.96, bg_outer.rgb * 0.66, smoothstep(0.02, 0.84, bg_d2 + velvet_wave));
	// Subtle directional heavenly glow from upper-left key light without lifting dark contrast
	vec2 key_v = (p - vec2(-0.42 * min(aspect * 0.65, 1.0), -0.40)) * vec2(0.72, 0.94);
	float key_lift = 1.0 - smoothstep(0.02, 1.12, dot(key_v, key_v));
	col += mix(accent.rgb, bg_inner.rgb * 1.45, 0.62) * key_lift * 0.068;

	vec3 primary_mote = mix(mote_color.rgb, accent.rgb, 0.24);

	// -------------------------------------------------------------------------
	// 6 signature per-scale atmospheres smoothly crossfaded in sync with Scales
	// -------------------------------------------------------------------------
	float sp = clamp(scale_progress, 0.0, 5.0);
	float idx_f = floor(min(sp, 4.9999));
	float frac = sp - idx_f;
	float blend = smoothstep(0.62, 1.0, frac);
	int idx = int(idx_f);

	float w0 = (idx == 0) ? (1.0 - blend) : 0.0;
	float w1 = (idx == 0) ? blend : ((idx == 1) ? (1.0 - blend) : 0.0);
	float w2 = (idx == 1) ? blend : ((idx == 2) ? (1.0 - blend) : 0.0);
	float w3 = (idx == 2) ? blend : ((idx == 3) ? (1.0 - blend) : 0.0);
	float w4 = (idx == 3) ? blend : ((idx == 4) ? (1.0 - blend) : 0.0);
	float w5 = (idx == 4) ? blend : 0.0;

	// Non-orthogonal rotation matrices to break all grid alignment across layers
	const mat2 ROT_A = mat2(vec2(0.9455, 0.3256), vec2(-0.3256, 0.9455));  // +19 deg
	const mat2 ROT_B = mat2(vec2(0.8572, -0.5150), vec2(0.5150, 0.8572));  // -31 deg
	const mat2 ROT_C = mat2(vec2(0.9816, 0.1908), vec2(-0.1908, 0.9816));  // +11 deg
	const mat2 ROT_D = mat2(vec2(0.9135, -0.4067), vec2(0.4067, 0.9135));  // -24 deg

	// Scale 0 (Quantique): luminous cyan/gold quantum probability haze + fine interference ripples
	if (w0 > 0.001) {
		vec2 qp = p + cam_norm * 0.07;
		vec2 q1 = (qp - vec2(sin(t * 0.19) * 0.38 - 0.32, cos(t * 0.16) * 0.20 - 0.10)) * vec2(0.84, 1.14);
		vec2 q2 = (qp - vec2(cos(t * 0.17) * 0.42 + 0.34, sin(t * 0.21) * 0.22 + 0.14)) * vec2(0.88, 1.08);
		float h1 = 1.0 - smoothstep(0.01, 0.56, dot(q1, q1));
		float h2 = 1.0 - smoothstep(0.01, 0.50, dot(q2, q2));
		// Delicate standing probability-wave interference shimmer
		float ripple_a = sin(length(q1) * 26.0 - t * 1.45);
		float ripple_b = sin(length(q2) * 22.0 + t * 1.20);
		float interf = smoothstep(0.55, 0.98, 0.5 + 0.25 * (ripple_a + ripple_b));
		vec3 q_haze = vec3(0.16, 0.90, 0.98) * (h1 * h1 * 0.24 + interf * h1 * 0.08)
			+ vec3(1.00, 0.82, 0.38) * (h2 * h2 * 0.20 + interf * h2 * 0.06);
		col += q_haze * w0;
	}

	// Scale 1 (Microscopique): razor-sharp underwater caustic network + organic crystal bubbles
	if (w1 > 0.001) {
		vec2 cp = p + cam_norm * 0.11;
		vec2 cw = cp + vec2(sin(cp.y * 4.2 + t * 0.52), cos(cp.x * 3.8 - t * 0.46)) * 0.082;
		float wa = sin(cw.x * 7.0 + cw.y * 3.1 + t * 0.92);
		float wb = sin(cw.x * -4.2 + cw.y * 6.3 - t * 0.76);
		float wc = sin(cw.x * 2.8 - cw.y * 5.5 + t * 0.64);
		float r1 = clamp(1.0 - abs(wa + wb) * 0.5, 0.0, 1.0);
		float r2 = clamp(1.0 - abs(wb - wc) * 0.5, 0.0, 1.0);
		float r1_2 = r1 * r1;
		float r2_2 = r2 * r2;
		float caustic_net = r1_2 * r1_2 * r1 * 0.72 + r2_2 * r2_2 * r2_2 * 0.52;
		float top_fade = 1.0 - smoothstep(0.06, 0.90, uv.y);
		float left_bias = 0.72 + 0.28 * (1.0 - smoothstep(0.0, 1.0, uv.x));
		col += vec3(0.24, 0.88, 0.78) * caustic_net * (0.045 + 0.13 * top_fade) * left_bias * w1;

		// Dual rotated organic bubble layers (zero grid alignment)
		vec2 b_shift_a = vec2(cam_norm.x * 0.48, cam_norm.y * 0.48 + t * 0.095);
		vec2 b_shift_b = vec2(cam_norm.x * 0.72, cam_norm.y * 0.72 + t * 0.135);
		vec3 bub_a = micro_bubble_layer(uv_asp, b_shift_a, ROT_C, 4.9, t, 31.7);
		vec3 bub_b = micro_bubble_layer(uv_asp, b_shift_b, ROT_D, 3.2, t, 67.3);
		vec3 bub = bub_a + bub_b * 0.85;
		col += (vec3(0.48, 0.92, 0.86) * bub.x * 0.58 + vec3(0.85, 0.96, 0.95) * bub.y * 0.65) * w1;
	}

	// Scale 2 (Sous-Bois): lush misty emerald clearing + organic pulsing HDR-tipped fireflies
	if (w2 > 0.001) {
		float edge_d = length(p * vec2(0.70, 1.04));
		float canopy_wave = sin(p.x * 4.2 + t * 0.18) * cos(p.y * 4.4 - t * 0.12) * 0.055;
		float vignette = smoothstep(0.46 + canopy_wave, 1.05 + canopy_wave, edge_d);
		// Luminous mossy emerald-jade heart in the upper-center clearing
		float clearing = 1.0 - smoothstep(0.02, 0.62, length((p - vec2(-0.04, -0.06)) * vec2(0.85, 1.05)));
		col += vec3(0.05, 0.19, 0.12) * clearing * clearing * 0.34 * w2;
		col = mix(col, col * vec3(0.40, 0.72, 0.52) + vec3(0.006, 0.036, 0.024), vignette * 0.68 * w2);

		// Dual rotated organic firefly bokeh fields with HDR golden heart shimmer
		vec3 ff_a = forest_firefly_layer(uv_asp, cam_norm * 0.56, ROT_A, 4.3, t, 71.2);
		vec3 ff_b = forest_firefly_layer(uv_asp, cam_norm * 0.82, ROT_B, 2.8, t, 19.8);
		col += (ff_a + ff_b * 0.90) * w2;
	}

	// Scale 3 (Ville Endormie): warm Ghibli amber twilight horizon + dual organic city bokeh
	if (w3 > 0.001) {
		float horizon = smoothstep(0.30, 1.02, uv.y);
		float center_lift = 1.0 - smoothstep(0.08, 1.18, abs(p.x));
		col += vec3(1.0, 0.50, 0.18) * (horizon * horizon * (0.18 + 0.12 * center_lift)) * w3;

		float city_mask = smoothstep(0.24, 0.74, uv.y);
		vec3 bk_a = city_bokeh_layer(uv_asp, vec2(cam_norm.x * 0.38 + t * 0.010, cam_norm.y * 0.30), ROT_C, 5.4, t, 53.1, city_mask);
		vec3 bk_b = city_bokeh_layer(uv_asp, vec2(cam_norm.x * 0.58 - t * 0.008, cam_norm.y * 0.44), ROT_D, 3.4, t, 89.4, city_mask);
		col += (bk_a + bk_b * 0.82) * w3;
	}

	// Scale 4 (Planetaire): atmospheric lower cerulean glow + razor-sharp orbital hairlines
	if (w4 > 0.001) {
		// Soft orbital twilight horizon aura harmonizing with MidgroundLayer's Earth limb
		float limb_glow = smoothstep(0.48, 1.04, uv.y) * (1.0 - smoothstep(0.10, 1.15, abs(p.x)));
		col += vec3(0.16, 0.54, 0.96) * (limb_glow * limb_glow * 0.22) * w4;

		vec2 op = p + cam_norm * 0.045;
		// Precomputed cos(0.32) = 0.94924, sin(0.32) = 0.31457
		vec2 rp = vec2(0.94924 * op.x - 0.31457 * op.y, 0.31457 * op.x + 0.94924 * op.y);
		float o1 = orbit_arc_rot(rp, vec2(0.46, 0.20), 0.0030);
		float o2 = orbit_arc_rot(rp, vec2(0.75, 0.33), 0.0033);
		float o3 = orbit_arc_rot(rp, vec2(1.06, 0.47), 0.0036);
		vec3 orb_col = vec3(0.58, 0.90, 1.0) * (o1 * 0.20 + o2 * 0.15 + o3 * 0.11);
		col += orb_col * w4;
	}

	// Scale 5 (Cosmique): deep velvety domain-warped rose/cyan/gold galactic nebula veils
	if (w5 > 0.001) {
		vec2 np_base = p + cam_norm * 0.045;
		// Silky organic domain warp for flowing galactic dust clouds
		vec2 warp = vec2(
			sin(np_base.y * 3.1 + t * 0.085) * 0.14 + cos(np_base.x * 2.2 - t * 0.065) * 0.07,
			cos(np_base.x * 2.7 - t * 0.075) * 0.12 + sin(np_base.y * 2.4 + t * 0.095) * 0.06
		);
		vec2 np = np_base + warp;

		// Diagonal galactic sweep band (lower-left -> upper-right)
		float diag = np.x * 0.52 + np.y * 0.85;
		float band = 1.0 - smoothstep(0.02, 0.52, abs(diag - 0.04 * sin(np.x * 3.5 + t * 0.08)));
		float band_fine = 0.5 + 0.5 * sin(np.x * 5.2 - np.y * 3.8 + t * 0.12);

		vec2 n1 = (np - vec2(-0.36, -0.10)) * vec2(0.76, 1.12);
		vec2 n2 = (np - vec2(0.34, 0.16)) * vec2(0.82, 1.08);
		vec2 n3 = (np - vec2(-0.04, 0.22)) * vec2(0.90, 1.06);
		float nb1 = 1.0 - smoothstep(0.01, 0.62, dot(n1, n1));
		float nb2 = 1.0 - smoothstep(0.01, 0.64, dot(n2, n2));
		float nb3 = 1.0 - smoothstep(0.01, 0.46, dot(n3, n3));

		vec3 neb = vec3(0.96, 0.30, 0.68) * (nb1 * nb1 * 0.19 + band * band_fine * 0.085)
			+ vec3(0.18, 0.80, 0.96) * (nb2 * nb2 * 0.18 + band * (1.0 - band_fine) * 0.085)
			+ vec3(0.98, 0.76, 0.30) * (nb3 * nb3 * 0.14 + band * band * 0.05);
		col += neb * w5;
	}

	// -------------------------------------------------------------------------
	// 3 non-orthogonal organic parallax star & bokeh layers (zero grid regularity)
	// -------------------------------------------------------------------------
	float star_boost = w3 * 0.20 + w4 * 0.48 + w5 * 0.68;
	float glint_rate = mix(0.08, 0.30, clamp(w4 * 0.7 + w5, 0.0, 1.0));

	// Plane 1: Razor-sharp distant pinpoint starfield (+19 deg)
	vec3 m_stars = organic_mote_layer(uv_asp, cam_norm * 0.14, ROT_A, 14.5, t, 0.14, 0.50, 0.095, 0.024, 3.1, glint_rate);
	// Plane 2: Mid bioluminescent drifting motes (-31 deg)
	vec3 m_mid = organic_mote_layer(uv_asp, cam_norm * 0.42, ROT_B, 8.2, t, 0.26, 0.52, 0.145, 0.036, 19.3, glint_rate * 0.55);
	// Plane 3: Near creamy bokeh motes (+11 deg)
	vec3 m_near = organic_mote_layer(uv_asp, cam_norm * 0.86, ROT_C, 4.4, t, 0.38, 0.56, 0.215, 0.048, 43.7, 0.0);

	vec3 mote_tint = mix(primary_mote, vec3(0.84, 0.94, 1.0), w4 * 0.65);
	mote_tint = mix(mote_tint, vec3(1.0, 0.90, 0.62), w5 * 0.62);
	vec3 core_tint = mix(mote_tint, vec3(1.0, 0.985, 0.94), 0.62 + (w4 + w5) * 0.24);

	float total_halo = m_stars.x * (0.09 + star_boost * 0.14)
		+ m_mid.x * (0.14 + star_boost * 0.10)
		+ m_near.x * (0.19 + w2 * 0.07 + w5 * 0.08);
	float total_core = m_stars.y * (0.22 + star_boost * 0.38)
		+ m_mid.y * (0.24 + star_boost * 0.20)
		+ m_near.y * (0.26 + w2 * 0.12 + w5 * 0.14);
	// Crisp selective shimmer on bright cosmic/night diamond stars without blinding wash
	float total_glint = (m_stars.z * (0.24 + star_boost * 0.46) + m_mid.z * (0.16 + star_boost * 0.28));

	col += mote_tint * total_halo
		+ core_tint * total_core
		+ vec3(1.0, 0.96, 0.86) * total_glint * 1.04;

	// -------------------------------------------------------------------------
	// The Distant Solitary Golden Star (all 6 worlds, grows in prominence 0 -> 5)
	// -------------------------------------------------------------------------
	vec2 golden_star_pos = vec2(min(0.33, aspect * 0.25), -0.29) - cam_norm * 0.010;
	col += distant_golden_star(p, golden_star_pos, t, sp);

	// Subtle outer radial contrast framing so Charlie and glowing creatures pop cleanly
	float outer_vig = smoothstep(0.58, 1.38, dot(p * vec2(0.76, 1.02), p * vec2(0.76, 1.02)));
	col *= mix(1.0, 0.84, outer_vig);

	// Subtle triangular hash dithering (+/-0.5 / 255.0) to eliminate 8-bit OLED banding
	// Upper clamp preserves delicate HDR sparkle peaks (up to 1.36) for WorldEnvironment AgX Bloom
	vec2 d = hash22(FRAGCOORD.xy);
	float dither = (d.x + d.y - 1.0) * (0.5 / 255.0);
	col = clamp(col + vec3(dither), vec3(0.0), vec3(1.36));

	COLOR = vec4(col, 1.0);
}
