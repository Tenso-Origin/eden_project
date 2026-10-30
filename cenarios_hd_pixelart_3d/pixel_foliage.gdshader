shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

// Shader de Folhagem e Grama Pixel-Art (Normal Trick)
// Modificado com NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
// para que as lâminas/planos de grama recebam iluminação idêntica ao solo subjacente.

uniform vec4 albedo_color : source_color = vec4(0.28, 0.60, 0.22, 1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, hint_default_white;
uniform vec4 shadow_tint : source_color = vec4(0.15, 0.12, 0.28, 1.0);
uniform int light_bands : hint_range(2, 6) = 3;
uniform float dither_spread : hint_range(0.0, 0.5) = 0.12;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0) = 0.5;

// Matriz de Bayer 4x4 normalizada
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
	ALBEDO = albedo_color.rgb * tex.rgb;
	ALPHA = tex.a * albedo_color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;

	// Normal Trick: força a normal a apontar para o teto (mundo Y up) no espaço de visão
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void light() {
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float raw_light = NdotL * ATTENUATION;

	float dither = bayer4x4(FRAGCOORD.xy) * dither_spread;
	float stepped_light = floor((raw_light + dither) * float(light_bands)) / float(light_bands - 1);
	stepped_light = clamp(stepped_light, 0.0, 1.0);

	vec3 shaded_color = mix(ALBEDO * shadow_tint.rgb, ALBEDO * LIGHT_COLOR / PI, stepped_light);
	DIFFUSE_LIGHT += shaded_color;
}

