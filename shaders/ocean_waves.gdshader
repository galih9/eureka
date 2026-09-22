shader_type spatial;
render_mode depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;

/*
 * Infinite Ocean Waves Shader for Godot 4 Forward+
 * ------------------------------------------------
 * Realistic Gerstner ocean waves with physically bounded wave amplitudes,
 * dual-layer micro-ripples, dynamic crest foam, shoreline contact foam,
 * and seamless horizon fog integration.
 */

group_uniforms WaterColors;
uniform vec4 deep_color : source_color = vec4(0.012, 0.032, 0.065, 0.98);
uniform vec4 shallow_color : source_color = vec4(0.028, 0.085, 0.14, 0.94);
uniform vec4 horizon_color : source_color = vec4(0.02, 0.03, 0.06, 1.0);
uniform vec4 foam_color : source_color = vec4(0.85, 0.92, 0.97, 0.95);
uniform float roughness : hint_range(0.0, 1.0) = 0.08;
uniform float metallic : hint_range(0.0, 1.0) = 0.02;
uniform float specular : hint_range(0.0, 1.0) = 0.65;
uniform float fresnel_power : hint_range(0.5, 10.0) = 4.0;

group_uniforms GerstnerWaves;
// wave format: (dir_x, dir_z, amplitude_meters, wavelength_meters)
uniform vec4 wave_a = vec4(1.0, 0.25, 0.28, 45.0);
uniform vec4 wave_b = vec4(0.35, 0.95, 0.20, 26.0);
uniform vec4 wave_c = vec4(-0.65, 0.75, 0.14, 15.0);
uniform vec4 wave_d = vec4(-0.3, -1.0, 0.08, 8.0);
uniform float wave_steepness : hint_range(0.0, 1.5) = 0.65;
uniform float wave_speed : hint_range(0.0, 4.0) = 1.0;
uniform float wave_amplitude_mult : hint_range(0.0, 3.0) = 1.0;

group_uniforms MicroRipples;
uniform sampler2D normal_texture_1 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture_2 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 ripple_direction_1 = vec2(0.025, 0.015);
uniform vec2 ripple_direction_2 = vec2(-0.018, 0.022);
uniform float ripple_scale_1 : hint_range(0.001, 1.0) = 0.04;
uniform float ripple_scale_2 : hint_range(0.001, 1.0) = 0.08;
uniform float ripple_strength : hint_range(0.0, 2.0) = 0.35;

group_uniforms FoamSettings;
uniform sampler2D foam_noise_texture : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float foam_noise_scale : hint_range(0.005, 1.0) = 0.06;
uniform float crest_foam_threshold : hint_range(0.0, 2.0) = 0.28;
uniform float crest_foam_softness : hint_range(0.01, 1.0) = 0.18;
uniform float edge_foam_distance : hint_range(0.05, 5.0) = 0.75;
uniform float edge_foam_intensity : hint_range(0.0, 3.0) = 1.1;

group_uniforms HorizonFade;
uniform float horizon_fade_start : hint_range(10.0, 1000.0) = 90.0;
uniform float horizon_fade_end : hint_range(20.0, 2000.0) = 240.0;

group_uniforms DepthFade;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear_mipmap;

varying vec3 v_world_pos;
varying float v_wave_height;
varying vec3 v_wave_normal;

void gerstner_wave(vec4 wave_param, vec2 pos, float time, inout vec3 disp, inout vec3 norm) {
	vec2 d = normalize(wave_param.xy);
	float a = wave_param.z * wave_amplitude_mult;
	float l = max(wave_param.w, 0.1);
	float k = 2.0 * PI / l;
	float c = sqrt(9.8 / k) * wave_speed;
	float theta = k * dot(d, pos) + c * k * time;
	
	// Physically bounded steepness (q * k * a <= 1.0)
	float q = clamp(wave_steepness, 0.0, 1.0 / max(k * a, 0.001));

	disp.x += q * a * d.x * cos(theta);
	disp.y += a * sin(theta);
	disp.z += q * a * d.y * cos(theta);

	norm.x -= k * a * d.x * cos(theta);
	norm.y -= q * k * a * sin(theta);
	norm.z -= k * a * d.y * cos(theta);
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 disp = vec3(0.0);
	vec3 norm = vec3(0.0, 1.0, 0.0);

	gerstner_wave(wave_a, world_pos.xz, TIME, disp, norm);
	gerstner_wave(wave_b, world_pos.xz, TIME, disp, norm);
	gerstner_wave(wave_c, world_pos.xz, TIME, disp, norm);
	gerstner_wave(wave_d, world_pos.xz, TIME, disp, norm);

	mat3 inv_model = inverse(mat3(MODEL_MATRIX));
	VERTEX += inv_model * disp;
	
	v_world_pos = world_pos + disp;
	v_wave_height = disp.y;
	v_wave_normal = normalize(norm);
	
	NORMAL = normalize(transpose(inv_model) * v_wave_normal);
}

