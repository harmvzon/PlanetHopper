shader_type spatial;

uniform float specular = 0.9;
uniform float roughness = 0.2;
uniform float radius = 8.0;
uniform float level = 4.0;
uniform sampler2D gradient: repeat_disable;
uniform sampler2D depth_texture : source_color, hint_depth_texture, filter_nearest;
uniform float foam_distance : hint_range(0.0, 1.0) = 0.1;
uniform float foam_softness : hint_range(0.0, 0.5) = 0.1;
uniform vec3 foam_color : hint_color(1.0, 1.0, 0.95);

float get_depth(vec2 screen_uv, mat4 inv_projection_matrix) {
	float depth = texture(depth_texture, screen_uv).r;
	vec3 ndc = vec3(screen_uv * 2.0 - 1.0, depth);
	vec4 view = inv_projection_matrix * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	ROUGHNESS = roughness;
	SPECULAR = specular;
	
	// Get base water color from depth
	float depth_dif = VERTEX.z - get_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	float color_uv = depth_dif / (level - radius);
	vec3 water_color = texture(gradient, vec2(color_uv, 0.0)).rgb;
	
	// Foam edge detection: sample 4 neighbors
	float water_depth = VERTEX.z;
	vec2 texel_size = 1.0 / VIEWPORT_SIZE.xy;
	
	vec2 uvs[4];
	uvs[0] = vec2(SCREEN_UV.x, SCREEN_UV.y + texel_size.y);
	uvs[1] = vec2(SCREEN_UV.x, SCREEN_UV.y - texel_size.y);
	uvs[2] = vec2(SCREEN_UV.x + texel_size.x, SCREEN_UV.y);
	uvs[3] = vec2(SCREEN_UV.x - texel_size.x, SCREEN_UV.y);
	
	float edge_count = 0.0;
	for (int i = 0; i < 4; i++) {
		float neighbor_depth = get_depth(uvs[i], INV_PROJECTION_MATRIX);
		float depth_diff = water_depth - neighbor_depth;
		// Only count edges where terrain is closer (positive depth_diff)
		if (depth_diff > foam_distance) {
			edge_count += 1.0;
		}
	}
	
	// Normalize to 0-1 range
	float edge_strength = edge_count / 4.0;
	float foam_mask = smoothstep(0.0, foam_softness, edge_strength);
	
	// Blend foam into water
	ALBEDO = mix(water_color, foam_color, foam_mask);
	
	// Optional: add a highlight
	EMISSION += vec3(0.1) * foam_mask;
}
