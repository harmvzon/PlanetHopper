shader_type spatial;

uniform vec3 colorA : source_color = vec3(0.2, 0.5, 0.3);
uniform vec3 colorB : source_color = vec3(0.5, 0.8, 0.4);
uniform vec3 colorC : source_color = vec3(0.9, 1.0, 0.6);
uniform float speed : hint_range(0.0, 2.0) = 1.0;
uniform float degradation : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = VERTEX;
}

float noise(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

float smoothnoise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float n000 = noise(i + vec3(0.0, 0.0, 0.0));
	float n100 = noise(i + vec3(1.0, 0.0, 0.0));
	float n010 = noise(i + vec3(0.0, 1.0, 0.0));
	float n110 = noise(i + vec3(1.0, 1.0, 0.0));
	float n001 = noise(i + vec3(0.0, 0.0, 1.0));
	float n101 = noise(i + vec3(1.0, 0.0, 1.0));
	float n011 = noise(i + vec3(0.0, 1.0, 1.0));
	float n111 = noise(i + vec3(1.0, 1.0, 1.0));
	
	float nx0 = mix(n000, n100, f.x);
	float nx1 = mix(n010, n110, f.x);
	float nxy0 = mix(nx0, nx1, f.y);
	
	float nx2 = mix(n001, n101, f.x);
	float nx3 = mix(n011, n111, f.x);
	float nxy1 = mix(nx2, nx3, f.y);
	
	return mix(nxy0, nxy1, f.z);
}

void fragment() {
	vec3 p = world_pos * 2.0;
	p += vec3(TIME * speed * 0.2, TIME * speed * 0.15, TIME * speed * 0.1);
	
	float n1 = smoothnoise(p);
	float n2 = smoothnoise(p * 2.0 + 10.0);
	float n3 = smoothnoise(p * 4.0 + 20.0);
	
	vec3 col = mix(colorA, colorB, n1);
	col = mix(col, colorC, n2 * 0.5 + n3 * 0.5);
	
	vec3 gray = vec3(0.25, 0.22, 0.20);
	col = mix(col, gray, degradation);
	
	ALBEDO = col;
}