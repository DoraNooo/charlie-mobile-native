shader_type canvas_item;

// Soft breathing dusk-ember edge vignette (Vulkan/Metal compliant, ascending smoothstep).
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.58, 0.14, 0.22, 1.0);
uniform vec4 rim_color : source_color = vec4(0.76, 0.24, 0.26, 1.0);

void fragment() {
	vec2 centered = (UV - vec2(0.5)) * 2.0;
	// Soft elliptical distance so corners & edges breathe evenly on landscape mobile screens
	float dist = length(centered * vec2(0.96, 1.04));

	// Strictly ascending smoothstep (edge0 < edge1) for Vulkan/Metal compliance
	float clear_center = 1.0 - smoothstep(0.46, 1.36, dist);
	float edge_falloff = 1.0 - clear_center;
	float outer_rim = smoothstep(0.88, 1.40, dist);

	// Gentle contemplative dusk-ember breath
	float breath = 0.88 + 0.12 * sin(TIME * 2.4);
	float alpha = (edge_falloff * edge_falloff * 0.30 + outer_rim * 0.14) * intensity * breath;
	vec3 col = mix(vignette_color.rgb, rim_color.rgb, outer_rim * 0.42);
	COLOR = vec4(col, clamp(alpha, 0.0, 0.38));
}
