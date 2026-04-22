shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

// SubViewport render target — your 3D world at low resolution
uniform sampler2D world_viewport : filter_nearest, source_color;
uniform vec2 viewport_size; // Set from script: SubViewport.size

// Edge detection uniforms (unchanged)
uniform float lineAlpha = 0.7;
uniform float lineHighlight = 0.2;
uniform float lineShadow = 0.55;

// Pixelation now handled by hardware — viewport_size is your "pixel size"

// We need depth and normal from SubViewport too
// Option A: Use MRT (Multi-Render Target) — requires custom SubViewport setup
// Option B: Pack depth into alpha, reconstruct normal from depth derivatives

// Simpler approach: MRT with NormalRoughness + Depth textures
uniform sampler2D world_depth : hint_depth_texture, filter_nearest;
uniform sampler2D world_normal : hint_normal_roughness_texture, filter_nearest;

float GetLinearDepth(vec2 uv, sampler2D depthTex, mat4 invProj) {
	float depth = texture(depthTex, uv).x;
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	vec4 view = invProj * vec4(ndc, 1.0);
	view.xyz /= view.w;
	return -view.z;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	// UVs are full-screen quad; sample into SubViewport space
	vec2 uv = UV; // 0-1 across screen
	
	// If SubViewport aspect doesn't match window, handle letterboxing here
	vec2 viewport_uv = uv;
	
	// Sample at pixel centers to avoid sub-pixel drift
	vec2 texel = 1.0 / viewport_size;
	vec2 center_uv = floor(viewport_uv * viewport_size) / viewport_size + texel * 0.5;
	
	// Neighbor samples for edge detection (in viewport texels)
	vec2 offsets[4];
	offsets[0] = center_uv + vec2(0.0, -texel.y);
	offsets[1] = center_uv + vec2(0.0, texel.y);
	offsets[2] = center_uv + vec2(texel.x, 0.0);
	offsets[3] = center_uv + vec2(-texel.x, 0.0);
	
	// Depth edge detection
	float depth = GetLinearDepth(center_uv, world_depth, INV_PROJECTION_MATRIX);
	float depthDiff = 0.0;
	
	for (int i = 0; i < 4; i++) {
		float d = GetLinearDepth(offsets[i], world_depth, INV_PROJECTION_MATRIX);
		depthDiff += abs(d - depth);
	}
	depthDiff = smoothstep(0.1, 0.2, depthDiff);
	
	// Normal edge detection
	vec3 normal = texture(world_normal, center_uv).rgb * 2.0 - 1.0;
	float normalDiff = 0.0;
	
	for (int i = 0; i < 4; i++) {
		vec3 n = texture(world_normal, offsets[i]).rgb * 2.0 - 1.0;
		normalDiff += 1.0 - dot(normal, n);
	}
	normalDiff = smoothstep(0.2, 0.3, normalDiff);
	
	// Composite
	vec3 color = texture(world_viewport, center_uv).rgb;
	float edge = clamp(depthDiff + normalDiff * 2.0, 0.0, 1.0) * lineAlpha;
	
	color += edge * lineHighlight;
	color -= color * depthDiff * lineShadow;
	
	ALBEDO = color;
}