shader_type spatial;
render_mode cull_disabled;
// Water in the toilet bowl. `flush` (0..1) drives a swirl that spins the water down the drain.
uniform vec4 water_color : source_color = vec4(0.45, 0.62, 0.7, 1.0);
uniform float flush = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = a + r * 7.0 - TIME * 7.0;
	float bands = sin(swirl * 3.0) * 0.5 + 0.5;
	float foam = flush * bands * smoothstep(1.0, 0.2, r);
	float hole = flush * smoothstep(0.35, 0.0, r);
	vec3 col = mix(water_color.rgb, vec3(0.92, 0.97, 1.0), foam * 0.7);
	col = mix(col, vec3(0.05, 0.08, 0.1), hole);
	ALBEDO = col;
	ROUGHNESS = 0.05;
	SPECULAR = 0.8;
	ALPHA = smoothstep(1.0, 0.92, r);
}
