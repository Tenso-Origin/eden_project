shader_type spatial;
render_mode diffuse_toon, specular_disabled;

// Shader de Metais Cromados e Cristais Luminosos (HD Pixel Art)
// Bandas metálicas quantizadas de alto contraste + Screen-Space Mirror + Emissão suave

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

group_uniforms MetalProperties;
uniform vec4 metal_base_color : source_color = vec4(0.35, 0.95, 0.78, 1.0); // Verde-água luminoso
uniform vec4 metal_dark_band : source_color = vec4(0.08, 0.45, 0.42, 1.0);
uniform vec4 metal_highlight : source_color = vec4(0.92, 1.0, 0.96, 1.0);
uniform float mirror_reflectivity : hint_range(0.0, 1.0) = 0.45;
uniform float emission_energy : hint_range(0.0, 2.0) = 0.35;
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
	float horizon_band = ref_vec.y;
	vec3 chrome_color = base_tint;
	
	if (horizon_band > 0.45) {
		chrome_color = mix(base_tint, metal_highlight.rgb, 0.65);
	} else if (horizon_band > 0.05) {
		chrome_color = base_tint;
	} else if (horizon_band > -0.25) {
		chrome_color = metal_dark_band.rgb;
	} else {
		chrome_color = base_tint * 0.75;
	}
	
	// 2. Reflexo da Cena Alinhado ao Pixel
	vec2 n_offset = round(NORMAL.xy * 4.0) * texel_size;
	vec2 ref_uv = is_horizontal_mirror_floor 
		? vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y) + n_offset 
		: SCREEN_UV + n_offset;
	ref_uv = clamp(ref_uv, texel_size, 1.0 - texel_size);
	
	vec3 scene_reflection = texture(screen_texture, ref_uv).rgb;
	
	ALBEDO = mix(chrome_color, scene_reflection * base_tint, mirror_reflectivity);
	// Emissão suave para brilho interno do cristal
	EMISSION = metal_base_color.rgb * emission_energy;
}

void light() {
	vec3 half_vec = normalize(LIGHT + VIEW);
	float NdotH = max(dot(NORMAL, half_vec), 0.0);
	float NdotL = max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION;
	
	float stepped_diffuse = floor(NdotL * 3.0) / 2.0;
	float hard_glint = step(0.90, pow(NdotH, 16.0) * ATTENUATION);
	
	vec3 lit_metal = mix(ALBEDO * metal_dark_band.rgb, ALBEDO * LIGHT_COLOR / PI, stepped_diffuse);
	DIFFUSE_LIGHT += lit_metal + (metal_highlight.rgb * hard_glint * 0.85);
}
