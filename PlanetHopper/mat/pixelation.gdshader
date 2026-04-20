shader_type canvas_item;
render_mode blend_mix;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float pixel_size : hint_range(1.0, 32.0) = 4.0;

void fragment() {
    // Grid size in normalized UV space
    vec2 grid_size = vec2(pixel_size) * SCREEN_PIXEL_SIZE;
    
    // Snap UV to grid
    vec2 pixelated_uv = floor(UV / grid_size) * grid_size;
    
    // Sample at snapped position
    COLOR = texture(SCREEN_TEXTURE, pixelated_uv);
}