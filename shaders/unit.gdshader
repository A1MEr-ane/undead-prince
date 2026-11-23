// 小兵精灵：朝向镜头的公告板 + 部位编码查调色板。
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D atlas : filter_nearest, repeat_disable;
uniform sampler2D palette : source_color, filter_nearest, repeat_disable;
uniform vec2 atlas_grid = vec2(8.0, 5.0);
uniform float quad_size = 0.8;
// 沿视线方向往镜头挪一点，避免身体后仰时插进身后的坡。
uniform float depth_nudge = 0.22;

instance uniform float frame = 0.0;
instance uniform float flip = 0.0;
instance uniform float palette_row = 0.0;
instance uniform float health = 1.0;
instance uniform float flash = 0.0;
instance uniform float spin = 0.0;

void vertex() {
	vec2 pivot = vec2(0.0, quad_size * 0.4);
	vec2 p = VERTEX.xy - pivot;
	float c = cos(spin);
	float s = sin(spin);
	p = vec2(p.x * c - p.y * s, p.x * s + p.y * c);
	VERTEX.xy = p + pivot;
	VERTEX.z += depth_nudge;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
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
	col = mix(col, vec3(1.0, 0.96, 0.9), flash);
	ALBEDO = col;
}
