shader_type canvas_item;

// Smooth 1-pass radial crimson danger vignette (Vulkan/Metal compliant, ascending smoothstep).
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.96, 0.16, 0.24, 1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.36, 0.34, 1.0);

void fragment() {
	vec2 centered = (UV - vec2(0.5)) * 2.0;
	// Soft elliptical distance so corners & edges glow evenly on landscape mobile screens
	float dist = length(centered * vec2(0.96, 1.04));

	// Strictly ascending smoothstep (edge0 < edge1) for Vulkan/Metal compliance
	float clear_center = 1.0 - smoothstep(0.42, 1.34, dist);
	float edge_falloff = 1.0 - clear_center;
	float outer_rim = 1.0 - (1.0 - smoothstep(0.88, 1.38, dist));

	float alpha = (edge_falloff * edge_falloff * 0.66 + outer_rim * 0.28) * intensity;
	vec3 col = mix(vignette_color.rgb, rim_color.rgb, outer_rim * 0.55);
	COLOR = vec4(col, clamp(alpha, 0.0, 0.86));
}
