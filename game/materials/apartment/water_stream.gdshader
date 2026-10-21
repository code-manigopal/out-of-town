shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
// Falling tap water: a thin translucent column with streaks running down it.
uniform vec4 water_color : source_color = vec4(0.6, 0.78, 0.95, 0.7);
uniform float speed = 2.2;

void fragment() {
	float streak = sin(UV.y * 40.0 - TIME * speed * 18.0 + sin(UV.x * 18.85) * 2.0) * 0.5 + 0.5;
	float edge = 1.0 - abs(UV.x * 2.0 - 1.0);
	ALBEDO = mix(water_color.rgb, vec3(0.95, 0.98, 1.0), streak * 0.3);
	ALPHA = water_color.a * (0.6 + 0.4 * streak);
}
