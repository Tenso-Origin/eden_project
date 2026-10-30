# SYSTEM RULE: Sistema de Chuva, Respingos e Superfícies Molhadas (Estética HD Pixel Art)

Você é um Engenheiro Técnico de Arte 3D e Shaders operando o **Blender MCP** e o **Godot 4**. Sempre que o usuário solicitar **efeitos de chuva, superfícies molhadas, poças d'água, respingos (splashes) ou preparação de assets para clima chuvoso**, você DEVE aplicar este protocolo em duas frentes: **Preparação de Geometria/Vértices no Blender** e **Shaders de Impacto no World-Space no Godot**.

---

## 1. Como Funciona o Visual de Chuva em HD Pixel Art (A Técnica)
Para que as gotas pareçam realmente cair *sobre* os objetos tridimensionais da paisagem (e não apenas como uma animação 2D na frente da câmera), o efeito é dividido em 4 camadas matemáticas:

1. **Anéis de Impacto no Espaço do Mundo (`World-Space XZ Ripples`):**
   * O shader de superfície divide o plano horizontal do mundo ($X, Z$) em células de grade alinhadas aos texels do mapa (ex: células de `0.25m x 0.25m`, alinhadas ao grid de `1x1x1m`).
   * Dentro de cada célula, um anel pixelado nasce em um ponto pseudo-aleatório, expande seu raio ao longo do tempo (`TIME`) e desaparece.
   * **Filtro de Direção:** Os anéis só são desenhados onde a normal da superfície no espaço do mundo aponta para cima ($WorldNormal_Y > 0.65$). Se a superfície for inclinada, o anel deforma seguindo a perspectiva 3D real do objeto!
2. **Escorrimento nas Laterais (`Vertical Wall Streaks`):**
   * Onde a superfície é vertical ($|WorldNormal_Y| \le 0.65$), como paredões de rocha, troncos ou blocos de subsolo, os anéis dão lugar a trilhas verticais pixeladas que deslizam no eixo $-Y$ do mundo.
3. **Física Óptica da Água (`Porous Wetness & Rim Glint`):**
   * Objetos secos têm cores mais claras e foscas. Quando `rain_intensity > 0`, materiais porosos (terra, pedra, casca de árvore) **escurecem em 25% a 40%** e aumentam levemente a saturação.
   * Quinas voltadas para cima ganham um brilho especular quantizado (1 degrau sólido de *highlight* branco-azulado) simulando a película de água refletindo o céu.
4. **Reação Mecânica nas Folhas (`Raindrop Impulse`):**
   * A vegetação usa o atributo `WeatherData` (Canal G = ponta da folha, Canal B = semente aleatória, Canal A = exposição ao céu) para dar pequenos "solavancos" rápidos para baixo (`step/fract` de alta frequência), imitando o peso das gotas batendo nas folhas.

---

## 2. Regras de Preparação dos Assets no Blender MCP (Grid 1x1x1m)

Sempre que criar ou adaptar um asset no Blender via `execute_blender_code` para suportar chuva rica:

1. **Máscara de Abrigo e Acúmulo de Água (`WeatherData` no Canal A):**
   * Todo objeto (seja solo, rocha ou planta) pode conter o atributo de cor de vértice `WeatherData`.
   * **Canal A (Exposição à Chuva / Poças):**
     * `A = 1.0`: Topo totalmente exposto à chuva e depressões/cavidades em blocos de solo e rocha onde a água empoça.
     * `A = 0.5`: Paredes laterais onde a água escorre.
     * `A = 0.0`: Áreas abrigadas (embaixo de saliências de rocha, interior de cavernas, face inferior de troncos e raízes). O shader do Godot usa `A = 0.0` para bloquear respingos em locais cobertos!
2. **Micro-Bacias para Poças Reais em Blocos de Solo/Rocha:**
   * Ao gerar blocos de solo, lama ou pedra de `1x1x1m`, crie uma depressão côncava interna de `0.02m` a `0.04m` no centro do tile ($Z \approx 0.96m$ enquanto a borda fica em $Z = 1.00m$) e pinte esses vértices com `WeatherData.a = 1.0`. No Godot, isso cria poças d'água reflexivas que reagem a cada pingo!
