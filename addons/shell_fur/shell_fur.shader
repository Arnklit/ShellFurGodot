shader_type spatial;
render_mode depth_draw_alpha_prepass;

uniform sampler2D pattern_texture : hint_black;
uniform vec4 base_color : hint_color = vec4(0.43, 0.35, 0.29, 1.0);
uniform vec4 tip_color : hint_color = vec4(0.78, 0.63, 0.52, 1.0);
uniform sampler2D color_texture : hint_albedo;
uniform vec2 color_tiling = vec2(1.0, 1.0);
uniform sampler2D length_texture : hint_white;
uniform vec2 length_tiling = vec2(1.0, 1.0);
uniform vec4 transmission = vec4(0.3, 0.3, 0.3, 1.0);
uniform float roughness = 1.0;
uniform float normal_adjustment = 0.0;
uniform float density = 5.0;
uniform float thickness_base = 0.75;
uniform float thickness_tip = 0.3;
uniform float fur_length = 0.5;
uniform float length_rand = 0.3;
uniform float ao = 1.0;
uniform float wind_strength = 0.0;
uniform float wind_speed = 1.0;
uniform float wind_scale = 1.0;
uniform vec3 wind_angle = vec3(1.0, 0.0, 0.0);
uniform vec3 physics_pos_offset;
uniform mat4 physics_rot_offset;
uniform float normal_bias = 0.0;
uniform float LOD = 1.0;
uniform float fur_contract = 0.0;

// Should not be changed on the material, only through script.
uniform int layers = 40;
uniform float blend_shape_multiplier = 1.0;
varying vec3 extrusion_vec;
varying vec3 forces_vec;
varying float lod_adjusted_layer_value;

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
	if (LOD >= COLOR.a) {
		lod_adjusted_layer_value = COLOR.a / LOD;
		// Rescaling the color values into vectors.
		extrusion_vec = ((vec3(COLOR.xyz) * 2.0 - 1.0) * blend_shape_multiplier); 
		
		vec3 normal_biased_extrude = mix(NORMAL * blend_shape_multiplier, extrusion_vec, lod_adjusted_layer_value);
		vec3 interpolated_extrude = mix(extrusion_vec, normal_biased_extrude, smoothstep(0.0, 2.0, normal_bias));
		vec3 offset_from_surface = interpolated_extrude * fur_length / float(layers);
		VERTEX += (vec4(interpolated_extrude * fur_length * lod_adjusted_layer_value + offset_from_surface, 0.0) * physics_rot_offset).xyz;
		VERTEX -= fur_contract * extrusion_vec * fur_length;
		
		vec3 winduv = VERTEX * wind_scale;
		winduv.y += TIME * wind_speed;	
		vec3 wind_angle_world = (vec4(wind_angle, 0) * WORLD_MATRIX).xyz;
		vec3 wind_dir_flattened = projectOnPlane(wind_angle_world, NORMAL);
		vec3 wind_vec = wind_dir_flattened * perlin3D(winduv, 0) * wind_strength;
		vec3 physics_pos_offset_world = (vec4(physics_pos_offset, 0) * WORLD_MATRIX).xyz;
		forces_vec = (physics_pos_offset_world + wind_vec) * length(extrusion_vec) * smoothstep(0.0, 2.0, lod_adjusted_layer_value);
		VERTEX += forces_vec;
	}
}

void fragment() {
	if (LOD < COLOR.a) {
		discard;
	}
	
	NORMAL = mix(NORMAL, projectOnPlane(VIEW, extrusion_vec.xyz), normal_adjustment);
	
	ALBEDO = (texture(color_texture, UV * color_tiling) * mix(base_color, tip_color, lod_adjusted_layer_value)).rgb;
	TRANSMISSION = transmission.rgb;
	ROUGHNESS = roughness;
	AO = 1.0 - (-lod_adjusted_layer_value + 1.0) * ao;
	
	// Workaround for issue https://github.com/godotengine/godot/issues/36669
	// to allow opaque prepass.
	vec2 pattern = texture(pattern_texture, UV * density).rg;
	float scissor_thresh =  mix(-thickness_base + 1.0, -thickness_tip + 1.0, lod_adjusted_layer_value); 
	float length_tex_value = texture(length_texture, UV * length_tiling).r;
	if (scissor_thresh < pattern.r * length_tex_value - pattern.r * length_tex_value * pattern.g * length_rand) {
    	ALPHA = 1.0;
	} else {
    	ALPHA = 0.0;
	}
}