shader_type spatial;

uniform float min_height;
uniform float max_height;
uniform sampler2D height_color;
uniform float degradation : hint_range(0.0, 1.0) = 0.0;

varying float height;

void vertex() {
	height = length(VERTEX);
}

void fragment() {
	float t = height / (max_height - min_height) - (min_height / (max_height - min_height));
	vec3 color = texture(height_color, vec2(t, 0.0)).rgb;
	vec3 depleted = vec3(0.25, 0.22, 0.20); 
	ALBEDO = mix(color, depleted, degradation); 
}