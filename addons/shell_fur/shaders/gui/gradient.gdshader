shader_type canvas_item;

uniform vec4 color1 : source_color = vec4(0.43, 0.35, 0.29, 1.0);
uniform vec4 color2 : source_color= vec4(0.78, 0.63, 0.52, 1.0);

void fragment() {
	vec4 mixed_color = mix(color1, color2, UV.x);
	COLOR = mixed_color;
}