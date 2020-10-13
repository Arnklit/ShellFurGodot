shader_type spatial;
render_mode cull_disabled, depth_draw_alpha_prepass;

uniform vec4 base_color = vec4(1.0);
uniform vec4 tip_color = vec4(1.0);
uniform sampler2D color_texture : hint_albedo;
uniform vec4 transmission = vec4(0.0);
uniform float roughness = 1.0;
uniform float density = 200.0;
uniform float thickness_base = 0.5;
uniform float thickness_tip = 0.5;
uniform float fur_length = 0.5;
uniform sampler2D length_texture : hint_white;
uniform float length_rand = 0.2;
uniform float curl = 5.0;
uniform float ao = 1.0;
uniform float gravity = 0.0;
uniform float wind = 0.0;

// Should no be changed on the material, only through script.
uniform int layers = 40;
uniform bool use_blend_shapes = false;
uniform float blend_shape_multiplier = 0.0;

vec2 hash( vec2 p ) { p=vec2(dot(p,vec2(127.1,311.7)),dot(p,vec2(269.5,183.3))); return fract(sin(p)*18.5453); }

vec2 voronoi_moving(vec2 coord, float depth) {
	vec2 n = floor(coord);
	vec2 f = fract(coord);
	
	vec3 m = vec3( 8.0 );
	for( int j=-1; j<=1; j++ ) {
		for( int i=-1; i<=1; i++ ) {
			vec2 g = vec2(float(i), float(j));
			vec2 o = hash( n + g );
			vec2 r = g - f + (0.5 + 0.5 * sin(curl * depth + 6.2831 * o));
			float d = dot( r, r );
			if( d<m.x )
				m = vec3( d, o );
		}
	}
	return vec2( sqrt(m.x), m.y+m.z );
}

vec3 get_wind_displacement(float time) {
	vec3 disp = vec3(cos(time * 0.8), 0, sin(time * 1.2));
	float fine_disp_frequency = 2.0;
	disp += 0.2 * vec3(cos((time * fine_disp_frequency) * 0.8), 0, sin((time * fine_disp_frequency) * 1.2));
	return disp;
}

void vertex() {
	if (use_blend_shapes) {
		vec3 adjusted_color;
		adjusted_color.x = COLOR.x * 2.0 - 1.0;
		adjusted_color.y = COLOR.y * 2.0 - 1.0;
		adjusted_color.z = COLOR.z * 2.0 - 1.0;
		
		VERTEX += (adjusted_color.xyz * fur_length * COLOR.a * blend_shape_multiplier);	
	} else {
		VERTEX += NORMAL * (fur_length / float(layers)) + NORMAL * fur_length * COLOR.a;
	}
	
	
	
	vec3 world_down = (vec4(0.0, -1.0, 0.0, 0.0) * WORLD_MATRIX).xyz;
	vec3 world_wind_displacement = (vec4(get_wind_displacement(TIME), 0.0) * WORLD_MATRIX).xyz;
	
	//VERTEX += world_down * smoothstep(0.0, 1.0, COLOR.a * gravity);
	//VERTEX += world_wind_displacement * smoothstep(0.0, 1.0, COLOR.a * wind);
}

void fragment() {
	// This is a pretty solid way of discarding every other layer from the fragment shader
	// Maybe I'll use this for LODs for skinned shading. For static I will display
	// fewer instances with the MMI instead.
	//float every_other_layer = 2.0 / float(layers);
	//if (mod(COLOR.a + every_other_layer * .25, every_other_layer) > every_other_layer * .5) {
	//	discard;
	//}
	
	
	
	vec2 coord = UV * density;
	
	vec2 noise = voronoi_moving(coord, COLOR.a);
	
	float strand = noise.x * -1.0 + 1.0;
	float cell = noise.y;
	
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
	
	// Code for opaque shader variant
	//if (cell * length_rand < -COLOR.a + 1.0 * texture(length_texture, UV).r ) {
	//	ALPHA = strand;
	//} else {
	//	ALPHA = 0.0;
	//}
	//ALPHA_SCISSOR = mix(-thickness_base + 1.0, -thickness_tip + 1.0, COLOR.a);
	
	
}