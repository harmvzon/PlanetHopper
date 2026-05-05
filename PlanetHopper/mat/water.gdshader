shader_type spatial;

uniform float specular = 0.9;
uniform float roughness = 0.2;
uniform float radius = 8.0;
uniform float level = 4.0;
uniform sampler2D gradient: repeat_disable;
uniform sampler2D depth_texture : source_color, hint_depth_texture, filter_nearest;

float get_depth(vec2 screen_uv, mat4 inv_projection_matrix) {
	float depth = texture(depth_texture, screen_uv).r;
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
	vec4 view = inv_projection_matrix * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return view.z;
}

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	ROUGHNESS = roughness;
	SPECULAR = specular;
	
	float depth_dif = VERTEX.z - get_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float color_uv = depth_dif / (level - radius);
	ALBEDO = texture(gradient, vec2(color_uv, 0.0)).rgb;
	
}