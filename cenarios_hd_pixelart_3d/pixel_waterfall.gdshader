shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;

// =========================================================================
// Shader de Queda d'Água / Cascata Vertical HD Pixel Art 3D (pixel_waterfall.gdshader)
// - Transição vertical física: Lâmina translúcida nos primeiros 2.0m abaixo da crista
// - Efervescência estocástica a 6 Hz para quedas > 2.0m com microbolhas orgânicas de pixel art
// - Espuma branca pura (#FFFFFF / foam_color) sem patamar intermediário ciano sólido
// - Refração estocástica revelando os paredões rochosos da calha atrás da cascata
// =========================================================================

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;

group_uniforms WaterColors;
uniform vec4 shallow_color : source_color = vec4(0.18, 0.72, 0.82, 0.40);
uniform vec4 deep_color : source_color = vec4(0.08, 0.32, 0.52, 0.70);

group_uniforms ThreeWayWaterBlend;
uniform bool enable_3way_blend = false;
// 1. Água Turquesa Cristalina (Clearwater / Calcário)
uniform vec4 turquesa_shallow : source_color = vec4(0.18, 0.82, 0.78, 0.50);
uniform vec4 turquesa_deep : source_color = vec4(0.05, 0.38, 0.48, 0.90);
// 2. Água Barrenta de Várzea (Whitewater / Sedimentos / Solimões)
uniform vec4 barrenta_shallow : source_color = vec4(0.62, 0.47, 0.31, 0.85);
uniform vec4 barrenta_deep : source_color = vec4(0.38, 0.26, 0.16, 0.98);
// 3. Água Preta de Igarapé (Blackwater / Chá Mate / Rio Negro)
uniform vec4 igarape_shallow : source_color = vec4(0.38, 0.24, 0.11, 0.60);
uniform vec4 igarape_deep : source_color = vec4(0.11, 0.06, 0.04, 0.96);

group_uniforms WaterfallParams;
uniform float pixel_grid_density : hint_range(8.0, 128.0) = 52.0; // Texels por metro
uniform float wave_speed : hint_range(0.5, 5.0) = 2.0;
uniform float laminar_length : hint_range(0.5, 5.0) = 2.0; // Lâmina de 2 metros antes da espuma
uniform vec3 foam_color : source_color = vec3(1.0, 1.0, 1.0);

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec4 v_flow_data;
varying vec2 v_uv2;
varying float v_fall_top;

// 1. Hash e Ruído de Gradiente Quintic Hermite
vec2 hash_grad(vec2 p) {
	vec2 k = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return -1.0 + 2.0 * fract(sin(k) * 43758.5453123);
}

float gradient_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(
		mix(dot(hash_grad(i + vec2(0.0, 0.0)), f - vec2(0.0, 0.0)),
			dot(hash_grad(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0)), u.x),
		mix(dot(hash_grad(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0)),
			dot(hash_grad(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void vertex() {
	v_flow_data = COLOR;
	v_uv2 = UV2;
	v_fall_top = UV.y;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	if (v_fall_top <= 0.001) {
		v_fall_top = w_pos.y;
	}
	v_world_pos = w_pos;
}

void fragment() {
	float fall_top = v_fall_top;
	float fall_dist = max(0.0, fall_top - v_world_pos.y);

	vec2 fall_snapped = floor(vec2(v_world_pos.x, v_world_pos.y) * pixel_grid_density) / pixel_grid_density;
	float cascade_speed = wave_speed * 4.2;

	// Cor base da água da cascata conforme o bioma (Chá-Mate / Turquesa / Barrenta)
	vec4 fall_water_col = shallow_color;
	if (enable_3way_blend) {
		float w_turq = v_uv2.x;
		float w_barr = v_uv2.y;
		float sum_uv = w_turq + w_barr;
		if (sum_uv > 0.001) {
			float w_iga = max(0.0, 1.0 - sum_uv);
			fall_water_col = turquesa_shallow * w_turq + barrenta_shallow * w_barr + igarape_shallow * w_iga;
		} else {
			float t = clamp(v_flow_data.a, 0.0, 1.0);
			fall_water_col = mix(turquesa_shallow, igarape_shallow, t);
		}
	}

	// Refração do fundo rochoso da calha atrás da cascata
	vec2 texel_size = 1.0 / VIEWPORT_SIZE;
	float refr_anim = sin(fall_snapped.y * 14.0 + TIME * 12.0) * cos(fall_snapped.x * 10.0);
	vec2 refr_uv = SCREEN_UV + vec2(refr_anim * 1.5, refr_anim * 0.8) * texel_size;
	vec3 bg_refracted = texture(screen_texture, refr_uv).rgb;

	// Estrias dinâmicas de aceleração laminar
	float stream1 = sin(fall_snapped.x * 12.0 + (fall_snapped.y + TIME * cascade_speed) * 8.0);
	float stream2 = cos(fall_snapped.x * 20.0 - (fall_snapped.y + TIME * cascade_speed * 1.3) * 11.0);
	float stream_noise = gradient_noise(vec2(fall_snapped.x * 3.5, (fall_snapped.y + TIME * cascade_speed) * 2.0));

	// Transição vertical em Y = Ytop - laminar_length (2.0m) com modulação de pixel art
	float col_hash = fract(sin(fall_snapped.x * 127.1) * 43758.5453);
	float threshold_y = laminar_length + (col_hash - 0.5) * 0.25;

	if (fall_dist <= threshold_y) {
		// =====================================================================
		// 1. LÂMINA TRANSLÚCIDA (Ytop a Ytop - 2.0m)
		// Lâmina transparente veloz, revelando os paredões de rocha da calha atrás
		// =====================================================================
		float cord_lines = sin(fall_snapped.x * 24.0 + stream_noise * 2.0) * 0.5 + 0.5;
		float cord_step = step(0.70, cord_lines);

		vec3 sheet_tint = fall_water_col.rgb * 1.08;
		vec3 laminar_sheet = mix(bg_refracted, sheet_tint, clamp(fall_water_col.a * 0.65, 0.35, 0.70));
		laminar_sheet = mix(laminar_sheet, vec3(1.0, 1.0, 1.0), cord_step * 0.25);

		ALBEDO = laminar_sheet;
		ALPHA = 1.0;
	} else {
		// =====================================================================
		// 2. EFERVESCÊNCIA BRANCA DE CASCATA A 6 HZ (Y < Ytop - 2.0m)
		// Cavitação violenta, microbolhas estocásticas a 6 Hz e densa espuma branca (#FFFFFF)
		// =====================================================================
		float foam_time_step = floor(TIME * 6.0);
		vec2 foam_grid = floor(vec2(v_world_pos.x, v_world_pos.y) * pixel_grid_density);
		float effervescence_noise = fract(sin(dot(foam_grid + vec2(foam_time_step * 19.3, foam_time_step * 37.1), vec2(12.9898, 78.233))) * 43758.5453);

		float foam_signal = stream_noise * 0.40 + (stream1 * stream2) * 0.30 + effervescence_noise * 0.45;
		float white_foam = step(0.28, foam_signal);

		vec3 boiling_cascade = mix(fall_water_col.rgb * 0.85, foam_color, clamp(white_foam + 0.55, 0.0, 1.0));

		ALBEDO = boiling_cascade;
		ALPHA = 1.0;
	}
}
