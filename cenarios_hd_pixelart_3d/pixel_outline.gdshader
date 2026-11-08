shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled;

// ==============================================================================
// Shader de Contornos HD Pixel Art (David Holland & t3ssel8r Architecture)
// - Operador de Sobel 3x3 no buffer de profundidade linear (elimina quebras diagonais)
// - Compensação de derivada tangencial de plano (elimina acne em pisos e rampas)
// - Selective Outlining (Sel-Out) com matiz de sombra rica em vez de cinza translúcido
// - Controle de espessura de texel e posicionamento de silhueta (Inner/Outer/Both)
// - Detecção de vincos geométricos internos (Normal Creases)
// ==============================================================================

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

group_uniforms Silhouette;
// Sensibilidade do gradiente de profundidade
uniform float depth_sensitivity : hint_range(0.1, 10.0) = 3.0;
// Limiar mínimo de salto de profundidade em metros (permite detectar pedras e degraus sutis)
uniform float depth_threshold : hint_range(0.005, 0.5) = 0.035;
// Multiplicador da espessura do traço (1.0 = 1 texel exato)
uniform float outline_thickness : hint_range(0.5, 3.0) = 1.0;
// Cor e opacidade do contorno de silhueta (estilo Sel-Out / tom de sombra profundo)
uniform vec4 outline_color : source_color = vec4(0.07, 0.08, 0.16, 0.90);
// Onde a linha deve nascer: 0 = No Objeto (Inner), 1 = No Fundo (Outer), 2 = Em Ambos (2px encorpado)
uniform int outline_side : hint_enum("Inner (Objeto):0", "Outer (Fundo):1", "Both (Encorpado):2") = 0;

group_uniforms Creases;
// Limiar angular para vincos internos de geometria
uniform float normal_threshold : hint_range(0.05, 1.0) = 0.35;
// Sensibilidade da linha de vinco
uniform float normal_sensitivity : hint_range(0.1, 5.0) = 2.0;
// Cor dos vincos e dobras internas
uniform vec4 crease_color : source_color = vec4(0.12, 0.14, 0.25, 0.65);

void vertex() {
	// Projeta o quad 2x2 diretamente no Clip Space cobrindo a câmera
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// Converte a profundidade não-linear do buffer para distância linear positiva no View Space
float get_linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_texture, uv).r;
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
	vec4 view = inv_proj * vec4(ndc, 1.0);
	return -view.z / view.w;
}

vec3 get_view_normal(vec2 uv) {
	vec3 n = texture(normal_roughness_texture, uv).xyz;
	return normalize(n * 2.0 - 1.0);
}

void fragment() {
	vec2 texel = (1.0 / VIEWPORT_SIZE) * outline_thickness;
	float center_d = get_linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 center_n = get_view_normal(SCREEN_UV);

	// Se o pixel atual estiver no infinito (céu/fundo distante sem geometria), limitamos o comportamento
	bool is_sky = center_d > 2500.0;

	// 1. Amostragem de Profundidade 3x3 (Kernel de Sobel)
	float d_tl = get_linear_depth(SCREEN_UV + vec2(-texel.x,  texel.y), INV_PROJECTION_MATRIX);
	float d_t  = get_linear_depth(SCREEN_UV + vec2( 0.0,      texel.y), INV_PROJECTION_MATRIX);
	float d_tr = get_linear_depth(SCREEN_UV + vec2( texel.x,  texel.y), INV_PROJECTION_MATRIX);
	float d_l  = get_linear_depth(SCREEN_UV + vec2(-texel.x,  0.0),     INV_PROJECTION_MATRIX);
	float d_r  = get_linear_depth(SCREEN_UV + vec2( texel.x,  0.0),     INV_PROJECTION_MATRIX);
	float d_bl = get_linear_depth(SCREEN_UV + vec2(-texel.x, -texel.y), INV_PROJECTION_MATRIX);
	float d_b  = get_linear_depth(SCREEN_UV + vec2( 0.0,     -texel.y), INV_PROJECTION_MATRIX);
	float d_br = get_linear_depth(SCREEN_UV + vec2( texel.x, -texel.y), INV_PROJECTION_MATRIX);

	// Magnitude do Gradiente de Sobel
	float gx_d = (d_tr + 2.0 * d_r + d_br) - (d_tl + 2.0 * d_l + d_bl);
	float gy_d = (d_bl + 2.0 * d_b + d_br) - (d_tl + 2.0 * d_t + d_tr);
	float depth_grad = sqrt(gx_d * gx_d + gy_d * gy_d);

	// 2. Compensação de Plano Tangente com Derivadas de Tela (David Holland)
	// Calcula a taxa esperada de variação de profundidade no plano atual
	float expected_slope = length(vec2(dFdx(center_d), dFdy(center_d))) * (8.0 * outline_thickness);
	float adjusted_depth_diff = depth_grad - (expected_slope + depth_threshold);
	float depth_edge = clamp(adjusted_depth_diff * depth_sensitivity, 0.0, 1.0);

	// 3. Posicionamento de Silhueta (Inner vs Outer vs Both)
	if (depth_edge > 0.0 && outline_side != 2) {
		float avg_neighbor_d = (d_tl + d_t + d_tr + d_l + d_r + d_bl + d_b + d_br) * 0.125;
		bool is_foreground = center_d < (avg_neighbor_d - 0.005);
		
		if (outline_side == 0 && (!is_foreground || is_sky)) {
			depth_edge = 0.0; // Desenha apenas sobre a malha do objeto à frente
		} else if (outline_side == 1 && is_foreground) {
			depth_edge = 0.0; // Desenha apenas no fundo envolvente
		}
	} else if (is_sky && outline_side != 1 && outline_side != 2) {
		depth_edge = 0.0;
	}

	// 4. Detecção de Vincos e Quinas de Normais (Creases)
	float normal_edge = 0.0;
	if (!is_sky && depth_edge < 0.2) {
		vec3 n_t = get_view_normal(SCREEN_UV + vec2( 0.0,      texel.y));
		vec3 n_b = get_view_normal(SCREEN_UV - vec2( 0.0,      texel.y));
		vec3 n_l = get_view_normal(SCREEN_UV - vec2( texel.x,  0.0));
		vec3 n_r = get_view_normal(SCREEN_UV + vec2( texel.x,  0.0));

		float normal_diff = length(n_r - n_l) + length(n_t - n_b);
		normal_edge = clamp((normal_diff - normal_threshold) * normal_sensitivity, 0.0, 1.0);
	}

	// 5. Composição Final de Cores com Descarte Transparente
	if (depth_edge > 0.05) {
		ALBEDO = outline_color.rgb;
		ALPHA = outline_color.a * depth_edge;
	} else if (normal_edge > 0.05) {
		ALBEDO = crease_color.rgb;
		ALPHA = crease_color.a * normal_edge;
	} else {
		ALPHA = 0.0;
		discard;
	}
}
