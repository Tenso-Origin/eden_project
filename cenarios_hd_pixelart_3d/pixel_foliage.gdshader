shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

// =========================================================================
// SHADER DE FOLHAGEM E VEGETAÇÃO HD PIXEL ART (David Holland Architecture)
// =========================================================================
// 1. Normal Trick do David Holland: força a normal da folhagem a apontar para
//    o céu no View Space, transformando a malha poliédrica facetada em uma
//    massa esférica suave e orgânica de folha sem linhas duras nas faces.
// 2. Animação de vento suave no vertex() com base em seno e coordenadas XZ.
// 3. Cel Shading em tons de verde floresta vivo: as sombras herdam a cor da
//    folha com shadow_tint rico, eliminando o escurecimento cinza escuro.
// 4. Desacoplamento de NdotL e ATTENUATION para eliminar shadow acne ao meio-dia.

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, hint_default_white;

group_uniforms ShadowTones;
## Cor que modula a sombra da folhagem (tom verde-floresta rico em vez de cinza)
uniform vec4 shadow_tint : source_color = vec4(0.38, 0.58, 0.30, 1.0);
## Número de bandas de cel shading
uniform int light_bands : hint_range(2, 6) = 3;
## Piso mínimo de luminosidade na sombra (mantém a leitura visual)
uniform float shadow_floor : hint_range(0.0, 0.6) = 0.38;
## Suavização da borda de sombra para evitar artefatos oscilatórios
uniform float shadow_softness : hint_range(0.0, 0.3) = 0.08;

group_uniforms WindAnimation;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.35;
uniform float wind_speed : hint_range(0.5, 6.0) = 2.2;

void vertex() {
	// Balanço orgânico do vento
	float phase = VERTEX.x * 3.5 + VERTEX.z * 2.8;
	// Garante balanço tanto para folhas (COLOR.a modulado) quanto para a copa da árvore
	float weight = max(COLOR.a, 0.45);
	float sway = sin(TIME * wind_speed + phase) * wind_strength * 0.08 * weight;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.35;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);

	// Gradiente vertical sutil: base mais profunda, topo mais iluminado
	vec3 height_tint = mix(vec3(0.82, 0.90, 0.75), vec3(1.10, 1.15, 0.95), clamp(COLOR.a, 0.0, 1.0));
	ALBEDO = albedo_color.rgb * tex.rgb * COLOR.rgb * height_tint;

	// Normal Trick do David Holland: forçar normais suavizadas para o topo
	// Elimina as facetas triangulares duras e cria o visual suave de folhagem pixel art
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void light() {
	// --- CANAL 1: Bandas Toon com NdotL puro (estável, sem oscilações) ---
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float scaled_light = NdotL * float(light_bands - 1);
	float band_idx = floor(scaled_light);
	float frac = fract(scaled_light);
	float smooth_frac = smoothstep(0.35, 0.65, frac);
	float stepped_light = clamp((band_idx + smooth_frac) / float(light_bands - 1), 0.0, 1.0);

	// --- CANAL 2: Sombra projetada com suavização e floor ---
	float smooth_shadow = smoothstep(shadow_softness, 1.0 - shadow_softness, ATTENUATION);
	float shadow_with_floor = mix(shadow_floor, 1.0, smooth_shadow);
	float final_light = stepped_light * shadow_with_floor;

	// --- COMBINAÇÃO: Sombra em tons de verde vivo (nunca cinza escuro!) ---
	vec3 lit_color    = ALBEDO * LIGHT_COLOR / PI;
	vec3 shadow_color = ALBEDO * shadow_tint.rgb;
	vec3 shaded_color = mix(shadow_color, lit_color, final_light);
	DIFFUSE_LIGHT += shaded_color;
}
