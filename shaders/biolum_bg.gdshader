shader_type canvas_item;

// Bioluminescent 6-scale atmospheric backdrop (Kurzgesagt / Ori aesthetic, 120 FPS mobile GPU)
uniform vec4 bg_inner : source_color = vec4(0.055, 0.153, 0.200, 1.0);
uniform vec4 bg_outer : source_color = vec4(0.024, 0.067, 0.098, 1.0);
uniform vec4 mote_color : source_color = vec4(0.431, 0.906, 0.855, 1.0);
uniform vec4 accent : source_color = vec4(0.431, 0.906, 0.855, 1.0);
uniform vec2 cam_offset = vec2(0.0, 0.0);
uniform float time_sec = 0.0;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform float scale_progress = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

vec2 hash22(vec2 p) {
	float n = hash21(p);
	return vec2(n, hash21(p + vec2(17.31, 41.73)));
}

// Single-cell parallax glowing mote layer: returns vec2(soft_halo, bright_core)
vec2 mote_layer(
	vec2 uv_asp,
	vec2 parallax_shift,
	float density,
	float t,
	float speed,
	float threshold,
	float halo_r,
	float core_r,
	float seed
) {
	vec2 grid = uv_asp * density + parallax_shift;
	vec2 id = floor(grid);
	vec2 gv = fract(grid) - vec2(0.5);
	vec2 rnd = hash22(id + vec2(seed, seed * 1.73));
	float active = step(threshold, rnd.x);
	vec2 drift = vec2(
		sin(rnd.x * 6.2831 + t * speed * (0.65 + rnd.y * 0.5)),
		cos(rnd.y * 6.2831 + t * speed * (0.55 + rnd.x * 0.5))
	) * 0.28;
	float dist = length(gv - drift);
	float twinkle = 0.48 + 0.52 * sin(t * (1.1 + rnd.y * 1.9) + rnd.x * 18.84);
	float halo = (1.0 - smoothstep(core_r * 0.6, halo_r, dist)) * twinkle * active;
	float core = (1.0 - smoothstep(core_r * 0.18, core_r, dist)) * (0.65 + 0.35 * twinkle) * active;
	return vec2(halo, core);
}

// Analytical tilted orbital ellipse arc for Scale 4 (Planetary)
float orbit_arc(vec2 p, vec2 radii, float tilt, float thickness) {
	float c = cos(tilt);
	float s = sin(tilt);
	vec2 rp = vec2(c * p.x - s * p.y, s * p.x + c * p.y);
	vec2 q = rp / radii;
	float len_q = length(q);
	// Approximate Euclidean distance to ellipse boundary
	float dist = abs(len_q - 1.0) * min(radii.x, radii.y);
	return 1.0 - smoothstep(thickness * 0.25, thickness, dist);
}

