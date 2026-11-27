shader_type canvas_item;

// Unified 2.5D Studio Ghibli Cel Creature Lighting + Soft Grounding Shadow + Live Charlie Bounce Light
// Designed for 4x1 horizontal sprite sheets (640x160) with VRAM mipmaps on Vulkan Mobile (linear non-HDR).

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

	// Safe 1/4 frame cell bounds for drop-shadow and silhouette rim taps
	float f_idx = floor(clamp(UV.x * 4.0, 0.0, 3.9999));
	float u_min = f_idx * 0.25 + TEXTURE_PIXEL_SIZE.x * 0.5;
	float u_max = (f_idx + 1.0) * 0.25 - TEXTURE_PIXEL_SIZE.x * 0.5;
	float v_min = TEXTURE_PIXEL_SIZE.y * 0.5;
	float v_max = 1.0 - TEXTURE_PIXEL_SIZE.y * 0.5;

	float cr = cos(world_rot);
	float sr = sin(world_rot);

	vec4 tex = texture(TEXTURE, UV);
	bool need_outline = (danger_rim > 0.01) || (edible_rim > 0.01);

	// Soft dark indigo-teal grounding drop-shadow offset bottom-right (0.014, 0.018 in world cell UV)
	// Rotated into local cell space by -world_rot so shadows always fall consistently bottom-right.
	vec2 world_shadow_off = vec2(0.014, 0.018);
	vec2 local_shadow_off = vec2(
		world_shadow_off.x * cr + world_shadow_off.y * sr,
		-world_shadow_off.x * sr + world_shadow_off.y * cr
	);
	vec2 shadow_cell_uv = cell_uv - local_shadow_off;
	float sh_edge_d = min(
		min(shadow_cell_uv.x, 1.0 - shadow_cell_uv.x),
		min(shadow_cell_uv.y, 1.0 - shadow_cell_uv.y)
	);
	float sh_in_bounds = smoothstep(0.01, 0.075, sh_edge_d);
	float shadow_a = 0.0;
	if (sh_in_bounds > 0.001) {
		vec2 sh_uv = vec2(
			clamp(UV.x - local_shadow_off.x * 0.25, u_min, u_max),
			clamp(UV.y - local_shadow_off.y, v_min, v_max)
		);
		vec2 sh_blur = vec2(0.0045 * 0.25, 0.0045);
		float s0 = texture(TEXTURE, sh_uv).a;
		float s1 = texture(TEXTURE, vec2(clamp(sh_uv.x + sh_blur.x, u_min, u_max), clamp(sh_uv.y + sh_blur.y, v_min, v_max))).a;
		float s2 = texture(TEXTURE, vec2(clamp(sh_uv.x - sh_blur.x, u_min, u_max), clamp(sh_uv.y - sh_blur.y, v_min, v_max))).a;
		float sh_raw = s0 * 0.52 + (s1 + s2) * 0.24;
		// Only solid silhouette mass casts grounding shadow (keeps wispy glow edges clean)
		shadow_a = smoothstep(0.16, 0.68, sh_raw) * 0.28 * sh_in_bounds * edge_feather;
	}

	if (tex.a <= 0.004 && shadow_a <= 0.003 && !need_outline) {
		discard;
	}

	// Early-out far outside silhouette corners even when outline pass is active
	if (tex.a <= 0.004 && shadow_a <= 0.003 && dot(local_uv, local_uv) > 0.24) {
		discard;
	}

	// Smooth 2.5D pseudo-dome normal in local sprite space
	vec2 dome_xy = local_uv * 2.35;
	float r_len = length(dome_xy);
	vec2 n_xy_local = (r_len > 0.0001) ? (dome_xy / r_len) * min(r_len, 0.94) : vec2(0.0);
	float n_z = sqrt(max(0.06, 1.0 - dot(n_xy_local, n_xy_local)));

	// Rotate local normal into world space by world_rot so lighting never spins upside-down
	vec2 n_xy_world = vec2(
		n_xy_local.x * cr - n_xy_local.y * sr,
		n_xy_local.x * sr + n_xy_local.y * cr
	);
	vec3 N_world = normalize(vec3(n_xy_world, n_z));

	// Rich Miyazaki top-left key light (sculptural 0.80..1.12 modeling + subtle warm/cool temp shift)
	vec3 L_key = (length(g_key_light_dir) > 0.001)
		? normalize(g_key_light_dir)
		: normalize(vec3(-0.52, -0.62, 0.58));
	float ndotl = dot(N_world, L_key);
	float half_lambert = clamp(ndotl * 0.5 + 0.5, 0.0, 1.0);
	float key_shade = mix(0.80, 1.12, smoothstep(0.0, 1.0, half_lambert));
	vec3 key_tint = mix(vec3(0.93, 0.97, 1.04), vec3(1.04, 1.00, 0.93), half_lambert);

	vec3 albedo = tex.rgb * v_tint;
	vec3 light_accum = key_tint * key_shade + g_world_ambient.rgb * mix(0.20, 0.02, half_lambert);
	vec3 lit_rgb = albedo * light_accum;

	// Ghibli jewel-tone saturation lift so cels pop cleanly over hand-painted backdrops
	float lit_lum = dot(lit_rgb, vec3(0.299, 0.587, 0.114));
	lit_rgb = max(vec3(0.0), mix(vec3(lit_lum), lit_rgb, 1.12));

	// Crisp cool/scale world Fresnel rim for luminous 2.5D silhouette separation
	float dome_fresnel = pow(clamp(1.0 - N_world.z, 0.0, 1.0), 2.15);
	float body_mask = smoothstep(0.14, 0.58, tex.a);
	float world_rim = dome_fresnel * (0.45 + 0.55 * half_lambert) * smoothstep(0.20, 0.72, tex.a);
	lit_rgb += g_world_rim_color.rgb * (world_rim * 0.16);

	// Live Charlie warm tangerine-amber lantern bounce light (hue-preserving cap at 0.34)
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
		float atten_lin = 1.0 - smoothstep(0.0, charlie_range, dist_c);
		float atten = atten_lin * (0.45 + 0.55 * atten_lin);
		if (atten > 0.001) {
			vec2 dir_xy = (dist_c > 0.001) ? (to_charlie / dist_c) : vec2(0.0);
			vec3 L_charlie = normalize(vec3(dir_xy, 0.38));
			float c_ndotl = clamp((dot(N_world, L_charlie) + 0.25) / 1.25, 0.0, 1.0);
			float c_facing = clamp(dot(N_world.xy, dir_xy) * 0.5 + 0.5, 0.0, 1.0);
			float c_rim = pow(clamp(1.0 - N_world.z, 0.0, 1.0), 1.65) * c_facing;
			vec3 bounce_diffuse = albedo * g_charlie_color.rgb * (c_ndotl * 0.34);
			vec3 bounce_rim = g_charlie_color.rgb * (c_rim * 0.38 + c_ndotl * c_ndotl * 0.10);
			vec3 bounce_lift = (bounce_diffuse + bounce_rim) * (atten * charlie_power * body_mask);
			float bounce_peak = max(bounce_lift.r, max(bounce_lift.g, bounce_lift.b));
			if (bounce_peak > 0.34) {
				bounce_lift *= (0.34 / bounce_peak);
			}
			lit_rgb += bounce_lift;
		}
	}

	// Subtle emissive lift strictly reserved for bright bioluminescent cores (lum > 0.84)
	float lum = dot(albedo, vec3(0.299, 0.587, 0.114));
	float core_peak = smoothstep(0.84, 0.99, lum) * smoothstep(0.32, 0.78, tex.a);
	core_peak = core_peak * core_peak;
	lit_rgb *= (1.0 + core_peak * 0.08);

	// Hue-preserving peak ceiling (<= 1.04): vibrant & luminous without ever clipping to flat white
	float max_allowed = mix(1.00, 1.04, core_peak);
	float cur_peak = max(lit_rgb.r, max(lit_rgb.g, lit_rgb.b));
	if (cur_peak > max_allowed) {
		lit_rgb *= (max_allowed / cur_peak);
	}

	float fg_alpha = tex.a;

	// Crisp silky Fresnel silhouette readability (predator danger rim & edible prey edge glint)
	if (need_outline) {
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
			vec3 danger_col = vec3(1.0, 0.22, 0.28);
			float inner_w = clamp(max(inner_rim * 0.84, soft_dome_rim * 0.44) * d_amt, 0.0, 0.86);
			lit_rgb = mix(lit_rgb, danger_col, inner_w);
			float outer_w = clamp(outer_aura * d_amt, 0.0, 1.0);
			lit_rgb = mix(lit_rgb, danger_col, outer_w * (1.0 - body_c * 0.85));
			fg_alpha = max(fg_alpha, outer_w * 0.64);
		}

		if (edible_rim > 0.01) {
			float glint = 0.84 + 0.16 * sin(anim_time * 4.2 + local_uv.x * 5.0);
			float e_amt = clamp(edible_rim, 0.0, 1.0) * glint;
			vec3 edible_col = mix(vec3(0.48, 0.98, 0.80), vec3(1.0, 0.90, 0.50), 0.40);
			float inner_w = clamp(max(inner_rim * 0.50, soft_dome_rim * 0.22) * e_amt, 0.0, 0.60);
			lit_rgb += edible_col * (inner_w * 0.22);
			float outer_w = clamp(outer_aura * e_amt * 0.48, 0.0, 0.48);
			lit_rgb = mix(lit_rgb, edible_col, outer_w * (1.0 - body_c * 0.85));
			fg_alpha = max(fg_alpha, outer_w * 0.34);
		}
	}

	// Warm golden flash when struck by Charlie's Lava Spit
	if (burn_flash > 0.01) {
		float bf = clamp(burn_flash, 0.0, 1.0);
		vec3 burn_col = vec3(1.0, 0.84, 0.46);
		float burn_mask = smoothstep(0.08, 0.48, tex.a);
		lit_rgb = mix(lit_rgb, burn_col, bf * 0.72 * burn_mask);
		lit_rgb += vec3(1.0, 0.70, 0.28) * (bf * 0.28 * dome_fresnel * burn_mask);
	}

	// Final safety ceiling on foreground cel before compositing over grounding drop-shadow
	float fg_peak = max(lit_rgb.r, max(lit_rgb.g, lit_rgb.b));
	if (fg_peak > 1.04) {
		lit_rgb *= (1.04 / fg_peak);
	}

	// Porter-Duff composite: vibrant creature cel cleanly OVER soft dark indigo-teal drop-shadow
	float fg_a = clamp(fg_alpha * edge_feather, 0.0, 1.0);
	vec3 shadow_col = vec3(0.025, 0.055, 0.115);
	float comp_alpha = fg_a + shadow_a * (1.0 - fg_a);
	vec3 comp_rgb = (comp_alpha > 0.0001)
		? (lit_rgb * fg_a + shadow_col * (shadow_a * (1.0 - fg_a))) / comp_alpha
		: lit_rgb;

	float final_alpha = clamp(comp_alpha * clamp(alpha_mult, 0.0, 1.0), 0.0, 1.0);
	if (final_alpha <= 0.003) {
		discard;
	}
	COLOR = vec4(comp_rgb, final_alpha);
}
