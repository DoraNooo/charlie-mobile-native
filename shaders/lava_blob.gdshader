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
		field += metaball_field(p, drop_pos_0, 0.22 * drop_scale_0);
	}
	if (droplet_count >= 2 && drop_scale_1 > 0.01) {
		field += metaball_field(p, drop_pos_1, 0.20 * drop_scale_1);
	}
	if (droplet_count >= 3 && drop_scale_2 > 0.01) {
		field += metaball_field(p, drop_pos_2, 0.19 * drop_scale_2);
	}

	// Smooth anti-aliased liquid boundary at field == 1.0
	float mask = smoothstep(0.92, 1.08, field);

	// Warm exponential outer radial glow tinted by glow_color, fading cleanly to 0 before quad edges
	float quad_edge = max(abs(p.x), abs(p.y));
	float edge_fade = 1.0 - smoothstep(1.95, 2.52, quad_edge);
	float exp_glow = exp(-max(1.0 - field, 0.0) * 3.4) * smoothstep(0.06, 0.90, field);
	float aura = exp_glow * 0.46 * edge_fade;

	// 4-stop incandescent gradient: deep_edge -> edge_color -> core_color -> hot_core (cream-gold)
	vec3 deep_edge = edge_color.rgb * vec3(0.76, 0.54, 0.62);
	vec3 hot_core = mix(core_color.rgb, vec3(1.0, 0.96, 0.84), 0.72);
	float inner_t = clamp((field - 1.0) * 0.42, 0.0, 1.0);
	vec3 body_col = mix(deep_edge, edge_color.rgb, smoothstep(0.0, 0.22, inner_t));
	body_col = mix(body_col, core_color.rgb, smoothstep(0.20, 0.68, inner_t));
	body_col = mix(body_col, hot_core, smoothstep(0.64, 1.0, inner_t));

	// 4 orbiting translucent internal convection bubbles with soft inner cores
	float b1 = convection_bubble(warped, vec2(cos(TIME * 0.82) * 0.23, sin(TIME * 0.64) * 0.21), 0.22, 0.09);
	float b2 = convection_bubble(warped, vec2(sin(TIME * 1.05 + 1.4) * 0.26, cos(TIME * 0.88 + 0.8) * 0.18), 0.18, 0.075);
	float b3 = convection_bubble(warped, vec2(cos(TIME * 0.71 + 3.1) * 0.19, sin(TIME * 0.94 + 2.3) * 0.25), 0.16, 0.065);
	float b4 = convection_bubble(warped, vec2(sin(TIME * 0.62 + 4.7) * 0.15, cos(TIME * 0.76 + 3.9) * 0.16), 0.13, 0.055);
	float bubbles = b1 * 0.12 + b2 * 0.10 + b3 * 0.09 + b4 * 0.08;
	body_col += vec3(1.0, 0.95, 0.80) * bubbles;

	// Bottom-right warm subsurface bounce glow (screen-space p)
	float bounce = 1.0 - smoothstep(0.06, 0.56, length(p - vec2(0.26, 0.28)));
	body_col += mix(glow_color.rgb, vec3(1.0, 0.86, 0.60), 0.45) * bounce * 0.24;

	// Screen-space tilted elliptical top-left specular highlight + pinpoint secondary sparkle
	vec2 sp_off = p - vec2(-0.23, -0.27);
	float sc = cos(-0.56);
	float ss = sin(-0.56);
	vec2 sp_rot = vec2(sc * sp_off.x - ss * sp_off.y, ss * sp_off.x + sc * sp_off.y);
	float ellip_d = length(sp_rot / vec2(0.22, 0.105));
	float spec_main = 1.0 - smoothstep(0.22, 1.0, ellip_d);
	float spec_pin = 1.0 - smoothstep(0.012, 0.062, length(p - vec2(-0.08, -0.37)));
	body_col += vec3(1.0, 0.99, 0.96) * (spec_main * 0.36 + spec_pin * 0.42);

	// Soft luminous glass-like rim stroke: rgba(255, 242, 224, 0.30)
	float glass_rim = smoothstep(0.94, 1.06, field) * (1.0 - smoothstep(1.08, 1.34, field));
	body_col = mix(body_col, vec3(1.0, 0.949, 0.878), glass_rim * 0.30);

	// Vulnerable danger ring when 0 droplets left
	float ring_d = abs(length(p) - (0.98 + sin(TIME * 7.0) * 0.08));
	float danger_ring = (1.0 - smoothstep(0.01, 0.06, ring_d)) * danger_pulse;

	vec3 aura_rgb = mix(glow_color.rgb, core_color.rgb, smoothstep(0.25, 0.95, field) * 0.35);
	vec3 final_rgb = mix(aura_rgb, body_col, mask);
	final_rgb = mix(final_rgb, vec3(1.0, 0.30, 0.36), danger_ring * 0.85);
	float final_alpha = max(mask, max(aura, danger_ring * 0.75));
	final_alpha *= (1.0 - invuln_flash * 0.38);

	COLOR = vec4(final_rgb, clamp(final_alpha, 0.0, 1.0));
}
