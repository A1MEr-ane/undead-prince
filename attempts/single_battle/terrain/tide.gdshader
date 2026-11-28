shader_type spatial;
render_mode unshaded, cull_disabled;

uniform float clock = 0.0;
uniform vec4 water : source_color = vec4(0.14, 0.23, 0.29, 1.0);
uniform vec4 headland : source_color = vec4(0.34, 0.43, 0.51, 1.0);
uniform vec4 horizon : source_color = vec4(0.50, 0.54, 0.62, 1.0);
uniform float dawn = 0.0;
uniform sampler2D shore_field : filter_linear, repeat_disable;
uniform vec2 shore_origin;
uniform vec2 shore_size;
uniform float shore_reach;
uniform vec4 shallows : source_color;
uniform vec4 froth : source_color;

varying vec2 water_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float wash(vec2 p) {
	vec2 grid = floor(p);
	vec2 t = smoothstep(0.0, 1.0, fract(p));
	return mix(
		mix(hash(grid), hash(grid + vec2(1.0, 0.0)), t.x),
		mix(hash(grid + vec2(0.0, 1.0)), hash(grid + vec2(1.0)), t.x), t.y);
}

void vertex() {
	water_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = water_pos + vec2(clock * 0.11, 0.0);
	vec2 uv = SCREEN_UV;
	float fog = wash(p * vec2(0.10, 0.22));
	float gust = wash(p * vec2(0.36, 0.82) + vec2(0.0, clock * 0.05));
	float swell = smoothstep(0.50, 0.69, wash(vec2(p.x * 0.33 + p.y * 0.37, p.y * 2.1)) * 0.75 + gust * 0.25);
	vec3 col = mix(water.rgb * 0.82, water.rgb * 1.18, fog);
	col = mix(col, headland.rgb, 0.13 * swell + 0.10 * gust);
	float painted_mist = 1.0 - smoothstep(0.0, 0.46 + fog * 0.08, uv.y);
	float sky_break = exp(-abs(uv.x - 0.82) * 2.3);
	col = mix(col, horizon.rgb, painted_mist * (0.26 + 0.21 * sky_break + 0.21 * dawn));
	vec2 shore_uv = (water_pos - shore_origin) / shore_size;
	float distance_to_rocks = texture(shore_field, shore_uv).r * shore_reach;
	float shelves = 1.0 - smoothstep(0.10, 1.85 + fog * 0.55, distance_to_rocks);
	col = mix(col, shallows.rgb, shelves * (0.32 + 0.23 * gust));
	float wet = 1.0 - smoothstep(0.11, 0.33, distance_to_rocks);
	col *= 1.0 - 0.21 * wet;
	float tide = 0.21 + sin(clock * 1.35 + water_pos.x * 0.76) * 0.045 + 0.12 * swell;
	float ribs = 1.0 - smoothstep(0.035, 0.135, abs(distance_to_rocks - tide));
	float wash_edge = tide + 0.31 + gust * 0.13;
	float runoff = 1.0 - smoothstep(0.023, 0.094, abs(distance_to_rocks - wash_edge));
	float breaks = smoothstep(0.30, 0.55, wash(p * vec2(0.95, 1.22)));
	col = mix(col, froth.rgb, max(ribs * (0.45 + 0.54 * breaks), runoff * breaks * 0.47) *
			(0.41 + 0.34 * dawn + 0.17 * gust));
	ALBEDO = col;
}
