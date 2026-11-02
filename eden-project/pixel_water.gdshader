shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;

// Shader de Água HD Pixel Art 3D (David Holland Architecture)
// - Transparência Embaçada (Blur 5 amostras) nas bordas de contato e cristas sem manchas brancas sólidas
// - Descarte de faces laterais/inferiores (apenas lâmina d'água superior)
// - Mistura final direta no ALBEDO com seabed_refracted (sem acúmulo de camadas transparentes)
// - Reflexo Planar Óptico orbital ancorado com escala proporcional à altura exposta

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

group_uniforms WaterColors;
uniform vec4 shallow_color : source_color = vec4(0.20, 0.72, 0.78, 0.85);
uniform vec4 deep_color : source_color = vec4(0.06, 0.22, 0.44, 0.92);
uniform float depth_fade_distance : hint_range(0.1, 5.0) = 0.75;

group_uniforms RipplesAndWaves;
uniform float pixel_grid_density : hint_range(8.0, 128.0) = 52.0; // Texels por metro
uniform float wave_speed : hint_range(0.5, 5.0) = 2.0;
uniform float wave_height : hint_range(0.0, 0.1) = 0.02;
uniform float shoreline_foam_dist : hint_range(0.05, 1.0) = 0.32;
uniform int shoreline_ripple_rings : hint_range(1, 5) = 3;

