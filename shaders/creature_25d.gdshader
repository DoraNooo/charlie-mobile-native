shader_type canvas_item;

// Unified 2.5D Creature Lighting + Live Charlie Molten Bounce Light + Selective HDR Bioluminescence
// Designed for 4x1 horizontal sprite sheets (640x160) with VRAM mipmaps and HDR 2D AgX bloom.

global uniform vec3 g_key_light_dir;
global uniform vec4 g_world_ambient : source_color;
global uniform vec4 g_world_rim_color : source_color;
global uniform vec4 g_charlie_light;
global uniform vec4 g_charlie_color : source_color;

uniform float world_rot = 0.0;
uniform float danger_rim = 0.0;
uniform float edible_rim = 0.0;
uniform float burn_flash = 0.0;
uniform float anim_time = 0.0;
uniform float sway_amp = 0.025;
uniform vec2 world_pos = vec2(0.0);
uniform float world_radius = 20.0;
uniform float alpha_mult = 1.0;

varying vec3 v_tint;

void vertex() {
	v_tint = COLOR.rgb;
	// Frame size in local sprite pixels for a 4-frame horizontal sheet
	vec2 frame_size = vec2(
		1.0 / max(TEXTURE_PIXEL_SIZE.x * 4.0, 0.0001),
		1.0 / max(TEXTURE_PIXEL_SIZE.y, 0.0001)
	);
	// Frame-change-invariant normalized coordinate in [-1, 1] across the centered quad
	vec2 norm_pos = VERTEX / max(frame_size * 0.5, vec2(1.0));
	// Silky continuous organic breathing + tail-to-head swimming sway
	float breath = sin(anim_time * 2.5) * sway_amp * 0.48;
	VERTEX.x *= (1.0 + breath);
	VERTEX.y *= (1.0 - breath);
	VERTEX.y += sin(anim_time * 3.8 + norm_pos.x * 1.65) * sway_amp * frame_size.y;
}

