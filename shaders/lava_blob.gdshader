shader_type canvas_item;

// Real-time GPU Metaball / Lava-Lamp shader for la petite Charlie (Vulkan/Metal 120 FPS)
uniform vec4 core_color : source_color = vec4(1.0, 0.78, 0.50, 1.0);
uniform vec4 edge_color : source_color = vec4(0.96, 0.38, 0.42, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.50, 0.28, 1.0);
uniform vec2 vel_dir = vec2(1.0, 0.0);
uniform float stretch = 0.0;
uniform float gulp_wave = 0.0;
uniform float danger_pulse = 0.0;
uniform float invuln_flash = 0.0;

// Up to 3 diegetic tethered lava-lamp droplets in local space + heal-bloom scales
uniform int droplet_count = 3;
uniform vec2 drop_pos_0 = vec2(-0.55, -0.25);
uniform vec2 drop_pos_1 = vec2(-0.62, 0.0);
uniform vec2 drop_pos_2 = vec2(-0.55, 0.25);
uniform float drop_scale_0 = 1.0;
uniform float drop_scale_1 = 1.0;
uniform float drop_scale_2 = 1.0;

float metaball_field(vec2 p, vec2 center, float r) {
	vec2 d = p - center;
	return (r * r) / max(dot(d, d), 0.0005);
}

float convection_blob(vec2 p, vec2 center, float radius) {
	float d = length(p - center);
	return 1.0 - smoothstep(radius * 0.12, radius, d);
}

