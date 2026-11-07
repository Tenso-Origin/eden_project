shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

// Shader de Superfície: Cel Shading com Bandas Suaves (David Holland Architecture)
// Substitui a iluminação com ruído Bayer por degraus estilizados de luz (light_bands)
// com transições suaves (smoothstep 0.35-0.65) nas faces dos blocos e estruturas.
//
// CORREÇÃO SOMBRA AO ZÊNITE + SOMBRAS NATURAIS NO CICLO DIA/NOITE:
// Separamos NdotL puro (geometria, estável) do ATTENUATION (shadow map dinâmico).
// A sombra projetada usa um "shadow floor" mínimo para nunca escurecer totalmente
// — mantém a leitura visual do terreno mesmo dentro de áreas de sombra longa.

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, hint_default_white;

// Cor da sombra ambiente (fria/azulada para complementar a luz solar quente)
uniform vec4 shadow_tint : source_color = vec4(0.15, 0.12, 0.28, 1.0);

uniform int light_bands : hint_range(2, 6) = 3;
uniform float dither_spread : hint_range(0.0, 0.5) = 0.0;

// Suavidade da transição de sombra projetada:
// 0.0 = sombra dura (pixel art puro), 0.08 = suave (elimina o acne visual)
uniform float shadow_softness : hint_range(0.0, 0.3) = 0.08;

// Luminosidade mínima dentro da sombra projetada (0 = preto, 0.4 = visível).
// Evita que sombras longas do amanhecer/pôr do sol apaguem completamente o terreno.
uniform float shadow_floor : hint_range(0.0, 0.6) = 0.35;

group_uniforms TopSurfaceTexture;
uniform bool use_top_texture = false;
uniform bool use_vertex_alpha_for_texture = false;
uniform sampler2D top_albedo_texture : source_color, filter_nearest, repeat_enable;
uniform float top_texture_scale : hint_range(0.05, 4.0) = 0.35;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

float bayer4x4(vec2 screen_pos) {
	int x = int(mod(screen_pos.x, 4.0));
	int y = int(mod(screen_pos.y, 4.0));
	const int bayer[16] = int[](
		0, 8, 2, 10,
		12, 4, 14, 6,
		3, 11, 1, 9,
		15, 7, 13, 5
	);
	return (float(bayer[y * 4 + x]) / 16.0) - 0.5;
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 base_color = albedo_color.rgb * COLOR.rgb;
	if (use_top_texture && v_world_normal.y > 0.55) {
		vec2 top_uv = v_world_pos.xz * top_texture_scale;
		vec4 top_tex = texture(top_albedo_texture, top_uv);
		float blend_factor = use_vertex_alpha_for_texture ? COLOR.a : clamp((0.55 - COLOR.r) * 3.5, 0.0, 1.0);
		base_color = mix(COLOR.rgb, top_tex.rgb, blend_factor);
	} else {
		vec4 tex = texture(albedo_texture, UV);
		base_color *= tex.rgb;
	}
	ALBEDO = base_color;
}

void light() {
	// --- CANAL 1: Bandas Toon com NdotL puro (estável, sem dependência do shadow map) ---
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);

	float scaled_light = NdotL * float(light_bands - 1);
	float band_idx = floor(scaled_light);
	float frac = fract(scaled_light);
	float smooth_frac = smoothstep(0.35, 0.65, frac);

	float dither = (dither_spread > 0.0) ? (bayer4x4(FRAGCOORD.xy) * dither_spread) : 0.0;
	float stepped_light = clamp((band_idx + smooth_frac + dither) / float(light_bands - 1), 0.0, 1.0);

	// --- CANAL 2: Sombra projetada com floor mínimo e suavização ---
	// ATTENUATION: 0.0 = totalmente em sombra, 1.0 = sem sombra.
	// O shadow_floor garante que áreas em sombra ainda sejam visíveis (não pretas),
	// eliminando as manchas escuras sólidas ao amanhecer/pôr do sol.
	float smooth_shadow = smoothstep(shadow_softness, 1.0 - shadow_softness, ATTENUATION);
	float shadow_with_floor = mix(shadow_floor, 1.0, smooth_shadow);

	// --- COMBINAÇÃO FINAL ---
	// stepped_light controla as bandas toon (geometria da face).
	// shadow_with_floor escurece uniformemente a área em sombra projetada,
	// mas nunca abaixo de shadow_floor — mantendo leitura visual.
	float final_light = stepped_light * shadow_with_floor;

	vec3 lit_color    = ALBEDO * LIGHT_COLOR / PI;
	vec3 shadow_color = ALBEDO * shadow_tint.rgb;
	vec3 shaded_color = mix(shadow_color, lit_color, final_light);
	DIFFUSE_LIGHT += shaded_color;
}
