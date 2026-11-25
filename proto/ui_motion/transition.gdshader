shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform int mode = 0; // 1 tide, 2 bell, 3 lantern, 4 desaturation/vignette
uniform float progress = 0.0;
uniform float phase = 0.0;
uniform float desaturate = 0.0;
uniform float vignette = 0.0;
uniform float wave_cycles = 2.0;
uniform float wave_secondary_cycles = 5.0;
uniform float wave_amplitude = 0.018;
uniform float wave_secondary_amplitude = 0.008;
uniform float wave_phase = 1.7;
uniform float wave_secondary_phase = 2.3;
uniform float grain_strength = 0.018;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec3 source = texture(screen_tex, uv).rgb;
    float gray = dot(source, vec3(0.299, 0.587, 0.114));
    source = mix(source, vec3(gray), desaturate);
    source *= 1.0 - vignette * smoothstep(0.10, 0.72, length(uv - 0.5));
    float grain = fract(sin(dot(floor(uv * vec2(1280.0, 800.0)), vec2(12.9898, 78.233))) * 43758.5453);
    vec3 ink = vec3(0.027, 0.055, 0.077) + (grain - 0.5) * grain_strength;
    float mask = 0.0;
    vec3 result = source;
    if (mode == 1) {
        float wave = sin(uv.x * 6.283185 * wave_cycles + phase * wave_phase) * wave_amplitude;
        wave += sin(uv.x * 6.283185 * wave_secondary_cycles - phase * wave_secondary_phase) * wave_secondary_amplitude;
        float edge = mix(1.05, -0.05, progress) + wave;
        mask = smoothstep(edge - 0.003, edge + 0.003, uv.y);
        result = mix(source, ink, mask);
        result += vec3(0.24, 0.30, 0.29) * (1.0 - smoothstep(0.0, 0.003, abs(uv.y - edge))) * 0.32;
    } else if (mode == 2) {
        float distance_from_bell = length((uv - vec2(0.5, 0.44)) * vec2(1.6, 1.0));
        float radius = progress * 1.2;
        mask = 1.0 - smoothstep(radius - 0.025, radius, distance_from_bell);
        result = mix(source, vec3(0.0), mask);
        float ring = 1.0 - smoothstep(0.001, 0.008, abs(distance_from_bell - radius));
        result += vec3(0.49, 0.55, 0.56) * ring * sin(progress * 3.141593) * 0.65;
    } else if (mode == 3) {
        float d = length((uv - vec2(0.5, 0.46)) * vec2(1.6, 1.0));
        float radius = progress * 1.2;
        float opening = 1.0 - smoothstep(radius - 0.07, radius + 0.03, d);
        result = mix(vec3(0.0), source, opening);
        float rim = exp(-abs(d - radius) * 55.0) * sin(progress * 3.141593);
        result += vec3(0.54, 0.39, 0.15) * rim * 0.4;
    }
    COLOR = vec4(result, 1.0);
}
