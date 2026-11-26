shader_type canvas_item;

// Real-time GPU Metaball / Lava-Lamp shader for la petite Charlie (Vulkan/Metal 120 FPS)
uniform vec4 core_color : source_color = vec4(1.0, 0.78, 0.50, 1.0);
uniform vec4 edge_color : source_color = vec4(0.96, 0.38, 0.42, 1.0);
uniform vec2 vel_dir = vec2(1.0, 0.0);
uniform float stretch = 0.0;
uniform float gulp_wave = 0.0;
uniform float danger_pulse = 0.0;
uniform float invuln_flash = 0.0;

// Up to 3 diegetic tethered lava-lamp droplets in local UV space (-1..1)
uniform int droplet_count = 3;
uniform vec2 drop_pos_0 = vec2(-0.55, -0.25);
uniform vec2 drop_pos_1 = vec2(-0.62, 0.0);
uniform vec2 drop_pos_2 = vec2(-0.55, 0.25);

float metaball_field(vec2 p, vec2 center, float r) {
	vec2 d = p - center;
	return (r * r) / max(dot(d, d), 0.0005);
}

void fragment() {
	// Map UV [0..1] to local [-1.8..1.8] so trailing metaball droplets merge seamlessly
	vec2 p = (UV - vec2(0.5)) * 3.6;

	// Velocity-aligned squash & stretch
	vec2 fwd = normalize(vel_dir + vec2(0.0001, 0.0));
	vec2 side = vec2(-fwd.y, fwd.x);
	vec2 aligned = vec2(dot(p, fwd), dot(p, side));
	vec2 warped = vec2(aligned.x / (1.0 + stretch * 0.24), aligned.y * (1.0 + stretch * 0.14));

	// Organic gentle lava-lamp wobble
	float ang = atan(warped.y, warped.x);
	float wobble = sin(ang * 3.0 + TIME * 2.8) * 0.032 + cos(ang * 5.0 - TIME * 2.1) * 0.02;
	float body_r = 0.66 + wobble + gulp_wave * 0.12 * smoothstep(-0.3, 0.9, cos(ang));

	// Metaball scalar field: main body + active diegetic lava droplets!
	float field = metaball_field(warped, vec2(0.0), body_r);
	if (droplet_count >= 1) field += metaball_field(p, drop_pos_0, 0.22);
	if (droplet_count >= 2) field += metaball_field(p, drop_pos_1, 0.20);
	if (droplet_count >= 3) field += metaball_field(p, drop_pos_2, 0.19);

	// Soft outer bioluminescent aura
	float aura = smoothstep(0.18, 0.95, field) * 0.34;

	// Smooth anti-aliased liquid boundary at field == 1.0
	float mask = smoothstep(0.92, 1.08, field);

	// Internal convection wax bubbles
	float b1 = smoothstep(0.28, 0.05, length(warped - vec2(cos(TIME * 0.8) * 0.22, sin(TIME * 0.6) * 0.22)));
	float b2 = smoothstep(0.22, 0.04, length(warped - vec2(sin(TIME * 1.1) * 0.26, cos(TIME * 0.9) * 0.18)));

	// 3D liquid shading (warm hot center -> glossy coral rim -> specular highlight)
	float inner_t = clamp((field - 1.0) * 0.45, 0.0, 1.0);
	vec3 body_col = mix(edge_color.rgb, core_color.rgb, smoothstep(0.0, 0.85, inner_t));
	body_col += vec3(1.0, 0.94, 0.78) * (b1 * 0.16 + b2 * 0.12);

	// Top-left glossy liquid catchlight
	float spec = smoothstep(0.26, 0.02, length(warped - vec2(-0.24, -0.26)));
	body_col += vec3(1.0) * spec * 0.32;

	// Fresnel rim highlight
	float rim = smoothstep(1.45, 0.98, field) * mask;
	body_col += core_color.rgb * rim * 0.25;

	// Vulnerable danger ring when 0 droplets left
	float ring_d = abs(length(p) - (0.98 + sin(TIME * 7.0) * 0.08));
	float danger_ring = smoothstep(0.06, 0.01, ring_d) * danger_pulse;

	vec3 final_rgb = mix(edge_color.rgb, body_col, mask);
	final_rgb = mix(final_rgb, vec3(1.0, 0.30, 0.36), danger_ring * 0.85);
	float final_alpha = max(mask, max(aura, danger_ring * 0.75));
	final_alpha *= (1.0 - invuln_flash * 0.38);

	COLOR = vec4(final_rgb, clamp(final_alpha, 0.0, 1.0));
}
