shader_type canvas_item;

// Real-time 2.5D Translucent Jiggly Slime shader for la petite Charlie (Vulkan/Metal 120 FPS)
uniform vec4 core_color : source_color = vec4(1.0, 0.78, 0.50, 1.0);
uniform vec4 edge_color : source_color = vec4(0.96, 0.38, 0.42, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.50, 0.28, 1.0);
uniform float danger_pulse = 0.0;
uniform float invuln_flash = 0.0;
uniform float core_radius = 0.46;
uniform float wobble_amp = 0.0;

// 5 viscous spring-mass lobes: xy = local pos, z = dynamic radius
uniform vec3 lobe_0 = vec3(-0.24, 0.0, 0.30);
uniform vec3 lobe_1 = vec3(-0.04, -0.24, 0.29);
uniform vec3 lobe_2 = vec3(-0.04, 0.24, 0.29);
uniform vec3 lobe_3 = vec3(0.20, -0.15, 0.27);
uniform vec3 lobe_4 = vec3(0.20, 0.15, 0.27);

// 3 internal vitality pearls: xy = local pos, z = bloom scale (0..1)
uniform vec3 pearl_0 = vec3(-0.14, -0.10, 1.0);
uniform vec3 pearl_1 = vec3(-0.04, 0.16, 1.0);
uniform vec3 pearl_2 = vec3(0.14, -0.05, 1.0);

float smin(float a, float b, float k) {
	float h = max(k - abs(a - b), 0.0) / k;
	return min(a, b) - h * h * k * 0.25;
}

float slime_sdf(vec2 p) {
	float d = length(p) - core_radius;
	d = smin(d, length(p - lobe_0.xy) - lobe_0.z, 0.42);
	d = smin(d, length(p - lobe_1.xy) - lobe_1.z, 0.42);
	d = smin(d, length(p - lobe_2.xy) - lobe_2.z, 0.42);
	d = smin(d, length(p - lobe_3.xy) - lobe_3.z, 0.42);
	d = smin(d, length(p - lobe_4.xy) - lobe_4.z, 0.42);
	float ripple = sin(p.x * 5.2 + TIME * 3.1) * cos(p.y * 5.2 - TIME * 2.6) * (0.011 + wobble_amp * 0.026);
	return d + ripple;
}

vec2 sample_pearl(vec2 p_ref, vec3 pearl) {
	if (pearl.z <= 0.01) {
		return vec2(0.0);
	}
	float r = max(0.02, 0.125 * pearl.z);
	float dist = length(p_ref - pearl.xy);
	float body = 1.0 - smoothstep(r * 0.20, r * 1.05, dist);
	float halo = (1.0 - smoothstep(r * 0.45, r * 2.05, dist)) * 0.46;
	float core_r = max(0.015, 0.062 * pearl.z);
	float sparkle = 1.0 - smoothstep(core_r * 0.25, core_r, dist);
	return vec2(clamp((body + halo) * pearl.z, 0.0, 1.0), sparkle * pearl.z);
}

