shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;

// Shader de Água HD Pixel Art 3D (David Holland Architecture)
// Suporta refração turva/embaçada, reflexos Screen-Space orbitais ancorados e volume diorama.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

group_uniforms WaterColors;
uniform vec4 shallow_color : source_color = vec4(0.18, 0.68, 0.82, 0.88);
uniform vec4 deep_color : source_color = vec4(0.10, 0.42, 0.62, 0.95);
uniform float depth_fade_distance : hint_range(0.1, 5.0) = 0.65;

group_uniforms RipplesAndTurbulence;
uniform float pixel_grid_density : hint_range(8.0, 128.0) = 52.0;
uniform float wave_speed : hint_range(0.5, 5.0) = 2.0;
uniform float wave_height : hint_range(0.0, 0.1) = 0.02;
uniform float shoreline_foam_dist : hint_range(0.05, 1.0) = 0.35;
uniform int shoreline_ripple_rings : hint_range(1, 5) = 3;

group_uniforms ScreenSpaceReflection;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.38;
uniform float reflection_distortion_px : hint_range(0.0, 8.0) = 2.0;
uniform int reflection_march_steps : hint_range(4, 24) = 14;
uniform float reflection_max_distance_px : hint_range(10.0, 140.0) = 75.0;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec4 v_flow_data;

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float voronoi_wave(vec2 uv, float time) {
	vec2 i_uv = floor(uv);
	vec2 f_uv = fract(uv);
	float min_dist = 1.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 neighbor = vec2(float(x), float(y));
			vec2 point = hash2(i_uv + neighbor);
			point = 0.5 + 0.5 * sin(time * wave_speed + 6.2831 * point);
			vec2 diff = neighbor + point - f_uv;
			min_dist = min(min_dist, length(diff));
		}
	}
	return min_dist;
}

