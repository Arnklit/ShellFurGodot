// Copyright © 2022 Kasper Arnklit Frandsen - MIT License
// See `LICENSE.md` included in the source distribution for details.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, depth_draw_opaque;

// If you are making your own shader, you can customize or add your own
// parameters below and they will automatically get parsed and displayed in
// the ShellFur inspector.

// Use prefixes: albedo_, shape_ and custom_ to automatically put your 
// parameters into categories in the inspector.

// mat4´s with "color" in their name will get parsed as gradients.

// Main
uniform vec4 transmission : hint_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform float ao : hint_range(0.0, 1.0) = 1.0;
uniform float ao_light_affect : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;

// Albedo
uniform mat4 albedo_color = mat4(
	vec4(0.43, 0.78, 0.0, 0.0), 
	vec4(0.35, 0.63, 0.0, 0.0), 
	vec4(0.29, 0.52, 0.0, 0.0), 
	vec4(0.0)
);
uniform vec3 albedo_uv_scale = vec3(1.0, 1.0, 0.0);
uniform sampler2D albedo_texture : hint_albedo;

// Shape
uniform float shape_length : hint_range(0.0, 5.0) = 0.5;
uniform float shape_length_rand : hint_range(0.0, 1.0) = 0.3;
uniform float shape_density : hint_range(0.0, 1.0) = 1.0;
uniform float shape_thickness_base : hint_range(0.0, 1.0) = 0.75;
uniform float shape_thickness_tip : hint_range(0.0, 1.0) = 0.3;
uniform float shape_thickness_rand : hint_range(0.0, 1.0) = 0.0;
uniform float shape_growth : hint_range(0.0, 2.0) = 1.0;
uniform float shape_growth_rand : hint_range(0.0, 1.0) = 0.0;
uniform vec3 shape_ldtg_uv_scale = vec3(1.0, 1.0, 0.0);
uniform sampler2D shape_ldtg_texture : hint_white; // Length, Desity, Thickness, Growth

// Internal uniforms - DO NOT CUSTOMIZE THESE IF YOU ARE CLONING THE SHADER
uniform int i_layers = 40;
uniform sampler2D i_pattern_texture : hint_black;
uniform float i_pattern_uv_scale : hint_range(0.0, 100.0) = 5.0;
uniform float i_wind_strength = 0.0;
uniform float i_wind_speed = 1.0;
uniform float i_wind_scale = 1.0;
uniform vec3 i_wind_angle = vec3(1.0, 0.0, 0.0);
uniform float i_normal_bias = 0.0;
uniform float i_LOD = 1.0;
uniform vec3 i_physics_pos_offset;
uniform mat4 i_physics_rot_offset;
uniform float i_blend_shape_multiplier = 1.0;
uniform float i_fur_contract = 0.0;

varying vec3 extrusion_vec;
varying vec3 forces_vec;
varying float lod_adjusted_layer_value;

float lin2srgb(float lin) {
	return pow(lin, 2.2);
}

mat4 gradient_lin2srgb(mat4 lin_mat) {
	mat4 srgb_mat = mat4(
		vec4(lin2srgb(lin_mat[0].x), lin2srgb(lin_mat[0].y), lin2srgb(lin_mat[0].z), lin2srgb(lin_mat[0].w)),
		vec4(lin2srgb(lin_mat[1].x), lin2srgb(lin_mat[1].y), lin2srgb(lin_mat[1].z), lin2srgb(lin_mat[1].w)),
		vec4(0.0),
		vec4(0.0)
	);
	return srgb_mat;
}

