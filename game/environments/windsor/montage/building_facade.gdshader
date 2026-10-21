shader_type spatial;
// Generic tower facade (ours, CC0): a window grid in world space, a few lit windows, no logos or lettering. Used for the
// distant skyline across the river (a real backdrop only, generic towers).
render_mode cull_back, specular_schlick_ggx;

uniform vec3 wall_color : source_color = vec3(0.45, 0.48, 0.52);
uniform vec3 glass_color : source_color = vec3(0.12, 0.2, 0.3);
uniform vec2 cell = vec2(3.3, 3.9);
uniform float glass_fill = 0.62;
uniform float lit_amount = 0.05;
uniform float seed = 1.0;
uniform float band = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.0) * 43758.5453); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	bool side = abs(wnrm.y) < 0.5;
	float u = abs(wnrm.x) > abs(wnrm.z) ? wpos.z : wpos.x;
	vec2 g = vec2(u, wpos.y) / cell;
	vec2 id = floor(g);
	vec2 f = fract(g);
	float win = side ? step(0.5 - glass_fill * 0.5, f.x) * step(f.x, 0.5 + glass_fill * 0.5) * step(0.5 - glass_fill * 0.42, f.y) * step(f.y, 0.5 + glass_fill * 0.42) : 0.0;
	if (band > 0.5) { win = side ? step(0.18, f.y) * step(f.y, 0.82) : 0.0; }
	float h = hash(id);
	vec3 gl = glass_color * (0.8 + 0.5 * h) * (0.8 + 0.3 * f.y);
	float lit = step(1.0 - lit_amount, hash(id + 7.0));
	vec3 col = mix(wall_color * (0.9 + 0.2 * hash(id + 3.0)), gl, win);
	ALBEDO = col;
	ROUGHNESS = mix(0.8, 0.12, win);
	METALLIC = win * 0.55;
	EMISSION = vec3(1.0, 0.82, 0.55) * lit * win * 0.5;
}
