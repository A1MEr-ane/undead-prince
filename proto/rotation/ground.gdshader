shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.12, 0.16, 0.18, 1.0);
uniform int kind = 0;
uniform float clock = 0.0;
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	if (r > 0.98) { discard; }
	vec3 ink = vec3(0.025, 0.035, 0.05);
	vec3 col = tint.rgb;
	if (kind == 0) {
		float ring = step(abs(r - 0.83), 0.035) + step(abs(r - 0.97), 0.025);
		float rune = step(abs(sin(atan(p.y, p.x) * 12.0)), 0.15) * step(0.70, r);
		col = mix(col * 0.22, col, clamp(ring + rune, 0.0, 1.0));
	} else {
		float flame = sin(p.x * 22.0 + clock * 3.0 + sin(p.y * 17.0)) * sin(p.y * 19.0 - clock * 5.0);
		col = mix(ink, col * 0.65, step(-0.30, flame));
		col = mix(col, tint.rgb * 1.5, step(0.53, flame));
		col = mix(col, ink, step(0.89, r));
	}
	ALBEDO = col;
}
