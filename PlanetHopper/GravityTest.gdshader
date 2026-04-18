shader_type spatial;

uniform vec3 color1 : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 color2 : source_color = vec3(0.2, 0.2, 0.2);
uniform float scale : hint_range(1.0, 50.0) = 10.0;

void fragment() {
    vec2 uv = UV * scale;
    float checker = mod(floor(uv.x) + floor(uv.y), 2.0);
    ALBEDO = mix(color1, color2, checker);
}