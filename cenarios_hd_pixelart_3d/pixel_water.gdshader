shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;

// Shader de Água HD Pixel Art 3D com Planar Reflection Camera (David Holland Architecture)
// - Reflexo planar puro renderizado por câmera espelhada dedicada (ReflectionViewport)
// - Ondulação senoidal horizontal alinhada ao texel (sem raymarching, sem manchas/bolas azuis)
// - Contorno fino e suave de 1-2 linhas de embaçamento/clareamento nas margens
// - Raros tracinhos horizontais de 1px de brilho solar
// - Descarte de faces laterais/inferiores e composição direta no ALBEDO

uniform sampler2D reflection_texture : source_color, filter_nearest, repeat_disable;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

group_uniforms WaterColors;
uniform vec4 shallow_color : source_color = vec4(0.20, 0.72, 0.82, 0.82);
uniform vec4 deep_color : source_color = vec4(0.08, 0.32, 0.54, 0.94);
uniform float depth_fade_distance : hint_range(0.1, 5.0) = 0.85;

group_uniforms RipplesAndWaves;
uniform float pixel_grid_density : hint_range(8.0, 128.0) = 52.0;
uniform float wave_speed : hint_range(0.5, 5.0) = 1.8;
uniform float wave_height : hint_range(0.0, 0.1) = 0.02;
uniform float shoreline_foam_dist : hint_range(0.05, 1.0) = 0.28;

group_uniforms PlanarReflection;
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.55;
uniform float wave_ripple_strength : hint_range(0.0, 5.0) = 1.8;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

void vertex() {
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	
	// Marola geométrica sutil apenas na face horizontal superior
	if (NORMAL.y > 0.5) {
		vec2 snapped_xz = floor(w_pos.xz * pixel_grid_density) / pixel_grid_density;
		float wave = sin(snapped_xz.x * 6.0 + TIME * wave_speed) * cos(snapped_xz.y * 6.0 + TIME * wave_speed * 0.8);
		VERTEX.y += wave * wave_height;
	}
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Descarte de faces laterais e inferiores
	if (v_world_normal.y <= 0.5) {
		discard;
	}

	vec2 texel_size = 1.0 / VIEWPORT_SIZE;
	vec2 world_xz_snapped = floor(v_world_pos.xz * pixel_grid_density) / pixel_grid_density;
	
	// 1. Refração sutil do leito de areia
	vec2 pixel_wave_offset = round(vec2(
		sin(v_world_pos.z * 14.0 + TIME * wave_speed * 2.0),
		cos(v_world_pos.x * 14.0 + TIME * wave_speed * 1.5)
	) * 1.5) * texel_size;
	
	vec2 bg_uv = SCREEN_UV + pixel_wave_offset * 0.35;
	vec3 refracted_bg = texture(screen_texture, bg_uv).rgb;
	
	// Blur em cruz (5 amostras) do leito
	vec2 blur_offset = texel_size * 1.5;
	vec3 bg_u = texture(screen_texture, bg_uv + vec2(0.0, blur_offset.y)).rgb;
	vec3 bg_d = texture(screen_texture, bg_uv - vec2(0.0, blur_offset.y)).rgb;
	vec3 bg_l = texture(screen_texture, bg_uv - vec2(blur_offset.x, 0.0)).rgb;
	vec3 bg_r = texture(screen_texture, bg_uv + vec2(blur_offset.x, 0.0)).rgb;
	vec3 blurred_bg = (refracted_bg * 0.36 + (bg_u + bg_d + bg_l + bg_r) * 0.16);

	// 2. Reconstrução de Profundidade Linear do Leito
	float bg_depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec3 bg_ndc = vec3(SCREEN_UV * 2.0 - 1.0, bg_depth_raw);
	vec4 bg_view = INV_PROJECTION_MATRIX * vec4(bg_ndc, 1.0);
	bg_view.xyz /= bg_view.w;
	
	float water_depth = max(0.0, VERTEX.z - bg_view.z);
	float depth_factor = clamp(water_depth / depth_fade_distance, 0.0, 1.0);
	float stepped_depth = floor(depth_factor * 5.0) / 5.0;

	// 3. Linhas finas e suaves de contato nas margens (sem bolas azuis nem manchas grossas)
	float shoreline_mask = 0.0;
	if (water_depth < shoreline_foam_dist && water_depth > 0.001) {
		float norm_shore = water_depth / shoreline_foam_dist; // 0 na borda, 1 no limite
		// Linha 1: bem encostada no contorno (espessura fina de ~1 texel)
		float edge_line = step(norm_shore, 0.10);
		// Linha 2: segundo anel fino concêntrico suave
		float ring_wave = sin(norm_shore * 12.566 - TIME * (wave_speed * 2.2));
		float ring_line = step(0.65, ring_wave) * (1.0 - norm_shore);
		shoreline_mask = clamp(edge_line * 0.90 + ring_line * 0.50, 0.0, 1.0);
	}
	
	// Raros tracinhos horizontais de 1px de brilho solar cintilante
	float sparkle_seed = dot(floor(world_xz_snapped * 2.0), vec2(17.13, 43.71)) + floor(TIME * 2.2);
	float sparkle_rand = fract(sin(sparkle_seed) * 43758.5453);
	float sparkle = step(0.988, sparkle_rand);

	// Leito com embaçamento suave apenas onde há linha de contato
	vec3 seabed_refracted = mix(refracted_bg, blurred_bg, shoreline_mask * 0.70);

	// 4. Mistura da cor da água com clareamento suave nos contornos
	vec4 base_water = mix(shallow_color, deep_color, stepped_depth);
	vec3 brightened_cyan = shallow_color.rgb * 1.25;
	vec3 water_tint = mix(base_water.rgb, brightened_cyan, shoreline_mask * 0.40);
	vec3 water_composite = mix(seabed_refracted, water_tint, base_water.a);

	// Adiciona tracinhos de brilho especular de 1px
	if (sparkle > 0.0) {
		water_composite = mix(water_composite, vec3(0.92, 0.98, 1.0), 0.85);
	}

	// 5. Reflexo Planar Puro via ReflectionViewport
	// Espelhamento vertical natural: a ReflectionCamera olha de baixo para cima
	vec2 refl_uv = vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y);
	
	// Ondulação característica do David Holland (deslocamento horizontal por onda quantizada)
	float wave_offset = sin(world_xz_snapped.y * 16.0 + TIME * wave_speed * 2.5) * cos(world_xz_snapped.x * 10.0 + TIME * wave_speed) * (wave_ripple_strength * texel_size.x);
	vec2 final_refl_uv = refl_uv + vec2(wave_offset, 0.0);
	
	if (final_refl_uv.x >= 0.001 && final_refl_uv.x <= 0.999 && final_refl_uv.y >= 0.001 && final_refl_uv.y <= 0.999) {
		vec4 planar_refl = texture(reflection_texture, final_refl_uv);
		if (planar_refl.a > 0.1) {
			// Mistura o reflexo escurecido/azulado sobre a água
			vec3 refl_tinted = planar_refl.rgb * vec3(0.75, 0.88, 0.95);
			water_composite = mix(water_composite, refl_tinted, planar_refl.a * reflection_strength);
		}
	}

	ALBEDO = water_composite;
	ALPHA = 1.0;
}
