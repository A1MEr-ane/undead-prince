shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 exposure = vec3(0.46, 0.59, 0.76);
uniform vec3 air = vec3(0.025, 0.042, 0.060);
uniform float dawn = 0.0;

varying vec3 world;
varying vec3 normal_world;

float grain(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	vec4 n = fract(sin(vec4(dot(cell, vec2(127.1, 311.7))) +
			vec4(0.0, 127.1, 311.7, 438.8)) * 43758.5453);
	return mix(mix(n.x, n.y, f.x), mix(n.z, n.w, f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normal_world = abs(normalize(MODEL_NORMAL_MATRIX * NORMAL));
}

void fragment() {
	vec2 surface = mix(world.xz, vec2(world.x + world.z * 0.72, world.y), 1.0 - normal_world.y);
	vec2 brush = vec2(surface.x + surface.y * 1.65, surface.y - surface.x * 0.34);
	float scumble = grain(brush * vec2(1.9, 8.2)) + grain(surface * 5.2) * 0.23;
	float wash = grain(brush * vec2(0.45, 1.5));
	float receptive = smoothstep(0.09, 0.33, max(COLOR.r, max(COLOR.g, COLOR.b)));
	float marks = 0.095 * smoothstep(0.62, 0.68, scumble) -
			0.088 * (1.0 - smoothstep(0.27, 0.39, scumble));
	vec3 painted = COLOR.rgb * (1.0 + receptive * (marks + 0.21 * (wash - 0.48)));
	vec3 dawn_warmth = vec3(0.116, 0.075, 0.028) * (0.4 + 0.6 * normal_world.y);
	vec3 color = painted * (exposure + dawn_warmth * dawn) + air * (0.30 + receptive * 0.28);
	ALBEDO = OUTPUT_IS_SRGB ? color : pow(max(color, vec3(0.0)), vec3(2.2));
}