void fragment() {
	// Per-frame local cell UV in [0, 1] across each 1/4 horizontal animation cell
	vec2 cell_uv = vec2(fract(UV.x * 4.0), clamp(UV.y, 0.0, 1.0));
	vec2 local_uv = cell_uv - vec2(0.5);
	// Smooth frame-cell UV edge feather: completely eliminates any rectangular sprite-cell seam (e.g. blackhole)
	float edge_dist = min(min(cell_uv.x, 1.0 - cell_uv.x), min(cell_uv.y, 1.0 - cell_uv.y));
	float edge_feather = smoothstep(0.0, 0.055, edge_dist);
	if (edge_feather <= 0.001) {
		discard;
	}

	vec4 tex = texture(TEXTURE, UV);
	bool need_outline = (danger_rim > 0.01) || (edible_rim > 0.01);
	if (tex.a <= 0.004 && !need_outline) {
		discard;
	}

	// Early-out far outside silhouette corners even when outline pass is active
	if (tex.a <= 0.004 && dot(local_uv, local_uv) > 0.24) {
		discard;
	}

	// Smooth 2.5D pseudo-dome normal in local sprite space
	vec2 dome_xy = local_uv * 2.35;
	float r_len = length(dome_xy);
	vec2 n_xy_local = (r_len > 0.0001) ? (dome_xy / r_len) * min(r_len, 0.94) : vec2(0.0);
	float n_z = sqrt(max(0.06, 1.0 - dot(n_xy_local, n_xy_local)));

	// Rotate local normal into world space by world_rot so lighting never spins upside-down
	float cr = cos(world_rot);
	float sr = sin(world_rot);
	vec2 n_xy_world = vec2(
		n_xy_local.x * cr - n_xy_local.y * sr,
		n_xy_local.x * sr + n_xy_local.y * cr
	);
	vec3 N_world = normalize(vec3(n_xy_world, n_z));

	// Gentle directional key-light preserving rich, saturated albedo without blowing highlights past 1.0
	vec3 L_key = (length(g_key_light_dir) > 0.001)
		? normalize(g_key_light_dir)
		: normalize(vec3(-0.52, -0.62, 0.58));
	float ndotl = dot(N_world, L_key);
	float half_lambert = clamp(ndotl * 0.5 + 0.5, 0.0, 1.0);
	float key_diff = clamp(ndotl, -0.75, 0.88);
	float key_shade = 0.90 + 0.16 * key_diff;

	vec3 albedo = tex.rgb * v_tint;
	vec3 light_accum = vec3(key_shade) + g_world_ambient.rgb * mix(0.16, 0.02, half_lambert);
	vec3 lit_rgb = albedo * light_accum;

	// Subtle world Fresnel rim catching scale bioluminescence without washing out body saturation
	float dome_fresnel = pow(clamp(1.0 - N_world.z, 0.0, 1.0), 2.25);
	float body_mask = smoothstep(0.14, 0.58, tex.a);
	float world_rim = dome_fresnel * (0.42 + 0.58 * half_lambert) * smoothstep(0.20, 0.74, tex.a);
	lit_rgb += g_world_rim_color.rgb * (world_rim * 0.10);

	// Live Charlie molten coral bounce light (hue-preserving cap at 0.22 max additive lift)
	float charlie_range = max(g_charlie_light.z, 1.0);
	float charlie_power = clamp(g_charlie_light.w, 0.0, 1.0);
	if (charlie_power > 0.001 && body_mask > 0.001) {
		vec2 local_world_off = vec2(
			local_uv.x * cr - local_uv.y * sr,
			local_uv.x * sr + local_uv.y * cr
		);
		vec2 pixel_world_pos = world_pos + local_world_off * (world_radius * 2.0);
		vec2 to_charlie = g_charlie_light.xy - pixel_world_pos;
		float dist_c = length(to_charlie);
		float atten = 1.0 - smoothstep(0.0, charlie_range, dist_c);
		atten = atten * atten;
		if (atten > 0.001) {
			vec2 dir_xy = (dist_c > 0.001) ? (to_charlie / dist_c) : vec2(0.0);
			vec3 L_charlie = normalize(vec3(dir_xy, 0.38));
			float c_ndotl = clamp((dot(N_world, L_charlie) + 0.25) / 1.25, 0.0, 1.0);
			float c_facing = clamp(dot(N_world.xy, dir_xy) * 0.5 + 0.5, 0.0, 1.0);
			float c_rim = pow(clamp(1.0 - N_world.z, 0.0, 1.0), 1.75) * c_facing;
			vec3 bounce_diffuse = albedo * g_charlie_color.rgb * (c_ndotl * 0.24);
			vec3 bounce_rim = g_charlie_color.rgb * (c_rim * 0.22 + c_ndotl * c_ndotl * 0.06);
			vec3 bounce_lift = (bounce_diffuse + bounce_rim) * (atten * charlie_power * body_mask);
			float bounce_peak = max(bounce_lift.r, max(bounce_lift.g, bounce_lift.b));
			if (bounce_peak > 0.22) {
				bounce_lift *= (0.22 / bounce_peak);
			}
			lit_rgb += bounce_lift;
		}
	}

	// Selective HDR bioluminescence (1.18-1.35) strictly reserved for bright emissive cores (lum > 0.84)
	float lum = dot(albedo, vec3(0.299, 0.587, 0.114));
	float core_peak = smoothstep(0.84, 0.99, lum) * smoothstep(0.32, 0.78, tex.a);
	core_peak = core_peak * core_peak;
	lit_rgb *= (1.0 + core_peak * 0.10);

	// Hue-preserving peak ceiling: keeps creatures rich and calm without blowing highlights to white
	float max_allowed = mix(0.98, 1.05, core_peak);
	float cur_peak = max(lit_rgb.r, max(lit_rgb.g, lit_rgb.b));
	if (cur_peak > max_allowed) {
		lit_rgb *= (max_allowed / cur_peak);
	}

	float out_alpha = tex.a;

	// Crisp silky Fresnel silhouette readability (predator danger rim & edible prey edge glint)
	if (need_outline) {
		float f_idx = floor(clamp(UV.x * 4.0, 0.0, 3.9999));
		float u_min = f_idx * 0.25 + TEXTURE_PIXEL_SIZE.x * 0.5;
		float u_max = (f_idx + 1.0) * 0.25 - TEXTURE_PIXEL_SIZE.x * 0.5;
		float v_min = TEXTURE_PIXEL_SIZE.y * 0.5;
		float v_max = 1.0 - TEXTURE_PIXEL_SIZE.y * 0.5;
		vec2 step_uv = TEXTURE_PIXEL_SIZE * 1.75;

		float a_l = texture(TEXTURE, vec2(clamp(UV.x - step_uv.x, u_min, u_max), UV.y)).a;
		float a_r = texture(TEXTURE, vec2(clamp(UV.x + step_uv.x, u_min, u_max), UV.y)).a;
		float a_u = texture(TEXTURE, vec2(UV.x, clamp(UV.y - step_uv.y, v_min, v_max))).a;
		float a_d = texture(TEXTURE, vec2(UV.x, clamp(UV.y + step_uv.y, v_min, v_max))).a;

		float min_a = min(min(a_l, a_r), min(a_u, a_d));
		float avg_a = 0.25 * (a_l + a_r + a_u + a_d);
		float body_c = smoothstep(0.18, 0.72, tex.a);
		// Smooth inner Fresnel edge right inside the creature silhouette
		float inner_rim = body_c * (1.0 - smoothstep(0.24, 0.88, min_a));
		// Soft 1.5px feathered aura hugging the outside of the silhouette (damped by cell edge feather)
		float outer_aura = (1.0 - smoothstep(0.22, 0.70, tex.a)) * smoothstep(0.10, 0.72, avg_a) * edge_feather;
		float soft_dome_rim = dome_fresnel * body_c;

		if (danger_rim > 0.01) {
			float pulse = 0.78 + 0.22 * sin(anim_time * 6.4);
			float d_amt = clamp(danger_rim, 0.0, 1.0) * pulse;
			vec3 danger_col = vec3(1.0, 0.22, 0.28) * 1.38;
			float inner_w = clamp(max(inner_rim * 0.84, soft_dome_rim * 0.44) * d_amt, 0.0, 0.88);
			lit_rgb = mix(lit_rgb, danger_col, inner_w);
			float outer_w = clamp(outer_aura * d_amt, 0.0, 1.0);
			lit_rgb = mix(lit_rgb, danger_col, outer_w * (1.0 - body_c * 0.85));
			out_alpha = max(out_alpha, outer_w * 0.64);
		}

		if (edible_rim > 0.01) {
			float glint = 0.84 + 0.16 * sin(anim_time * 4.2 + local_uv.x * 5.0);
			float e_amt = clamp(edible_rim, 0.0, 1.0) * glint;
			vec3 edible_col = mix(vec3(0.54, 0.98, 0.82), vec3(1.0, 0.92, 0.56), 0.38) * 1.08;
			float inner_w = clamp(max(inner_rim * 0.50, soft_dome_rim * 0.20) * e_amt, 0.0, 0.62);
			lit_rgb += edible_col * (inner_w * 0.24);
			float outer_w = clamp(outer_aura * e_amt * 0.48, 0.0, 0.48);
			lit_rgb = mix(lit_rgb, edible_col, outer_w * (1.0 - body_c * 0.85));
			out_alpha = max(out_alpha, outer_w * 0.34);
		}
	}

	// Warm golden-white HDR flash when struck by Charlie's Lava Spit
	if (burn_flash > 0.01) {
		float bf = clamp(burn_flash, 0.0, 1.0);
		vec3 burn_col = vec3(1.0, 0.88, 0.56) * 1.55;
		float burn_mask = smoothstep(0.08, 0.48, tex.a);
		lit_rgb = mix(lit_rgb, burn_col, bf * 0.74 * burn_mask);
		lit_rgb += vec3(1.0, 0.74, 0.34) * (bf * 0.38 * dome_fresnel * burn_mask);
	}

	float final_alpha = clamp(out_alpha * edge_feather * clamp(alpha_mult, 0.0, 1.0), 0.0, 1.0);
	if (final_alpha <= 0.003) {
		discard;
	}
	COLOR = vec4(lit_rgb, final_alpha);
}
