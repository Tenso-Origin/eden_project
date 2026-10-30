shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;

// Shader de Água HD Pixel Art 3D (David Holland Architecture)
// Suporta refração com blur suave de borda, reflexo espelhado 2.5D limpo e volume diorama.

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
uniform float shoreline_foam_dist : hint_range(0.02, 0.8) = 0.25;

group_uniforms ScreenSpaceReflection;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.28;
uniform float reflection_distortion_px : hint_range(0.0, 6.0) = 1.5;
uniform float reflection_offset_px : hint_range(2.0, 40.0) = 14.0;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec4 v_flow_data;

void vertex() {
	v_flow_data = COLOR;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Marola sutil geométrica na face superior
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
	
	if (is_top) {
		// --- SUPERFÍCIE SUPERIOR DA ÁGUA ---
		vec2 world_xz_snapped = floor(v_world_pos.xz * pixel_grid_density) / pixel_grid_density;
		
		// 1. Reconstrução da profundidade do fundo
		float bg_depth_raw = texture(depth_texture, SCREEN_UV).r;
		vec3 bg_ndc = vec3(SCREEN_UV * 2.0 - 1.0, bg_depth_raw);
		vec4 bg_view = INV_PROJECTION_MATRIX * vec4(bg_ndc, 1.0);
		bg_view.xyz /= bg_view.w;
		
		float water_depth = max(0.0, VERTEX.z - bg_view.z);
		float depth_factor = clamp(water_depth / depth_fade_distance, 0.0, 1.0);
		float stepped_depth = floor(depth_factor * 6.0) / 6.0;
		
		// 2. Efeito Embaçado simples nas bordas de contato (Item 3: sem loops longos, sem duplicar blocos)
		float shore_factor = 0.0;
		if (water_depth < shoreline_foam_dist && water_depth > 0.001) {
			shore_factor = clamp(1.0 - (water_depth / shoreline_foam_dist), 0.0, 1.0);
		}
		
		// Blur curto de 1 a 2 texels de raio na screen_texture
		vec2 blur_offset = texel_size * 1.25;
		vec3 bg_center = texture(screen_texture, SCREEN_UV).rgb;
		vec3 bg_blurred = (
			bg_center * 0.36 +
			texture(screen_texture, SCREEN_UV + vec2(blur_offset.x, 0.0)).rgb * 0.16 +
			texture(screen_texture, SCREEN_UV - vec2(blur_offset.x, 0.0)).rgb * 0.16 +
			texture(screen_texture, SCREEN_UV + vec2(0.0, blur_offset.y)).rgb * 0.16 +
			texture(screen_texture, SCREEN_UV - vec2(0.0, blur_offset.y)).rgb * 0.16
		);
		vec3 refracted_bg = mix(bg_center, bg_blurred, shore_factor * 0.75);
		
		// 3. Reflexo 2.5D Limpo Ancorado na Frente (Item 2: sem clones, frente/baixo na tela)
		// Distorção senoidal horizontal sutil (ripple_x)
		float ripple_x = sin(world_xz_snapped.x * 12.0 + TIME * wave_speed * 1.5) * (reflection_distortion_px * texel_size.x);
		
		vec3 reflected_scene = vec3(0.0);
		float reflection_weight = 0.0;
		
		// Faz a busca vertical para cima na tela (-Y em SCREEN_UV) e para no primeiro hit (sem acumular amostras)
		for (int step_idx = 1; step_idx <= 8; step_idx++) {
			float offset_y = float(step_idx) * 3.0;
			vec2 test_uv = SCREEN_UV + vec2(ripple_x, -offset_y * texel_size.y);
			
			if (test_uv.y < 0.01 || test_uv.y > 0.99 || test_uv.x < 0.01 || test_uv.x > 0.99) {
				break;
			}
			
			float ref_depth = texture(depth_texture, test_uv).r;
			vec3 ref_ndc = vec3(test_uv * 2.0 - 1.0, ref_depth);
			vec4 ref_view = INV_PROJECTION_MATRIX * vec4(ref_ndc, 1.0);
			ref_view.xyz /= ref_view.w;
			vec3 ref_world = (INV_VIEW_MATRIX * vec4(ref_view.xyz, 1.0)).xyz;
			
			// Validação via depth_texture: checa se pertence a um objeto acima da água (Y > 0.04m)
			// e garante que o objeto está mais ao fundo no view space que o pixel da água (ref_view.z < VERTEX.z + 0.25),
			// impedindo qualquer projeção de reflexo para trás/acima do objeto.
			if (ref_world.y > 0.04 && ref_view.z < VERTEX.z + 0.25) {
				reflected_scene = texture(screen_texture, test_uv).rgb;
				reflection_weight = reflection_strength; // 0.28 fixo e limpo
				break; // Para no primeiro hit
			}
		}
		
		// 4. Composição de Cor da Água
		vec4 base_water = mix(shallow_color, deep_color, stepped_depth);
		
		// Aumenta levemente a luminosidade azul-turquesa e opacidade (ALPHA) na borda de contato
		vec3 water_tint = mix(base_water.rgb, shallow_color.rgb * 1.25, shore_factor * 0.45);
		float final_alpha = mix(base_water.a, min(1.0, base_water.a + 0.12), shore_factor);
		
		// Mistura água com o fundo refratado
		vec3 composite = mix(refracted_bg, water_tint, final_alpha);
		
		// Aplica reflexo limpo
		if (reflection_weight > 0.0) {
			composite = mix(composite, reflected_scene, reflection_weight);
		}
		
		ALBEDO = composite;
		ALPHA = final_alpha;
	} else {
		// --- FACES LATERAIS DO VOLUME DIORAMA (Aquário) ---
		vec3 side_bg = texture(screen_texture, SCREEN_UV).rgb;
		vec3 side_color = mix(deep_color.rgb * 0.75, deep_color.rgb, clamp((v_world_pos.y + 0.65) / 0.65, 0.0, 1.0));
		ALBEDO = mix(side_bg, side_color, 0.65);
		ALPHA = 0.85;
	}
}