vec3 mod289(vec3 x)
{
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289_4(vec4 x)
{
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x)
{
  return mod289_4(((x*34.0)+1.0)*x);
}

vec4 taylorInvSqrt(vec4 r)
{
  return 1.79284291400159 - 0.85373472095314 * r;
}

vec3 fade(vec3 t) {
  return t*t*t*(t*(t*6.0-15.0)+10.0);
}

// Classic Perlin noise by Stefan Gustavson, see README for license
float cnoise(vec3 P)
{
  vec3 Pi0 = floor(P); // Integer part for indexing
  vec3 Pi1 = Pi0 + vec3(1.0); // Integer part + 1
  Pi0 = mod289(Pi0);
  Pi1 = mod289(Pi1);
  vec3 Pf0 = fract(P); // Fractional part for interpolation
  vec3 Pf1 = Pf0 - vec3(1.0); // Fractional part - 1.0
  vec4 ix = vec4(Pi0.x, Pi1.x, Pi0.x, Pi1.x);
  vec4 iy = vec4(Pi0.yy, Pi1.yy);
  vec4 iz0 = Pi0.zzzz;
  vec4 iz1 = Pi1.zzzz;

  vec4 ixy = permute(permute(ix) + iy);
  vec4 ixy0 = permute(ixy + iz0);
  vec4 ixy1 = permute(ixy + iz1);

  vec4 gx0 = ixy0 * (1.0 / 7.0);
  vec4 gy0 = fract(floor(gx0) * (1.0 / 7.0)) - 0.5;
  gx0 = fract(gx0);
  vec4 gz0 = vec4(0.5) - abs(gx0) - abs(gy0);
  vec4 sz0 = step(gz0, vec4(0.0));
  gx0 -= sz0 * (step(0.0, gx0) - 0.5);
  gy0 -= sz0 * (step(0.0, gy0) - 0.5);

  vec4 gx1 = ixy1 * (1.0 / 7.0);
  vec4 gy1 = fract(floor(gx1) * (1.0 / 7.0)) - 0.5;
  gx1 = fract(gx1);
  vec4 gz1 = vec4(0.5) - abs(gx1) - abs(gy1);
  vec4 sz1 = step(gz1, vec4(0.0));
  gx1 -= sz1 * (step(0.0, gx1) - 0.5);
  gy1 -= sz1 * (step(0.0, gy1) - 0.5);

  vec3 g000 = vec3(gx0.x,gy0.x,gz0.x);
  vec3 g100 = vec3(gx0.y,gy0.y,gz0.y);
  vec3 g010 = vec3(gx0.z,gy0.z,gz0.z);
  vec3 g110 = vec3(gx0.w,gy0.w,gz0.w);
  vec3 g001 = vec3(gx1.x,gy1.x,gz1.x);
  vec3 g101 = vec3(gx1.y,gy1.y,gz1.y);
  vec3 g011 = vec3(gx1.z,gy1.z,gz1.z);
  vec3 g111 = vec3(gx1.w,gy1.w,gz1.w);

  vec4 norm0 = taylorInvSqrt(vec4(dot(g000, g000), dot(g010, g010), dot(g100, g100), dot(g110, g110)));
  g000 *= norm0.x;
  g010 *= norm0.y;
  g100 *= norm0.z;
  g110 *= norm0.w;
  vec4 norm1 = taylorInvSqrt(vec4(dot(g001, g001), dot(g011, g011), dot(g101, g101), dot(g111, g111)));
  g001 *= norm1.x;
  g011 *= norm1.y;
  g101 *= norm1.z;
  g111 *= norm1.w;

  float n000 = dot(g000, Pf0);
  float n100 = dot(g100, vec3(Pf1.x, Pf0.yz));
  float n010 = dot(g010, vec3(Pf0.x, Pf1.y, Pf0.z));
  float n110 = dot(g110, vec3(Pf1.xy, Pf0.z));
  float n001 = dot(g001, vec3(Pf0.xy, Pf1.z));
  float n101 = dot(g101, vec3(Pf1.x, Pf0.y, Pf1.z));
  float n011 = dot(g011, vec3(Pf0.x, Pf1.yz));
  float n111 = dot(g111, Pf1);

  vec3 fade_xyz = fade(Pf0);
  vec4 n_z = mix(vec4(n000, n100, n010, n110), vec4(n001, n101, n011, n111), fade_xyz.z);
  vec2 n_yz = mix(n_z.xy, n_z.zw, fade_xyz.y);
  float n_xyz = mix(n_yz.x, n_yz.y, fade_xyz.x);
  return 1.1 * n_xyz + 0.5;
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
		VERTEX += (vec4(interpolated_extrude * shape_length * lod_adjusted_layer_value + offset_from_surface, 1.0) * i_physics_rot_offset).xyz;
		VERTEX -= i_fur_contract * extrusion_vec * shape_length;
		
		vec3 wind_vec = vec3(0.0);
		if (i_wind_strength > 0.01) { // Skipping wind calculations if wind_strength is less than 0.01
			vec3 winduv = VERTEX * i_wind_scale;
			winduv.y += TIME * i_wind_speed;
			vec3 wind_angle_world = (vec4(i_wind_angle, 0) * WORLD_MATRIX).xyz;
			vec3 wind_dir_flattened = projectOnPlane(wind_angle_world, NORMAL);
			wind_vec = wind_dir_flattened * cnoise(winduv) * i_wind_strength;
		}
		
		vec3 physics_pos_offset_world = (vec4(i_physics_pos_offset, 0.0) * WORLD_MATRIX).xyz;
		forces_vec = (physics_pos_offset_world + wind_vec) * length(extrusion_vec) * smoothstep(0.0, 2.0, lod_adjusted_layer_value);
		VERTEX += forces_vec;
	}
}

