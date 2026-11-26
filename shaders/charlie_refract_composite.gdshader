shader_type canvas_item;
render_mode blend_mix;

// Refractive Optical Compositor for 3D Hybride Charlie Slime.
// Magnifies & refracts the real 2D world behind Charlie via BackBufferCopy,
// applies warm Beer-Lambert jelly absorption + subsurface honey glow + subtle chromatic edge dispersion,
// wraps Charlie in a soft exponential outer bioluminescent aura, and alpha-composites
// the 3D SubViewport render (premultiplied alpha) cleanly on top.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

uniform vec4 core_color : source_color = vec4(1.0, 0.71, 0.42, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.42, 0.34, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.50, 0.28, 1.0);
uniform vec4 flavor_tint : source_color = vec4(1.0, 0.71, 0.42, 0.0);

uniform float vitality_ratio = 1.0;
uniform float invuln_flash = 0.0;
uniform float refract_strength = 0.024;
uniform float aura_intensity = 0.68;
uniform float time_sec = 0.0;

void fragment() {
	// 4-tap Rotated Grid Super-Sampling (RGSS) on the 256x256 MSAA_4X SubViewport texture:
	// guarantees silky butter-smooth subpixel downscaling (~85px gameplay scale) with zero stair-stepping!
	vec2 aa_step = clamp(fwidth(UV) * 0.30, TEXTURE_PIXEL_SIZE * 0.45, vec2(0.006));
	vec4 t0 = texture(TEXTURE, clamp(UV + vec2( aa_step.x * 0.35,  aa_step.y * 0.90), vec2(0.001), vec2(0.999)));
	vec4 t1 = texture(TEXTURE, clamp(UV + vec2(-aa_step.x * 0.90,  aa_step.y * 0.35), vec2(0.001), vec2(0.999)));
	vec4 t2 = texture(TEXTURE, clamp(UV + vec2(-aa_step.x * 0.35, -aa_step.y * 0.90), vec2(0.001), vec2(0.999)));
	vec4 t3 = texture(TEXTURE, clamp(UV + vec2( aa_step.x * 0.90, -aa_step.y * 0.35), vec2(0.001), vec2(0.999)));
	vec4 tex_3d = (t0 + t1 + t2 + t3) * 0.25;
	float a_c = tex_3d.a;

	// Lightweight silhouette rings on the 3D render to track Charlie's live organic contour & feathered aura
	float a_r = texture(TEXTURE, clamp(UV + vec2(0.024, 0.0), vec2(0.002), vec2(0.998))).a;
	float a_l = texture(TEXTURE, clamp(UV - vec2(0.024, 0.0), vec2(0.002), vec2(0.998))).a;
	float a_d = texture(TEXTURE, clamp(UV + vec2(0.0, 0.024), vec2(0.002), vec2(0.998))).a;
	float a_u = texture(TEXTURE, clamp(UV - vec2(0.0, 0.024), vec2(0.002), vec2(0.998))).a;
	float ring1 = (a_r + a_l + a_d + a_u) * 0.25;

	float a_d1 = texture(TEXTURE, clamp(UV + vec2(0.062, 0.062), vec2(0.002), vec2(0.998))).a;
	float a_d2 = texture(TEXTURE, clamp(UV + vec2(-0.062, 0.062), vec2(0.002), vec2(0.998))).a;
	float a_d3 = texture(TEXTURE, clamp(UV + vec2(0.062, -0.062), vec2(0.002), vec2(0.998))).a;
	float a_d4 = texture(TEXTURE, clamp(UV + vec2(-0.062, -0.062), vec2(0.002), vec2(0.998))).a;
	float ring2 = (a_d1 + a_d2 + a_d3 + a_d4) * 0.25;

	float a_w1 = texture(TEXTURE, clamp(UV + vec2(0.118, 0.0), vec2(0.002), vec2(0.998))).a;
	float a_w2 = texture(TEXTURE, clamp(UV - vec2(0.118, 0.0), vec2(0.002), vec2(0.998))).a;
	float a_w3 = texture(TEXTURE, clamp(UV + vec2(0.0, 0.118), vec2(0.002), vec2(0.998))).a;
	float a_w4 = texture(TEXTURE, clamp(UV - vec2(0.0, 0.118), vec2(0.002), vec2(0.998))).a;
	float ring3 = (a_w1 + a_w2 + a_w3 + a_w4) * 0.25;

	// Smooth subpixel AA silhouette edge mask: 0 outside Charlie, 1 inside Charlie's jelly volume
	float body_mask = smoothstep(0.02, 0.18, a_c);

	// Radial convex-lens curvature blended with live 5-lobe silhouette normal
	vec2 rel = (UV - vec2(0.5)) * 2.0;
	float r_dist = length(rel);
	vec2 rad_dir = (r_dist > 0.001) ? (rel / r_dist) : vec2(0.0);
	vec2 sil_grad = vec2(a_l - a_r, a_u - a_d);

	float r_curve = smoothstep(0.02, 0.72, r_dist);
	float edge_curve = smoothstep(0.24, 0.76, r_dist);
	float lens_slope = r_curve * (0.68 + 0.62 * r_curve);

	// Aspect-corrected screen-space magnification shift (warps stars/creatures through Charlie's jelly!)
	vec2 asp_corr = vec2(SCREEN_PIXEL_SIZE.x / max(SCREEN_PIXEL_SIZE.y, 0.00001), 1.0);
	vec2 refract_dir = rad_dir * lens_slope + sil_grad * 0.45;
	vec2 uv_shift = refract_dir * refract_strength * body_mask * asp_corr;

	// Subtle chromatic edge dispersion across Charlie's curved jelly rim
	vec2 chrom_shift = uv_shift * (0.24 * edge_curve);
	vec2 uv_g = clamp(SCREEN_UV - uv_shift, vec2(0.001), vec2(0.999));
	vec2 uv_r = clamp(SCREEN_UV - uv_shift - chrom_shift, vec2(0.001), vec2(0.999));
	vec2 uv_b = clamp(SCREEN_UV - uv_shift + chrom_shift, vec2(0.001), vec2(0.999));

	vec3 bg_refract = vec3(
		texture(screen_tex, uv_r).r,
		texture(screen_tex, uv_g).g,
		texture(screen_tex, uv_b).b
	);

	// Rich, lush warm honey-apricot-to-coral saturation (#ffb56b inner -> #ff6b57 rich coral rim)
	// Anchored to Charlie's iconic palette so bright cosmic skies NEVER wash her out and
	// dark green/cyan worlds NEVER turn her belly muddy olive/brown!
	float vit = clamp(vitality_ratio, 0.0, 1.0);
	vec3 rich_honey = mix(vec3(1.0, 0.71, 0.42), core_color.rgb, 0.34);
	vec3 rich_coral = mix(vec3(1.0, 0.42, 0.34), edge_color.rgb, 0.36);
	vec3 sss_col = mix(rich_honey, rich_coral, edge_curve * 0.62);
	sss_col = mix(sss_col, vec3(0.92, 0.80, 0.76), (1.0 - vit) * 0.56);

	// Jewel-like flavor wash glows softly in Charlie's belly interior while keeping her coral rim vivid
	float belly_flavor = clamp(flavor_tint.a, 0.0, 1.0) * (1.0 - edge_curve * 0.72);
	sss_col = mix(sss_col, clamp(flavor_tint.rgb * 1.08, vec3(0.0), vec3(1.0)), belly_flavor * 0.52);

	// Warm Beer-Lambert filtering on refracted world light
	vec3 warm_absorb = mix(vec3(1.0, 0.86, 0.70), clamp(rich_honey * vec3(1.02, 0.96, 0.88), vec3(0.0), vec3(1.0)), 0.45);
	warm_absorb = mix(warm_absorb, vec3(0.96, 0.90, 0.88), (1.0 - vit) * 0.48);
	warm_absorb = mix(warm_absorb, clamp(flavor_tint.rgb * 1.10, vec3(0.42), vec3(1.0)), belly_flavor * 0.36);
	vec3 bg_refr = bg_refract * warm_absorb;

	// Clean energy-conserving optical composite:
	// - Inside Charlie's silhouette, preserve premultiplied 3D render and fill transmittance cleanly with
	//   luminous internal honey-coral scatter + 0.30x attenuated refracted world (NEVER additive blowout!).
	// - Right at the outer AA silhouette rim (where ring1 drops), unpremultiply cleanly so there is
	//   ZERO dark fringe and ZERO background bleed along the feathered edge!
	float inside_fill = smoothstep(0.08, 0.44, ring1);
	float eff_alpha = mix(0.92, a_c, inside_fill);
	float transmittance = clamp(1.0 - eff_alpha, 0.0, 0.65) * body_mask;
	vec3 unpremul_3d = (a_c > 0.008) ? clamp(tex_3d.rgb / a_c, vec3(0.0), vec3(1.0)) : rich_coral;
	vec3 fg_rgb = mix(unpremul_3d * eff_alpha, tex_3d.rgb, inside_fill);

	vec3 body_comp = fg_rgb + sss_col * (transmittance * 0.78) + bg_refr * (transmittance * 0.30);

	// Soft, smooth, feathered warm coral-amber outer bioluminescent glow (exp(-dist * 3.8), zero quad clipping)
	float blur_sil = a_c * 0.22 + ring1 * 0.34 + ring2 * 0.26 + ring3 * 0.18;
	float dist_beyond = max(r_dist - 0.64, 0.0);
	float exp_falloff = exp(-dist_beyond * 3.8);
	float edge_dist = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float quad_fade = smoothstep(0.01, 0.16, edge_dist);
	float breath_glow = 0.94 + 0.06 * sin(time_sec * 2.7);
	float vit_glow = mix(0.36, 1.0, vit);
	float aura_field = clamp(blur_sil * 0.56 + exp_falloff * (0.28 + 0.72 * clamp(blur_sil * 2.2, 0.0, 1.0)) * 0.48, 0.0, 1.0);
	float aura_alpha = clamp(aura_field * aura_intensity * vit_glow * breath_glow * quad_fade, 0.0, 0.66);
	aura_alpha *= (1.0 - clamp(invuln_flash, 0.0, 1.0) * 0.35);

	vec3 aura_col = mix(vec3(1.0, 0.56, 0.26), vec3(1.0, 0.42, 0.34), 0.38);
	aura_col = mix(aura_col, glow_color.rgb, 0.32);
	aura_col = mix(aura_col, vec3(0.96, 0.86, 0.82), (1.0 - vit) * 0.50);
	aura_col = mix(aura_col, clamp(flavor_tint.rgb * 1.14, vec3(0.0), vec3(1.0)), clamp(flavor_tint.a, 0.0, 1.0) * 0.26);

	// Seamless butter-smooth transition from world -> feathered warm coral-amber aura -> refracted 3D Charlie
	vec3 out_rgb = mix(aura_col, body_comp, body_mask);
	float out_alpha = clamp(body_mask + aura_alpha * (1.0 - body_mask), 0.0, 1.0);

	COLOR = vec4(clamp(out_rgb, vec3(0.0), vec3(1.0)), out_alpha);
}
