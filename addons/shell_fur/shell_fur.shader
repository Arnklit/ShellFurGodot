shader_type spatial;
render_mode cull_disabled, depth_draw_alpha_prepass;

uniform sampler2D pattern_texture : hint_black;
uniform vec4 base_color = vec4(0.43, 0.35, 0.29, 1.0);
uniform vec4 tip_color = vec4(0.78, 0.63, 0.52, 1.0);
uniform sampler2D color_texture : hint_albedo;
uniform sampler2D length_texture : hint_white;
uniform vec2 tiling = vec2(1.0, 1.0);
uniform vec4 transmission = vec4(0.3, 0.3, 0.3, 1.0);
uniform float roughness = 1.0;
uniform float normal_correction = 1.0;
uniform float density = 5.0;
uniform float thickness_base = 0.65;
uniform float thickness_tip = 0.3;
uniform float fur_length = 0.5;
uniform float length_rand = 0.3;
uniform float ao = 1.0;
uniform float gravity = 0.1;
uniform float wind_strength = 0.0;
uniform float wind_speed = 1.0;
uniform float wind_scale = 1.0;
uniform vec3 wind_angle = vec3(1.0, 0.0, 0.0);
uniform float normal_bias = 0.0;

// Should not be changed on the material, only through script.
uniform int layers = 40;
uniform float blend_shape_multiplier = 1.0;
varying vec3 extrusion_vec;
varying vec3 forces_vec;

int rand3(vec3 uv, int seed) {
	return int(4769.*fract(cos(floor(uv.y-5234.)*755.)*245.* sin(floor(uv.x-534.)*531.)*643.)*sin(floor(uv.z-53345.)*765.)*139.);
}

vec3 randVec3(vec3 uv, int seed) {
	int a = rand3(uv, seed)*5237;
	int p1 = (a & 1) * 2 - 1;
	int p2 = (a & 2) - 1;
	int p3 = (a & 4) / 2 - 1;
	return vec3( float(p1), float(p2), float(p3));
}


float perlin3D(vec3 uv, int seed) {
	vec3 fuv = fract(uv);
	float c1 = dot(fuv - vec3(0, 0, 0), randVec3(floor(uv) + vec3(0, 0, 0), seed));
	float c2 = dot(fuv - vec3(0, 0, 1), randVec3(floor(uv) + vec3(0, 0, 1), seed));
	float c3 = dot(fuv - vec3(0, 1, 0), randVec3(floor(uv) + vec3(0, 1, 0), seed));
	float c4 = dot(fuv - vec3(0, 1, 1), randVec3(floor(uv) + vec3(0, 1, 1), seed));
	float c5 = dot(fuv - vec3(1, 0, 0), randVec3(floor(uv) + vec3(1, 0, 0), seed));
	float c6 = dot(fuv - vec3(1, 0, 1), randVec3(floor(uv) + vec3(1, 0, 1), seed));
	float c7 = dot(fuv - vec3(1, 1, 0), randVec3(floor(uv) + vec3(1, 1, 0), seed));
	float c8 = dot(fuv - vec3(1, 1, 1), randVec3(floor(uv) + vec3(1, 1, 1), seed));
	return (1. + 
			mix(
				mix(
					mix(c1, c2, fuv.z), 
					mix(c3, c4, fuv.z), 
					fuv.y), 
				mix(
					mix(c5, c6, fuv.z), 
					mix(c7, c8, fuv.z), 
					fuv.y), 
				fuv.x)
			)/2.;
}

vec3 projectOnPlane( vec3 vec, vec3 normal ) {
	return vec - normal * dot( vec, normal );
}

void vertex() {
	// Rescaling the color values into vectors.
	extrusion_vec = (vec3(COLOR.xyz) * 2.0 - 1.0) * blend_shape_multiplier; 
	
	vec3 normal_biased_extrude = mix(NORMAL, extrusion_vec.xyz, COLOR.a);
	vec3 interpolated_extrude = mix(extrusion_vec, normal_biased_extrude, smoothstep(0.0, 2.0, normal_bias));
	vec3 offset_from_surface = interpolated_extrude * fur_length / float(layers);
	VERTEX += interpolated_extrude * fur_length * COLOR.a + offset_from_surface;

	vec3 winduv = VERTEX * wind_scale;
	winduv.y += TIME * wind_speed;	
	vec3 wind_dir_flattened = projectOnPlane(wind_angle, NORMAL);
	vec3 wind_vec = wind_dir_flattened * perlin3D(winduv, 0) * wind_strength;
	
	forces_vec = (vec4(vec3(0.0, -1.0, 0.0) * gravity + wind_vec, 0.0) * WORLD_MATRIX).xyz * length(extrusion_vec) * smoothstep(0.0, 2.0, COLOR.a);
	
	VERTEX += forces_vec;
}

void fragment() {
	// This seems a pretty solid way of discarding every other layer from the fragment shader
	// Maybe I'll use this for LODs for skinned shading. For static I will display
	// fewer instances with the MMI instead.
	//float every_other_layer = 2.0 / float(layers);
	//if (mod(COLOR.a + every_other_layer * .25, every_other_layer) > every_other_layer * .5) {
	//	discard;
	//}
	NORMAL = mix(NORMAL, projectOnPlane(VIEW, extrusion_vec.xyz), normal_correction);
	
	ALBEDO = (texture(color_texture, UV * tiling) * mix(base_color, tip_color, COLOR.a)).rgb;
	TRANSMISSION = transmission.rgb;
	ROUGHNESS = roughness;
	AO = 1.0 - (-COLOR.a + 1.0) * ao;
	
	// Workaround for issue https://github.com/godotengine/godot/issues/36669
	// to allow opaque prepass.
	vec2 pattern = texture(pattern_texture, UV * density).rg;
	float scissor_thresh =  mix(-thickness_base + 1.0, -thickness_tip + 1.0, COLOR.a); 
	float length_tex_value = texture(length_texture, UV * tiling).r;
	if (scissor_thresh < pattern.r * length_tex_value - pattern.r * length_tex_value * pattern.g * length_rand) {
    	ALPHA = 1.0;
	} else {
    	ALPHA = 0.0;
	}
}