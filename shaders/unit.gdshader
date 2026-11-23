// 小兵精灵：只绕竖轴转的公告板 + 部位编码查调色板。
// 正交镜头俯角 30°，竖向乘 1/sin(60°) 抵消俯视压缩。
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D atlas : filter_nearest, repeat_disable;
uniform sampler2D palette : source_color, filter_nearest, repeat_disable;
uniform vec2 atlas_grid = vec2(8.0, 5.0);
uniform float quad_size = 0.8;
uniform float up_scale = 1.1547;
// 沿水平视线方向往镜头挪一点，避免贴着身后的崖壁时被吃掉
uniform float depth_nudge = 0.08;
// 脚下陷进草里：精灵底部按草量混成草色
uniform vec3 feet_color : source_color = vec3(0.36, 0.47, 0.25);
uniform float feet_height = 0.13;

instance uniform float frame = 0.0;
instance uniform float flip = 0.0;
instance uniform float palette_row = 0.0;
instance uniform float health = 1.0;
instance uniform float flash = 0.0;
instance uniform float spin = 0.0;
instance uniform float grass = 0.0;

void vertex() {
	vec2 pivot = vec2(0.0, quad_size * 0.4);
	vec2 p = VERTEX.xy - pivot;
	float c = cos(spin);
	float s = sin(spin);
	p = vec2(p.x * c - p.y * s, p.x * s + p.y * c);
	VERTEX.xy = p + pivot;
	VERTEX.z += depth_nudge;
	vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
	vec3 back = normalize(vec3(INV_VIEW_MATRIX[2].x, 0.0, INV_VIEW_MATRIX[2].z));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(0.0, up_scale, 0.0, 0.0), vec4(back, 0.0), MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 uv = UV;
	if (flip > 0.5) {
		uv.x = 1.0 - uv.x;
	}
	uv = clamp(uv, vec2(0.002), vec2(0.998));
	float f = floor(frame + 0.5);
	vec2 cell = vec2(mod(f, atlas_grid.x), floor(f / atlas_grid.x));
	vec4 t = texture(atlas, (cell + uv) / atlas_grid);
	if (t.a < 0.5) {
		discard;
	}
	int code = int(t.r * 15.0 + 0.5);
	vec3 col = texelFetch(palette, ivec2(code, int(palette_row + 0.5)), 0).rgb * t.g;
	// 受伤：按帧内像素位置撒血点，血量越低越多。
	vec2 px = floor(uv * 32.0);
	float h = fract(sin(dot(px, vec2(12.9898, 78.233))) * 43758.5453);
	bool cloth = code == 1 || code == 2 || code == 3 || code == 4 || code == 7;
	if (cloth && h < (1.0 - health) * 0.22) {
		col = vec3(0.42, 0.03, 0.03) * t.g;
	}
	float feet = clamp((UV.y - (1.0 - feet_height)) / feet_height, 0.0, 1.0);
	col = mix(col, feet_color, feet * grass * 0.85);
	col = mix(col, vec3(1.0, 0.96, 0.9), flash);
	ALBEDO = col;
}
