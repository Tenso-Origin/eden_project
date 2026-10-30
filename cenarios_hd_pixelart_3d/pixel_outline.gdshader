shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled;

// Shader de Contornos 3D Pixel-Perfect (David Holland Architecture)
// Lê apenas depth_texture e normal_roughness_texture, sem screen_texture opaco,
// desenhando apenas as linhas de contorno (silhueta) e creases com transparência (ALPHA).

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_roughness_texture : hint_normal_roughness_texture, repeat_disable, filter_nearest;

group_uniforms OutlineSettings;
uniform float depth_threshold : hint_range(0.01, 1.0) = 0.05;
uniform float normal_threshold : hint_range(0.01, 1.0) = 0.25;
uniform float shadow_darken : hint_range(0.0, 1.0) = 0.65; // Escurece bordas externas (Silhueta)
uniform float highlight_brighten : hint_range(0.0, 1.0) = 0.35; // Clareia quinas convexas (Creases)

void vertex() {
	// Trava o Quad 2x2 diretamente no Clip Space cobrindo toda a câmera
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// Reconstrói a posição 3D no View Space para medir distâncias lineares reais
vec3 get_view_pos(vec2 uv, mat4 inv_proj) {
	float depth = texture(depth_texture, uv).r;
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	vec4 view = inv_proj * vec4(ndc, 1.0);
	return view.xyz / view.w;
}

vec3 get_view_normal(vec2 uv) {
	vec3 n = texture(normal_roughness_texture, uv).xyz;
	return normalize(n * 2.0 - 1.0);
}

void fragment() {
	vec2 texel = 1.0 / VIEWPORT_SIZE;
	vec3 center_pos = get_view_pos(SCREEN_UV, INV_PROJECTION_MATRIX);
	vec3 center_normal = get_view_normal(SCREEN_UV);

	// Amostragem em cruz de 4 vizinhos (1 texel de distância exata)
	vec2 offsets[4] = vec2[](
		vec2(0.0, texel.y),  // Cima
		vec2(0.0, -texel.y), // Baixo
		vec2(-texel.x, 0.0), // Esquerda
		vec2(texel.x, 0.0)   // Direita
	);

	float depth_diff = 0.0;
	float normal_crease = 0.0;

	for (int i = 0; i < 4; i++) {
		vec2 sample_uv = SCREEN_UV + offsets[i];
		vec3 neighbor_pos = get_view_pos(sample_uv, INV_PROJECTION_MATRIX);
		vec3 neighbor_normal = get_view_normal(sample_uv);

		// Modula o limite de profundidade pelo ângulo rasante da superfície (evita artefatos em pisos)
		float grazing_mod = clamp(1.0 - center_normal.z, 0.0, 1.0);
		float adjusted_threshold = depth_threshold * (1.0 + grazing_mod * 2.0);

		// Descontinuidade de profundidade: desenha a silhueta apenas no objeto que está na FRENTE
		// (No Godot View Space, -Z é para frente, então maior Z = mais perto da câmera)
		float d_diff = center_pos.z - neighbor_pos.z;
		if (d_diff > adjusted_threshold) {
			depth_diff = 1.0;
		}

		// Descontinuidade de Normal: avalia se a quina é convexa para aplicar highlight de 1px
		vec3 n_diff = center_normal - neighbor_normal;
		float n_dist = length(n_diff);
		if (n_dist > normal_threshold && abs(d_diff) < adjusted_threshold) {
			// Prioriza bordas superiores/esquerdas para simular luz de topo
			float dir_bias = dot(n_diff.xy, offsets[i] / texel);
			if (dir_bias > 0.0) {
				normal_crease = 1.0;
			}
		}
	}

	// Desenha APENAS as linhas de contorno e crease, descartando onde não há bordas
	// Isso permite que objetos transparentes (como a água) continuem 100% visíveis abaixo!
	if (depth_diff > 0.0) {
		ALBEDO = vec3(0.0);
		ALPHA = shadow_darken;
	} else if (normal_crease > 0.0) {
		ALBEDO = vec3(1.0);
		ALPHA = highlight_brighten;
	} else {
		ALPHA = 0.0;
		discard;
	}
}
