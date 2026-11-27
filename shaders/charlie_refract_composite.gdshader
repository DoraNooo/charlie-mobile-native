shader_type canvas_item;
render_mode blend_mix;

// Refractive Optical Compositor for Dual-Shell 3D Studio Ghibli Charlie Slime.
// Because InnerVolumetricShell uses depth_draw_opaque (a = 1.0 with MSAA_4X), tex_3d.rgb needs
// ZERO destructive 1/alpha division -> rich honey-tangerine-coral stays 100% vivid and jewel-like
// across ALL 6 worlds on Vulkan Mobile & OpenGL3!
// Adds smooth convex-lens background refraction through Charlie's translucent lower belly & edges
// plus a warm feathered golden-tangerine Studio Ghibli bioluminescent aura.

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
	// 4-tap Rotated Grid Super-Sampling (RGSS) on 320x320 MSAA_4X SubViewport texture
	vec2 aa_step = clamp(fwidth(UV) * 0.28, TEXTURE_PIXEL_SIZE * 0.45, vec2(0.005));
	vec4 t0 = texture(TEXTURE, clamp(UV + vec2( aa_step.x * 0.35,  aa_step.y * 0.90), vec2(0.001), vec2(0.999)));
	vec4 t1 = texture(TEXTURE, clamp(UV + vec2(-aa_step.x * 0.90,  aa_step.y * 0.35), vec2(0.001), vec2(0.999)));
	vec4 t2 = texture(TEXTURE, clamp(UV + vec2(-aa_step.x * 0.35, -aa_step.y * 0.90), vec2(0.001), vec2(0.999)));
	vec4 t3 = texture(TEXTURE, clamp(UV + vec2( aa_step.x * 0.90, -aa_step.y * 0.35), vec2(0.001), vec2(0.999)));
	vec4 tex_3d = (t0 + t1 + t2 + t3) * 0.25;
	float a_c = clamp(tex_3d.a, 0.0, 1.0);

	// Multi-ring silhouette sampling tracks Charlie's live sculpted head, molten tail & flippers
	float a_r = texture(TEXTURE, clamp(UV + vec2(0.024, 0.0), vec2(0.002), vec2(0.998))).a;
	float a_l = texture(TEXTURE, clamp(UV - vec2(0.024, 0.0), vec2(0.002), vec2(0.998))).a;
	float a_d = texture(TEXTURE, clamp(UV + vec2(0.0, 0.024), vec2(0.002), vec2(0.998))).a;
	float a_u = texture(TEXTURE, clamp(UV - vec2(0.0, 0.024), vec2(0.002), vec2(0.998))).a;
	float ring1 = (a_r + a_l + a_d + a_u) * 0.25;

	float a_d1 = texture(TEXTURE, clamp(UV + vec2(0.058, 0.058), vec2(0.002), vec2(0.998))).a;
	float a_d2 = texture(TEXTURE, clamp(UV + vec2(-0.058, 0.058), vec2(0.002), vec2(0.998))).a;
	float a_d3 = texture(TEXTURE, clamp(UV + vec2(0.058, -0.058), vec2(0.002), vec2(0.998))).a;
	float a_d4 = texture(TEXTURE, clamp(UV + vec2(-0.058, -0.058), vec2(0.002), vec2(0.998))).a;
	float ring2 = (a_d1 + a_d2 + a_d3 + a_d4) * 0.25;

	float a_w1 = texture(TEXTURE, clamp(UV + vec2(0.112, 0.0), vec2(0.002), vec2(0.998))).a;
	float a_w2 = texture(TEXTURE, clamp(UV - vec2(0.112, 0.0), vec2(0.002), vec2(0.998))).a;
	float a_w3 = texture(TEXTURE, clamp(UV + vec2(0.0, 0.112), vec2(0.002), vec2(0.998))).a;
	float a_w4 = texture(TEXTURE, clamp(UV - vec2(0.0, 0.112), vec2(0.002), vec2(0.998))).a;
	float ring3 = (a_w1 + a_w2 + a_w3 + a_w4) * 0.25;

	float vit = clamp(vitality_ratio, 0.0, 1.0);
	float flav_amt = clamp(flavor_tint.a, 0.0, 1.0);

	// Smooth silhouette coverage (a_c is 1.0 inside opaque core and MSAA-feathered at edge!)
	float body_cov = smoothstep(0.04, 0.92, a_c);

	// Convex lens refraction of the painted Ghibli world behind Charlie
	vec2 rel = (UV - vec2(0.5)) * 2.0;
	float r_dist = length(rel);
	vec2 rad_dir = (r_dist > 0.001) ? (rel / r_dist) : vec2(0.0);
	vec2 sil_grad = vec2(a_l - a_r, a_u - a_d);

	float r_curve = smoothstep(0.02, 0.78, r_dist);
	float edge_curve = smoothstep(0.22, 0.80, r_dist);
	float lens_slope = r_curve * (0.60 + 0.56 * r_curve);

	vec2 asp_corr = vec2(SCREEN_PIXEL_SIZE.x / max(SCREEN_PIXEL_SIZE.y, 0.00001), 1.0);
	vec2 refract_dir = rad_dir * lens_slope + sil_grad * 0.55;
	vec2 uv_shift = refract_dir * refract_strength * body_cov * asp_corr;

	vec2 chrom_shift = uv_shift * (0.24 * edge_curve);
	vec2 uv_g = clamp(SCREEN_UV - uv_shift, vec2(0.001), vec2(0.999));
	vec2 uv_r = clamp(SCREEN_UV - uv_shift - chrom_shift, vec2(0.001), vec2(0.999));
	vec2 uv_b = clamp(SCREEN_UV - uv_shift + chrom_shift, vec2(0.001), vec2(0.999));

	vec3 bg_refract = vec3(
		texture(screen_tex, uv_r).r,
		texture(screen_tex, uv_g).g,
		texture(screen_tex, uv_b).b
	);

	// Exact zero-washout color recovery:
	// Inside body (a_c == 1.0), tex_3d.rgb is already exact rich Studio Ghibli coral-honey!
	// On outermost AA feather pixels (a_c < 0.85), softly blend toward sunset-coral rim to eliminate dark fringes.
	vec3 rim_coral = mix(vec3(0.84, 0.72, 0.68), vec3(0.94, 0.42, 0.22), smoothstep(0.0, 0.92, vit));
	vec3 charlie_rgb = mix(rim_coral, tex_3d.rgb, smoothstep(0.18, 0.86, a_c));

	// Subtle, jewel-like translucent glass refraction through Charlie's outer belly & sweeping tail:
	// Warm honey-amber filtered background gently shines through (max 18%) without EVER dulling her saturation!
	vec3 warm_filter = mix(vec3(0.92, 0.82, 0.78), vec3(1.00, 0.54, 0.26), smoothstep(0.0, 0.92, vit));
	vec3 bg_glass = bg_refract * warm_filter * 0.95;
	// Keep face area (upper center) crystal clear; allow gentle glass transmission across lower belly & tail
	float face_protect = 1.0 - smoothstep(0.10, 0.34, length((UV - vec2(0.50, 0.46)) * vec2(1.15, 1.35)));
	float trans_amt = (0.14 + 0.08 * smoothstep(0.18, 0.56, r_dist)) * (1.0 - face_protect * 0.85) * smoothstep(0.25, 0.85, a_c);
	trans_amt *= mix(1.25, 1.0, vit); // slightly glassier when fragile (0 pearls)
	vec3 body_rgb = mix(charlie_rgb, bg_glass, clamp(trans_amt, 0.0, 0.24));

	// Rich warm Studio Ghibli golden-tangerine bioluminescent aura following Charlie's sculpted silhouette
	float blur_sil = a_c * 0.20 + ring1 * 0.36 + ring2 * 0.26 + ring3 * 0.18;
	float edge_dist = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float quad_fade = smoothstep(0.015, 0.14, edge_dist);
	float breath_glow = 0.94 + 0.06 * sin(time_sec * 2.7);
	float vit_glow = mix(0.32, 1.0, vit);
	float aura_field = clamp(pow(max(blur_sil, 0.0), 1.15) * 0.98, 0.0, 1.0);
	float aura_alpha = clamp(aura_field * aura_intensity * vit_glow * breath_glow * quad_fade, 0.0, 0.44);
	aura_alpha *= (1.0 - clamp(invuln_flash, 0.0, 1.0) * 0.35);

	vec3 aura_col = mix(vec3(1.00, 0.58, 0.20), vec3(0.94, 0.34, 0.18), 0.38);
	aura_col = mix(aura_col, glow_color.rgb, 0.20);
	aura_col = mix(vec3(0.92, 0.82, 0.78), aura_col, smoothstep(0.0, 0.92, vit));
	aura_col = mix(aura_col, clamp(flavor_tint.rgb * 1.12, vec3(0.0), vec3(1.0)), flav_amt * 0.28);

	// Butter-smooth composite over warm golden-tangerine aura (zero dark border, zero washout!)
	float invuln_fade = 1.0 - clamp(invuln_flash, 0.0, 1.0) * 0.32;
	float eff_body = body_cov * invuln_fade;
	float out_alpha = clamp(eff_body + aura_alpha * (1.0 - eff_body), 0.0, 1.0);
	vec3 out_rgb = (out_alpha > 0.0005)
		? (body_rgb * eff_body + aura_col * aura_alpha * (1.0 - eff_body)) / out_alpha
		: aura_col;

	COLOR = vec4(clamp(out_rgb, vec3(0.0), vec3(1.0)), out_alpha);
}