void fragment() { 
	// Discarding fragment if layer is beyond LOD threshhold
	if (i_LOD < COLOR.a) { 
		discard;
	}
	
	vec4 ldtg_texture_data = texture(shape_ldtg_texture, UV * shape_ldtg_uv_scale.xy);

	vec4 pattern = texture(i_pattern_texture, UV * i_pattern_uv_scale);
	// We multiply the thicknesses with ldtg texture's B channel and a random value based on 
	// the pattern's B channel ids to allow for control of the thickness through texture.
	float t_rand = 1.0 - shape_thickness_rand * pattern.b;
	float g_rand = 1.0 - shape_growth_rand * ((pattern.g + pattern.b) / 2.0); // We use two random channels to generate an extra "random" for growth
	float thickness_base = shape_thickness_base * ldtg_texture_data.b * t_rand; 
	float thickness_tip = shape_thickness_tip * ldtg_texture_data.b * pattern.b * t_rand;
	float scissor_thresh =  mix(-thickness_base + 1.0, -thickness_tip + 1.0, lod_adjusted_layer_value) + clamp(1.0 - shape_growth + (1.0 - g_rand * ldtg_texture_data.a), 0.0, 1.0); 

	float lod_alpha = float(i_LOD > COLOR.a);
	// density is multiplied by the ldtg textures G channel to allow fine control
	float density_alpha = float( shape_density * ldtg_texture_data.g * 1.02 > pattern.b + 0.01 );
	float shape_alpha = float(scissor_thresh < pattern.r * ldtg_texture_data.r - pattern.r * ldtg_texture_data.r * pattern.g * shape_length_rand);

	// We use the unique id's in pattern.b to discard if density is under the threshold
	// density is multiplied by the ldtg textures G channel to allow fine control
	if (shape_density * ldtg_texture_data.g * 1.02 <= pattern.b + 0.01) {
		discard;
	}

	ALPHA_SCISSOR = scissor_thresh;
	ALPHA = pattern.r * ldtg_texture_data.r - pattern.r * ldtg_texture_data.r * pattern.g * shape_length_rand;

	mat4 albedo_color_srgb = gradient_lin2srgb(albedo_color);
	vec3 albedo_base_color = vec3(albedo_color_srgb[0].x, albedo_color_srgb[0].y, albedo_color_srgb[0].z);
	vec3 albedo_tip_color = vec3(albedo_color_srgb[1].x, albedo_color_srgb[1].y, albedo_color_srgb[1].z);
	ALBEDO = (texture(albedo_texture, UV * albedo_uv_scale.xy).rgb * mix(albedo_base_color, albedo_tip_color, lod_adjusted_layer_value));
	TRANSMISSION = transmission.rgb;
	ROUGHNESS = roughness;
	AO = 1.0 - (-lod_adjusted_layer_value + 1.0) * ao;
	AO_LIGHT_AFFECT = ao_light_affect;
}