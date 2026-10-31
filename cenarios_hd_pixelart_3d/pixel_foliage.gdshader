shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_disabled;

// Shader de Folhagem e Grama Pixel-Art (David Holland Normal Trick)
// Transição suave entre bandas de luz com smoothstep(0.35, 0.65, frac) sem quadriculado Bayer.
// Suporta corte de geometria submersa para a ReflectionCamera planar.

uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest, hint_default_white;
uniform vec4 shadow_tint : source_color = vec4(0.12, 0.10, 0.24, 1.0);
uniform int light_bands : hint_range(2, 6) = 3;
uniform float dither_spread : hint_range(0.0, 0.5) = 0.0;
uniform float water_cutoff_y = 0.0;

group_uniforms WindAnimation;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.35;
uniform float wind_speed : hint_range(0.5, 6.0) = 2.5;

varying float v_world_y;

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

void vertex() {
	v_world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	
	// Balanço do vento usando o peso no canal Alpha de COLOR
	float phase = VERTEX.x * 4.0 + VERTEX.z * 3.0;
	float sway = sin(TIME * wind_speed + phase) * wind_strength * 0.09 * COLOR.a;
	VERTEX.x += sway;
	VERTEX.z += sway * 0.35;
}

void fragment() {
	// Se estiver sendo renderizado pela ReflectionCamera (olhando de baixo para cima) e abaixo do nível da água, corta!
	if (INV_VIEW_MATRIX[1].y < 0.0 || (INV_VIEW_MATRIX * vec4(0.0, 0.0, -1.0, 0.0)).y > 0.0) {
		if (v_world_y < water_cutoff_y) {
			discard;
		}
	}

	vec4 tex = texture(albedo_texture, UV);
	
	vec3 height_tint = mix(vec3(0.78, 0.88, 0.72), vec3(1.12, 1.18, 0.95), clamp(COLOR.a, 0.0, 1.0));
	ALBEDO = albedo_color.rgb * tex.rgb * COLOR.rgb * height_tint;

	// Normal Trick do David Holland
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void light() {
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float raw_light = NdotL * ATTENUATION;

	float scaled_light = raw_light * float(light_bands - 1);
	float band_idx = floor(scaled_light);
	float frac = fract(scaled_light);
	float smooth_frac = smoothstep(0.35, 0.65, frac);

	float dither = (dither_spread > 0.0) ? (bayer4x4(FRAGCOORD.xy) * dither_spread) : 0.0;
	float stepped_light = clamp((band_idx + smooth_frac + dither) / float(light_bands - 1), 0.0, 1.0);

	vec3 shaded_color = mix(ALBEDO * shadow_tint.rgb, ALBEDO * LIGHT_COLOR / PI, stepped_light);
	DIFFUSE_LIGHT += shaded_color;
}
