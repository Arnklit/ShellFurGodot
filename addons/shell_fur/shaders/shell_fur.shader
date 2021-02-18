// Copyright © 2021 Kasper Arnklit Frandsen - MIT License
// See `LICENSE.md` included in the source distribution for details.
shader_type spatial;
render_mode depth_draw_alpha_prepass;

// If you are making your own shader, you can customize or add your own
// parameters below and they will automatically get parsed and displayed in
// the ShellFur inspector.

// Use prefixes: shape_, look_  and custom_
// to automatically put your parameters into categories in the inspector.

// If "curve" is in the name, the inspector will represent and easing curve.
// mat4´s with "color" in their name will get parsed as gradients.

// Shape
uniform sampler2D shape_pattern_texture : hint_black;
uniform float shape_pattern_uv_scale = 5.0;
uniform float shape_length = 0.5;
uniform float shape_length_rand = 0.3;
uniform float shape_density = 1.0; // TODO - implement
uniform float shape_thickness_base = 0.75;
uniform float shape_thickness_tip = 0.3;
uniform sampler2D shape_ldt_texture : hint_white;
uniform vec3 shape_ldt_uv_scale = vec3(1.0, 1.0, 0.0);

// Look
uniform vec4 look_base_color : hint_color = vec4(0.43, 0.35, 0.29, 1.0); // TODO - Change color to albedo
uniform vec4 look_tip_color : hint_color = vec4(0.78, 0.63, 0.52, 1.0);
uniform sampler2D look_color_texture : hint_albedo;
uniform vec3 look_color_uv_scale = vec3(1.0, 1.0, 0.0);
uniform vec4 look_transmission = vec4(0.3, 0.3, 0.3, 1.0);
uniform float look_ao = 1.0;
uniform float look_roughness = 1.0;
uniform float look_normal_adjustment = 0.0;

// Internal uniforms - DO NOT CUSTOMIZE THESE
uniform float i_wind_strength = 0.0;
uniform float i_wind_speed = 1.0;
uniform float i_wind_scale = 1.0;
uniform vec3 i_wind_angle = vec3(1.0, 0.0, 0.0);
uniform float i_normal_bias = 0.0;
uniform float i_LOD = 1.0;
uniform vec3 i_physics_pos_offset;
uniform mat4 i_physics_rot_offset;
uniform int i_layers = 40;
uniform float i_blend_shape_multiplier = 1.0;
uniform float i_fur_contract = 0.0;

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
	if (i_LOD >= COLOR.a) { // Skipping vertex calculations if layer is beyond LOD threshhold
		lod_adjusted_layer_value = COLOR.a / i_LOD;
		// Rescaling the color values into vectors.
		extrusion_vec = ((vec3(COLOR.xyz) * 2.0 - 1.0) * i_blend_shape_multiplier); 
		
		vec3 normal_biased_extrude = mix(NORMAL * i_blend_shape_multiplier, extrusion_vec, lod_adjusted_layer_value);
		vec3 interpolated_extrude = mix(extrusion_vec, normal_biased_extrude, smoothstep(0.0, 2.0, i_normal_bias));
		vec3 offset_from_surface = interpolated_extrude * shape_length / float(i_layers);
		VERTEX += (vec4(interpolated_extrude * shape_length * lod_adjusted_layer_value + offset_from_surface, 0.0) * i_physics_rot_offset).xyz;
		VERTEX -= i_fur_contract * extrusion_vec * shape_length;
		
		vec3 wind_vec = vec3(0.0);
		if (i_wind_strength > 0.01) { // Skipping wind calculations if wind_strength is less than 0.01
			vec3 winduv = VERTEX * i_wind_scale;
			winduv.y += TIME * i_wind_speed;
			vec3 wind_angle_world = (vec4(i_wind_angle, 0) * WORLD_MATRIX).xyz;
			vec3 wind_dir_flattened = projectOnPlane(wind_angle_world, NORMAL);
			wind_vec = wind_dir_flattened * perlin3D(winduv, 0) * i_wind_strength;
		}
		
		vec3 physics_pos_offset_world = (vec4(i_physics_pos_offset, 0) * WORLD_MATRIX).xyz;
		forces_vec = (physics_pos_offset_world + wind_vec) * length(extrusion_vec) * smoothstep(0.0, 2.0, lod_adjusted_layer_value);
		VERTEX += forces_vec;
	}
}

void fragment() { // Discarding fragment if layer is beyond LOD threshhold
	if (i_LOD < COLOR.a) { 
		discard;
	}
	// Workaround for issue https://github.com/godotengine/godot/issues/36669
	// to allow opaque prepass.
	vec2 pattern = texture(shape_pattern_texture, UV * shape_pattern_uv_scale).rg;
	float scissor_thresh =  mix(-shape_thickness_base + 1.0, -shape_thickness_tip + 1.0, lod_adjusted_layer_value); 
	vec3 ldt_texture_data = texture(shape_ldt_texture, UV * shape_ldt_uv_scale.xy).rgb; // TODO - implement density and length texture data

//	ALPHA = float(scissor_thresh < pattern.r * length_tex_value - pattern.r * length_tex_value * pattern.g * length_rand);
	
	if (scissor_thresh > pattern.r * ldt_texture_data.r - pattern.r * ldt_texture_data.r * pattern.g * shape_length_rand) {
		discard;
	}
	
	NORMAL = mix(NORMAL, projectOnPlane(VIEW, extrusion_vec.xyz), look_normal_adjustment);
	
	ALBEDO = (texture(look_color_texture, UV * look_color_uv_scale.xy) * mix(look_base_color, look_tip_color, lod_adjusted_layer_value)).rgb;
	TRANSMISSION = look_transmission.rgb;
	ROUGHNESS = look_roughness;
	AO = 1.0 - (-lod_adjusted_layer_value + 1.0) * look_ao;
}