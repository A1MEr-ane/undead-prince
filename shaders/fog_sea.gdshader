// 海面即雾面：雾色上叠一层随风缓慢滚动的云影。
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 fog_color = vec3(0.75, 0.76, 0.78);
uniform vec3 cloud_color = vec3(0.62, 0.66, 0.71);
uniform sampler2D cloud_noise : filter_linear, repeat_enable;
uniform vec2 wind = vec2(0.012, 0.006);
uniform float cloud_amount = 0.55;

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
	ALBEDO = pow(col, vec3(2.2));
}
