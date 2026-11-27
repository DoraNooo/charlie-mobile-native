shader_type canvas_item;

// Lush Painted Studio Ghibli x Ori World Backdrop Shader (Godot 4.3 Vulkan Mobile, 60-120 FPS)
// Blends two 16:9 hand-painted world artworks with aspect-correct cover UV, silky bounded
// panoramic parallax drift, subtle living Ghibli atmosphere, jewel-tone contrast, and OLED dithering.

uniform vec4 bg_inner : source_color = vec4(0.045, 0.165, 0.255, 1.0);
uniform vec4 bg_outer : source_color = vec4(0.016, 0.062, 0.125, 1.0);
uniform vec4 mote_color : source_color = vec4(0.360, 0.925, 0.945, 1.0);
uniform vec4 accent : source_color = vec4(0.360, 0.925, 0.945, 1.0);
uniform vec2 cam_offset = vec2(0.0, 0.0);
uniform float time_sec = 0.0;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform float scale_progress = 0.0;

uniform sampler2D world_tex_a : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D world_tex_b : source_color, filter_linear_mipmap, repeat_disable;
uniform float world_blend = 0.0;

// Fast 2-instruction mobile-friendly hash
vec2 hash22(vec2 p) {
	vec2 q = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(q) * 43758.5453);
}

// Compute aspect-correct cover UV with silky zoom & strictly bounded panoramic parallax drift.
// Guarantees zero aspect distortion across 4:3..21:9 screens and zero edge clamping streaks.
vec2 compute_cover_parallax_uv(vec2 uv, float vp_aspect, float tex_aspect, float zoom, vec2 pan) {
	vec2 cover_scale = (vp_aspect > tex_aspect)
		? vec2(1.0, tex_aspect / max(vp_aspect, 0.001))
		: vec2(vp_aspect / max(tex_aspect, 0.001), 1.0);
	vec2 half_span = (cover_scale / max(zoom, 1.0)) * 0.5;
	vec2 max_pan = max(vec2(0.496) - half_span, vec2(0.0));
	vec2 safe_pan = clamp(pan, -max_pan, max_pan);
	vec2 centered = (uv - vec2(0.5)) * (cover_scale / max(zoom, 1.0));
	return clamp(vec2(0.5) + centered + safe_pan, vec2(0.002), vec2(0.998));
}

// Delicate twinkling starfield sparkles (rotated non-orthogonal cells, zero grid artifacts)
// Returns vec2(soft_halo, crisp_sparkle)
vec2 twinkling_stars(vec2 uv_asp, vec2 shift, mat2 rot_m, float density, float t, float threshold, float seed) {
	vec2 grid = rot_m * (uv_asp + shift) * density;
	vec2 id = floor(grid);
	vec2 gv = fract(grid) - vec2(0.5);

	vec2 rnd_a = hash22(id + vec2(seed, seed * 1.73));
	vec2 rnd_b = hash22(id * 1.37 + vec2(seed * 2.11 + 19.7, seed * 0.63 + 41.3));
	float active = step(threshold, rnd_a.x);

	float size_var = mix(0.48, 1.32, rnd_b.x * rnd_b.x);
	float r_halo = min(0.11 * size_var, 0.22);
	float r_core = min(0.028 * size_var, r_halo * 0.45);
	float max_off = max(0.04, 0.45 - r_halo);
	vec2 pos = clamp((rnd_b - vec2(0.5)) * (max_off * 1.55), vec2(-max_off), vec2(max_off));

	vec2 delta = gv - pos;
	float dist = length(delta);

	float tw_raw = 0.5 + 0.5 * sin(t * (1.25 + rnd_a.y * 2.25) + rnd_b.y * 25.13);
	float twinkle = 0.28 + 0.72 * (tw_raw * tw_raw);
	float bright = mix(0.55, 1.25, rnd_b.y);

	float halo = (1.0 - smoothstep(r_core * 0.4, r_halo, dist)) * twinkle * bright * active;
	float core = (1.0 - smoothstep(r_core * 0.08, r_core, dist)) * twinkle * bright * active;

	// Subtle 4-point diamond star glint on rarest bright stars
	float glint_on = step(0.80, rnd_a.y) * active;
	vec2 ad = abs(delta);
	float g_len = max(r_halo * 1.15, 0.04);
	float g_w = max(0.0032, r_core * 0.44);
	float tx = clamp(ad.x / g_len, 0.0, 1.0);
	float ty = clamp(ad.y / g_len, 0.0, 1.0);
	float wh = mix(g_w, g_w * 0.16, tx);
	float wv = mix(g_w, g_w * 0.16, ty);
	float ray_h = (1.0 - smoothstep(wh * 0.12, wh, ad.y)) * (1.0 - smoothstep(0.0, 1.0, tx));
	float ray_v = (1.0 - smoothstep(wv * 0.12, wv, ad.x)) * (1.0 - smoothstep(0.0, 1.0, ty));
	float sparkle = (core + max(ray_h, ray_v) * 0.55 * glint_on) * twinkle;

	return vec2(halo, sparkle);
}

