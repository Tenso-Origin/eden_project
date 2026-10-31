shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;

// Shader de Água HD Pixel Art 3D com Reflexo Screen-Space Ancorado Orbital
// Implementa reflexos 2.5D alinhados à vertical da câmera que acompanham a rotação 360° do CameraPivot,
// ondulações Voronoi quantizadas e espuma de profundidade linear (Depth Ripples).

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
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.35;
uniform float reflection_distortion_px : hint_range(0.0, 6.0) = 1.5;
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
		
		// 1. Reconstrução de Profundidade Linear do Fundo
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
		
		// 3. Ondas Voronoi e Glints Especulares
		float v_wave = voronoi_wave(animated_xz * 3.5, TIME);
		float caustic_band = step(0.72, v_wave);
		float specular_glint = step(specular_glint_threshold, v_wave);
		
		// 4. Reflexo em Screen-Space Ancorado à Posição de Mundo/Tela do Fragmento
		// Busca verticalmente para cima na tela (SCREEN_UV - vec2(ripple_distortion_x, vertical_march_offset))
		// garantindo alinhamento perfeito com o objeto mesmo com rotação 360° da câmera.
		float ripple_phase = (v_world_pos.x + v_world_pos.z) * 10.0 + TIME * wave_speed * 1.5;
		float ripple_distortion_x = sin(ripple_phase) * (reflection_distortion_px * texel_size.x);
		
		vec3 reflected_scene = vec3(0.0);
		float reflection_weight = 0.0;
		
		for (int step_idx = 1; step_idx <= 12; step_idx++) {
			float vertical_march_offset = float(step_idx) * 2.5 * texel_size.y;
			vec2 test_uv = SCREEN_UV - vec2(ripple_distortion_x, vertical_march_offset);
			
			if (test_uv.y < 0.005 || test_uv.y > 0.995 || test_uv.x < 0.005 || test_uv.x > 0.995) {
				break;
			}
			
			float ref_depth = texture(depth_texture, test_uv).r;
			vec3 ref_ndc = vec3(test_uv * 2.0 - 1.0, ref_depth);
			vec4 ref_view = INV_PROJECTION_MATRIX * vec4(ref_ndc, 1.0);
			ref_view.xyz /= ref_view.w;
			vec3 ref_world = (INV_VIEW_MATRIX * vec4(ref_view.xyz, 1.0)).xyz;
			
			// Validação via depth_texture e coordenadas de mundo:
			// - Reflete apenas objetos acima da superfície da água (Y > 0.0 ou Y > v_world_pos.y + 0.02)
			// - Garante que o objeto está mais ao fundo no view space que o pixel da água (ref_view.z < VERTEX.z + 0.25),
			//   impedindo qualquer projeção de reflexo para trás/acima do objeto.
			if ((ref_world.y > 0.0 || ref_world.y > v_world_pos.y + 0.02) && ref_view.z < VERTEX.z + 0.25) {
				reflected_scene = texture(screen_texture, test_uv).rgb;
				float falloff = 1.0 - (float(step_idx) / 12.0) * 0.40;
				reflection_weight = reflection_strength * falloff;
				break; // Para no primeiro hit para evitar clones e espelho infinito
			}
		}
		
		// 5. Composição de Cor da Água
		vec4 base_water = mix(shallow_color, deep_color, stepped_depth);
		vec3 water_composite = mix(refracted_bg, base_water.rgb, base_water.a);
		
		// Aplica reflexo ancorado
		if (reflection_weight > 0.0) {
			water_composite = mix(water_composite, reflected_scene, reflection_weight);
		}
		
		water_composite = mix(water_composite, shallow_color.rgb * 1.25, caustic_band * 0.35);
		
		// Espuma branca brilhante nas margens e brilho especular
		vec3 final_color = mix(water_composite, foam_color, clamp(foam_mask + specular_glint, 0.0, 1.0));
		ALBEDO = final_color;
		ALPHA = 0.92;
	} else {
		// --- FACES LATERAIS DO VOLUME DIORAMA (Aquário em corte) ---
		vec3 side_color = mix(deep_color.rgb * 0.75, deep_color.rgb, clamp(v_world_pos.y / 0.85, 0.0, 1.0));
		ALBEDO = mix(refracted_bg, side_color, 0.65);
		ALPHA = 0.82;
	}
}
