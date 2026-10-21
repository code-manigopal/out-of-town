shader_type spatial;
// Detroit River water for the opening montage (ours, CC0). Planar reflection from a mirrored camera (planar_reflection.gd),
// two scrolling procedural normal maps, Fresnel, a Beer-Lambert-ish shore fade and a little foam.
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform sampler2D reflection_tex : source_color, filter_linear, repeat_disable;
uniform sampler2D normal_a : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_b : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec3 deep_color : source_color = vec3(0.02, 0.04, 0.05);
uniform vec3 shallow_color : source_color = vec3(0.06, 0.1, 0.1);
uniform float reflection_gain = 1.0;
uniform float distort = 0.08;
uniform float wave_scale = 0.045;
uniform float wave_speed = 1.0;
uniform float roughness_base = 0.06;
uniform float shore_depth = 2.4;
uniform float foam_width = 0.35;
uniform vec3 foam_color : source_color = vec3(0.8, 0.84, 0.86);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	VERTEX.y += 0.05 * sin(world_pos.x * 0.18 + t * 0.9) * sin(world_pos.z * 0.13 + t * 0.7)
		+ 0.025 * sin(world_pos.x * 0.41 - t * 1.3 + world_pos.z * 0.22);
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 p = world_pos.xz;
	vec3 na = texture(normal_a, p * wave_scale + vec2(0.018, 0.007) * t).xyz * 2.0 - 1.0;
	vec3 nb = texture(normal_b, p * wave_scale * 2.7 - vec2(0.012, -0.02) * t).xyz * 2.0 - 1.0;
	vec3 nm = normalize(vec3(na.xy + nb.xy * 0.7, na.z + 0.6));
	float dist_fade = clamp(1.0 - length(VERTEX) * 0.0016, 0.25, 1.0);
	NORMAL_MAP = nm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.2 * dist_fade;

	// scene depth under the water (for the shore)
	float d = textureLod(depth_tex, SCREEN_UV, 0.0).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, d);
	vec4 vp = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	vp.xyz /= vp.w;
	float under = clamp(-vp.z - (-VERTEX.z), 0.0, 100.0);

	float fres = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	fres = mix(0.03, 1.0, fres);
	vec2 ruv = vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y) + nm.xy * distort * dist_fade;
	ruv = clamp(ruv, vec2(0.002), vec2(0.998));
	vec3 refl = texture(reflection_tex, ruv).rgb * reflection_gain;

	float depth_mix = clamp(under / shore_depth, 0.0, 1.0);
	vec3 body = mix(shallow_color, deep_color, depth_mix);
	float foam = (1.0 - smoothstep(0.0, foam_width, under)) * (0.55 + 0.45 * sin(p.x * 3.1 + t * 1.7) * sin(p.y * 2.7 - t * 1.1));
	ALBEDO = body * (1.0 - fres) + foam_color * foam * 0.6;
	EMISSION = refl * fres;
	ROUGHNESS = roughness_base + foam * 0.5;
	SPECULAR = 0.55;
	METALLIC = 0.0;
	ALPHA = clamp(under / 0.5, 0.0, 1.0);
}
