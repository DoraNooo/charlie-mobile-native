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

// Fast 2-instruction mobile-friendly hash
vec2 hash22(vec2 p) {
	vec2 q = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(q) * 43758.5453);
}

// Single-cell parallax glowing mote layer: returns vec2(soft_halo, bright_core)
// Softened radii prevent subpixel shimmer when rendered at 0.5x and linearly upscaled
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
	) * 0.26;
	float dist = length(gv - drift);
	float twinkle = 0.54 + 0.46 * sin(t * (1.05 + rnd.y * 1.75) + rnd.x * 18.84);
	float halo = (1.0 - smoothstep(core_r * 0.55, halo_r, dist)) * twinkle * active;
	float core = (1.0 - smoothstep(core_r * 0.12, core_r, dist)) * (0.68 + 0.32 * twinkle) * active;
	return vec2(halo, core);
}

// Analytical orbital ellipse arc on pre-rotated coordinates for Scale 4 (Planetary)
float orbit_arc_rot(vec2 rp, vec2 radii, float thickness) {
	float len_q = length(rp / radii);
	float dist = abs(len_q - 1.0) * min(radii.x, radii.y);
	return 1.0 - smoothstep(thickness * 0.15, thickness, dist);
}

void fragment() {
	float t = (time_sec > 0.0) ? time_sec : TIME;
	float aspect = viewport_size.x / max(viewport_size.y, 1.0);

	vec2 uv = UV;
	// Aspect-corrected centered coordinates: circles stay 100% circular on 20:9 screens
	vec2 p = (uv - vec2(0.5)) * vec2(aspect, 1.0);
	vec2 uv_asp = uv * vec2(aspect, 1.0);
	vec2 cam_norm = cam_offset * 0.00055;

	// Deeper, richer luminous radial backdrop with subtle organic breathing
	vec2 bg_center = vec2(0.0, -0.04) + vec2(sin(t * 0.18) * 0.04, cos(t * 0.14) * 0.03);
	vec2 bg_v = (p - bg_center) * vec2(0.86, 1.06);
	float bg_d2 = dot(bg_v, bg_v);
	vec3 col = mix(bg_inner.rgb * 1.12, bg_outer.rgb * 0.84, smoothstep(0.01, 0.84, bg_d2));
	col += accent.rgb * (1.0 - smoothstep(0.0, 0.48, bg_d2)) * 0.08;

	// Blend mote_color with accent subtly so both uniforms contribute harmoniously
	vec3 primary_mote = mix(mote_color.rgb, accent.rgb, 0.24);

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

	// Scale 0 (Quantum): luminous cyan/gold bioluminescent quantum haze clouds
	if (w0 > 0.001) {
		vec2 q1 = (p - vec2(sin(t * 0.21) * 0.42 - 0.34, cos(t * 0.17) * 0.22 - 0.12) + cam_norm * 0.08) * vec2(0.85, 1.15);
		vec2 q2 = (p - vec2(cos(t * 0.19) * 0.46 + 0.36, sin(t * 0.23) * 0.24 + 0.14) + cam_norm * 0.06) * vec2(0.90, 1.10);
		float h1 = 1.0 - smoothstep(0.01, 0.58, dot(q1, q1));
		float h2 = 1.0 - smoothstep(0.01, 0.52, dot(q2, q2));
		vec3 q_haze = vec3(0.18, 0.90, 0.96) * (h1 * h1 * 0.24)
			+ vec3(1.00, 0.82, 0.38) * (h2 * h2 * 0.19);
		col += q_haze * w0;
	}

	// Scale 1 (Micro): painterly aquatic caustic ribbons + silky translucent depth bubbles
	if (w1 > 0.001) {
		vec2 cp = p + cam_norm * 0.12;
		float wave_a = sin(cp.x * 5.0 + cp.y * 3.0 + t * 0.85);
		float wave_b = sin(cp.x * 3.6 - cp.y * 4.4 - t * 0.72);
		float c_base = 0.5 + 0.25 * (wave_a + wave_b);
		float c2 = c_base * c_base;
		float caustic = c2 * c2;
		float top_fade = 1.0 - smoothstep(0.10, 0.92, uv.y);
		col += vec3(0.28, 0.96, 0.84) * caustic * (0.13 + 0.22 * top_fade) * w1;

		// Soft translucent rising depth bubbles (widened rim for alias-free half-res)
		vec2 b_grid = uv_asp * 4.2 + vec2(cam_norm.x * 0.55, cam_norm.y * 0.55 + t * 0.12);
		vec2 b_id = floor(b_grid);
		vec2 b_gv = fract(b_grid) - vec2(0.5);
		vec2 b_rnd = hash22(b_id + vec2(31.7, 19.3));
		float b_on = step(0.56, b_rnd.x);
		vec2 b_off = vec2(sin(t * 0.6 + b_rnd.y * 6.2831) * 0.18, (b_rnd.y - 0.5) * 0.32);
		float b_rad = 0.080 + b_rnd.y * 0.085;
		float b_d = length(b_gv - b_off);
		float b_ring = smoothstep(b_rad * 0.58, b_rad * 0.94, b_d) * (1.0 - smoothstep(b_rad * 0.94, b_rad * 1.18, b_d));
		float b_fill = (1.0 - smoothstep(0.0, b_rad * 1.02, b_d)) * 0.24;
		float b_spec = 1.0 - smoothstep(0.004, b_rad * 0.42, length(b_gv - b_off + vec2(b_rad * 0.32, b_rad * 0.32)));
		col += vec3(0.64, 1.0, 0.92) * (b_ring * 0.25 + b_fill * 0.20 + b_spec * 0.22) * b_on * w1;
	}

	// Scale 2 (Forest / Sous-Bois): organic emerald foliage vignette + dreamy emerald-gold fireflies
	if (w2 > 0.001) {
		float edge_d = length(p * vec2(0.72, 1.05));
		float canopy_wave = sin(p.x * 4.5 + t * 0.2) * cos(p.y * 4.5) * 0.065;
		float vignette = smoothstep(0.50 + canopy_wave, 1.06 + canopy_wave, edge_d);
		col = mix(col, col * vec3(0.46, 0.78, 0.58) + vec3(0.012, 0.055, 0.032), vignette * 0.62 * w2);

		// Pulsing warm emerald-gold firefly bokeh orbs
		vec2 f_grid = uv_asp * 3.6 + cam_norm * 0.65;
		vec2 f_id = floor(f_grid);
		vec2 f_gv = fract(f_grid) - vec2(0.5);
		vec2 f_rnd = hash22(f_id + vec2(71.2, 13.8));
		float f_on = step(0.50, f_rnd.x);
		vec2 f_off = vec2(sin(t * 0.42 + f_rnd.x * 6.2831), cos(t * 0.36 + f_rnd.y * 6.2831)) * 0.25;
		float f_d = length(f_gv - f_off);
		float f_raw = 0.5 + 0.5 * sin(t * (1.35 + f_rnd.y * 1.35) + f_rnd.x * 12.56);
		float f_pulse = f_raw * f_raw;
		float f_orb = (1.0 - smoothstep(0.02, 0.24, f_d)) * 0.46 + (1.0 - smoothstep(0.01, 0.082, f_d)) * 0.66;
		vec3 f_col = mix(vec3(1.0, 0.86, 0.30), vec3(0.30, 0.98, 0.60), step(0.72, f_rnd.y));
		col += f_col * f_orb * f_pulse * 0.36 * f_on * w2;
	}

	// Scale 3 (City Nocturne): deeper amber horizon glow + buttery amber & cool blue city bokeh
	if (w3 > 0.001) {
		float horizon = smoothstep(0.24, 1.02, uv.y);
		float center_lift = 1.0 - smoothstep(0.08, 1.15, abs(p.x));
		col += vec3(1.0, 0.50, 0.18) * (horizon * horizon * (0.22 + 0.14 * center_lift)) * w3;

		vec2 c_grid = uv_asp * 4.8 + vec2(cam_norm.x * 0.42 + t * 0.015, cam_norm.y * 0.35);
		vec2 c_id = floor(c_grid);
		vec2 c_gv = fract(c_grid) - vec2(0.5);
		vec2 c_rnd = hash22(c_id + vec2(53.1, 89.4));
		float c_on = step(0.46, c_rnd.x) * smoothstep(0.16, 0.70, uv.y);
		vec2 c_off = (c_rnd - vec2(0.5)) * 0.46;
		float c_rad = 0.072 + c_rnd.y * 0.098;
		float c_d = length(c_gv - c_off);
		float c_bokeh = (1.0 - smoothstep(c_rad * 0.48, c_rad, c_d)) * 0.78
			+ smoothstep(c_rad * 0.56, c_rad * 0.84, c_d) * (1.0 - smoothstep(c_rad * 0.84, c_rad * 1.12, c_d)) * 0.50;
		float c_twinkle = 0.68 + 0.32 * sin(t * (0.85 + c_rnd.x * 1.4) + c_rnd.y * 10.0);
		vec3 c_col = mix(vec3(1.0, 0.68, 0.28), vec3(0.38, 0.78, 1.0), step(0.60, c_rnd.y));
		col += c_col * c_bokeh * c_twinkle * 0.25 * c_on * w3;
	}

	// Scale 4 (Planetary): silky anti-aliased tilted concentric orbital arcs
	if (w4 > 0.001) {
		vec2 op = p + cam_norm * 0.05;
		// Precomputed cos(0.34) = 0.94275, sin(0.34) = 0.33349
		vec2 rp = vec2(0.94275 * op.x - 0.33349 * op.y, 0.33349 * op.x + 0.94275 * op.y);
		float o1 = orbit_arc_rot(rp, vec2(0.46, 0.21), 0.0085);
		float o2 = orbit_arc_rot(rp, vec2(0.74, 0.34), 0.0092);
		float o3 = orbit_arc_rot(rp, vec2(1.04, 0.48), 0.0098);
		vec3 orb_col = vec3(0.58, 0.88, 1.0) * (o1 * 0.23 + o2 * 0.17 + o3 * 0.13);
		col += orb_col * w4;
	}

	// Scale 5 (Cosmic): poetic drifting pink/cyan/gold radial nebula clouds
	if (w5 > 0.001) {
		vec2 n1 = (p - vec2(-0.38 + sin(t * 0.09) * 0.16, -0.14 + cos(t * 0.08) * 0.10) + cam_norm * 0.05) * vec2(0.76, 1.12);
		vec2 n2 = (p - vec2(0.36 + cos(t * 0.08) * 0.18, 0.16 + sin(t * 0.10) * 0.11) + cam_norm * 0.04) * vec2(0.82, 1.08);
		vec2 n3 = (p - vec2(0.02 + sin(t * 0.07 + 1.8) * 0.20, -0.22 + cos(t * 0.09 + 0.9) * 0.12) + cam_norm * 0.06) * vec2(0.92, 1.04);
		float nb1 = 1.0 - smoothstep(0.01, 0.66, dot(n1, n1));
		float nb2 = 1.0 - smoothstep(0.01, 0.72, dot(n2, n2));
		float nb3 = 1.0 - smoothstep(0.01, 0.52, dot(n3, n3));
		vec3 neb = vec3(1.00, 0.36, 0.74) * (nb1 * nb1 * 0.25)
			+ vec3(0.22, 0.86, 1.00) * (nb2 * nb2 * 0.23)
			+ vec3(1.00, 0.80, 0.32) * (nb3 * nb3 * 0.20);
		col += neb * w5;
	}

	// -------------------------------------------------------------------------
	// 2 lush global parallax mote layers (far twinkling stars + near soft bokeh)
	// Softened core/halo radii prevent 0.5x->1.0x linear upscale shimmer
	// -------------------------------------------------------------------------
	vec2 m_far = mote_layer(uv_asp, cam_norm * 0.25, 10.8, t, 0.22, 0.50, 0.175, 0.056, 3.1);
	vec2 m_near = mote_layer(uv_asp, cam_norm * 0.85, 5.0, t, 0.40, 0.55, 0.28, 0.072, 19.3);

	vec3 mote_tint = mix(primary_mote, vec3(0.84, 0.94, 1.0), w4 * 0.65);
	mote_tint = mix(mote_tint, vec3(1.0, 0.88, 0.56), w5 * 0.65);
	vec3 core_tint = mix(mote_tint, vec3(1.0, 0.98, 0.94), 0.58 + (w4 + w5) * 0.28);

	float total_halo = m_far.x * (0.15 + w4 * 0.16 + w5 * 0.22) + m_near.x * (0.25 + w4 * 0.08 + w5 * 0.14);
	float total_core = m_far.y * (0.22 + w4 * 0.34 + w5 * 0.44) + m_near.y * (0.34 + w4 * 0.22 + w5 * 0.32);
	col += mote_tint * total_halo + core_tint * total_core;

	// Subtle triangular hash dithering (±0.5 / 255.0) to eliminate 8-bit OLED banding
	vec2 d = hash22(FRAGCOORD.xy);
	float dither = (d.x + d.y - 1.0) * (0.5 / 255.0);
	col = clamp(col + vec3(dither), vec3(0.0), vec3(1.0));

	COLOR = vec4(col, 1.0);
}
