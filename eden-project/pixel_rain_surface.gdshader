shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// Shader de Superfície com Impacto de Chuva, Escorrimento Vertical e Tremer de Folhas (HD Pixel Art)
// Baseado nas regras de clima de David Holland / Blender MCP + Godot 4

group_uniforms SurfacePalette;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform vec4 shadow_tint : source_color = vec4(0.15, 0.12, 0.28, 1.0);
uniform int light_bands : hint_range(2, 6) = 3;
uniform float dither_spread : hint_range(0.0, 0.5) = 0.12;
uniform float porosity : hint_range(0.0, 1.0) = 0.7; // Quanto o material escurece ao molhar

group_uniforms RainAndWeather;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.85;
uniform float ripple_density : hint_range(1.0, 20.0) = 6.0; // Células de gotas por metro (1x1m)
uniform float ripple_speed : hint_range(1.0, 10.0) = 3.5;
uniform vec3 ripple_color : source_color = vec3(0.75, 0.88, 1.0);
uniform bool is_foliage = false;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.25;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec4 v_vertex_col;

// Hash pseudo-aleatório 2D rápido para posicionar as gotas no grid do mundo
vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// Matriz de Bayer 4x4 para manter o estilo Pixel Art clássico
float bayer4x4(vec2 screen_pos) {
	int x = int(mod(screen_pos.x, 4.0));
	int y = int(mod(screen_pos.y, 4.0));
	const int bayer[16] = int[](
		 0,  8,  2, 10,
		12,  4, 14,  6,
		 3, 11,  1,  9,
		15,  7, 13,  5
	);
	return (float(bayer[y * 4 + x]) / 16.0) - 0.5;
}

// Calcula os anéis pixelados de impacto de gota no plano XZ do mundo
float compute_rain_ripples(vec2 world_xz, float time) {
	// Quantiza a coordenada do mundo para manter estética de pixels nítidos (ex: 32 texels por metro)
	vec2 pixelated_xz = floor(world_xz * 32.0) / 32.0;
	vec2 grid_uv = pixelated_xz * ripple_density;
	vec2 cell_id = floor(grid_uv);
	vec2 cell_uv = fract(grid_uv) - 0.5;
	
	vec2 rand = hash22(cell_id);
	// Desloca o centro da gota dentro da célula
	vec2 drop_center = (rand - 0.5) * 0.5;
	
	// Fase temporal única para cada gota
	float t = fract(time * ripple_speed + rand.x * 6.2831 + rand.y * 3.1415);
	
	float dist = length(cell_uv - drop_center);
	float current_radius = t * 0.45;
	
	// Cria um anel nítido de 1 texel de espessura que some no fim do ciclo
	float ring_thickness = 0.06;
	float ring = step( abs(dist - current_radius), ring_thickness ) * (1.0 - t);
	
	// Ponto central branco no instante exato em que a gota toca o chão (t < 0.15)
	float splash_core = step(dist, 0.07) * step(t, 0.15);
	
	// Só ativa uma fração das células dependendo da intensidade da chuva
	float active_cell = step(1.0 - rain_intensity, fract(rand.x + rand.y));
	return clamp((ring + splash_core) * active_cell, 0.0, 1.0);
}

// Calcula o escorrimento vertical nas faces laterais (paredes/pedras/troncos)
float compute_wall_streaks(vec3 world_pos, float time) {
	vec2 p = floor(vec2(world_pos.x + world_pos.z, world_pos.y) * 24.0) / 24.0;
	float col_hash = hash22(vec2(floor(p.x * 8.0), 0.0)).x;
	float drop_y = fract(p.y * 1.5 + time * (ripple_speed * 0.6) + col_hash * 10.0);
	float streak = step(0.92, drop_y) * step(1.0 - rain_intensity * 0.7, col_hash);
	return streak * 0.5;
}

void vertex() {
	v_vertex_col = COLOR;
	
	// Se for vegetação, aplica balanço de vento + "beliscão" vertical de gotas batendo nas folhas
	if (is_foliage) {
		float phase = COLOR.b * 6.2831;
		// Vento contínuo
		float sway = sin(TIME * 2.5 + phase) * wind_strength * 0.12;
		VERTEX.x += sway;
		
		// Impacto rápido de gota de chuva puxando a ponta da folha para baixo
		if (rain_intensity > 0.05) {
			float drop_hit = pow( max(0.0, sin(TIME * 14.0 + phase * 3.7)), 12.0 );
			VERTEX.y -= drop_hit * 0.035 * rain_intensity;
		}
	}
	
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// 1. Cor base vinda do Atributo de Vértice do Blender (AlbedoCol)
	vec3 base_albedo = v_vertex_col.rgb * albedo_tint.rgb;
	
	// 2. Escurecimento físico de material poroso quando molhado
	float wetness = rain_intensity * porosity;
	base_albedo = mix(base_albedo, base_albedo * 0.62, wetness);
	
	// 3. Avaliação de Superfície Superior vs Lateral no World-Space
	float up_factor = clamp(v_world_normal.y, 0.0, 1.0);
	float ripple_mask = 0.0;
	
	if (rain_intensity > 0.01) {
		if (up_factor > 0.65) {
			// Topo do bloco/pedra/folha: Desenha os anéis de impacto das gotas!
			ripple_mask = compute_rain_ripples(v_world_pos.xz, TIME);
		} else if (up_factor > 0.05) {
			// Lateral do bloco/pedra: Desenha gotas escorrendo verticalmente!
			ripple_mask = compute_wall_streaks(v_world_pos, TIME);
		}
	}
	
	// Mistura o brilho da gota/anel na cor final do pixel
	ALBEDO = mix(base_albedo, ripple_color, ripple_mask * 0.75);
}

void light() {
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float raw_light = NdotL * ATTENUATION;
	
	// Dithering 4x4 clássico
	float dither = bayer4x4(FRAGCOORD.xy) * dither_spread;
	float stepped_light = floor((raw_light + dither) * float(light_bands)) / float(light_bands - 1);
	stepped_light = clamp(stepped_light, 0.0, 1.0);
	
	// Reflexo especular duro (1px Rim/Glint) apenas quando a superfície está molhada
	float wet_glint = 0.0;
	if (rain_intensity > 0.2 && v_world_normal.y > 0.4) {
		vec3 half_vec = normalize(LIGHT + VIEW);
		float spec = pow(max(dot(NORMAL, half_vec), 0.0), 32.0);
		wet_glint = step(0.75, spec * ATTENUATION) * rain_intensity * 0.35;
	}
	
	vec3 shaded_color = mix(ALBEDO * shadow_tint.rgb, ALBEDO * LIGHT_COLOR / PI, stepped_light);
	DIFFUSE_LIGHT += shaded_color + (LIGHT_COLOR * wet_glint);
}

