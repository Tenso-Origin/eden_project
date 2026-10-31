shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;

// Shader de Água HD Pixel Art 3D com Lei da Reflexão Planar Óptica de Superfície (David Holland Architecture)
// Suporta reflexos Screen-Space ancorados que orbitam em 360° com a câmera (Y-Up),
// corte físico por nível de água (Y > water_y), reflexo situado NA SUPERFÍCIE DA ÁGUA (sobre o leito e cáusticas),
// escala rigorosa do tamanho do reflexo pela altura do objeto exposto acima da água (pedras pequenas = reflexos curtos),
// variação dinâmica viva com o movimento e ondulações da superfície, e anéis de espuma de profundidade linear.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

group_uniforms WaterColors;
uniform vec4 shallow_color : source_color = vec4(0.20, 0.72, 0.78, 0.85);
uniform vec4 deep_color : source_color = vec4(0.06, 0.22, 0.44, 0.92);
uniform vec3 foam_color : source_color = vec3(1.0, 1.0, 1.0); // Espuma branca 100% opaca
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
	
	// Aplica marola geométrica apenas na face superior (normal Y para cima)
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
	
	// Refração sutil do fundo através da screen_texture
	vec2 pixel_wave_offset = round(vec2(
		sin(v_world_pos.z * 16.0 + TIME * wave_speed * 2.0),
		cos(v_world_pos.x * 16.0 + TIME * wave_speed * 1.5)
	) * reflection_distortion_px) * texel_size;
	
	vec3 refracted_bg = texture(screen_texture, SCREEN_UV + pixel_wave_offset * 0.4).rgb;
	
	if (is_top) {
		// --- SUPERFÍCIE SUPERIOR DA ÁGUA ---
		vec2 flow_dir = (v_flow_data.rg * 2.0 - 1.0);
		vec2 world_xz_snapped = floor(v_world_pos.xz * pixel_grid_density) / pixel_grid_density;
		vec2 animated_xz = world_xz_snapped - flow_dir * (TIME * 0.25);
		
		// 1. Reconstrução de Profundidade Linear do Fundo (Leito)
		float bg_depth_raw = texture(depth_texture, SCREEN_UV).r;
		vec3 bg_ndc = vec3(SCREEN_UV * 2.0 - 1.0, bg_depth_raw);
		vec4 bg_view = INV_PROJECTION_MATRIX * vec4(bg_ndc, 1.0);
		bg_view.xyz /= bg_view.w;
		
		float water_depth = max(0.0, VERTEX.z - bg_view.z);
		float depth_factor = clamp(water_depth / depth_fade_distance, 0.0, 1.0);
		float stepped_depth = floor(depth_factor * 5.0) / 5.0;
		
		// 2. Ondulações concêntricas de espuma ao redor da rocha e margens
		float foam_mask = 0.0;
		if (water_depth < shoreline_foam_dist && water_depth > 0.001) {
			float norm_shore = water_depth / shoreline_foam_dist;
			float wave_perturb = sin(world_xz_snapped.x * 12.0 + world_xz_snapped.y * 12.0) * 0.08;
			float rings = sin((norm_shore + wave_perturb) * float(shoreline_ripple_rings) * 6.2831 - TIME * (wave_speed * 2.5));
			float ring_step = step(0.40 + norm_shore * 0.4, rings);
			float edge_solid = step(norm_shore, 0.22);
			foam_mask = clamp(ring_step + edge_solid, 0.0, 1.0);
		}
		
		// 3. Dinâmica de Movimento da Superfície (Ondas e Voronoi)
		float wave_curr = sin(world_xz_snapped.x * 6.0 + TIME * wave_speed) * cos(world_xz_snapped.y * 6.0 + TIME * wave_speed * 0.8);
		float v_wave = voronoi_wave(animated_xz * 3.5, TIME);
		float caustic_band = step(0.72, v_wave);
		float specular_glint = step(specular_glint_threshold, v_wave);
		
		// 4. Reflexo Planar Óptico na SUPERFÍCIE com Escala Proporcional à Altura Exposta
		vec4 clip_curr = PROJECTION_MATRIX * VIEW_MATRIX * vec4(v_world_pos, 1.0);
		vec4 clip_up = PROJECTION_MATRIX * VIEW_MATRIX * vec4(v_world_pos + vec3(0.0, 1.0, 0.0), 1.0);
		vec2 uv_curr = (clip_curr.xy / clip_curr.w) * 0.5 + 0.5;
		vec2 uv_up = (clip_up.xy / clip_up.w) * 0.5 + 0.5;
		vec2 screen_up_per_meter = uv_up - uv_curr;
		vec2 screen_perp = vec2(-screen_up_per_meter.y, screen_up_per_meter.x);
		
		// Inclinação (slope) da onda de superfície: altera dinamicamente o ângulo do raio refletido
		vec2 wave_slope = vec2(
			cos(world_xz_snapped.x * 6.0 + TIME * wave_speed) * cos(world_xz_snapped.y * 6.0 + TIME * wave_speed * 0.8),
			-sin(world_xz_snapped.x * 6.0 + TIME * wave_speed) * sin(world_xz_snapped.y * 6.0 + TIME * wave_speed * 0.8)
		);
		float voronoi_ripple = (v_wave - 0.5) * 2.0;
		
		// Deslocamento de onda quantizado em texels para ondulação visual retro pixel art
		vec2 surface_wave_offset = (screen_perp * (wave_slope.x * 1.5 + voronoi_ripple * 0.8) + screen_up_per_meter * (wave_slope.y * 1.8 + wave_curr * 0.7)) * (reflection_distortion_px * texel_size.y * 14.0);
		vec2 pixel_wave_distortion = round(surface_wave_offset / texel_size) * texel_size;
		
		vec3 reflected_scene = vec3(0.0);
		float reflection_weight = 0.0;
		
		// Marcha progressiva em 24 passos: granularidade fina perto da superfície (~0.07m) para capturar
		// pedras rasas, expandindo suavemente até 4.8m para refletir árvores e colunas altas
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
			
			// Altura real da geometria física acima da superfície da água
			float obj_h = sample_world_pos.y - v_world_pos.y;
			
			// Descarta pontos submersos
			if (obj_h <= 0.02) {
				continue;
			}
			
			// REGRA ÓPTICA DE ALCANCE POR ALTURA EXPOSTA:
			// O alcance do reflexo na superfície da água é rigorosamente limitado pela altura do objeto exposto acima da água.
			// Objetos menores (ex: pontas de pedras de 0.05m a 0.15m) não projetam reflexos além de sua silhueta física.
			if (h > obj_h * 2.2 + 0.15) {
				continue;
			}
			
			// Tolerância proporcional à altura exposta (evita reflexos desproporcionais em objetos baixos)
			float max_tol = max(0.045, obj_h * 0.35);
			float wave_h_mod = wave_curr * wave_height * 2.5;
			float expected_h = h * 0.5 + wave_h_mod;
			
			if (abs(obj_h - expected_h) < max_tol && sample_view.z < VERTEX.z + 0.25) {
				reflected_scene = texture(screen_texture, sample_uv).rgb;
				
				// Intensidade proporcional: pontas de pedra têm reflexos suaves e contidos na sua borda;
				// estruturas altas têm reflexos ricos e dominantes
				float height_scale = clamp(obj_h / 0.35, 0.30, 1.0);
				float falloff = 1.0 - t * 0.30;
				reflection_weight = clamp(reflection_strength * 1.65 * falloff * height_scale, 0.0, 0.82);
				break; // Interrompe no primeiro hit válido
			}
		}
		
		// 5. Composição de Camadas (Leito de Fundo -> Cáusticas -> SUPERFÍCIE Reflexiva -> Espuma)
		// A. Água do fundo (leito de areia + atenuação por profundidade)
		vec4 base_water = mix(shallow_color, deep_color, stepped_depth);
		vec3 underwater_floor = mix(refracted_bg, base_water.rgb, base_water.a);
		
		// B. Cáusticas no leito submerso
		underwater_floor = mix(underwater_floor, shallow_color.rgb * 1.35, caustic_band * 0.35);
		
		// C. Reflexo Planar Óptico na SUPERFÍCIE (cobre o fundo onde há reflexo evidente)
		vec3 surface_composite = underwater_floor;
		if (reflection_weight > 0.0) {
			surface_composite = mix(underwater_floor, reflected_scene, reflection_weight);
		}
		
		// D. Espuma de borda e glints na crista das ondas (topo da superfície)
		vec3 final_color = mix(surface_composite, foam_color, clamp(foam_mask + specular_glint, 0.0, 1.0));
		ALBEDO = final_color;
		ALPHA = 0.96;
	} else {
		// --- FACES LATERAIS DO VOLUME DIORAMA (Aquário em corte) ---
		vec3 side_color = mix(deep_color.rgb * 0.75, deep_color.rgb, clamp(v_world_pos.y / 0.85, 0.0, 1.0));
		ALBEDO = mix(refracted_bg, side_color, 0.65);
		ALPHA = 0.82;
	}
}
