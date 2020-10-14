shader_type spatial;
render_mode cull_disabled, depth_draw_alpha_prepass;

uniform sampler2D pattern_texture : hint_black;
uniform vec4 base_color = vec4(0.43, 0.35, 0.29, 1.0);
uniform vec4 tip_color = vec4(0.78, 0.63, 0.52, 1.0);
uniform sampler2D color_texture : hint_albedo;
uniform vec4 transmission = vec4(0.3, 0.3, 0.3, 1.0);
uniform float roughness = 1.0;
uniform float density = 5.0;
uniform float thickness_base = 0.65;
uniform float thickness_tip = 0.3;
uniform float fur_length = 0.5;
uniform sampler2D length_texture : hint_white;
uniform float length_rand = 0.3;
uniform float ao = 1.0;
uniform float gravity = 0.1;

// Should not be changed on the material, only through script.
uniform int layers = 40;
uniform float blend_shape_multiplier = 1.0;
varying vec3 adjusted_color;
varying vec3 gravity_vec;

void vertex() {
	// rescaling the color values into vectors.
	adjusted_color = (vec3(COLOR.xyz) * 2.0 - 1.0) * blend_shape_multiplier; 
	
	VERTEX += (adjusted_color.xyz * fur_length * COLOR.a) + adjusted_color.xyz * (fur_length / float(layers)); 
	// Below is an attempt to make the fur bend towards the blend shape, but I think I'd need to add some control to that
	//VERTEX += mix(NORMAL * (fur_length / float(layers)), adjusted_color.xyz, COLOR.a) * blend_shape_multiplier * fur_length * COLOR.a  + adjusted_color.xyz * (fur_length / float(layers));

		
	gravity_vec = (vec4(0.0, -1.0, 0.0, 0.0) * WORLD_MATRIX).xyz * length(adjusted_color) * smoothstep(0.0, 1.0, COLOR.a * gravity);
	
	VERTEX += gravity_vec;
}

vec3 projectOnPlane( vec3 vec, vec3 normal ) {
    return vec - normal * ( dot( vec, normal ) / dot( normal, normal ) );
}

void fragment() {
	// This seems a pretty solid way of discarding every other layer from the fragment shader
	// Maybe I'll use this for LODs for skinned shading. For static I will display
	// fewer instances with the MMI instead.
	//float every_other_layer = 2.0 / float(layers);
	//if (mod(COLOR.a + every_other_layer * .25, every_other_layer) > every_other_layer * .5) {
	//	discard;
	//}
	NORMAL = projectOnPlane(VIEW, normalize(adjusted_color.xyz + gravity_vec));
	
	vec2 pattern = texture(pattern_texture, UV * density).rg;
	float strand = pattern.r;
	float cell = pattern.g;
	
	ALBEDO = (texture(color_texture, UV) * mix(base_color, tip_color, COLOR.a)).rgb;
	TRANSMISSION = transmission.rgb;
	ROUGHNESS = roughness;
	AO = 1.0 - (-COLOR.a + 1.0) * ao;
	
	// Workaround for issue https://github.com/godotengine/godot/issues/36669
	// to allow opaque prepass.
	float scissor_thresh =  mix(-thickness_base + 1.0, -thickness_tip + 1.0, COLOR.a); 
	if (cell * length_rand < -COLOR.a + 1.0 * texture(length_texture, UV).r ) {
		if (scissor_thresh < strand) {
			ALPHA = 1.0;
		} else {
			ALPHA = 0.0;
		}
	} else {
		ALPHA = 0.0;
	}
}