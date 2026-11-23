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

varying vec3 w_pos;
varying vec3 w_nrm;

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	w_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash1(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

vec3 sky(vec3 p) {
	vec3 uvw = vec3(p.x + 0.5, p.z + 0.5, (p.y - vol_base_y) / vol_dy + 0.5) / vol_size;
	return texture(sky_volume, uvw).rgb;
}

// 岩层：按高度分条，每条随机深浅；用粗网格噪声把条带边缘错开
float strata(vec3 p) {
	float jitter = hash1(floor(p.x * 2.0) * 7.0 + floor(p.z * 2.0) * 13.0) - 0.5;
	float b = floor((p.y + 3.0) * 6.0 + jitter * 0.9);
	float dark = step(hash1(b), 0.32);
	return mix(0.74, 0.46, dark) + (hash1(b + 31.0) - 0.5) * 0.07;
}

void fragment() {
	vec3 n = normalize(w_nrm);
	vec3 base = use_vertex_color ? COLOR.rgb : albedo_color;
	bool rock = cliff_bands && COLOR.a < 0.5;
	if (rock) {
		base = vec3(strata(w_pos)) * vec3(1.0, 0.97, 0.93);
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
	if (rock && above > -0.05 && above < 0.07) {
		col *= 0.86;
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
