shader_type spatial;
render_mode unshaded,fog_disabled;

uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D NORMAL_TEXTURE : hint_normal_roughness_texture, filter_nearest;

uniform float lineAlpha = 0.7;
uniform float lineHighlight = 0.2;
uniform float lineShadow = 0.55;
uniform float pixel_size : hint_range(0.0, 100.0, 2.0) = 4.0;

float GetLinearDepth(vec2 sUV, sampler2D depthTexture, mat4 invProjectionMat, float mask){
	float depth = texture(depthTexture, sUV).x * mask;
	vec3 ndc = vec3(sUV * 2.0 - 1.0, depth);
    vec4 view = invProjectionMat * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

vec3 GetNormal(vec2 uv, sampler2D normalTexture, float mask){
	vec3 normal = texture(normalTexture, uv).rgb;
	normal = normal * 2.0 - 1.0 * mask;
	return normal;
}

float NormalEdgeIndicator(vec3 normalEdgeBias, vec3 normal, vec3 neighborNormal, float depthDifference){
	float normalDifference = dot(normal - neighborNormal, normalEdgeBias);
	float normalIndicator = clamp(smoothstep(-.01, .01, normalDifference), 0.0, 1.0);
	float depthIndicator = clamp(sign(depthDifference * .25 + .0025), 0.0, 1.0);
	return (1.0 - dot(normal, neighborNormal)) * depthIndicator * normalIndicator;
}

vec3 GetPixelatedColor(vec2 uv, sampler2D screenTexture, float psize){
	vec2 tex_size = vec2(textureSize(screenTexture, 0));
	vec2 pixel_count = tex_size / psize;
	vec2 pixelated_uv = floor(uv * pixel_count) / pixel_count;
	return texture(screenTexture, pixelated_uv).rgb;
}

void vertex(){
  POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 tex_size = vec2(textureSize(SCREEN_TEXTURE, 0));
	vec2 pixel_count = tex_size / pixel_size;
	vec2 pixelated_uv = floor(SCREEN_UV * pixel_count) / pixel_count;

	// Offset in pixelated grid space
	float grid_offset = (1.0 / pixel_count.x);
	vec2 UVOffsets[4];
		UVOffsets[0] = pixelated_uv + vec2(0.0, -grid_offset);
		UVOffsets[1] = pixelated_uv + vec2(0.0, grid_offset);
		UVOffsets[2] = pixelated_uv + vec2(grid_offset, 0.0);
		UVOffsets[3] = pixelated_uv + vec2(-grid_offset, 0.0);

	float outlineMask = texture(NORMAL_TEXTURE, SCREEN_UV).a;
	outlineMask = ceil(outlineMask);

	float depthDifference = 0.1;
	float invDepthDifference = 0.5;
	float depth = GetLinearDepth(pixelated_uv, DEPTH_TEXTURE, INV_PROJECTION_MATRIX, outlineMask);
	

	for (int i = 0; i < UVOffsets.length(); i++){
		float dOff = GetLinearDepth(UVOffsets[i], DEPTH_TEXTURE, INV_PROJECTION_MATRIX, outlineMask);
		depthDifference += clamp(dOff - depth, 0.0, 1.0);
		invDepthDifference += depth - dOff;
	}
	invDepthDifference = clamp(invDepthDifference, 0.0, 1.0);
	invDepthDifference = clamp(smoothstep(0.9, 0.9, invDepthDifference) * 10.0, 0.0, 1.0);
	depthDifference = smoothstep(0.25, 0.3, depthDifference);

	float normalDifference = 0.;
	vec3 normalEdgeBias = vec3(1.0, 1.0, 1.0);
	vec3 normal = GetNormal(pixelated_uv, NORMAL_TEXTURE, outlineMask);

	for (int i = 0; i < UVOffsets.length(); i++){
		vec3 nOff = GetNormal(UVOffsets[i], NORMAL_TEXTURE, outlineMask);
		normalDifference += NormalEdgeIndicator(normalEdgeBias, normal, nOff, depthDifference);
	}
	normalDifference = smoothstep(0.2, 0.2, normalDifference);
	normalDifference = clamp(normalDifference - invDepthDifference, 0.0, 1.0);
	
	ALBEDO = GetPixelatedColor(SCREEN_UV, SCREEN_TEXTURE, pixel_size);
	float lineMask = clamp(0.1, lineAlpha, (depthDifference + normalDifference * 5.0));
	ALBEDO += clamp((normalDifference - depthDifference), 0.0, 1.0) * lineHighlight;
	ALBEDO -= ALBEDO * depthDifference * lineShadow;
	
}