void fragment() {
	// Map UV [0..1] to [-2.6..2.6] (BODY_QUAD_SCALE = 5.2) — zero square clipping around aura & droplets
	vec2 p = (UV - vec2(0.5)) * 5.2;

	// Velocity-aligned viscous squash & stretch
	vec2 fwd = normalize(vel_dir + vec2(0.0001, 0.0));
	vec2 side = vec2(-fwd.y, fwd.x);
	vec2 aligned = vec2(dot(p, fwd), dot(p, side));
	vec2 warped = vec2(aligned.x / (1.0 + stretch * 0.24), aligned.y * (1.0 + stretch * 0.14));

	// Slow, heavy undulating viscous surface wobble (2nd & 3rd-order smooth oil deformation, zero flame jitter)
	float ang = atan(warped.y, warped.x);
	float wobble = sin(ang * 2.0 + TIME * 1.15) * 0.036 + cos(ang * 3.0 - TIME * 0.85) * 0.026;
	float body_r = 0.66 + wobble + gulp_wave * 0.12 * smoothstep(-0.3, 0.9, cos(ang));

	// Heavier viscous metaball field: main body + thick trailing wax droplets that form stretchy liquid necks
	float field = metaball_field(warped, vec2(0.0), body_r);
	if (droplet_count >= 1 && drop_scale_0 > 0.01) {
		field += metaball_field(p, drop_pos_0, 0.27 * drop_scale_0);
	}
	if (droplet_count >= 2 && drop_scale_1 > 0.01) {
		field += metaball_field(p, drop_pos_1, 0.25 * drop_scale_1);
	}
	if (droplet_count >= 3 && drop_scale_2 > 0.01) {
		field += metaball_field(p, drop_pos_2, 0.23 * drop_scale_2);
	}

	// Crisp, wet, glossy liquid meniscus at field == 1.0
	float mask = smoothstep(0.94, 1.03, field);

	// Subtle, soft, translucent warm glow hugging the liquid silhouette (no fireball halo)
	float quad_edge = max(abs(p.x), abs(p.y));
	float edge_fade = 1.0 - smoothstep(1.88, 2.50, quad_edge);
	float exp_glow = exp(-max(1.0 - field, 0.0) * 4.2) * smoothstep(0.18, 0.94, field);
	float aura = exp_glow * 0.18 * edge_fade;

	// Rich, velvety, translucent molten-wax / thick-oil subsurface shading (zero white-hot fire core)
	vec3 deep_edge = edge_color.rgb * vec3(0.56, 0.34, 0.42);
	vec3 mid_oil = mix(edge_color.rgb, core_color.rgb, 0.52);
	vec3 warm_center = clamp(core_color.rgb * vec3(1.04, 1.01, 0.95), 0.0, 1.0);
	float inner_t = clamp((field - 1.0) * 0.44, 0.0, 1.0);
	vec3 body_col = mix(deep_edge, edge_color.rgb, smoothstep(0.0, 0.22, inner_t));
	body_col = mix(body_col, mid_oil, smoothstep(0.18, 0.62, inner_t));
	body_col = mix(body_col, warm_center, smoothstep(0.54, 0.96, inner_t));

	// Slow heavy internal wax convection: 4 large, soft, slow-drifting wax density blobs
	float interior_mask = smoothstep(1.04, 1.38, field);
	float c1 = convection_blob(warped, vec2(cos(TIME * 0.38) * 0.22, sin(TIME * 0.31) * 0.20), 0.34);
	float c2 = convection_blob(warped, vec2(sin(TIME * 0.44 + 1.6) * 0.25, cos(TIME * 0.35 + 0.9) * 0.21), 0.30);
	float c3 = convection_blob(warped, vec2(cos(TIME * 0.33 + 3.2) * 0.21, sin(TIME * 0.41 + 2.4) * 0.24), 0.28);
	float c4 = convection_blob(warped, vec2(sin(TIME * 0.29 + 4.9) * 0.18, cos(TIME * 0.36 + 4.1) * 0.19), 0.25);
	float warm_wax = clamp(c1 * 0.48 + c2 * 0.38 + c3 * 0.28, 0.0, 1.0);
	float dense_wax = clamp(c4 * 0.55, 0.0, 1.0);
	vec3 wax_lume = clamp(mix(core_color.rgb, glow_color.rgb * 1.08, 0.35), 0.0, 1.0);
	body_col = mix(body_col, wax_lume, warm_wax * 0.26 * interior_mask);
	body_col = mix(body_col, deep_edge, dense_wax * 0.18 * interior_mask);

	// Soft warm bottom-right internal caustic refraction glow (light passing through thick colored oil)
	float caustic_d = length((p - vec2(0.24, 0.28)) / vec2(0.52, 0.46));
	float caustic = (1.0 - smoothstep(0.10, 0.95, caustic_d)) * smoothstep(1.02, 1.45, field);
	vec3 caustic_col = mix(core_color.rgb, glow_color.rgb * vec3(1.12, 1.02, 0.86), 0.42);
	body_col = mix(body_col, clamp(body_col + caustic_col * 0.32, 0.0, 1.0), caustic * 0.72);

	// Signature wet-oil specular highlight: curved glossy crescent hugging upper-left dome + crisp secondary dot
	vec2 spec_c = p - vec2(0.04, 0.05);
	float spec_r = length(spec_c);
	float spec_ang = atan(spec_c.y, spec_c.x);
	float ang_diff = abs(atan(sin(spec_ang + 2.38), cos(spec_ang + 2.38)));
	float arc_taper = 1.0 - smoothstep(0.18, 0.62, ang_diff);
	float radial_band = 1.0 - smoothstep(0.015, 0.068 * mix(0.35, 1.0, arc_taper), abs(spec_r - 0.47));
	float spec_inside = smoothstep(1.02, 1.18, field);
	float crescent = radial_band * arc_taper * spec_inside;
	float spec_dot = (1.0 - smoothstep(0.016, 0.056, length(p - vec2(-0.07, -0.45)))) * spec_inside;
	float wet_spec = clamp(crescent * 0.78 + spec_dot * 0.72, 0.0, 0.92);
	body_col = mix(body_col, vec3(1.0, 0.99, 0.97), wet_spec);

	// Subtle translucent glass-like meniscus rim sheen (brighter on upper-left light side, rich on shadow side)
	float rim_band = smoothstep(0.95, 1.04, field) * (1.0 - smoothstep(1.05, 1.24, field));
	float light_side = smoothstep(-0.35, 0.55, dot(normalize(p + vec2(0.0001)), normalize(vec2(-0.7, -0.75))));
	vec3 rim_tint = mix(core_color.rgb * 1.06, vec3(1.0, 0.97, 0.92), 0.62);
	body_col = mix(body_col, rim_tint, rim_band * mix(0.14, 0.40, light_side));

	// Vulnerable danger ring when 0 droplets left
	float ring_d = abs(length(p) - (0.98 + sin(TIME * 7.0) * 0.08));
	float danger_ring = (1.0 - smoothstep(0.01, 0.06, ring_d)) * danger_pulse;

	vec3 aura_rgb = clamp(mix(edge_color.rgb, glow_color.rgb, 0.65), 0.0, 1.0);
	vec3 final_rgb = mix(aura_rgb, body_col, mask);
	final_rgb = mix(final_rgb, vec3(1.0, 0.30, 0.36), danger_ring * 0.85);
	float final_alpha = max(mask, max(aura, danger_ring * 0.75));
	final_alpha *= (1.0 - invuln_flash * 0.38);

	COLOR = vec4(final_rgb, clamp(final_alpha, 0.0, 1.0));
}