group_uniforms ScreenSpaceReflection;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.45;
uniform float reflection_distortion_px : hint_range(0.0, 6.0) = 1.8;
uniform float specular_glint_threshold : hint_range(0.5, 0.99) = 0.88;

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
	
	// Aplica marola geométrica apenas na face superior
	if (NORMAL.y > 0.5) {
		vec2 snapped_xz = floor(w_pos.xz * pixel_grid_density) / pixel_grid_density;
		float wave = sin(snapped_xz.x * 6.0 + TIME * wave_speed) * cos(snapped_xz.y * 6.0 + TIME * wave_speed * 0.8);
		VERTEX.y += wave * wave_height;
	}
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Descarte obrigatório de faces laterais e inferiores da malha
	if (v_world_normal.y <= 0.5) {
		discard;
	}

	vec2 texel_size = 1.0 / VIEWPORT_SIZE;
	vec2 flow_dir = (v_flow_data.rg * 2.0 - 1.0);
	vec2 world_xz_snapped = floor(v_world_pos.xz * pixel_grid_density) / pixel_grid_density;
	vec2 animated_xz = world_xz_snapped - flow_dir * (TIME * 0.25);
	
	// 1. Refração e Blur de 5 amostras (cruz texel_size * 1.5) no leito da screen_texture
	vec2 pixel_wave_offset = round(vec2(
		sin(v_world_pos.z * 16.0 + TIME * wave_speed * 2.0),
		cos(v_world_pos.x * 16.0 + TIME * wave_speed * 1.5)
	) * reflection_distortion_px) * texel_size;
	
	vec2 bg_uv = SCREEN_UV + pixel_wave_offset * 0.4;
	vec3 refracted_bg = texture(screen_texture, bg_uv).rgb;
	
	vec2 blur_offset = texel_size * 1.5;
	vec3 bg_blur_u = texture(screen_texture, bg_uv + vec2(0.0, blur_offset.y)).rgb;
	vec3 bg_blur_d = texture(screen_texture, bg_uv - vec2(0.0, blur_offset.y)).rgb;
	vec3 bg_blur_l = texture(screen_texture, bg_uv - vec2(blur_offset.x, 0.0)).rgb;
	vec3 bg_blur_r = texture(screen_texture, bg_uv + vec2(blur_offset.x, 0.0)).rgb;
	vec3 blurred_bg = (refracted_bg * 0.36 + (bg_blur_u + bg_blur_d + bg_blur_l + bg_blur_r) * 0.16);

	// 2. Reconstrução de Profundidade Linear do Fundo (Leito)
	float bg_depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec3 bg_ndc = vec3(SCREEN_UV * 2.0 - 1.0, bg_depth_raw);
	vec4 bg_view = INV_PROJECTION_MATRIX * vec4(bg_ndc, 1.0);
	bg_view.xyz /= bg_view.w;
	
	float water_depth = max(0.0, VERTEX.z - bg_view.z);
	float depth_factor = clamp(water_depth / depth_fade_distance, 0.0, 1.0);
	float stepped_depth = floor(depth_factor * 5.0) / 5.0;
	
	// 3. Bordas de contato e cristas de ondas (Turbidez / Embaçamento sem manchas brancas)
	float shoreline_turbid = 0.0;
	if (water_depth < shoreline_foam_dist && water_depth > 0.001) {
		float norm_shore = water_depth / shoreline_foam_dist;
		float wave_perturb = sin(world_xz_snapped.x * 12.0 + world_xz_snapped.y * 12.0) * 0.08;
		float rings = sin((norm_shore + wave_perturb) * float(shoreline_ripple_rings) * 6.2831 - TIME * (wave_speed * 2.5));
		float ring_step = step(0.40 + norm_shore * 0.4, rings);
		float edge_solid = step(norm_shore, 0.22);
		shoreline_turbid = clamp(ring_step + edge_solid, 0.0, 1.0);
	}
	
	float wave_curr = sin(world_xz_snapped.x * 6.0 + TIME * wave_speed) * cos(world_xz_snapped.y * 6.0 + TIME * wave_speed * 0.8);
	float v_wave = voronoi_wave(animated_xz * 3.5, TIME);
	float caustic_band = step(0.72, v_wave);
	float crest_turbid = clamp(caustic_band * 0.65 + step(specular_glint_threshold, v_wave) * 0.35, 0.0, 1.0);
	
	// Fator total de embaçamento/turbidez: ativo nas bordas e cristas das ondas
	float turbid_factor = clamp(shoreline_turbid * 0.90 + crest_turbid * 0.70, 0.0, 1.0);
	
	// Leito refratado: nítido em água calma e embaçado (blur 5 amostras) onde há turbidez
	vec3 seabed_refracted = mix(refracted_bg, blurred_bg, turbid_factor);

	// 4. Reflexo Planar Óptico na SUPERFÍCIE com Escala Proporcional à Altura Exposta
	vec4 clip_curr = PROJECTION_MATRIX * VIEW_MATRIX * vec4(v_world_pos, 1.0);
	vec4 clip_up = PROJECTION_MATRIX * VIEW_MATRIX * vec4(v_world_pos + vec3(0.0, 1.0, 0.0), 1.0);
	vec2 uv_curr = (clip_curr.xy / clip_curr.w) * 0.5 + 0.5;
	vec2 uv_up = (clip_up.xy / clip_up.w) * 0.5 + 0.5;
	vec2 screen_up_per_meter = uv_up - uv_curr;
	vec2 screen_perp = vec2(-screen_up_per_meter.y, screen_up_per_meter.x);
	
	vec2 wave_slope = vec2(
		cos(world_xz_snapped.x * 6.0 + TIME * wave_speed) * cos(world_xz_snapped.y * 6.0 + TIME * wave_speed * 0.8),
		-sin(world_xz_snapped.x * 6.0 + TIME * wave_speed) * sin(world_xz_snapped.y * 6.0 + TIME * wave_speed * 0.8)
	);
	float voronoi_ripple = (v_wave - 0.5) * 2.0;
	
	vec2 surface_wave_offset = (screen_perp * (wave_slope.x * 1.5 + voronoi_ripple * 0.8) + screen_up_per_meter * (wave_slope.y * 1.8 + wave_curr * 0.7)) * (reflection_distortion_px * texel_size.y * 14.0);
	vec2 pixel_wave_distortion = round(surface_wave_offset / texel_size) * texel_size;
	
	vec3 reflected_scene = vec3(0.0);
	float reflection_weight = 0.0;
	
	// Marcha progressiva em 24 passos de 0.07m até 4.8m
	for (int step_idx = 1; step_idx <= 24; step_idx++) {
		float t = float(step_idx) / 24.0;
		float h = t * t * 3.2 + t * 1.6;
		vec2 sample_uv = SCREEN_UV + screen_up_per_meter * h + pixel_wave_distortion;
		
		if (sample_uv.x < 0.005 || sample_uv.x > 0.995 || sample_uv.y < 0.005 || sample_uv.y > 0.995) {
			break;
		}
		
		float sample_depth = texture(depth_texture, sample_uv).r;
		vec3 sample_ndc = vec3(sample_uv * 2.0 - 1.0, sample_depth);
		vec4 sample_view = INV_PROJECTION_MATRIX * vec4(sample_ndc, 1.0);
		sample_view.xyz /= sample_view.w;
		vec3 sample_world_pos = (INV_VIEW_MATRIX * vec4(sample_view.xyz, 1.0)).xyz;
		
		float obj_h = sample_world_pos.y - v_world_pos.y;
		if (obj_h <= 0.02) {
			continue;
		}
		
		// Trava de alcance por altura exposta (pedras pequenas têm reflexos curtos)
		if (h > obj_h * 2.2 + 0.15) {
			continue;
		}
		
		float max_tol = max(0.045, obj_h * 0.35);
		float wave_h_mod = wave_curr * wave_height * 2.5;
		float expected_h = h * 0.5 + wave_h_mod;
		
		if (abs(obj_h - expected_h) < max_tol && sample_view.z < VERTEX.z + 0.25) {
			reflected_scene = texture(screen_texture, sample_uv).rgb;
			float height_scale = clamp(obj_h / 0.35, 0.30, 1.0);
			float falloff = 1.0 - t * 0.30;
			reflection_weight = clamp(reflection_strength * 1.65 * falloff * height_scale, 0.0, 0.82);
			break;
		}
	}
	
	// 5. Composição de Cores da Água
	// Clareia levemente o tom azul-ciano da água nos pontos turvos (sem tinta branca sólida)
	vec4 base_water = mix(shallow_color, deep_color, stepped_depth);
	vec3 brightened_cyan = shallow_color.rgb * 1.25;
	vec3 water_tint = mix(base_water.rgb, brightened_cyan, turbid_factor * 0.38);
	
	// Mistura direta do leito embaçado/refratado com a água
	vec3 underwater_floor = mix(seabed_refracted, water_tint, base_water.a);
	
	// Cáusticas suaves no leito
	underwater_floor = mix(underwater_floor, shallow_color.rgb * 1.30, caustic_band * 0.28);
	
	// Reflexo planar na superfície sobre o leito
	vec3 surface_composite = underwater_floor;
	if (reflection_weight > 0.0) {
		surface_composite = mix(underwater_floor, reflected_scene, reflection_weight);
	}
	
	// Aplicação direta no ALBEDO com opacidade total (sem acúmulo de camadas transparentes)
	ALBEDO = surface_composite;
	ALPHA = 1.0;
}