3. **Malha de Respingo Físico (`Splash Crown / Rain Particle Mesh`):**
   * Para partículas físicas de chuva (`GPUParticles3D`), gere no Blender duas micro-malhas low-poly sem textura:
     * `RainStreak_Mesh`: Um prisma triangular vertical ultra-fino (`0.02m x 0.02m x 0.45m`) com origem no centro.
     * `RainSplash_Crown`: Uma pequena coroa cônica aberta de 4 pontas (`0.12m x 0.12m x 0.08m`) com `Shade Flat` para ser instanciada no chão quando a partícula colide.

---

## 3. Script Python (`bpy`) para Preparar Qualquer Asset ou Gerar Malhas de Chuva no Blender MCP

Use este script no Blender MCP para injetar automaticamente a máscara de exposição à chuva e poças em qualquer conjunto de objetos selecionados, além de criar os modelos 3D das gotas e respingos:

```python
import bpy
import bmesh
from mathutils import Vector

def bake_rain_exposure_on_object(obj):
    """Calcula exposição à chuva (topo vs áreas abrigadas) e grava em WeatherData.a"""
    if obj.type != 'MESH':
        return
    mesh = obj.data
    
    if "WeatherData" not in mesh.color_attributes:
        mesh.color_attributes.new(name="WeatherData", type='BYTE_COLOR', domain='CORNER')
        
    weather_layer = mesh.color_attributes["WeatherData"].data
    
    for poly in mesh.polygons:
        # No Blender, +Z é para cima.
        up_dot = poly.normal.z
        if up_dot > 0.65:
            # Face voltada para o céu (recebe anéis de impacto e poças)
            rain_mask = 1.0
        elif up_dot > -0.15:
            # Face lateral (recebe escorrimento vertical)
            rain_mask = 0.5
        else:
            # Face voltada para baixo / abrigada (seca)
            rain_mask = 0.0
            
        for loop_idx in poly.loop_indices:
            old_col = weather_layer[loop_idx].color
            # Preserva R, G, B (usados para vento na vegetação) e atualiza o A (Chuva)
            weather_layer[loop_idx].color = (old_col[0], old_col[1], old_col[2], rain_mask)

def create_rain_particle_meshes():
    """Cria as malhas 3D de Gota (Streak) e Coroa de Respingo (Splash) em escala 1x1x1m"""
    # 1. Gota Alongada 3D (Rain Streak)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=3, radius1=0.015, radius2=0.002, depth=0.45)
    mesh_streak = bpy.data.meshes.new("FX_RainStreak_Mesh")
    bm.to_mesh(mesh_streak)
    bm.free()
    obj_streak = bpy.data.objects.new("FX_RainStreak", mesh_streak)
    bpy.context.collection.objects.link(obj_streak)
    
    # 2. Coroa de Respingo 3D (Splash Crown para Pixel Art)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=4, radius1=0.02, radius2=0.09, depth=0.07)
    for f in bm.faces:
        f.smooth = False
    mesh_splash = bpy.data.meshes.new("FX_RainSplash_Mesh")
    bm.to_mesh(mesh_splash)
    bm.free()
    obj_splash = bpy.data.objects.new("FX_RainSplash", mesh_splash)
    obj_splash.location.x = 0.5
    bpy.context.collection.objects.link(obj_splash)
```

---

## 4. Shader Unificado de Superfície com Impacto de Chuva no Godot 4 (`pixel_rain_surface.gdshader`)

Este shader evolui o `pixel_surface.gdshader`. Ele lê a cor do Blender (`COLOR`), aplica o **Toon Shading com Bayer Dithering**, escurece a superfície quando molhada, desenha os **anéis de impacto de gotas em World-Space XZ** no topo dos objetos, **trilhas de água escorrendo** nas laterais e faz as **folhas tremerem** sob impacto de gotas!

