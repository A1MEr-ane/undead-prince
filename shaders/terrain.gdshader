// 地形与道具：不受实时光照。亮度来自烘焙的三光瓣天光体积，按太阳方向合成；
// 岩壁按高度画岩层；水线压暗；按到岛中心的距离混入雾色。
// 颜色计算在"感知空间"（类似 sRGB）里进行，最后转成线性输出。
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler3D sky_volume : filter_linear, repeat_disable;
uniform vec3 vol_size = vec3(25.0, 25.0, 10.0);
uniform float vol_base_y = -0.35;
uniform float vol_dy = 0.3;

uniform vec3 sun_dir = vec3(-0.6, -0.8, 0.0);   // 光线行进方向
uniform vec3 min_ambient = vec3(0.30, 0.27, 0.34);
uniform vec3 max_ambient = vec3(0.86, 0.90, 0.95);
uniform vec3 side_sun = vec3(0.36, 0.29, 0.20);
uniform vec3 fog_color = vec3(0.75, 0.76, 0.78);
uniform vec2 fog_center = vec2(12.0, 12.0);
uniform float fog_min = 7.0;
uniform float fog_max = 15.0;
uniform float water_y = 0.08;
uniform float saturation = 0.78;
uniform vec3 grade_color = vec3(0.52, 0.56, 0.62);
uniform float grade_amount = 0.06;

uniform vec3 albedo_color = vec3(1.0);
uniform bool use_vertex_color = true;
uniform bool cliff_bands = true;
uniform bool ground_surface = false;
uniform sampler2D shore_field : filter_linear, repeat_disable;
uniform float island_size = 24.0;
// UV.x 是程序网格写入的摆动权重；根部为零，只给草/树冠材质开启。
uniform bool wind_enabled = false;
uniform float wind_strength = 0.035;
uniform vec2 wind_direction = vec2(0.94, 0.34);

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	if (wind_enabled) {
		float wave = sin(TIME * 1.8 - dot(w_pos.xz, vec2(0.72, 0.44)));
		float flutter = sin(TIME * 3.7 + w_pos.x * 2.3 + w_pos.z * 1.9);
		vec2 sway = wind_direction * (wave + flutter * 0.18) * wind_strength * UV.x;
		// 装饰合批在世界坐标中生成；逆变换也支持外部带变换的实例。
		VERTEX += (inverse(MODEL_MATRIX) * vec4(sway.x, 0.0, sway.y, 0.0)).xyz;
		w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	}
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash1(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash1(dot(i, vec2(17.0, 131.0)));
	float b = hash1(dot(i + vec2(1.0, 0.0), vec2(17.0, 131.0)));
	float c = hash1(dot(i + vec2(0.0, 1.0), vec2(17.0, 131.0)));
	float d = hash1(dot(i + vec2(1.0), vec2(17.0, 131.0)));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 sky(vec3 p) {
	vec3 uvw = vec3(p.x + 0.5, p.z + 0.5, (p.y - vol_base_y) / vol_dy + 0.5) / vol_size;
	return texture(sky_volume, uvw).rgb;
}

// 岩层：按高度分条，每条随机深浅；用粗网格噪声把条带边缘错开
float strata(vec3 p) {
	float layer = (p.y + 3.0) * 4.2 + (noise2(p.xz * 1.1) - 0.5) * 0.65;
	float b = floor(layer);
	float width = max(fwidth(layer), 0.035);
	float value = mix(hash1(b - 1.0), hash1(b), smoothstep(0.0, width, fract(layer)));
	return mix(0.52, 0.72, value) + (noise2(p.xz * 3.0) - 0.5) * 0.035;
}

void fragment() {
	vec3 n = normalize(w_nrm);
	vec3 base = use_vertex_color ? COLOR.rgb : albedo_color;
	bool rock = cliff_bands && COLOR.a < 0.5;
	if (rock) {
		base = vec3(strata(w_pos)) * vec3(1.0, 0.97, 0.93) * COLOR.r;
	} else if (ground_surface) {
		float coast = (texture(shore_field, w_pos.xz / island_size).r - 0.5) * 16.0;
		float patch = noise2(w_pos.xz * 0.32);
		float grass = smoothstep(0.38, 1.85, coast + (patch - 0.5) * 0.7);
		// 二级以上台地即使贴近岸边也保持草皮，一级岸台逐渐露沙。
		grass = max(grass, smoothstep(0.46, 0.72, w_pos.y));
		vec3 sand = mix(vec3(0.72, 0.67, 0.52), vec3(0.84, 0.78, 0.60), patch);
		base = mix(sand, base * mix(0.93, 1.06, patch), grass);
	}

	// 三光瓣：R = +X 侧，G = 上方，B = −X 侧
	vec3 ao = sky(w_pos + n * 0.35);
	vec3 L = -normalize(sun_dir);
	vec3 w = vec3(max(L.x, 0.0), max(L.y, 0.0), max(-L.x, 0.0));
	float ws = w.x + w.y + w.z + 1e-4;
	float light = dot(ao, w) / ws;
	// 朝阳面：只有法线朝向某个光瓣、且该光瓣没被挡时才吃到太阳
	vec3 facing = vec3(max(n.x, 0.0), max(n.y, 0.0), max(-n.x, 0.0));
	float sunlit = dot(ao * w, facing) / ws;

	vec3 col = base * mix(min_ambient, max_ambient, light) + base * side_sun * sunlit;

	// 水线：岩壁贴近水面的一圈压暗
	float above = w_pos.y - water_y;
	if (rock) {
		float wet = 1.0 - smoothstep(0.025, 0.115, abs(above + 0.015));
		col *= 1.0 - wet * 0.18;
	}

	// 去饱和 + 往时段颜色偏
	float lum = dot(col, vec3(0.2, 0.7, 0.1));
	col = mix(vec3(lum), col, saturation);
	col = mix(col, grade_color, grade_amount);

	// 径向雾
	float d = length(w_pos.xz - fog_center);
	col = mix(col, fog_color, smoothstep(fog_min, fog_max, d));

	ALBEDO = pow(max(col, vec3(0.0)), vec3(2.2));
}