void vertex() {
	v_flow_data = COLOR;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Marola geométrica na face superior
	if (NORMAL.y > 0.5) {
		vec2 snapped_xz = floor(w_pos.xz * pixel_grid_density) / pixel_grid_density;
		float wave = sin(snapped_xz.x * 6.0 + TIME * wave_speed) * cos(snapped_xz.y * 6.0 + TIME * wave_speed * 0.8);
		VERTEX.y += wave * wave_height;
	}
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 texel_size = 1.0 / VIEWPORT_SIZE;
	bool is_top = v_world_normal.y > 0.5;
	
	// Ondulação de distorção de pixel
	vec2 pixel_wave_offset = round(vec2(
		sin(v_world_pos.z * 16.0 + TIME * wave_speed * 2.0),
		cos(v_world_pos.x * 16.0 + TIME * wave_speed * 1.5)
	) * reflection_distortion_px) * texel_size;
	
	if (is_top) {
		// --- SUPERFÍCIE SUPERIOR DA ÁGUA ---
		vec2 world_xz_snapped = floor(v_world_pos.xz * pixel_grid_density) / pixel_grid_density;
		vec2 animated_xz = world_xz_snapped - vec2(0.2, 0.1) * (TIME * 0.25);
		
		// 1. Reconstrução da profundidade do fundo
		float bg_depth_raw = texture(depth_texture, SCREEN_UV).r;
		vec3 bg_ndc = vec3(SCREEN_UV * 2.0 - 1.0, bg_depth_raw);
		vec4 bg_view = INV_PROJECTION_MATRIX * vec4(bg_ndc, 1.0);
		bg_view.xyz /= bg_view.w;
		
		float water_depth = max(0.0, VERTEX.z - bg_view.z);
		float depth_factor = clamp(water_depth / depth_fade_distance, 0.0, 1.0);
		float stepped_depth = floor(depth_factor * 6.0) / 6.0;
		
		// 2. Máscara de Turbulência / Agitação (sem branco chapado)
		float shoreline_mask = 0.0;
		if (water_depth < shoreline_foam_dist && water_depth > 0.001) {
			float norm_shore = water_depth / shoreline_foam_dist;
			float wave_perturb = sin(world_xz_snapped.x * 14.0 + world_xz_snapped.y * 14.0) * 0.08;
			float rings = sin((norm_shore + wave_perturb) * float(shoreline_ripple_rings) * 6.2831 - TIME * (wave_speed * 2.5));
			float ring_step = smoothstep(0.20, 0.65, rings);
			float edge_solid = smoothstep(0.35, 0.05, norm_shore);
			shoreline_mask = clamp(ring_step * (1.0 - norm_shore * 0.45) + edge_solid * 0.75, 0.0, 1.0);
		}
		
		float v_wave = voronoi_wave(animated_xz * 3.5, TIME);
		float wave_turb = smoothstep(0.68, 0.88, v_wave);
		float effect_mask = clamp(shoreline_mask + wave_turb * 0.45, 0.0, 1.0);
		
		// 3. Refração Turva / Embaçada (Frosted Glass Effect) nas áreas de turbulência
		vec2 base_uv = SCREEN_UV + pixel_wave_offset * 0.3;
		vec2 blur_spread = texel_size * (1.5 + effect_mask * 3.5);
		
		vec3 bg_c0 = texture(screen_texture, base_uv).rgb;
		vec3 bg_c1 = texture(screen_texture, base_uv + vec2(blur_spread.x, blur_spread.y)).rgb;
		vec3 bg_c2 = texture(screen_texture, base_uv + vec2(-blur_spread.x, blur_spread.y)).rgb;
		vec3 bg_c3 = texture(screen_texture, base_uv + vec2(blur_spread.x, -blur_spread.y)).rgb;
		vec3 bg_c4 = texture(screen_texture, base_uv + vec2(-blur_spread.x, -blur_spread.y)).rgb;
		
		vec3 blurred_bg = (bg_c0 * 0.40) + (bg_c1 + bg_c2 + bg_c3 + bg_c4) * 0.15;
		vec3 refracted_bg = mix(bg_c0, blurred_bg, effect_mask * 0.85);
		
		// 4. Reflexo Screen-Space Ancorado Verticalmente (Gira junto com a câmera em 360°)
		vec3 reflected_scene = vec3(0.0);
		float reflection_weight = 0.0;
		float ripple_h = sin(world_xz_snapped.x * 12.0 + TIME * wave_speed * 1.5) * reflection_distortion_px;
		
		for (int step_idx = 1; step_idx <= reflection_march_steps; step_idx++) {
			float march_t = float(step_idx) / float(reflection_march_steps);
			float march_px = march_t * reflection_max_distance_px;
			
			// Busca verticalmente para cima na tela (-Y em UV)
			vec2 march_uv = SCREEN_UV + vec2(ripple_h * texel_size.x * (1.0 - march_t * 0.3), -march_px * texel_size.y);
			
			if (march_uv.y < 0.01 || march_uv.y > 0.99 || march_uv.x < 0.01 || march_uv.x > 0.99) {
				break;
			}
			
			// Mede a profundidade e altura de mundo no ponto de amostragem
			float s_depth = texture(depth_texture, march_uv).r;
			vec3 s_ndc = vec3(march_uv * 2.0 - 1.0, s_depth);
			vec4 s_view = INV_PROJECTION_MATRIX * vec4(s_ndc, 1.0);
			s_view.xyz /= s_view.w;
			vec3 s_world = (INV_VIEW_MATRIX * vec4(s_view.xyz, 1.0)).xyz;
			
			// Se o objeto amostrado estiver acima da água (Y > 0.04m no mundo do Godot)
			if (s_world.y > 0.04) {
				reflected_scene = texture(screen_texture, march_uv).rgb;
				reflection_weight = 1.0 - march_t * 0.55;
				break; // Primeiro objeto encontrado acima da água
			}
		}
		
		// 5. Composição de Cor da Água
		vec4 base_water = mix(shallow_color, deep_color, stepped_depth);
		
		// Clareia levemente o tom ciano da própria água na turbulência (sem usar branco sólido)
		vec3 water_tint = mix(base_water.rgb, shallow_color.rgb * 1.30, effect_mask * 0.45);
		float final_alpha = mix(base_water.a, 0.92, effect_mask);
		
		// Mistura água com o fundo turvo refratado
		vec3 composite = mix(refracted_bg, water_tint, final_alpha);
		
		// Aplica reflexo ancorado
		if (reflection_weight > 0.0) {
			composite = mix(composite, reflected_scene, reflection_weight * reflection_strength);
		}
		
		ALBEDO = composite;
		ALPHA = final_alpha;
	} else {
		// --- FACES LATERAIS DO VOLUME DIORAMA (Aquário) ---
		vec3 side_bg = texture(screen_texture, SCREEN_UV + pixel_wave_offset * 0.4).rgb;
		vec3 side_color = mix(deep_color.rgb * 0.75, deep_color.rgb, clamp((v_world_pos.y + 0.65) / 0.65, 0.0, 1.0));
		ALBEDO = mix(side_bg, side_color, 0.65);
		ALPHA = 0.85;
	}
}