```glsl
shader_type spatial;
render_mode diffuse_toon, specular_disabled;

group_uniforms SurfacePalette;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform vec4 shadow_tint : source_color = vec4(0.15, 0.12, 0.28, 1.0);
uniform int light_bands : hint_range(2, 6) = 3;
uniform float dither_spread : hint_range(0.0, 0.5) = 0.12;
uniform float porosity : hint_range(0.0, 1.0) = 0.7; // Quanto o material escurece ao molhar

group_uniforms RainAndWeather;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.85;
uniform float ripple_density : hint_range(1.0, 20.0) = 6.0; // Células de gotas por metro (1x1m)
uniform float ripple_speed : hint_range(1.0, 10.0) = 3.5;
uniform vec3 ripple_color : source_color = vec3(0.75, 0.88, 1.0);
uniform bool is_foliage = false;
uniform float wind_strength : hint_range(0.0, 1.0) = 0.25;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec4 v_vertex_col;

// Hash pseudo-aleatório 2D rápido para posicionar as gotas no grid do mundo
vec2 hash22(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

// Matriz de Bayer 4x4 para manter o estilo Pixel Art clássico
float bayer4x4(vec2 screen_pos) {
	int x = int(mod(screen_pos.x, 4.0));
	int y = int(mod(screen_pos.y, 4.0));
	const int bayer[16] = int[](
		 0,  8,  2, 10,
		12,  4, 14,  6,
		 3, 11,  1,  9,
		15,  7, 13,  5
	);
	return (float(bayer[y * 4 + x]) / 16.0) - 0.5;
}

// Calcula os anéis pixelados de impacto de gota no plano XZ do mundo
float compute_rain_ripples(vec2 world_xz, float time) {
	// Quantiza a coordenada do mundo para manter estética de pixels nítidos (ex: 32 texels por metro)
	vec2 pixelated_xz = floor(world_xz * 32.0) / 32.0;
	vec2 grid_uv = pixelated_xz * ripple_density;
	vec2 cell_id = floor(grid_uv);
	vec2 cell_uv = fract(grid_uv) - 0.5;
	
	vec2 rand = hash22(cell_id);
	// Desloca o centro da gota dentro da célula
	vec2 drop_center = (rand - 0.5) * 0.5;
	
	// Fase temporal única para cada gota
	float t = fract(time * ripple_speed + rand.x * 6.2831 + rand.y * 3.1415);
	
	float dist = length(cell_uv - drop_center);
	float current_radius = t * 0.45;
	
	// Cria um anel nítido de 1 texel de espessura que some no fim do ciclo
	float ring_thickness = 0.06;
	float ring = step( abs(dist - current_radius), ring_thickness ) * (1.0 - t);
	
	// Ponto central branco no instante exato em que a gota toca o chão (t < 0.15)
	float splash_core = step(dist, 0.07) * step(t, 0.15);
	
	// Só ativa uma fração das células dependendo da intensidade da chuva
	float active_cell = step(1.0 - rain_intensity, fract(rand.x + rand.y));
	return clamp((ring + splash_core) * active_cell, 0.0, 1.0);
}

// Calcula o escorrimento vertical nas faces laterais (paredes/pedras/troncos)
float compute_wall_streaks(vec3 world_pos, float time) {
	vec2 p = floor(vec2(world_pos.x + world_pos.z, world_pos.y) * 24.0) / 24.0;
	float col_hash = hash22(vec2(floor(p.x * 8.0), 0.0)).x;
	float drop_y = fract(p.y * 1.5 + time * (ripple_speed * 0.6) + col_hash * 10.0);
	float streak = step(0.92, drop_y) * step(1.0 - rain_intensity * 0.7, col_hash);
	return streak * 0.5;
}

void vertex() {
	v_vertex_col = COLOR;
	
	// Se for vegetação, aplica balanço de vento + "beliscão" vertical de gotas batendo nas folhas
	if (is_foliage) {
		float phase = COLOR.b * 6.2831;
		// Vento contínuo
		float sway = sin(TIME * 2.5 + phase) * wind_strength * 0.12;
		VERTEX.x += sway;
		
		// Impacto rápido de gota de chuva puxando a ponta da folha para baixo
		if (rain_intensity > 0.05) {
			float drop_hit = pow( max(0.0, sin(TIME * 14.0 + phase * 3.7)), 12.0 );
			VERTEX.y -= drop_hit * 0.035 * rain_intensity;
		}
	}
	
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// 1. Cor base vinda do Atributo de Vértice do Blender (AlbedoCol)
	vec3 base_albedo = v_vertex_col.rgb * albedo_tint.rgb;
	
	// 2. Escurecimento físico de material poroso quando molhado
	float wetness = rain_intensity * porosity;
	base_albedo = mix(base_albedo, base_albedo * 0.62, wetness);
	
	// 3. Avaliação de Superfície Superior vs Lateral no World-Space
	float up_factor = clamp(v_world_normal.y, 0.0, 1.0);
	float ripple_mask = 0.0;
	
	if (rain_intensity > 0.01) {
		if (up_factor > 0.65) {
			// Topo do bloco/pedra/folha: Desenha os anéis de impacto das gotas!
			ripple_mask = compute_rain_ripples(v_world_pos.xz, TIME);
		} else if (up_factor > 0.05) {
			// Lateral do bloco/pedra: Desenha gotas escorrendo verticalmente!
			ripple_mask = compute_wall_streaks(v_world_pos, TIME);
		}
	}
	
	// Mistura o brilho da gota/anel na cor final do pixel
	ALBEDO = mix(base_albedo, ripple_color, ripple_mask * 0.75);
}

void light() {
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float raw_light = NdotL * ATTENUATION;
	
	// Dithering 4x4 clássico
	float dither = bayer4x4(FRAGCOORD.xy) * dither_spread;
	float stepped_light = floor((raw_light + dither) * float(light_bands)) / float(light_bands - 1);
	stepped_light = clamp(stepped_light, 0.0, 1.0);
	
	// Reflexo especular duro (1px Rim/Glint) apenas quando a superfície está molhada
	float wet_glint = 0.0;
	if (rain_intensity > 0.2 && v_world_normal.y > 0.4) {
		vec3 half_vec = normalize(LIGHT + VIEW);
		float spec = pow(max(dot(NORMAL, half_vec), 0.0), 32.0);
		wet_glint = step(0.75, spec * ATTENUATION) * rain_intensity * 0.35;
	}
	
	vec3 shaded_color = mix(ALBEDO * shadow_tint.rgb, ALBEDO * LIGHT_COLOR / PI, stepped_light);
	DIFFUSE_LIGHT += shaded_color + (LIGHT_COLOR * wet_glint);
}
```

