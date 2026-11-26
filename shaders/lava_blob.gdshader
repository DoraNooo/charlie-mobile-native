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

float convection_bubble(vec2 p, vec2 center, float r_outer, float r_inner) {
	float d = length(p - center);
	float outer = (1.0 - smoothstep(r_outer * 0.25, r_outer, d)) * 0.55;
	float inner = (1.0 - smoothstep(r_inner * 0.15, r_inner, d)) * 0.85;
	return outer + inner;
}

void fragment() {
	// Map UV [0..1] to [-2.6..2.6] (BODY_QUAD_SCALE = 5.2) — zero square clipping around aura & droplets
	vec2 p = (UV - vec2(0.5)) * 5.2;

	// Velocity-aligned squash & stretch
	vec2 fwd = normalize(vel_dir + vec2(0.0001, 0.0));
	vec2 side = vec2(-fwd.y, fwd.x);
	vec2 aligned = vec2(dot(p, fwd), dot(p, side));
	vec2 warped = vec2(aligned.x / (1.0 + stretch * 0.24), aligned.y * (1.0 + stretch * 0.14));

	// Organic gentle lava-lamp wobble + gulp wave
	float ang = atan(warped.y, warped.x);
	float wobble = sin(ang * 3.0 + TIME * 2.8) * 0.032 + cos(ang * 5.0 - TIME * 2.1) * 0.020;
	float body_r = 0.66 + wobble + gulp_wave * 0.12 * smoothstep(-0.3, 0.9, cos(ang));

	// Metaball scalar field: main body + active diegetic lava droplets with heal-bloom scale
	float field = metaball_field(warped, vec2(0.0), body_r);
	if (droplet_count >= 1 && drop_scale_0 > 0.01) {
		field += metaball_field(p, drop_pos_0, 0.24 * drop_scale_0);
	}
	if (droplet_count >= 2 && drop_scale_1 > 0.01) {
		field += metaball_field(p, drop_pos_1, 0.22 * drop_scale_1);
	}
	if (droplet_count >= 3 && drop_scale_2 > 0.01) {
		field += metaball_field(p, drop_pos_2, 0.21 * drop_scale_2);
	}

	// Smooth anti-aliased liquid boundary at field == 1.0
	float mask = smoothstep(0.92, 1.08, field);

	// Lush warm bioluminescent outer halo tinted by glow_color, fading cleanly to 0 before quad edges
	float quad_edge = max(abs(p.x), abs(p.y));
	float edge_fade = 1.0 - smoothstep(1.88, 2.50, quad_edge);
	float exp_glow = exp(-max(1.0 - field, 0.0) * 2.55) * smoothstep(0.04, 0.88, field);
	float aura = exp_glow * 0.68 * edge_fade;

	// 4-stop incandescent gradient: deep sunset-coral rim -> edge_color -> saturated mid-body -> cream-gold hot core
	vec3 deep_edge = edge_color.rgb * vec3(0.72, 0.42, 0.54);
	vec3 mid_body = clamp(core_color.rgb * vec3(1.06, 1.02, 0.94), 0.0, 1.0);
	vec3 hot_core = mix(core_color.rgb, vec3(1.0, 0.97, 0.84), 0.86);
	float inner_t = clamp((field - 1.0) * 0.46, 0.0, 1.0);
	vec3 body_col = mix(deep_edge, edge_color.rgb, smoothstep(0.0, 0.24, inner_t));
	body_col = mix(body_col, mid_body, smoothstep(0.20, 0.62, inner_t));
	body_col = mix(body_col, hot_core, smoothstep(0.56, 0.98, inner_t));

	// 4 orbiting translucent internal convection bubbles with warm glowing cores
	float b1 = convection_bubble(warped, vec2(cos(TIME * 0.86) * 0.24, sin(TIME * 0.68) * 0.21), 0.23, 0.10);
	float b2 = convection_bubble(warped, vec2(sin(TIME * 1.08 + 1.4) * 0.27, cos(TIME * 0.92 + 0.8) * 0.19), 0.19, 0.085);
	float b3 = convection_bubble(warped, vec2(cos(TIME * 0.74 + 3.1) * 0.20, sin(TIME * 0.96 + 2.3) * 0.26), 0.17, 0.075);
	float b4 = convection_bubble(warped, vec2(sin(TIME * 0.66 + 4.7) * 0.16, cos(TIME * 0.80 + 3.9) * 0.17), 0.14, 0.062);
	float bubbles = b1 * 0.18 + b2 * 0.15 + b3 * 0.13 + b4 * 0.11;
	body_col += vec3(1.0, 0.97, 0.82) * bubbles;

	// Bottom-right warm subsurface bounce glow (screen-space p)
	float bounce = 1.0 - smoothstep(0.05, 0.58, length(p - vec2(0.26, 0.28)));
	body_col += mix(glow_color.rgb, vec3(1.0, 0.90, 0.64), 0.48) * bounce * 0.28;

	// Crisp glossy tilted elliptical top-left specular highlight + bright pinpoint secondary sparkle
	vec2 sp_off = p - vec2(-0.23, -0.27);
	float sc = cos(-0.56);
	float ss = sin(-0.56);
	vec2 sp_rot = vec2(sc * sp_off.x - ss * sp_off.y, ss * sp_off.x + sc * sp_off.y);
	float ellip_d = length(sp_rot / vec2(0.22, 0.10));
	float spec_main = (1.0 - smoothstep(0.42, 0.96, ellip_d)) * 0.42 + (1.0 - smoothstep(0.16, 0.58, ellip_d)) * 0.24;
	float spec_pin = 1.0 - smoothstep(0.014, 0.058, length(p - vec2(-0.06, -0.37)));
	body_col += vec3(1.0, 0.995, 0.97) * (spec_main + spec_pin * 0.64);

	// Soft luminous glass-like rim stroke: rgba(255, 245, 228, 0.38)
	float glass_rim = smoothstep(0.94, 1.06, field) * (1.0 - smoothstep(1.08, 1.32, field));
	body_col = mix(body_col, vec3(1.0, 0.96, 0.89), glass_rim * 0.38);

	// Vulnerable danger ring when 0 droplets left
	float ring_d = abs(length(p) - (0.98 + sin(TIME * 7.0) * 0.08));
	float danger_ring = (1.0 - smoothstep(0.01, 0.06, ring_d)) * danger_pulse;

	vec3 aura_rgb = clamp(mix(glow_color.rgb * 1.12, vec3(1.0, 0.90, 0.68), smoothstep(0.26, 0.95, field) * 0.42), 0.0, 1.0);
	vec3 final_rgb = mix(aura_rgb, body_col, mask);
	final_rgb = mix(final_rgb, vec3(1.0, 0.30, 0.36), danger_ring * 0.85);
	float final_alpha = max(mask, max(aura, danger_ring * 0.75));
	final_alpha *= (1.0 - invuln_flash * 0.38);

	COLOR = vec4(final_rgb, clamp(final_alpha, 0.0, 1.0));
}
