// 海面即雾面：雾色上叠一层随风缓慢滚动的云影。
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 fog_color = vec3(0.75, 0.76, 0.78);
uniform vec3 cloud_color = vec3(0.62, 0.66, 0.71);
uniform sampler2D cloud_noise : filter_linear, repeat_enable;
uniform vec2 wind = vec2(0.012, 0.006);
uniform float cloud_amount = 0.55;
uniform sampler2D shore_field : filter_linear, repeat_disable;
uniform bool shore_enabled = false;
uniform float island_size = 24.0;

varying vec3 w_pos;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = w_pos.xz * 0.025 + wind * TIME;
	float a = texture(cloud_noise, uv).r;
	float b = texture(cloud_noise, uv * 2.3 - wind * TIME * 1.7).r;
	// 两层噪声之间用正弦来回摆动，云影缓慢变形
	float c = mix(a, b, 0.5 + 0.5 * sin(TIME * 0.2));
	float m = clamp((c + cloud_amount - 1.0) * 3.0, 0.0, 1.0);
	vec3 col = mix(fog_color, cloud_color, m * 0.3);
	if (shore_enabled) {
		vec2 shore_uv = w_pos.xz / island_size;
		float inside = step(0.0, shore_uv.x) * step(shore_uv.x, 1.0) * step(0.0, shore_uv.y) * step(shore_uv.y, 1.0);
		float coast = (texture(shore_field, shore_uv).r - 0.5) * 16.0;
		float water_distance = max(-coast, 0.0);
		float shallows = (1.0 - smoothstep(0.0, 0.65, water_distance)) * inside;
		col = mix(col, vec3(0.66, 0.72, 0.70), shallows * 0.30);
		// 不透明雾面内直接画泡沫，不加透明平面或额外 draw call。
		float breakup = sin(w_pos.x * 5.7 + sin(w_pos.z * 3.3) + TIME * 0.8) * 0.5 + 0.5;
		float width = 0.10 + 0.035 * sin(TIME * 1.15 + w_pos.x * 0.8 + w_pos.z * 0.6);
		float foam = (1.0 - smoothstep(width, width + 0.10, water_distance)) * (0.67 + breakup * 0.20) * inside;
		col = mix(col, vec3(0.86, 0.87, 0.80), foam * 0.72);
	}
	ALBEDO = pow(col, vec3(2.2));
}
