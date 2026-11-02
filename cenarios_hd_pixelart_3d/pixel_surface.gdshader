shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// Shader de Superfície: Cel Shading com Bandas Suaves (David Holland Architecture)
// Substitui a iluminação com ruído Bayer por degraus estilizados de luz (light_bands)
// com transições suaves (smoothstep 0.35-0.65) nas faces dos blocos e estruturas.

uniform vec4 albedo_color : source_color = vec4(0.35, 0.65, 0.30, 1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, hint_default_white;
uniform vec4 shadow_tint : source_color = vec4(0.15, 0.12, 0.28, 1.0);
uniform int light_bands : hint_range(2, 6) = 3;
uniform float dither_spread : hint_range(0.0, 0.5) = 0.0;

// Matriz de Bayer 4x4 mantida opcional para compatibilidade
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

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = albedo_color.rgb * tex.rgb * COLOR.rgb;
}

void light() {
	// Calcula intensidade da luz + sombra projetada
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float raw_light = NdotL * ATTENUATION;

	// Transição suave entre bandas de luz sem quadriculado Bayer
	float scaled_light = raw_light * float(light_bands - 1);
	float band_idx = floor(scaled_light);
	float frac = fract(scaled_light);
	float smooth_frac = smoothstep(0.35, 0.65, frac);

	float dither = (dither_spread > 0.0) ? (bayer4x4(FRAGCOORD.xy) * dither_spread) : 0.0;
	float stepped_light = clamp((band_idx + smooth_frac + dither) / float(light_bands - 1), 0.0, 1.0);

	// Mistura entre a cor da sombra (fria/azulada) e a luz direta do sol
	vec3 shaded_color = mix(ALBEDO * shadow_tint.rgb, ALBEDO * LIGHT_COLOR / PI, stepped_light);
	DIFFUSE_LIGHT += shaded_color;
}