void fragment() {
	// Quad coordinate space matching BODY_QUAD_SCALE = 3.4
	vec2 p = (UV - vec2(0.5)) * 3.4;

	float d = slime_sdf(p);
	if (d > 0.06 && danger_pulse < 0.01) {
		discard;
	}

	// Crisp AA silhouette + delicate 1-2px translucent gel meniscus rim (ZERO smoky outer halo)
	float body_mask = 1.0 - smoothstep(-0.025, 0.025, d);
	float meniscus = (1.0 - smoothstep(0.0, 0.042, d)) * smoothstep(-0.018, 0.015, d);

	// True 3D dome surface normal via 4-tap central differences + hemispherical z
	const float EPS = 0.02;
	float gx = slime_sdf(p + vec2(EPS, 0.0)) - slime_sdf(p - vec2(EPS, 0.0));
	float gy = slime_sdf(p + vec2(0.0, EPS)) - slime_sdf(p - vec2(0.0, EPS));
	vec2 grad = vec2(gx, gy) / (2.0 * EPS);
	float grad_len = length(grad);
	vec2 grad_dir = grad_len > 0.0001 ? grad / grad_len : vec2(0.0);

	float depth = max(-d, 0.0);
	float dome_slope = 1.0 - smoothstep(0.0, 0.56, depth);
	vec2 n_xy = grad_dir * (dome_slope * 0.96);
	float xy_mag = min(length(n_xy), 0.995);
	vec3 N = normalize(vec3(n_xy, sqrt(max(0.0, 1.0 - xy_mag * xy_mag))));

	// Lighting vectors
	vec3 L_key = normalize(vec3(-0.52, -0.62, 0.58));
	vec3 L_caustic = normalize(vec3(0.58, 0.64, 0.50));
	vec3 V = vec3(0.0, 0.0, 1.0);
	vec3 H = normalize(L_key + V);
	float NdotL = max(dot(N, L_key), 0.0);
	float NdotH = max(dot(N, H), 0.0);

	// Fresnel thickness: deeply saturated jelly rim -> luminous semi-translucent gel interior
	float fresnel = pow(clamp(1.0 - N.z, 0.0, 1.0), 2.15);
	float rim_thickness = clamp(max(fresnel, (1.0 - smoothstep(0.0, 0.34, depth)) * 0.85), 0.0, 1.0);
	vec3 deep_rim = edge_color.rgb * vec3(0.68, 0.46, 0.52);
	vec3 mid_gel = mix(edge_color.rgb, core_color.rgb, 0.56);
	vec3 core_gel = clamp(core_color.rgb * vec3(1.06, 1.03, 0.98), 0.0, 1.0);
	vec3 body_col = mix(core_gel, mid_gel, smoothstep(0.08, 0.58, rim_thickness));
	body_col = mix(body_col, deep_rim, smoothstep(0.54, 0.96, rim_thickness));
	body_col *= mix(0.84, 1.08, NdotL);

	// 3 internal glowing gelatinous vitality pearls refracted by dome normal
	float interior_mask = smoothstep(0.04, 0.22, depth);
	vec2 p_ref = p - N.xy * 0.065;
	vec2 s0 = sample_pearl(p_ref, pearl_0);
	vec2 s1 = sample_pearl(p_ref, pearl_1);
	vec2 s2 = sample_pearl(p_ref, pearl_2);
	float pearl_glow = clamp(s0.x + s1.x + s2.x, 0.0, 1.25) * interior_mask;
	float pearl_core = clamp(s0.y + s1.y + s2.y, 0.0, 1.0) * interior_mask;
	vec3 pearl_tint = clamp(mix(core_color.rgb * 1.16, vec3(1.0, 0.97, 0.88), 0.56), 0.0, 1.0);
	body_col = mix(body_col, clamp(body_col + pearl_tint * 0.52, 0.0, 1.0), clamp(pearl_glow * 0.76, 0.0, 0.92));
	body_col = mix(body_col, vec3(1.0, 0.99, 0.94), pearl_core * 0.48);

	// Warm subsurface transmitted caustic bounce on bottom-right
	float caustic_l = max(dot(N, L_caustic), 0.0);
	float caustic = pow(caustic_l, 3.0) * smoothstep(0.02, 0.26, depth) * (1.0 - smoothstep(0.28, 0.62, depth) * 0.42);
	vec3 caustic_col = clamp(mix(glow_color.rgb * 1.15, core_color.rgb * 1.12, 0.45), 0.0, 1.0);
	body_col = clamp(body_col + caustic_col * caustic * 0.42, 0.0, 1.0);

	// 2-layer wet glossy Blinn-Phong specular + crisp wet pinpoint glint
	float spec_layer = pow(NdotH, 10.0) * 0.24 + pow(NdotH, 42.0) * 0.78;
	float pinpoint = smoothstep(0.965, 0.992, NdotH) * 0.95;
	float wet_spec = clamp(spec_layer + pinpoint, 0.0, 1.0) * smoothstep(0.0, 0.09, depth);
	body_col = mix(body_col, vec3(1.0, 0.995, 0.98), wet_spec * 0.88);

	// Subtle glossy rim sheen
	float rim_sheen = fresnel * (0.18 + 0.44 * NdotL);
	vec3 sheen_col = mix(core_color.rgb * 1.08, vec3(1.0, 0.98, 0.94), 0.65);
	body_col = mix(body_col, sheen_col, clamp(rim_sheen * 0.42, 0.0, 0.48));

	// Semi-translucent interior -> denser saturated rim
	float body_alpha = mix(0.84, 0.98, clamp(rim_thickness + wet_spec * 0.35, 0.0, 1.0));

	// Compose body + delicate gel meniscus rim
	vec3 meniscus_col = clamp(mix(edge_color.rgb, vec3(1.0, 0.98, 0.95), 0.32 + 0.36 * NdotL), 0.0, 1.0);
	vec3 final_rgb = mix(meniscus_col, body_col, body_mask);
	float final_alpha = max(body_mask * body_alpha, meniscus * 0.54);

	// Vulnerable danger ring when 0 vitality pearls left or predator close
	if (danger_pulse > 0.01) {
		float ring_r = 0.92 + sin(TIME * 7.0) * 0.06;
		float ring_d = abs(length(p) - ring_r);
		float danger_ring = (1.0 - smoothstep(0.012, 0.055, ring_d)) * danger_pulse;
		final_rgb = mix(final_rgb, vec3(1.0, 0.30, 0.36), danger_ring * 0.85);
		final_alpha = max(final_alpha, danger_ring * 0.78);
	}

	final_alpha *= (1.0 - invuln_flash * 0.38);
	COLOR = vec4(final_rgb, clamp(final_alpha, 0.0, 1.0));
}
