shader_type sky;

uniform vec3 sky_color : source_color = vec3(0.05, 0.05, 0.15);
uniform vec3 star_color : source_color = vec3(1.0);
uniform float star_density : hint_range(0.0, 1.0) = 0.3;
uniform float star_brightness : hint_range(0.0, 2.0) = 1.0;

float hash(vec3 p) {
    return fract(sin(dot(p, vec3(12.9898, 78.233, 45.164))) * 43758.5453);
}

float stars(vec3 direction, float density) {
    vec3 p = normalize(direction) * 100.0;
    vec3 i = floor(p);
    vec3 f = fract(p);
    
    float star_value = 0.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            for (int z = -1; z <= 1; z++) {
                vec3 cell = i + vec3(float(x), float(y), float(z));
                float h = hash(cell);
                if (h < density) {
                    vec3 offset = vec3(float(x), float(y), float(z)) + vec3(
                        fract(sin(h * 73.0) * 0.5 + 0.5),
                        fract(sin(h * 97.0) * 0.5 + 0.5),
                        fract(sin(h * 113.0) * 0.5 + 0.5)
                    );
                    float dist = length(f - offset);
                    float brightness = pow(1.0 - dist, 3.0) * h * star_brightness;
                    star_value += brightness;
                }
            }
        }
    }
    return star_value;
}

void sky() {
    vec3 direction = normalize(EYEDIR);
    vec3 final_color = sky_color;
    final_color += stars(direction, star_density) * star_color;
    COLOR = final_color;
}