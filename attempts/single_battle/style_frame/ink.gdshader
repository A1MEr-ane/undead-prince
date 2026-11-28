shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 exposure = vec3(0.70, 0.78, 0.91);
uniform vec3 air = vec3(0.029, 0.040, 0.061);

varying vec3 world;
varying vec3 face_normal;

float grain(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = smoothstep(0.0, 1.0, fract(p));
	vec4 n = fract(sin(vec4(dot(cell, vec2(127.1, 311.7))) +
			vec4(0.0, 127.1, 311.7, 438.8)) * 43758.5453);
	return mix(mix(n.x, n.y, f.x), mix(n.z, n.w, f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	face_normal = abs(normalize(MODEL_NORMAL_MATRIX * NORMAL));
}

void fragment() {
	vec2 paper = mix(world.xz, vec2(world.x + world.z * 0.72, world.y), 1.0 - face_normal.y);
	vec2 brush = vec2(paper.x + paper.y * 1.65, paper.y - paper.x * 0.34);
	float broken_edge = grain(paper * 5.2) * 0.23;
	float scumble = grain(brush * vec2(1.9, 8.2)) + broken_edge;
	float wash = grain(brush * vec2(0.45, 1.5));
	float receptive = smoothstep(0.10, 0.28, max(COLOR.r, max(COLOR.g, COLOR.b)));
	float marks = 0.075 * smoothstep(0.62, 0.68, scumble) - 0.065 * (1.0 - smoothstep(0.30, 0.39, scumble));
	vec3 painted = COLOR.rgb * (1.0 + receptive * (marks + 0.15 * (wash - 0.48)));
	vec3 color = painted * exposure + air * (0.27 + receptive * 0.36);
	color = mix(color, air + color * 0.74, smoothstep(3.0, 16.0, -world.z) * 0.20);
	ALBEDO = OUTPUT_IS_SRGB ? color : pow(max(color, vec3(0.0)), vec3(2.2));
}
