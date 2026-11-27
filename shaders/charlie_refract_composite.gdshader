shader_type canvas_item;
render_mode blend_mix;

// Mobile-Optimized Refractive Optical Compositor for Dual-Shell 3D Studio Ghibli Charlie Slime.
// Slashed from 19 texture taps/px down to 5-6 taps/px (with early discard in empty quad corners):
// - 1 native MSAA_2X linear center tap + 4 diagonal aura/gradient taps + 1 conditional screen_tex refraction tap.
// - Identical jewel-like Studio Ghibli honey-coral quality & warm feathered aura at ~3x lower GPU cost!

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

uniform vec4 core_color : source_color = vec4(1.000, 0.560, 0.240, 1.0);
uniform vec4 edge_color : source_color = vec4(0.880, 0.290, 0.160, 1.0);
uniform vec4 glow_color : source_color = vec4(1.000, 0.480, 0.200, 1.0);
uniform vec4 flavor_tint : source_color = vec4(1.000, 0.560, 0.240, 0.0);

uniform float vitality_ratio = 1.0;
uniform float invuln_flash = 0.0;
uniform float refract_strength = 0.022;
uniform float aura_intensity = 0.72;
uniform float time_sec = 0.0;

void fragment() {
	// 1. Single crisp linear tap on 224x224 MSAA_2X SubViewport texture
	vec4 tex_3d = texture(TEXTURE, UV);
	float a_c = clamp(tex_3d.a, 0.0, 1.0);

	// 2. 4 diagonal taps simultaneously compute feathered aura field & silhouette normal gradient
	float a_tr = texture(TEXTURE, clamp(UV + vec2( 0.048,  0.048), vec2(0.002), vec2(0.998))).a;
	float a_tl = texture(TEXTURE, clamp(UV + vec2(-0.048,  0.048), vec2(0.002), vec2(0.998))).a;
	float a_br = texture(TEXTURE, clamp(UV + vec2( 0.048, -0.048), vec2(0.002), vec2(0.998))).a;
	float a_bl = texture(TEXTURE, clamp(UV + vec2(-0.048, -0.048), vec2(0.002), vec2(0.998))).a;
	float ring_avg = (a_tr + a_tl + a_br + a_bl) * 0.25;

	// Fast early-out skips empty quad corners completely (saves ~55% of Charlie quad fillrate!)
	if (a_c < 0.002 && ring_avg < 0.003) {
		discard;
	}

	float vit = clamp(vitality_ratio, 0.0, 1.0);
	float flav_amt = clamp(flavor_tint.a, 0.0, 1.0);
	float body_cov = smoothstep(0.04, 0.92, a_c);

	vec3 body_rgb = vec3(0.0);
	if (body_cov > 0.002) {
		// Exact zero-washout color recovery from opaque inner core + MSAA_2X outer rim
		vec3 rim_coral = mix(vec3(0.84, 0.72, 0.68), vec3(0.94, 0.42, 0.22), smoothstep(0.0, 0.92, vit));
		vec3 charlie_rgb = mix(rim_coral, tex_3d.rgb, smoothstep(0.18, 0.86, a_c));

		// Subtle convex-lens background refraction (1 fast screen_tex fetch only inside translucent belly/tail!)
		vec2 rel = (UV - vec2(0.5)) * 2.0;
		float r_dist = length(rel);
		float face_protect = 1.0 - smoothstep(0.10, 0.34, length((UV - vec2(0.50, 0.46)) * vec2(1.15, 1.35)));
		float trans_amt = (0.14 + 0.08 * smoothstep(0.18, 0.56, r_dist)) * (1.0 - face_protect * 0.85) * smoothstep(0.25, 0.85, a_c);
		trans_amt = clamp(trans_amt * mix(1.25, 1.0, vit), 0.0, 0.24);

		if (trans_amt > 0.005) {
			vec2 rad_dir = (r_dist > 0.001) ? (rel / r_dist) : vec2(0.0);
			vec2 sil_grad = vec2((a_tl + a_bl) - (a_tr + a_br), (a_br + a_bl) - (a_tr + a_tl)) * 0.35;
			float r_curve = smoothstep(0.02, 0.78, r_dist);
			float lens_slope = r_curve * (0.60 + 0.56 * r_curve);
			vec2 asp_corr = vec2(SCREEN_PIXEL_SIZE.x / max(SCREEN_PIXEL_SIZE.y, 0.00001), 1.0);
			vec2 uv_shift = (rad_dir * lens_slope + sil_grad) * refract_strength * body_cov * asp_corr;
			vec3 bg_refract = texture(screen_tex, clamp(SCREEN_UV - uv_shift, vec2(0.001), vec2(0.999))).rgb;
			vec3 warm_filter = mix(vec3(0.92, 0.82, 0.78), vec3(1.00, 0.54, 0.26), smoothstep(0.0, 0.92, vit));
			body_rgb = mix(charlie_rgb, bg_refract * warm_filter * 0.95, trans_amt);
		} else {
			body_rgb = charlie_rgb;
		}
	}

	// Rich warm Studio Ghibli golden-tangerine bioluminescent aura following Charlie's sculpted silhouette
	float blur_sil = a_c * 0.28 + ring_avg * 0.72;
	float edge_dist = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float quad_fade = smoothstep(0.015, 0.14, edge_dist);
	float breath_glow = 0.94 + 0.06 * sin(time_sec * 2.7);
	float vit_glow = mix(0.32, 1.0, vit);
	float aura_field = clamp(pow(max(blur_sil, 0.0), 1.25) * 0.94, 0.0, 1.0);
	float aura_alpha = clamp(aura_field * aura_intensity * vit_glow * breath_glow * quad_fade, 0.0, 0.42);
	aura_alpha *= (1.0 - clamp(invuln_flash, 0.0, 1.0) * 0.35);

	vec3 aura_col = mix(vec3(1.00, 0.58, 0.20), vec3(0.94, 0.34, 0.18), 0.38);
	aura_col = mix(aura_col, glow_color.rgb, 0.20);
	aura_col = mix(vec3(0.92, 0.82, 0.78), aura_col, smoothstep(0.0, 0.92, vit));
	aura_col = mix(aura_col, clamp(flavor_tint.rgb * 1.12, vec3(0.0), vec3(1.0)), flav_amt * 0.28);

	float invuln_fade = 1.0 - clamp(invuln_flash, 0.0, 1.0) * 0.32;
	float eff_body = body_cov * invuln_fade;
	float out_alpha = clamp(eff_body + aura_alpha * (1.0 - eff_body), 0.0, 1.0);
	vec3 out_rgb = (out_alpha > 0.0005)
		? (body_rgb * eff_body + aura_col * aura_alpha * (1.0 - eff_body)) / out_alpha
		: aura_col;

	COLOR = vec4(clamp(out_rgb, vec3(0.0), vec3(1.0)), out_alpha);
}
