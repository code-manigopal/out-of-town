shader_type canvas_item;
// Subtle filmic finish: luma-weighted grain, slight radial chromatic aberration, faint vignette.
// Kept very low so subtitles and HUD (drawn on a higher CanvasLayer) are never affected.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.03;
uniform float grain_size : hint_range(1.0, 4.0) = 1.5;
uniform float aberration : hint_range(0.0, 0.01) = 0.0006;
uniform float vignette : hint_range(0.0, 1.0) = 0.12;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - vec2(0.5);
	float r2 = dot(dir, dir);
	vec2 off = dir * aberration * (0.4 + 4.0 * r2);
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	vec2 px = floor(FRAGCOORD.xy / grain_size);
	float n = hash12(px + fract(TIME * 7.13) * 311.7) - 0.5;
	float weight = 1.0 - abs(luma - 0.45) * 1.2;
	col += vec3(n) * grain_strength * clamp(weight, 0.25, 1.0);
	col *= 1.0 - vignette * smoothstep(0.1, 0.55, r2);
	COLOR = vec4(col, 1.0);
}
