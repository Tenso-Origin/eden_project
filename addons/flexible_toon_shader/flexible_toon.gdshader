shader_type spatial;

// Flexible Toon Shader (Godot 4.x - Eden Project Custom Edition)
// Suporta:
// - Cortes/bandas estilizadas de cel shading (cuts)
// - Sombras em diferentes tons da cor do próprio objeto (use_shadow_color)
//   eliminando o escurecimento cinza escuro genérico do ambient light
// - Atenuação suave com shadow_softness e shadow_floor
// - Animação de vento opcional para folhagem e grama (use_wind)
// - Suporte a rampas de cores customizadas (use_ramp)
// - Especular escalonado (use_specular) e iluminação de borda (use_rim)

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform bool clamp_diffuse_to_max = false;

uniform int cuts : hint_range(1, 8) = 3;
uniform float wrap : hint_range(-2.0, 2.0) = 0.0;
uniform float steepness : hint_range(1.0, 8.0) = 1.5;

uniform bool use_attenuation = true;

group_uniforms ShadowTones;
## Habilita sombras ricas em tons da cor do objeto em vez de cinza escuro
uniform bool use_shadow_color = true;
## Matiz que modula o albedo na sombra (fria/azulada para contrastar com a luz solar quente)
uniform vec4 shadow_color : source_color = vec4(0.40, 0.36, 0.52, 1.0);
## Piso de luminosidade mínima dentro da sombra projetada (0.0 = preto, 0.35 = legível)
uniform float shadow_floor : hint_range(0.0, 0.6) = 0.32;
## Suavização da transição da sombra projetada para evitar shadow acne
uniform float shadow_softness : hint_range(0.0, 0.3) = 0.08;

group_uniforms SpecularAndRim;
uniform bool use_specular = true;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.4;
uniform float specular_shininess : hint_range(0.0, 32.0) = 16.0;
uniform sampler2D specular_map : source_color, filter_linear_mipmap;

uniform bool use_rim = true;
uniform float rim_width : hint_range(0.0, 16.0) = 8.0;
uniform vec4 rim_color : source_color = vec4(0.9, 0.95, 1.0, 0.4);

group_uniforms ColorRamp;
uniform bool use_ramp = false;
uniform sampler2D ramp : source_color, filter_linear_mipmap;

group_uniforms Borders;
uniform bool use_borders = false;
uniform float border_width = 0.01;

group_uniforms WindAnimation;
## Habilita balanço de vento para folhagens e vegetação
uniform bool use_wind = false;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.35;
uniform float wind_speed : hint_range(0.5, 6.0) = 2.2;

varying vec3 vertex_pos;
varying vec3 normal;

float split_specular(float specular) {
	return step(0.5, specular);
}

void vertex() {
	vertex_pos = VERTEX;
	normal = NORMAL;

	if (use_wind) {
		float phase = VERTEX.x * 4.0 + VERTEX.z * 3.0;
		float sway = sin(TIME * wind_speed + phase) * wind_strength * 0.09 * COLOR.a;
		VERTEX.x += sway;
		VERTEX.z += sway * 0.35;
	}
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	vec3 tex_rgb = (tex.a > 0.0) ? tex.rgb : vec3(1.0);
	ALBEDO = albedo.rgb * COLOR.rgb * tex_rgb;
}

void light() {
	// 1. Atenuação com suavização para prevenir shadow acne
	float attenuation = 1.0;
	if (use_attenuation) {
		attenuation = smoothstep(shadow_softness, 1.0 - shadow_softness, ATTENUATION);
	}

	// 2. Cálculo do diffuse toon com bandas escalonadas (cuts)
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float diffuse_amount = NdotL + (attenuation - 1.0) + wrap;
	diffuse_amount *= steepness;
	float cuts_inv = 1.0 / float(cuts);
	float diffuse_stepped = clamp(diffuse_amount + mod(1.0 - diffuse_amount, cuts_inv), 0.0, 1.0);

	// 3. Bordas entre bandas
	float border = 0.0;
	if (use_borders) {
		float corr_border_width = length(cross(NORMAL, LIGHT)) * border_width * steepness;
		border = step(diffuse_stepped - corr_border_width, diffuse_amount)
				 - step(1.0 - corr_border_width, diffuse_amount);
	}

	// 4. Aplicação do estilo cromático de sombra
	vec3 lit_color = ALBEDO.rgb * LIGHT_COLOR / PI;
	vec3 diffuse = lit_color;

	if (use_ramp) {
		diffuse = lit_color * texture(ramp, vec2(diffuse_stepped * (1.0 - border), 0.0)).rgb;
	} else if (use_shadow_color) {
		// --- SOMBRAS EM TONS DA PRÓPRIA COR DO OBJETO ---
		// O tom da sombra é proporcional ao ALBEDO, modulado por shadow_color e shadow_floor:
		// Em vez de escurecer para cinza ou preto, o objeto desce por degraus da sua própria cor!
		vec3 shadow_tone = ALBEDO.rgb * shadow_color.rgb;
		float shadow_mult = mix(shadow_floor, 1.0, diffuse_stepped * (1.0 - border));
		diffuse = mix(shadow_tone, lit_color, shadow_mult);
	} else {
		diffuse = lit_color * (diffuse_stepped * (1.0 - border));
	}

	if (clamp_diffuse_to_max) {
		DIFFUSE_LIGHT = max(DIFFUSE_LIGHT, diffuse);
	} else {
		DIFFUSE_LIGHT += diffuse;
	}

	// 5. Brilho especular estilizado
	if (use_specular) {
		vec3 H = normalize(LIGHT + VIEW);
		float NdotH = dot(NORMAL, H);
		float specular_amount = max(pow(NdotH, specular_shininess * specular_shininess), 0.0)
							    * texture(specular_map, UV).r
								* attenuation;
		specular_amount = split_specular(specular_amount);
		SPECULAR_LIGHT += specular_strength * specular_amount * LIGHT_COLOR;
	}

	// 6. Iluminação de borda (Rim Lighting)
	if (use_rim) {
		float NdotV = dot(NORMAL, VIEW);
		float rim_light = pow(1.0 - NdotV, rim_width);
		DIFFUSE_LIGHT += rim_light * rim_color.rgb * rim_color.a * LIGHT_COLOR / PI;
	}
}