void fragment() {
	float t = (time_sec > 0.0) ? time_sec : TIME;
	float aspect = viewport_size.x / max(viewport_size.y, 1.0);

	vec2 uv = UV;
	// Aspect-corrected centered coordinates: circles stay 100% circular on 20:9 screens
	vec2 p = (uv - vec2(0.5)) * vec2(aspect, 1.0);
	vec2 uv_asp = uv * vec2(aspect, 1.0);
	vec2 cam_norm = cam_offset * 0.00055;

	// Base bioluminescent radial gradient with gentle organic breathing
	vec2 bg_center = vec2(0.0, -0.04) + vec2(sin(t * 0.18) * 0.04, cos(t * 0.14) * 0.03);
	float bg_d = length((p - bg_center) * vec2(0.88, 1.08));
	vec3 col = mix(bg_inner.rgb, bg_outer.rgb, smoothstep(0.04, 0.92, bg_d));

	// Blend mote_color with accent subtly so both uniforms contribute harmoniously
	vec3 primary_mote = mix(mote_color.rgb, accent.rgb, 0.22);

	// -------------------------------------------------------------------------
	// 6 signature per-scale atmospheres smoothly crossfaded via scale_progress
	// -------------------------------------------------------------------------
	float sp = clamp(scale_progress, 0.0, 5.0);
	float w0 = 1.0 - smoothstep(0.0, 1.0, abs(sp - 0.0));
	float w1 = 1.0 - smoothstep(0.0, 1.0, abs(sp - 1.0));
	float w2 = 1.0 - smoothstep(0.0, 1.0, abs(sp - 2.0));
	float w3 = 1.0 - smoothstep(0.0, 1.0, abs(sp - 3.0));
	float w4 = 1.0 - smoothstep(0.0, 1.0, abs(sp - 4.0));
	float w5 = 1.0 - smoothstep(0.0, 1.0, abs(sp - 5.0));

	// Scale 0 (Quantum): drifting cyan/gold bioluminescent quantum haze clouds
	if (w0 > 0.001) {
		vec2 q1 = p - vec2(sin(t * 0.21) * 0.42 - 0.34, cos(t * 0.17) * 0.22 - 0.12) + cam_norm * 0.08;
		vec2 q2 = p - vec2(cos(t * 0.19) * 0.46 + 0.36, sin(t * 0.23) * 0.24 + 0.14) + cam_norm * 0.06;
		vec2 q3 = p - vec2(sin(t * 0.13 + 2.1) * 0.28, cos(t * 0.16 + 1.4) * 0.26) + cam_norm * 0.10;
		float h1 = 1.0 - smoothstep(0.05, 0.72, length(q1 * vec2(0.85, 1.15)));
		float h2 = 1.0 - smoothstep(0.04, 0.68, length(q2 * vec2(0.90, 1.10)));
		float h3 = 1.0 - smoothstep(0.04, 0.56, length(q3));
		vec3 q_haze = vec3(0.20, 0.86, 0.92) * (h1 * h1 * 0.16 + h3 * h3 * 0.08)
			+ vec3(0.99, 0.82, 0.42) * (h2 * h2 * 0.13);
		col += q_haze * w0;
	}

	// Scale 1 (Micro): shimmering aquatic caustic ribbons + translucent depth bubbles
	if (w1 > 0.001) {
		vec2 cp = p + cam_norm * 0.12;
		float wave_a = sin(cp.x * 5.2 + cp.y * 3.1 + t * 0.85 + sin(cp.y * 4.0 - t * 0.6) * 0.75);
		float wave_b = sin(cp.x * 3.8 - cp.y * 4.6 - t * 0.72 + cos(cp.x * 3.2 + t * 0.5) * 0.65);
		float caustic = pow(max(0.0, 0.5 + 0.5 * (wave_a * 0.55 + wave_b * 0.45)), 4.0);
		float top_fade = 1.0 - smoothstep(0.15, 0.95, uv.y);
		col += vec3(0.32, 0.92, 0.78) * caustic * (0.07 + 0.12 * top_fade) * w1;

		// Soft translucent rising depth bubbles
		vec2 b_grid = uv_asp * 4.2 + vec2(cam_norm.x * 0.55, cam_norm.y * 0.55 + t * 0.12);
		vec2 b_id = floor(b_grid);
		vec2 b_gv = fract(b_grid) - vec2(0.5);
		vec2 b_rnd = hash22(b_id + vec2(31.7, 19.3));
		float b_on = step(0.58, b_rnd.x);
		vec2 b_off = vec2(sin(t * 0.6 + b_rnd.y * 6.2831) * 0.18, (b_rnd.y - 0.5) * 0.32);
		float b_rad = 0.075 + b_rnd.y * 0.085;
		float b_d = length(b_gv - b_off);
		float b_ring = smoothstep(b_rad * 0.62, b_rad * 0.96, b_d) * (1.0 - smoothstep(b_rad * 0.96, b_rad * 1.12, b_d));
		float b_fill = (1.0 - smoothstep(0.0, b_rad, b_d)) * 0.22;
		float b_spec = 1.0 - smoothstep(0.005, b_rad * 0.34, length(b_gv - b_off + vec2(b_rad * 0.34, b_rad * 0.34)));
		col += vec3(0.62, 0.98, 0.90) * (b_ring * 0.20 + b_fill * 0.18 + b_spec * 0.18) * b_on * w1;
	}

	// Scale 2 (Forest / Sous-Bois): peripheral emerald foliage vignette + golden/emerald firefly bokeh
	if (w2 > 0.001) {
		float edge_d = length(p * vec2(0.72, 1.05));
		float canopy_wave = sin(atan(p.y, p.x) * 7.0 + t * 0.15) * 0.045 + cos(atan(p.y, p.x) * 11.0 - t * 0.11) * 0.03;
		float vignette = smoothstep(0.52 + canopy_wave, 1.08 + canopy_wave, edge_d);
		col = mix(col, col * vec3(0.52, 0.78, 0.62) + vec3(0.01, 0.045, 0.03), vignette * 0.55 * w2);

		// Pulsing golden & emerald firefly bokeh orbs
		vec2 f_grid = uv_asp * 3.6 + cam_norm * 0.65;
		vec2 f_id = floor(f_grid);
		vec2 f_gv = fract(f_grid) - vec2(0.5);
		vec2 f_rnd = hash22(f_id + vec2(71.2, 13.8));
		float f_on = step(0.54, f_rnd.x);
		vec2 f_off = vec2(sin(t * 0.42 + f_rnd.x * 6.2831), cos(t * 0.36 + f_rnd.y * 6.2831)) * 0.26;
		float f_d = length(f_gv - f_off);
		float f_pulse = pow(0.5 + 0.5 * sin(t * (1.4 + f_rnd.y * 1.4) + f_rnd.x * 12.56), 1.6);
		float f_orb = (1.0 - smoothstep(0.02, 0.19, f_d)) * 0.34 + (1.0 - smoothstep(0.008, 0.055, f_d)) * 0.66;
		vec3 f_col = mix(vec3(1.0, 0.86, 0.36), vec3(0.32, 0.96, 0.62), step(0.76, f_rnd.y));
		col += f_col * f_orb * f_pulse * 0.28 * f_on * w2;
	}

	// Scale 3 (City Nocturne): warm amber bottom horizon glow + warm amber & cool blue city bokeh
	if (w3 > 0.001) {
		float horizon = smoothstep(0.28, 1.02, uv.y);
		float center_lift = 1.0 - smoothstep(0.10, 1.15, abs(p.x));
		col += vec3(0.95, 0.52, 0.22) * (horizon * horizon * (0.14 + 0.09 * center_lift)) * w3;

		vec2 c_grid = uv_asp * 4.8 + vec2(cam_norm.x * 0.42 + t * 0.015, cam_norm.y * 0.35);
		vec2 c_id = floor(c_grid);
		vec2 c_gv = fract(c_grid) - vec2(0.5);
		vec2 c_rnd = hash22(c_id + vec2(53.1, 89.4));
		float c_on = step(0.50, c_rnd.x) * smoothstep(0.18, 0.72, uv.y);
		vec2 c_off = (c_rnd - vec2(0.5)) * 0.48;
		float c_rad = 0.065 + c_rnd.y * 0.095;
		float c_d = length(c_gv - c_off);
		float c_bokeh = (1.0 - smoothstep(c_rad * 0.55, c_rad, c_d)) * 0.72
			+ smoothstep(c_rad * 0.60, c_rad * 0.88, c_d) * (1.0 - smoothstep(c_rad * 0.88, c_rad * 1.05, c_d)) * 0.45;
		float c_twinkle = 0.65 + 0.35 * sin(t * (0.9 + c_rnd.x * 1.5) + c_rnd.y * 10.0);
		vec3 c_col = mix(vec3(1.0, 0.68, 0.32), vec3(0.42, 0.76, 1.0), step(0.62, c_rnd.y));
		col += c_col * c_bokeh * c_twinkle * 0.18 * c_on * w3;
	}

	// Scale 4 (Planetary): crisp multi-size twinkling starfield + 3 tilted concentric orbital arcs
	if (w4 > 0.001) {
		vec2 s_far = mote_layer(uv_asp, cam_norm * 0.18, 16.0, t, 0.12, 0.66, 0.085, 0.028, 11.4);
		vec2 s_mid = mote_layer(uv_asp, cam_norm * 0.32, 9.5, t, 0.18, 0.74, 0.11, 0.036, 27.9);
		col += (vec3(0.84, 0.93, 1.0) * (s_far.x * 0.22 + s_mid.x * 0.26)
			+ vec3(1.0, 0.98, 0.92) * (s_far.y * 0.48 + s_mid.y * 0.58)) * w4;

		vec2 op = p + cam_norm * 0.05;
		float o1 = orbit_arc(op, vec2(0.46, 0.21), 0.34, 0.0065);
		float o2 = orbit_arc(op, vec2(0.74, 0.34), 0.34, 0.0070);
		float o3 = orbit_arc(op, vec2(1.04, 0.48), 0.34, 0.0075);
		vec3 orb_col = vec3(0.56, 0.84, 1.0) * (o1 * 0.16 + o2 * 0.12 + o3 * 0.09);
		col += orb_col * w4;
	}

	// Scale 5 (Cosmic): 3 large drifting pink/cyan/gold radial nebula clouds + dense golden/white star shimmer
	if (w5 > 0.001) {
		vec2 n1 = p - vec2(-0.38 + sin(t * 0.09) * 0.16, -0.14 + cos(t * 0.08) * 0.10) + cam_norm * 0.05;
		vec2 n2 = p - vec2(0.36 + cos(t * 0.08) * 0.18, 0.16 + sin(t * 0.10) * 0.11) + cam_norm * 0.04;
		vec2 n3 = p - vec2(0.02 + sin(t * 0.07 + 1.8) * 0.20, -0.22 + cos(t * 0.09 + 0.9) * 0.12) + cam_norm * 0.06;
		float nb1 = 1.0 - smoothstep(0.04, 0.78, length(n1 * vec2(0.76, 1.12)));
		float nb2 = 1.0 - smoothstep(0.04, 0.82, length(n2 * vec2(0.82, 1.08)));
		float nb3 = 1.0 - smoothstep(0.04, 0.68, length(n3 * vec2(0.92, 1.04)));
		vec3 neb = vec3(0.96, 0.42, 0.72) * (nb1 * nb1 * 0.16)
			+ vec3(0.28, 0.82, 0.96) * (nb2 * nb2 * 0.15)
			+ vec3(1.00, 0.78, 0.36) * (nb3 * nb3 * 0.13);
		col += neb * w5;

		vec2 cs1 = mote_layer(uv_asp, cam_norm * 0.20, 18.0, t, 0.14, 0.56, 0.09, 0.030, 41.2);
		vec2 cs2 = mote_layer(uv_asp, cam_norm * 0.38, 11.0, t, 0.20, 0.64, 0.13, 0.042, 63.7);
		col += (vec3(1.0, 0.88, 0.58) * (cs1.x * 0.24 + cs2.x * 0.28)
			+ vec3(1.0, 0.98, 0.94) * (cs1.y * 0.52 + cs2.y * 0.64)) * w5;
	}

	// -------------------------------------------------------------------------
	// 3-layer parallax glowing motes (far / mid / near) with soft halo + core
	// -------------------------------------------------------------------------
	vec2 m_far = mote_layer(uv_asp, cam_norm * 0.25, 11.5, t, 0.28, 0.58, 0.14, 0.036, 3.1);
	vec2 m_mid = mote_layer(uv_asp, cam_norm * 0.55, 7.2, t, 0.38, 0.54, 0.18, 0.048, 9.7);
	vec2 m_near = mote_layer(uv_asp, cam_norm * 1.05, 4.4, t, 0.50, 0.62, 0.24, 0.062, 19.3);

	float total_halo = m_far.x * 0.11 + m_mid.x * 0.17 + m_near.x * 0.22;
	float total_core = m_far.y * 0.18 + m_mid.y * 0.28 + m_near.y * 0.36;
	col += primary_mote * total_halo + mix(primary_mote, vec3(1.0), 0.58) * total_core;

	// Subtle triangular hash dithering (±0.5 / 255.0) to eliminate 8-bit OLED banding
	float d1 = hash21(FRAGCOORD.xy);
	float d2 = hash21(FRAGCOORD.xy + vec2(19.19, 47.73));
	float dither = (d1 + d2 - 1.0) * (0.5 / 255.0);
	col = clamp(col + vec3(dither), vec3(0.0), vec3(1.0));

	COLOR = vec4(col, 1.0);
}
