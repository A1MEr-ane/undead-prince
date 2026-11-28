shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform float daylight = 0.0;

void vertex() {
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	VERTEX = (inverse(MODEL_MATRIX) * vec4(center + VERTEX.x * right + VERTEX.y * up, 1.0)).xyz;
}

void fragment() {
	vec2 p = (UV - vec2(0.50, 0.53)) * 2.0;
	float halo = (1.0 - smoothstep(0.09, 0.97, length(p * vec2(1.0, 1.05)))) * 0.23;
	vec2 tail = vec2(p.x + 0.10 * sin(p.y * 8.0), p.y + 0.03);
	float flame = 1.0 - smoothstep(0.11, 0.32, length(tail * vec2(1.9 + max(0.0, -p.y * 8.0), 0.68)));
	float heart = 1.0 - smoothstep(0.02, 0.15, length((p - vec2(0.02, 0.20)) * vec2(1.6, 0.91)));
	vec2 ember = p - vec2(0.19, -0.48);
	float spark = 1.0 - smoothstep(0.025, 0.074, abs(ember.x) + abs(ember.y));
	float strength = halo + flame * 0.66 + spark * 0.54;
	vec3 cyan = mix(vec3(0.055, 0.88, 0.63), vec3(0.60, 1.0, 0.82), heart);
	ALBEDO = OUTPUT_IS_SRGB ? cyan : pow(cyan, vec3(2.2));
	ALPHA = strength * mix(1.0, 0.68, daylight);
}
