// UV sprite: nearest RG/light data, filtered supersample coverage, local part texture.
// 正交镜头俯角 30°，竖向乘 1/sin(60°) 抵消俯视压缩。
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, alpha_to_coverage_and_one;

uniform sampler2D atlas : filter_nearest, repeat_disable;
// Same atlas, separate sampler: interpolating encoded RG would cross materials.
uniform sampler2D atlas_coverage : filter_linear, repeat_disable;
uniform sampler2D parts : source_color, filter_linear, repeat_disable;
uniform vec2 look_grid = vec2(2.0, 2.0);
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
	vec2 frame_size = vec2(textureSize(atlas, 0)) / atlas_grid;
	uv = clamp(uv, 0.5 / frame_size, vec2(1.0) - 0.5 / frame_size);
	float f = floor(frame + 0.5);
	vec2 cell = vec2(mod(f, atlas_grid.x), floor(f / atlas_grid.x));
	vec2 atlas_uv = (cell + uv) / atlas_grid;
	vec4 t = texture(atlas, atlas_uv);
	float coverage = texture(atlas_coverage, atlas_uv).a;
	float look = clamp(floor(palette_row + 0.5), 0.0, look_grid.x * look_grid.y - 1.0);
	vec2 look_cell = vec2(mod(look, look_grid.x), floor(look / look_grid.x));
	vec4 material = texture(parts, (look_cell + t.rg) / look_grid);
	float light = t.b <= 0.5 ? 0.6 + t.b * 0.8 : 0.7 + t.b * 0.6;
	vec3 col = material.rgb * light;

	// Alpha in the part sheet is a stable, smooth blood field, not opacity.
	// Its coordinates follow each body part; no TIME or screen-space randomness.
	ivec2 slot = ivec2(floor(t.rg * 4.0));
	int part = slot.y * 4 + slot.x + 1;
	bool stainable = part == 1 || part == 2 || part == 3 || part == 4 || part == 7;
	float wound = sqrt(clamp(1.0 - health, 0.0, 1.0));
	float blood = smoothstep(1.02 - wound * 0.82, 1.10 - wound * 0.82, material.a);
	if (stainable) {
		col = mix(col, col * vec3(0.37, 0.055, 0.075), blood * 0.92);
	}
	// Spectral eyes retain their bright cyan-green color in the baked shadows.
	if (part == 9 && look >= 2.0) {
		col = material.rgb * 1.2;
	}
	float feet = clamp((UV.y - (1.0 - feet_height)) / feet_height, 0.0, 1.0);
	col = mix(col, feet_color, feet * grass * 0.85);
	col = mix(col, vec3(1.0, 0.96, 0.9), clamp(flash, 0.0, 1.0));
	ALBEDO = col;
	// Alpha scissor keeps depth writes and avoids transparent-sprite sorting.
	// Project uses 4x MSAA; alpha-to-coverage smooths the sampled silhouette.
	ALPHA = coverage;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ALPHA_ANTIALIASING_EDGE = 0.3;
	ALPHA_TEXTURE_COORDINATE = uv * frame_size;
}