void fragment() {
	// Micro ripple sampling with dual-layer panning normal maps
	vec2 uv1 = v_world_pos.xz * ripple_scale_1 + TIME * ripple_direction_1;
	vec2 uv2 = v_world_pos.xz * ripple_scale_2 + TIME * ripple_direction_2;
	vec3 n1 = texture(normal_texture_1, uv1).rgb * 2.0 - 1.0;
	vec3 n2 = texture(normal_texture_2, uv2).rgb * 2.0 - 1.0;
	vec3 ripple_norm = normalize(vec3(n1.xy + n2.xy, max(n1.z * n2.z, 0.1)));

	// Blend micro ripples with Gerstner wave normal in world space
	vec3 world_normal = normalize(v_wave_normal + vec3(ripple_norm.x, 0.0, ripple_norm.y) * ripple_strength);
	NORMAL = (VIEW_MATRIX * vec4(world_normal, 0.0)).xyz;

	// Sample foam noise for organic breaking crests and shoreline foam
	vec2 foam_uv = v_world_pos.xz * foam_noise_scale + TIME * (ripple_direction_1 * 0.3);
	float foam_noise = texture(foam_noise_texture, foam_uv).r;

	// 1. Wave Crest Foam (peaks of high swells)
	float crest_factor = smoothstep(crest_foam_threshold, crest_foam_threshold + crest_foam_softness, v_wave_height);
	float crest_foam = clamp(crest_factor * smoothstep(0.4, 0.8, foam_noise) * 1.5, 0.0, 1.0);

	// 2. Shore / Arena Wall Contact Foam (Depth Buffer sampling)
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view_pos = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view_pos.xyz /= view_pos.w;
	float linear_depth = -view_pos.z;
	float vertex_depth = -VERTEX.z;
	float depth_diff = linear_depth - vertex_depth;

	float contact_foam = 0.0;
	if (depth_diff > 0.0) {
		float contact_raw = clamp(1.0 - (depth_diff / max(edge_foam_distance, 0.001)), 0.0, 1.0);
		contact_foam = pow(contact_raw, 1.5) * edge_foam_intensity;
		contact_foam *= smoothstep(0.25, 0.7, foam_noise);
	}

	float total_foam = clamp(crest_foam + contact_foam, 0.0, 1.0);

	// Color gradient based on wave height
	float height_t = clamp((v_wave_height + 0.35) / 0.7, 0.0, 1.0);
	vec4 water_color = mix(deep_color, shallow_color, height_t);

	// Fresnel reflection highlight
	float ndotv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - ndotv, fresnel_power);
	water_color.rgb = mix(water_color.rgb, shallow_color.rgb * 1.35, fresnel * 0.45);

	// Blend with foam
	vec3 final_albedo = mix(water_color.rgb, foam_color.rgb, total_foam);
	float final_alpha = mix(water_color.a, foam_color.a, total_foam);

	// Infinite Horizon Blending: smoothly fade water into atmospheric horizon fog
	vec3 cam_pos = INV_VIEW_MATRIX[3].xyz;
	float cam_dist = length(v_world_pos.xz - cam_pos.xz);
	float horizon_t = smoothstep(horizon_fade_start, horizon_fade_end, cam_dist);
	final_albedo = mix(final_albedo, horizon_color.rgb, horizon_t);
	final_alpha = mix(final_alpha, horizon_color.a, horizon_t);

	ALBEDO = final_albedo;
	ALPHA = final_alpha;
	ROUGHNESS = mix(roughness, 0.65, total_foam);
	METALLIC = metallic;
	SPECULAR = specular;
}
