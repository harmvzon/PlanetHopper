shader_type spatial;

uniform vec3 colorA : source_color = vec3(0.2, 0.5, 0.3);
uniform vec3 colorB : source_color = vec3(0.5, 0.8, 0.4);
uniform vec3 colorC : source_color = vec3(0.9, 1.0, 0.6);
uniform float speed : hint_range(0.0, 2.0) = 1.0;
uniform float degradation : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	// Test: just average the three colors
	vec3 col = (colorA + colorB + colorC) / 3.0;
	
	// Lerp toward gray when degraded
	vec3 gray = vec3(0.25, 0.22, 0.20);
	col = mix(col, gray, degradation);
	
	ALBEDO = col;
}