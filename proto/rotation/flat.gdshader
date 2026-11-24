shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, blend_mix, depth_draw_opaque;
void fragment() {
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a;
}
