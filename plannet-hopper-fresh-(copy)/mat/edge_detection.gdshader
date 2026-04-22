shader_type spatial;
render_mode blend_mix;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D NORMAL_TEXTURE : hint_normal_roughness_texture, filter_nearest;

uniform float opacity : hint_range(0.0, 1.0) = 0.5;
uniform bool shadows_enabled = true;
uniform bool highlights_enabled = true;
uniform float shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform float highlight_strength : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform vec3 highlight_color : source_color = vec3(1.);
uniform vec3 shadow_color : source_color = vec3(0.0);

float getDepth(vec2 screen_uv){
	float raw_depth = texture(DEPTH_TEXTURE, screen_uv)[0];
	return raw_depth;
}

float normalIndicator(vec3 normalEdgeBias, vec3 baseNormal, vec3 newNormal){
	float normalDiff = dot(baseNormal - newNormal, normalEdgeBias);
	return clamp(smoothstep(-.01, .01, normalDiff), 0.0, 1.0);
}

void fragment() {
	vec2 e = 1.0 / VIEWPORT_SIZE.xy;
	
	// Shadows (depth edges)
	float depth_diff = 0.0;
	if (shadows_enabled) {
		float depth = getDepth(SCREEN_UV);
		float du = getDepth(SCREEN_UV + vec2(0., -1.) * e);
		float dr = getDepth(SCREEN_UV + vec2(1., 0.) * e);
		float dd = getDepth(SCREEN_UV + vec2(0., 1.) * e);
		float dl = getDepth(SCREEN_UV + vec2(-1., 0.) * e);
		
		depth_diff += clamp(du - depth, 0., 1.);
		depth_diff += clamp(dd - depth, 0., 1.);
		depth_diff += clamp(dr - depth, 0., 1.);
		depth_diff += clamp(dl - depth, 0., 1.);
		depth_diff = smoothstep(0.2, 0.3, depth_diff);
	}
	
	// Highlights (normal edges)
	float normal_diff = 0.0;
	if (highlights_enabled) {
		vec3 normal = texture(NORMAL_TEXTURE, SCREEN_UV).rgb * 2.0 - 1.0;
		vec3 nu = texture(NORMAL_TEXTURE, SCREEN_UV + vec2(0., -1.) * e).rgb * 2.0 - 1.0;
		vec3 nr = texture(NORMAL_TEXTURE, SCREEN_UV + vec2(1., 0.) * e).rgb * 2.0 - 1.0;
		vec3 nd = texture(NORMAL_TEXTURE, SCREEN_UV + vec2(0., 1.) * e).rgb * 2.0 - 1.0;
		vec3 nl = texture(NORMAL_TEXTURE, SCREEN_UV + vec2(-1., 0.) * e).rgb * 2.0 - 1.0;
		
		vec3 normal_edge_bias = vec3(1., 1., 1.);
		normal_diff += normalIndicator(normal_edge_bias, normal, nu);
		normal_diff += normalIndicator(normal_edge_bias, normal, nr);
		normal_diff += normalIndicator(normal_edge_bias, normal, nd);
		normal_diff += normalIndicator(normal_edge_bias, normal, nl);
		normal_diff = smoothstep(0.2, 0.8, normal_diff);
		normal_diff = clamp(normal_diff - depth_diff, 0., 1.);
	}
	
	vec3 original_color = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	vec3 final = original_color;

	if (highlights_enabled) {
		vec3 final_highlight = mix(original_color, highlight_color, highlight_strength);
		final = mix(final, final_highlight, normal_diff);
	}
	if (shadows_enabled) {
		vec3 final_shadow = mix(original_color, shadow_color, shadow_strength);
		final = mix(final, final_shadow, depth_diff);
	}
	
	ALPHA = opacity;
	// Debug: visualize depth_diff
	// ALBEDO = vec3(depth_diff);

	// Debug: visualize normal_diff
	//ALBEDO = vec3(normal_diff);

	// Debug: visualize original screen color
	ALBEDO = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
}