void fragment() {
	float t = (time_sec > 0.0) ? time_sec : TIME;
	float vp_aspect = viewport_size.x / max(viewport_size.y, 1.0);

	vec2 uv = UV;
	vec2 p = (uv - vec2(0.5)) * vec2(vp_aspect, 1.0);
	vec2 uv_asp = uv * vec2(vp_aspect, 1.0);

	// -------------------------------------------------------------------------
	// 1. Silky bounded panoramic parallax & slow organic breathing zoom
	// -------------------------------------------------------------------------
	float breath_zoom = 1.11 * (1.0 + 0.008 * sin(t * 0.25));
	// Bounded smooth wave pan driven by cam_offset + delicate ambient drift
	vec2 pan_a = vec2(
		sin(cam_offset.x * 0.00045) * 0.042 + sin(t * 0.11) * 0.0025,
		sin(cam_offset.y * 0.00045) * 0.036 + cos(t * 0.09) * 0.0025
	);
	vec2 pan_b = vec2(
		sin(cam_offset.x * 0.00045 + 0.04) * 0.039 + sin(t * 0.10 + 0.8) * 0.0025,
		sin(cam_offset.y * 0.00045 + 0.04) * 0.034 + cos(t * 0.08 + 0.8) * 0.0025
	);

	vec2 sz_a = vec2(textureSize(world_tex_a, 0));
	vec2 sz_b = vec2(textureSize(world_tex_b, 0));
	float has_a = step(16.0, sz_a.x);
	float has_b = step(16.0, sz_b.x);
	float tex_aspect_a = (has_a > 0.5) ? (sz_a.x / max(sz_a.y, 1.0)) : (16.0 / 9.0);
	float tex_aspect_b = (has_b > 0.5) ? (sz_b.x / max(sz_b.y, 1.0)) : (16.0 / 9.0);

	vec2 uv_a = compute_cover_parallax_uv(uv, vp_aspect, tex_aspect_a, breath_zoom, pan_a);
	vec2 uv_b = compute_cover_parallax_uv(uv, vp_aspect, tex_aspect_b, breath_zoom * 1.012, pan_b);

	// Graceful velvety procedural fallback if a world texture is unbound
	vec2 bg_v = (p - vec2(-0.06, -0.05)) * vec2(0.84, 1.06);
	float velvet_wave = sin(p.x * 2.4 + t * 0.11) * cos(p.y * 2.8 - t * 0.09) * 0.028;
	vec3 proc_col = mix(bg_inner.rgb, bg_outer.rgb * 0.72, smoothstep(0.02, 0.88, dot(bg_v, bg_v) + velvet_wave));
	vec2 key_v = (p - vec2(-0.42 * min(vp_aspect * 0.65, 1.0), -0.40)) * vec2(0.74, 0.94);
	float key_lift = 1.0 - smoothstep(0.02, 1.12, dot(key_v, key_v));
	proc_col += mix(accent.rgb, bg_inner.rgb * 1.35, 0.60) * key_lift * 0.055;

	vec3 sample_a = texture(world_tex_a, uv_a).rgb;
	vec3 sample_b = texture(world_tex_b, uv_b).rgb;
	vec3 col_a = mix(proc_col, sample_a, has_a);
	vec3 col_b = mix(col_a, sample_b, has_b);

	// Silky C1 crossfade between painted worlds
	float wb = smoothstep(0.0, 1.0, clamp(world_blend, 0.0, 1.0));
	vec3 col = mix(col_a, col_b, wb);

	// -------------------------------------------------------------------------
	// 2. Cinematic Miyazaki jewel-tone richness (vibrant on OLED, never washed out)
	// -------------------------------------------------------------------------
	float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	// Gentle luminance-preserving jewel saturation lift
	col = mix(vec3(luma), col, 1.13);
	// Soft filmic S-curve micro-contrast keeping shadows velvety and mids luminous
	vec3 col_c = clamp(col, vec3(0.0), vec3(1.0));
	vec3 s_curve = col_c * col_c * (vec3(3.0) - 2.0 * col_c);
	col = mix(col, s_curve, 0.14);
	// Subtle cohesive world-palette infusion (keeps darks rich, never muddy)
	col = mix(col, col * mix(vec3(0.96), vec3(1.04) + bg_inner.rgb * 0.16, 0.5), 0.18);

	// -------------------------------------------------------------------------
	// 3. Per-scale living Ghibli atmospheric shimmer (synchronized with Scales)
	// -------------------------------------------------------------------------
	float sp = clamp(scale_progress, 0.0, 5.0);
	float idx_f = floor(min(sp, 4.9999));
	float frac = sp - idx_f;
	float s_blend = smoothstep(0.62, 1.0, frac);
	int idx = int(idx_f);

	float w0 = (idx == 0) ? (1.0 - s_blend) : 0.0;
	float w1 = (idx == 0) ? s_blend : ((idx == 1) ? (1.0 - s_blend) : 0.0);
	float w2 = (idx == 1) ? s_blend : ((idx == 2) ? (1.0 - s_blend) : 0.0);
	float w3 = (idx == 2) ? s_blend : ((idx == 3) ? (1.0 - s_blend) : 0.0);
	float w4 = (idx == 3) ? s_blend : ((idx == 4) ? (1.0 - s_blend) : 0.0);
	float w5 = (idx == 4) ? s_blend : 0.0;

	// Diagonal top-left sun/moonlight breathing shimmer aligned with g_key_light_dir (-0.52, -0.62)
	float diag_coord = p.x * 0.766 - p.y * 0.643;
	float ray_band = 0.5 + 0.5 * sin(diag_coord * 11.5 - t * 0.42 + sin(p.y * 3.0 + t * 0.22) * 0.45);
	float ray_band2 = 0.5 + 0.5 * sin(diag_coord * 17.0 + t * 0.31);
	float ray_shimmer = ray_band * ray_band * 0.65 + ray_band2 * ray_band2 * 0.35;
	float ray_env = (1.0 - smoothstep(0.05, 0.92, uv.y)) * (1.0 - smoothstep(0.05, 1.05, uv.x));
	float ray_strength = w0 * 0.032 + w1 * 0.048 + w2 * 0.042 + w3 * 0.014;
	vec3 ray_tint = mix(mote_color.rgb, vec3(1.0, 0.92, 0.72), w2 * 0.55 + w1 * 0.20);
	col += ray_tint * (ray_shimmer * ray_env * ray_strength);

	// Scale 0 (Quantique): subtle breathing cyan/gold quantum wave iridescence
	if (w0 > 0.001) {
		vec2 qp = p + pan_a * 1.4;
		float ring_a = sin(length(qp - vec2(-0.22, -0.10)) * 18.0 - t * 1.25);
		float ring_b = sin(length(qp - vec2(0.24, 0.12)) * 15.0 + t * 1.05);
		float q_shimmer = smoothstep(0.45, 0.98, 0.5 + 0.25 * (ring_a + ring_b));
		float rim_band = smoothstep(0.18, 0.68, length(p * vec2(0.75, 1.0)));
		col += mix(vec3(0.20, 0.88, 0.96), vec3(1.0, 0.84, 0.44), 0.5 + 0.5 * sin(p.x * 3.0 + t * 0.35))
			* (q_shimmer * rim_band * 0.045 * w0);
	}

	// Scale 1 (Microscopique): delicate dancing underwater teal caustic ripples
	if (w1 > 0.001) {
		vec2 cp = p + pan_a * 1.8;
		vec2 cw = cp + vec2(sin(cp.y * 4.4 + t * 0.58), cos(cp.x * 4.0 - t * 0.50)) * 0.075;
		float wa = sin(cw.x * 7.2 + cw.y * 3.0 + t * 0.96);
		float wb = sin(cw.x * -4.1 + cw.y * 6.4 - t * 0.80);
		float wc = sin(cw.x * 2.9 - cw.y * 5.6 + t * 0.68);
		float r1 = clamp(1.0 - abs(wa + wb) * 0.5, 0.0, 1.0);
		float r2 = clamp(1.0 - abs(wb - wc) * 0.5, 0.0, 1.0);
		float r1_2 = r1 * r1;
		float r2_2 = r2 * r2;
		float caustic = r1_2 * r1_2 * 0.65 + r2_2 * r2_2 * r2 * 0.55;
		// Strongest in sunlit upper-mid water, gently fading over lower kelp
		float water_mask = smoothstep(0.08, 0.24, uv.y) * (1.0 - smoothstep(0.48, 0.88, uv.y));
		col += vec3(0.32, 0.94, 0.84) * (caustic * water_mask * 0.088 * w1);
	}

	// Scale 2 (Sous-Bois): subtle dappled woodland air shimmer in the sunlit clearing
	if (w2 > 0.001) {
		float clearing = 1.0 - smoothstep(0.05, 0.66, length((p - vec2(-0.02, -0.04)) * vec2(0.88, 1.05)));
		float dapple = 0.5 + 0.5 * sin(p.x * 8.5 + t * 0.55) * cos(p.y * 7.5 - t * 0.42);
		col += vec3(0.95, 0.86, 0.48) * (clearing * dapple * 0.028 * w2);
	}

	// Scale 3 (Ville Endormie): subtle warm candle-breathing glow along the lower village windows
	if (w3 > 0.001) {
		float village_band = smoothstep(0.56, 0.92, uv.y);
		float hearth_pulse = 0.5 + 0.5 * sin(p.x * 12.0 + t * 1.4) * cos(p.x * 7.0 - t * 0.9);
		col += vec3(1.0, 0.66, 0.26) * (village_band * hearth_pulse * 0.026 * w3);
	}

	// Scale 4 (Planetaire): gentle shimmering emerald-violet aurora wave dancing over the painted aurora
	if (w4 > 0.001) {
		float aurora_y = smoothstep(0.42, 0.64, uv.y) * (1.0 - smoothstep(0.74, 0.88, uv.y));
		float aurora_x = 1.0 - smoothstep(0.18, 0.92, abs(p.x));
		float curtain = 0.5 + 0.5 * sin(p.x * 9.5 + t * 0.82 + sin(p.y * 6.0 - t * 0.55) * 0.9);
		float curtain_s = curtain * curtain;
		vec3 aurora_col = mix(vec3(0.24, 0.94, 0.66), vec3(0.68, 0.42, 0.98), 0.5 + 0.5 * sin(p.x * 4.2 - t * 0.35));
		col += aurora_col * (aurora_y * aurora_x * curtain_s * 0.052 * w4);
	}

	// Scale 5 (Cosmique): subtle breathing iridescent nebula shimmer along the outer painted clouds
	if (w5 > 0.001) {
		float rim_neb = smoothstep(0.24, 0.82, length(p * vec2(0.78, 1.02)));
		float neb_wave = 0.5 + 0.5 * sin(p.x * 4.2 + p.y * 3.6 + t * 0.38);
		vec3 neb_tint = mix(vec3(0.68, 0.38, 0.96), vec3(0.98, 0.78, 0.38), neb_wave);
		col += neb_tint * (rim_neb * (0.4 + 0.6 * neb_wave) * 0.032 * w5);
	}

	// Subtle twinkling stars layered gently into night/celestial skies (Scales 3, 4, 5)
	float star_weight = w3 * 0.55 * (1.0 - smoothstep(0.30, 0.62, uv.y)) + w4 * 0.82 * (1.0 - smoothstep(0.62, 0.82, uv.y)) + w5 * 0.95;
	if (star_weight > 0.005) {
		const mat2 ROT_A = mat2(vec2(0.9455, 0.3256), vec2(-0.3256, 0.9455));
		const mat2 ROT_B = mat2(vec2(0.8572, -0.5150), vec2(0.5150, 0.8572));
		vec2 st_far = twinkling_stars(uv_asp, pan_a * 0.85, ROT_A, 13.5, t, 0.62, 7.3);
		vec2 st_mid = twinkling_stars(uv_asp, pan_a * 1.35, ROT_B, 7.8, t, 0.68, 29.1);
		vec3 star_tint = mix(vec3(0.82, 0.92, 1.0), vec3(1.0, 0.90, 0.62), w5 * 0.65);
		vec3 star_rgb = star_tint * (st_far.x * 0.14 + st_mid.x * 0.18)
			+ vec3(1.0, 0.97, 0.88) * (st_far.y * 0.36 + st_mid.y * 0.32);
		col += star_rgb * star_weight;
	}

	// -------------------------------------------------------------------------
	// 4. Subtle warm ambient response near center + soft cinematic edge vignette
	// -------------------------------------------------------------------------
	float center_d2 = dot(p * vec2(0.95, 1.15), p * vec2(0.95, 1.15));
	float charlie_warmth = 1.0 - smoothstep(0.0, 0.44, center_d2);
	col += vec3(1.0, 0.62, 0.28) * (charlie_warmth * charlie_warmth * 0.036);

	// Soft velvety dark edge vignette so painted frame borders feel deep and Charlie pops
	float outer_vig = smoothstep(0.46, 1.34, dot(p * vec2(0.76, 1.02), p * vec2(0.76, 1.02)));
	col *= mix(1.0, 0.78, outer_vig);

	// Subtle triangular hash dithering (+/-0.5 / 255.0) to eliminate 8-bit OLED banding
	vec2 d = hash22(FRAGCOORD.xy);
	float dither = (d.x + d.y - 1.0) * (0.5 / 255.0);
	col = clamp(col + vec3(dither), vec3(0.0), vec3(1.08));

	COLOR = vec4(col, 1.0);
}
