shader_type spatial;
render_mode unshaded, cull_disabled;
// Shows the mirrored camera's SubViewport. The virtual camera looks into the room through the mirror window,
// so its image is left-right reversed relative to what a viewer in front sees; flip U back.
uniform sampler2D reflection : source_color, filter_linear, repeat_disable;
uniform vec4 tint : source_color = vec4(0.93, 0.96, 0.98, 1.0);
uniform float live = 1.0;
uniform vec4 idle_color : source_color = vec4(0.55, 0.6, 0.64, 1.0);

void fragment() {
	vec2 uv = vec2(1.0 - UV.x, UV.y);
	vec3 c = texture(reflection, uv).rgb * tint.rgb;
	// faint silvering falloff and a slight vignette near the edges
	float e = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	c *= mix(0.82, 1.0, smoothstep(0.0, 0.08, e));
	// not rendering (player elsewhere): a dull silvered glass instead of a black hole
	vec3 idle = idle_color.rgb * mix(0.8, 1.0, UV.y);
	ALBEDO = mix(idle, c, live);
}
