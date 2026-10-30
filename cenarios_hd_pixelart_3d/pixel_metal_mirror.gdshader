shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// Shader de Metais Cromados e Superfícies Espelhadas (HD Pixel Art)
// Bandas metálicas quantizadas de alto contraste + Screen-Space Mirror alinhado ao texel

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

group_uniforms MetalProperties;
uniform vec4 metal_base_color : source_color = vec4(0.75, 0.78, 0.85, 1.0); // Prata/Aço ou Ouro
uniform vec4 metal_dark_band : source_color = vec4(0.22, 0.25, 0.35, 1.0);
uniform vec4 metal_highlight : source_color = vec4(1.0, 0.98, 0.92, 1.0);
uniform float mirror_reflectivity : hint_range(0.0, 1.0) = 0.4; // 0.0 = Metal Cromado Toon, 0.8 = Espelho Puro
uniform bool is_horizontal_mirror_floor = false;

varying vec3 v_world_normal;
varying vec4 v_vertex_col;

void vertex() {
	v_vertex_col = COLOR;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 texel_size = 1.0 / VIEWPORT_SIZE;
	vec3 base_tint = metal_base_color.rgb * v_vertex_col.rgb;
	
	// 1. Cálculo do Vetor de Reflexão Estilizado (Cromado estilo 16-bits / PS1)
	vec3 ref_vec = reflect(-VIEW, NORMAL);
	// Quantiza o ângulo vertical do reflexo em 4 faixas discretas (Céu, Horizonte, Chão, Brilho)
	float horizon_band = ref_vec.y;
	vec3 chrome_color = base_tint;
	
	if (horizon_band > 0.45) {
		chrome_color = mix(base_tint, metal_highlight.rgb, 0.65); // Faixa superior clara
	} else if (horizon_band > 0.05) {
		chrome_color = base_tint; // Meio-tom metálico
	} else if (horizon_band > -0.25) {
		chrome_color = metal_dark_band.rgb; // Linha escura do horizonte típica de Pixel Art cromada!
	} else {
		chrome_color = base_tint * 0.75; // Reflexo inferior
	}
	
	// 2. Reflexo da Cena Alinhado ao Pixel (Screen-Space Mirror Quantizado)
	vec2 n_offset = round(NORMAL.xy * 4.0) * texel_size;
	vec2 ref_uv = is_horizontal_mirror_floor 
		? vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y) + n_offset 
		: SCREEN_UV + n_offset;
	ref_uv = clamp(ref_uv, texel_size, 1.0 - texel_size);
	
	vec3 scene_reflection = texture(screen_texture, ref_uv).rgb;
	
	ALBEDO = mix(chrome_color, scene_reflection * base_tint, mirror_reflectivity);
}

void light() {
	// Brilho especular ultra-duro (1 degrau) nas faces chanfradas (Bevels do Blender)
	vec3 half_vec = normalize(LIGHT + VIEW);
	float NdotH = max(dot(NORMAL, half_vec), 0.0);
	float NdotL = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION;
	
	float stepped_diffuse = floor(NdotL * 3.0) / 2.0;
	float hard_glint = step(0.92, pow(NdotH, 16.0) * ATTENUATION);
	
	vec3 lit_metal = mix(ALBEDO * metal_dark_band.rgb, ALBEDO * LIGHT_COLOR / PI, stepped_diffuse);
	DIFFUSE_LIGHT += lit_metal + (metal_highlight.rgb * hard_glint * 0.85);
}