---

## 5. Configuração da Chuva Caindo e Colidindo no Godot 4 (`GPUParticles3D`)

Para fechar o efeito com gotas caindo no ar e explodindo APENAS nas superfícies desabrigadas do seu mapa:

1. **Colisão Real por Altura de Pixel (`GPUParticlesCollisionHeightField3D`):**
   * Adicione um nó `GPUParticlesCollisionHeightField3D` como filho do seu mapa (ou acompanhe o `CameraPivot`).
   * Defina o `Resolution` para `1024` e `Update Mode` para `When Moved`. Ele lê automaticamente toda a geometria 3D gerada no Blender (árvores, telhados, pedras) de cima para baixo, impedindo que a chuva atravesse objetos!
2. **Emissor Principal (`RainDrops_Particles`):**
   * Use a malha `FX_RainStreak` gerada pelo script do Blender.
   * No `ParticleProcessMaterial`, ative **`Collision -> Mode: Hide On Contact`** e conecte um **Sub-Emitter (`FX_RainSplash`)** no modo `At Collision (1 particle)`.
   * Assim, toda vez que o risco 3D da gota tocar uma pedra, folha ou o chão do mapa, ele desaparece e instancia a pequena coroa low-poly (`FX_RainSplash`) por `0.12` segundos, que será contornada automaticamente pelo seu `pixel_outline.gdshader`!