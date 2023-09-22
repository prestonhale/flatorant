shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D mask_texture: filter_linear, repeat_enable;
uniform vec4 masking_color: source_color;
uniform float masking_range = 0.1;

void fragment() {
	vec4 world_pixel = texture(SCREEN_TEXTURE, SCREEN_UV);
	vec4 mask_color = textureLod(mask_texture, UV, 0.0);
	if (length(abs(masking_color - mask_color)) <= masking_range) {
		discard;
	}
}
