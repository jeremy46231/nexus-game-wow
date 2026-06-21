shader_type canvas_item;

// pulls a sprite's colour toward greyscale. 1.0 = untouched, 0.0 = full grey.
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
// brightens the sprite toward white. 0.0 = untouched, 1.0 = full white.
uniform float lightness : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 rgb = mix(vec3(grey), c.rgb, saturation);
	rgb = mix(rgb, vec3(1.0), lightness);
	COLOR = vec4(rgb, c.a);
}
