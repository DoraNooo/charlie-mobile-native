shader_type canvas_item;

// Smooth bioluminescent radial backdrop with subtle drifting stardust & caustics (GPU 120 FPS)
uniform vec4 bg_inner : source_color = vec4(0.055, 0.153, 0.200, 1.0);
uniform vec4 bg_outer : source_color = vec4(0.024, 0.067, 0.098, 1.0);
uniform vec4 mote_color : source_color = vec4(0.431, 0.906, 0.855, 1.0);
uniform vec2 cam_offset = vec2(0.0, 0.0);

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float d = length((uv - vec2(0.5, 0.45)) * vec2(1.4, 1.1));
	vec3 col = mix(bg_inner.rgb, bg_outer.rgb, smoothstep(0.05, 0.95, d));

	// Subtle bioluminescent parallax motes on GPU (zero CPU loop!)
	vec2 grid_uv = uv * vec2(10.0, 6.0) + cam_offset * 0.0008;
	vec2 id = floor(grid_uv);
	vec2 gv = fract(grid_uv) - 0.5;
	float rnd = hash21(id);
	vec2 jitter = vec2(sin(rnd * 6.28 + TIME * 0.4), cos(rnd * 9.42 + TIME * 0.35)) * 0.28;
	float dist = length(gv - jitter);
	float twinkle = 0.45 + 0.55 * sin(TIME * (1.2 + rnd * 1.8) + rnd * 12.0);
	float star = (1.0 - smoothstep(0.01, 0.075, dist)) * twinkle * step(0.45, rnd);

	col += mote_color.rgb * star * 0.32;
	COLOR = vec4(col, 1.0);
}
