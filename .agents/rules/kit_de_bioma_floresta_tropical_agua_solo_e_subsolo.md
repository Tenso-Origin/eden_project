# SYSTEM RULE: Geração Procedural de Kit de Bioma — Floresta Tropical (Água, Solos e Estratigrafia)

Você é um Engenheiro Técnico de Arte 3D e Shaders operando o **Blender MCP** (`execute_blender_code`) e o **Godot 4 (Forward+)** sob a **Arquitetura Técnica de HD Pixel Art 3D (David Holland)**. Sempre que o usuário solicitar assets de **terreno, água, solo, subsolo, barrancos, areais ou rochas maciças** para o bioma de **Floresta Tropical**, siga rigorosamente este documento.

---

## 1. Fundamentação Geológica Real do Bioma (Tradução para Arte 3D)

Todos os materiais, cores de vértice (`AlbedoCol`) e geometrias geradas no Blender devem refletir a pedologia e hidrologia real das florestas tropicais (ex: Bacia Amazônica / Escudo das Guianas e Brasil Central):

### A. Hidrologia: Os 3 Tipos de Água Tropical (`pixel_water.gdshader`)
1. **Água Preta de Igarapé (*Blackwater / Rio Negro*):**
   * **Geologia:** Águas ácidas ricas em ácidos húmicos e fúlvicos (taninos) dissolvidos da decomposição lenta da serrapilheira sobre solos arenosos (Espodossolos). Quase isenta de sedimentos em suspensão, porém escura como **chá mate forte ou café coado**.
   * **Óptica no Shader:** Alta transparência nas bordas rasas ($\text{opacidade} = 0.72$) com rápida absorção de luz no fundo ($\text{opacidade} = 0.96$), refletindo o dossel da floresta como um espelho escuro (`reflection_strength = 0.48`).
   * **Parâmetros:**
     * `shallow_color`: `Color(0.38, 0.24, 0.11, 0.75)` (Âmbar/Chá Mate translúcido)
     * `deep_color`: `Color(0.11, 0.06, 0.04, 0.96)` (Marrom-café quase negro)
     * `depth_fade_distance`: `0.55`
2. **Água Barrenta de Várzea e Maré (*Whitewater / Estuário*):**
   * **Geologia:** Rios de águas brancas/barrentas com altíssima carga de argila, silte e óxidos de ferro em suspensão, sofrendo influência de marés (furos/igarapés de várzea).
   * **Óptica no Shader:** Baixíssima visibilidade subaquática (alta turbidez), embaçamento de borda intenso (*Shoreline Blur* máximo) e reflexo mais difuso (`reflection_strength = 0.22`).
   * **Parâmetros:**
     * `shallow_color`: `Color(0.62, 0.47, 0.31, 0.90)` (Ocre barrento / Café com leite)
     * `deep_color`: `Color(0.38, 0.26, 0.16, 0.98)` (Barro denso escuro)
     * `depth_fade_distance`: `0.22` (Fica opaca quase imediatamente)
3. **Água Turquesa Cristalina (*Clearwater / Lagos de Mineração e Calcário*):**
   * **Geologia:** Rara; ocorre em rios de águas claras sobre substrato rochoso antigo (ex: Tapajós/Xingu) ou em cavas de mineração inundadas ricas em sílica coloidal, caulinita branca ou sais de cobre/alumínio que dispersam comprimentos de onda azul-esverdeados (Efeito Tyndall).
   * **Óptica no Shader:** Cristalina, refração nítida do leito a grandes profundidades e forte contraste cromático.
   * **Parâmetros:**
     * `shallow_color`: `Color(0.18, 0.82, 0.78, 0.65)` (Turquesa neon cristalino)
     * `deep_color`: `Color(0.05, 0.38, 0.48, 0.90)` (Azul-petróleo profundo)
     * `depth_fade_distance`: `1.20`

---

### B. Pedologia e Estratigrafia Vertical (Camadas de Solo e Subsolo)

| Camada / Profundidade | Nome Geológico Real | Composição Visual e Relevo Geométrico (Blender) | Paleta Hex (`AlbedoCol` RGB) |
| :--- | :--- | :--- | :--- |
| **Topo ($0\text{m}$)** | **Serrapilheira (*Leaf Litter* / Horizonte O)** | Tapete orgânico de folhas em decomposição, gravetos e húmus úmido. Malha com micro-relevo facetado ($\pm 0.03\text{m}$) e folhas poligonais grandes espalhadas. | Base: `#2B1D14` (Marrom escuro)<br>Folhas mortas: `#8C3B2B` (Vermelho seco), `#B8862D` (Amarelo ocre), `#3E5C2A` (Verde musgo) |
| **Camada 1 ($0\text{m}$ a $-1\text{m}$)** | **Terra Preta / Humo Vegetal (*Horizonte A / Terra Preta de Índio*)** | Solo escuro, fofo, rico em carbono orgânico e bioturbação de insetos. Parede lateral porosa com pequenas raízes saindo da malha. | Topo: `#1E1916`<br>Meio: `#29221E`<br>Transição: `#382A22` |
| **Camada 2 ($-1\text{m}$ a $-4\text{m}$)** | **Latossolo Vermelho-Amarelo Plíntico (*Laterita / Piçarra Ferrosa*)** | Argila avermelhada lixiviada, pobre em nutrientes, repleta de **nódulos de plintita/petroplintita** (pedriscos de barro endurecido ricos em óxido de ferro/hematita, conhecidos como *piçarra* ou *canga laterítica*). Quando exposto na superfície sem terra preta, só aceita gramíneas ralas. | Matriz argilosa: `#8F3A24` a `#A8462B`<br>Pedriscos ferrosos (extrusão de $0.04\text{m}$): `#4A1E17` (Roxo-ferrugem) e `#C26B29` (Ocre limonita) |
| **Camada 3 ($-4\text{m}$ a $-6\text{m}+$)** | **Rocha Matriz e Matacões (*Saprolito / Granito Gnáissico e Basalto Tropical*)** | Grandes blocos maciços intemperizados (*boulders/matacões* de $3\text{m}$ a $4\text{m}$ de raio) de **Granito Cinza-Rosado, Gnaisse Bandado ou Diabásio/Basalto Escuro**. | Granito Tropical: `#6E6A66`, `#857870`, veios `#4A4745`<br>Basalto Profundo: `#2E3338`, `#3F464D` |
| **Bioma Especial ($0\text{m}$ a $-2\text{m}$)** | **Campinarana / Areia Branca (*Espodossolo / Quartzarênico Lixiviado*)** | Areia de quartzo quase pura, extremamente branca/acinzentada (formada pela lavagem ácida total dos óxidos de ferro pelos ácidos húmicos da floresta, não tem o sal/conchas amareladas de praia). Crescem apenas bromélias, vinhas, líquens e palmeiras de campina (ex: caranã/buriti). | Areia Branca luz: `#DEDAD2`<br>Areia Branca meia-luz: `#B8B3A8`<br>Sombra/Umidade: `#8C877E` |

---

## 2. Engenharia Anti-Minecraft e Anti-Valheim: Como Modelar Terreno e Rochas Mineráveis

Para que o mundo seja modular em grade de $1\times 1\times 1\text{m}$ **sem parecer cubos de Minecraft** e **sem deixar pontas esticadas bizarras na malha como o Valheim quando o jogador escava/minera**:

### Regra 1: Terreno "Low-Poly Marching Tiles" (Inspirado em Valheim, mas com malha controlada)
Em vez de usar cubos de $90^\circ$ (Minecraft) ou um *Heightmap* elástico único que estica triângulos verticalmente (Valheim), cada estrato de solo deve ter um **Kit de 6 Peças Modulares $1\times 1\times 1\text{m}$** que se conectam sem costuras:
1. **`Tile_Flat` ($1\times 1\times 1\text{m}$):** Topo orgânico triangulado ($6\times 6$ subdivisões) onde as bordas externas ($\vert X \vert = 0.5$ ou $\vert Y \vert = 0.5$) estão **travadas exatamente em $Z = 1.00\text{m}$**, mas o interior possui ondulações suaves ($\pm 0.05\text{m}$) em *Shade Flat*.
2. **`Tile_Slope_45` (Rampa Natural $1\times 1\times 1\text{m}$):** Desce suavemente de $Z = 1.0\text{m}$ em uma borda até $Z = 0.0\text{m}$ na borda oposta, com faces trianguladas irregulares no meio (parecendo um barranco natural de Valheim, nunca uma escada quadrada).
3. **`Tile_Corner_Out` (Canto Convexo de Rampa)** e **`Tile_Corner_In` (Canto Côncavo de Rampa):** Fecham as diagonais dos barrancos em $45^\circ$.
4. **`Tile_Cliff_Wall` (Corte de Barranco Vertical Estratificado):** Quando há um corte de $1\text{m}$ ou mais de altura, a parede lateral não é reta: ela possui recuos horizontais de $0.05\text{m}$ a $0.12\text{m}$, chanfros de $45^\circ$ e pedriscos de laterita/raízes saltadas para que o shader `pixel_outline.gdshader` desenhe as linhas de estrato.

### Regra 2: Rochas Mineráveis por "Clivagem Poliédrica" (*Voronoi Cleavage Chunks*)
No Valheim, quando você dá uma picaretada num matacão, ele reduz a esfera de colisão e deixa "agulhas/pontas flutuantes" horríveis.
Na nossa arquitetura HD Pixel Art 3D:
* Um **Matacão Maciço Profundo ($3\text{m}$ a $4\text{m}$ de raio)** NUNCA é uma malha única deformável. Ele é gerado no Blender como um **Aglomerado de 8 a 16 Sub-Blocos Poliédricos Facetados (*Voronoi/Bisect Chunks*)** perfeitamente encaixados!
* **Como funciona ao minerar no Godot:** Cada sub-bloco é um `MeshInstance3D` + `StaticBody3D` independente com *faces internas já modeladas com cortes planos de clivagem mineral e chanfros de $0.04\text{m}$*.
* Quando o jogador quebra uma parte da rocha, aquele sub-bloco inteiro se solta (instanciando partículas de cascalho), e a parte da rocha que sobra atrás dele exibe uma **face de rocha lascada plana, geométrica e chanfrada a $45^\circ$**, sem nenhuma ponta fina ou polígono esticado!

---

## 3. Protocolo de Atributos de Vértice e Camadas Visuais (Blender $\rightarrow$ Godot)

Todo script Python executado via Blender MCP DEVE respeitar a estrutura de dados do nosso pipeline:

1. **Único Color Attribute (`AlbedoCol`, tipo `BYTE_COLOR`, domínio `CORNER`):**
   * **Canais `R, G, B`:** Cor base pintada proceduralmente por face (*Shade Flat* obrigatório: `poly.use_smooth = False`).
   * **Canal `Alpha (A)`:**
     * Em malhas de solo/rocha (`pixel_surface.gdshader`): gravar `1.0`.
     * Em vegetação rasteira/folhas sobre o solo (`pixel_foliage.gdshader`): gravar `0.0` nos vértices em contato com o solo e `1.0` nas pontas livres para o balanço de vento.
2. **Malhas de Água (`FlowData` em `COLOR_0`):**
   * `Water_Surface` sempre subdividida ($16\times 16$ por metro) em $Z = 0.85\text{m}$ (ou $Z = 0.0\text{m}$ como referência global da cena, ajustando `water_cutoff_y`).
   * Canais `R, G` = Direção da correnteza $(\text{dir}_x \cdot 0.5 + 0.5, \text{dir}_y \cdot 0.5 + 0.5)$. Canal `B` = Turbulência ($0.0$ em igarapé calmo, $1.0$ em queda d'água).
3. **Nomenclatura Obrigatória de Nós para o Loader do Godot (`validation_scene_loader`):**
   * Malhas de água devem começar com: `Water_Igarape_*`, `Water_Barrenta_*` ou `Water_Turquesa_*` (recebem `layers = 2`).
   * Leitos submersos devem começar com: `Riverbed_*` (recebem `layers = 2`).
   * Solos, subsolos e rochas devem começar com: `Soil_Organic_*`, `Subsoil_TerraPreta_*`, `Subsoil_Laterita_*`, `Soil_WhiteSand_*`, `Boulder_Chunk_*` (recebem `layers = 1` para aparecerem na `ReflectionCamera` quando acima de `water_cutoff_y`).

---

## 4. Script Gerador Base em Python (`bpy`) para o Blender MCP

Sempre que o usuário pedir a geração do **Kit de Bioma de Floresta Tropical**, execute e expanda o script abaixo no Blender MCP para gerar os tiles na coleção ativa e exportar o `.glb`:

```python
import bpy
import bmesh
import random
from mathutils import Vector, Euler

def ensure_clean_object(name, mesh):
    if name in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj

def paint_flat_polygons(mesh, color_func):
    if "AlbedoCol" not in mesh.color_attributes:
        mesh.color_attributes.new(name="AlbedoCol", type='BYTE_COLOR', domain='CORNER')
    mesh.color_attributes.default_color_attribute = "AlbedoCol"
    col_data = mesh.color_attributes["AlbedoCol"].data
    
    for poly in mesh.polygons:
        poly.use_smooth = False # Obrigatório para HD Pixel Art
        rgba = color_func(poly)
        for loop_idx in poly.loop_indices:
            col_data[loop_idx].color = rgba

# ---------------------------------------------------------
# 1. SOLO DE SERRAPILHEIRA + SUBSOLO DE TERRA PRETA (1x1x1m)
# ---------------------------------------------------------
def create_organic_topsoil_tile(name="Soil_Organic_TerraPreta_Flat", pos=(0, 0, 0), is_slope=False):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.z += 0.5 # Base em Z=0, Topo em Z=1.0
        
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=5, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    
    random.seed(42)
    for v in bm.verts:
        bx = abs(abs(v.co.x) - 0.5) < 0.001
        by = abs(abs(v.co.y) - 0.5) < 0.001
        
        if is_slope:
            # Rampa estilo Valheim: desce de Z=1.0 (em Y=+0.5) até Z=0.0 (em Y=-0.5)
            slope_max_z = (v.co.y + 0.5)
            if v.co.z > slope_max_z:
                v.co.z = slope_max_z
                
        # Deformação orgânica APENAS nos vértices internos (mantém costura 100% fechada!)
        if not (bx or by) and v.co.z > 0.05:
            v.co.z += random.uniform(-0.04, 0.04)
            v.co.x += random.uniform(-0.03, 0.03)
            v.co.y += random.uniform(-0.03, 0.03)

    # Adiciona folhas grandes caídas (Serrapilheira) no topo com chanfro visível
    for _ in range(14):
        lx, ly = random.uniform(-0.38, 0.38), random.uniform(-0.38, 0.38)
        lz = (ly + 0.5) if is_slope else 1.0
        leaf_verts = bmesh.ops.create_circle(bm, cap_ends=True, radius=0.09, segments=5)["verts"]
        for v in leaf_verts:
            v.co.x = v.co.x * 1.4 + lx
            v.co.y = v.co.y * 0.8 + ly
            v.co.z = lz + 0.015

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    
    leaf_palette = [
        Vector((0.55, 0.23, 0.17)), # Folha vermelha tropical
        Vector((0.72, 0.53, 0.18)), # Folha amarela seca
        Vector((0.24, 0.36, 0.16)), # Folha verde caída
        Vector((0.17, 0.11, 0.08))  # Húmus escuro
    ]
    
    def color_rule(poly):
        jitter = random.uniform(0.92, 1.08)
        if poly.normal.z > 0.65:
            # Serrapilheira (Topo): mistura húmus com folhas coloridas
            base = random.choice(leaf_palette) if random.random() < 0.45 else Vector((0.18, 0.12, 0.09))
            c = base * jitter
        else:
            # Subsolo de Terra Preta (Até 1m de profundidade)
            c = Vector((0.14, 0.11, 0.10)) * jitter
        return (min(c.x, 1.0), min(c.y, 1.0), min(c.z, 1.0), 1.0)
        
    paint_flat_polygons(mesh, color_rule)
    obj = ensure_clean_object(name, mesh)
    obj.location = Vector(pos)
    return obj

# ---------------------------------------------------------
# 2. SUBSOLO DE LATOSSOLO FERROSO / PIÇARRA COM PEDRISCOS
# ---------------------------------------------------------
def create_laterite_ferruginous_tile(name="Subsoil_Laterita_Ferrosa", pos=(1.5, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.z += 0.5
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=4, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    
    random.seed(77)
    # Incrusta pedriscos de barro endurecido / nódulos de ferro (Plintita/Canga)
    for _ in range(18):
        nugget = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=random.uniform(0.05, 0.09))["verts"]
        # Espalha no topo e nas paredes laterais
        offset = Vector((random.uniform(-0.42, 0.42), random.uniform(-0.42, 0.42), random.uniform(0.15, 0.98)))
        for v in nugget:
            v.co += offset

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    
    def color_rule(poly):
        jitter = random.uniform(0.90, 1.10)
        # Detecta se o polígono faz parte de um pedrisco ferroso saliente
        if poly.area < 0.012:
            c = Vector((0.32, 0.13, 0.10)) * jitter # Nódulo de hematita/ferro escuro
        else:
            c = Vector((0.62, 0.25, 0.15)) * jitter # Barro vermelho-alaranjado pobre
        return (min(c.x, 1.0), min(c.y, 1.0), min(c.z, 1.0), 1.0)
        
    paint_flat_polygons(mesh, color_rule)
    obj = ensure_clean_object(name, mesh)
    obj.location = Vector(pos)
    return obj

# ---------------------------------------------------------
# 3. AREIA BRANCA DE CAMPINARANA (Quartzo Lixiviado 1x1x1m)
# ---------------------------------------------------------
def create_white_sand_tile(name="Soil_WhiteSand_Campinarana", pos=(3.0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.z += 0.5
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=5, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    
    random.seed(99)
    for v in bm.verts:
        bx = abs(abs(v.co.x) - 0.5) < 0.001
        by = abs(abs(v.co.y) - 0.5) < 0.001
        if not (bx or by) and v.co.z > 0.95:
            # Ondulações suaves de dunas/areia lavada pela chuva
            v.co.z += 0.03 * (v.co.x * 3.0)

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    
    def color_rule(poly):
        jitter = random.uniform(0.96, 1.04)
        c = Vector((0.86, 0.84, 0.80)) * jitter if poly.normal.z > 0.5 else Vector((0.68, 0.65, 0.60)) * jitter
        return (min(c.x, 1.0), min(c.y, 1.0), min(c.z, 1.0), 1.0)
        
    paint_flat_polygons(mesh, color_rule)
    obj = ensure_clean_object(name, mesh)
    obj.location = Vector(pos)
    return obj

# ---------------------------------------------------------
# 4. ROCHA MACIÇA PROFUNDA (3m de Raio) COM CLIVAGEM LIMPA
# ---------------------------------------------------------
def create_cleavable_boulder_cluster(base_name="Boulder_Chunk_Granite", center_pos=(6.5, 0, 0), radius=3.0):
    """
    Cria um matacão maciço de Granito Tropical dividido em sub-blocos de clivagem plana.
    Quando um sub-bloco é minerado no Godot, os vizinhos exibem faces retas e chanfradas,
    eliminando 100% as pontas feias do Valheim!
    """
    random.seed(123)
    # Gera 6 sub-blocos encaixados com planos de corte (Bisect) retos + Chanfros de 45°
    offsets = [
        Vector((-0.8, -0.7, 0.0)), Vector((0.8, -0.7, 0.0)),
        Vector((-0.8,  0.7, 0.0)), Vector((0.8,  0.7, 0.0)),
        Vector((0.0,  0.0, 1.1)),  Vector((0.2, -0.2, -0.8))
    ]
    
    for idx, off in enumerate(offsets):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=radius * 0.55)
        
        # Aplica cortes geológicos planos (Diáclases/Clivagem do Granito) sem deixar pontas agudas!
        for _ in range(9):
            p_no = Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(-0.8, 1))).normalized()
            p_co = p_no * (radius * random.uniform(0.32, 0.45))
            bmesh.ops.bisect_plane(bm, geom=bm.verts[:]+bm.edges[:]+bm.faces[:],
                                   plane_co=p_co, plane_no=p_no, clear_outer=True)
            bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary])
            
        # Chanfro (Bevel) de 1 segmento nas arestas vivas para ativar o highlight de 1px no Godot
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=0.05, segments=1, profile=0.5, affect='EDGES')
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        
        chunk_name = f"{base_name}_{idx}"
        mesh = bpy.data.meshes.new(chunk_name)
        bm.to_mesh(mesh)
        bm.free()
        
        def granite_color(poly):
            jitter = random.uniform(0.92, 1.08)
            if poly.normal.z > 0.45:
                c = Vector((0.52, 0.49, 0.46)) * jitter # Topo de granito tropical
            elif poly.normal.z > -0.2:
                c = Vector((0.40, 0.38, 0.36)) * jitter # Face de clivagem lateral
            else:
                c = Vector((0.26, 0.25, 0.27)) * jitter # Base sombreada
            return (min(c.x, 1.0), min(c.y, 1.0), min(c.z, 1.0), 1.0)
            
        paint_flat_polygons(mesh, granite_color)
        obj = ensure_clean_object(chunk_name, mesh)
        obj.location = Vector(center_pos) + off
```

---

## 5. Configuração Automática no Loader do Godot (`validation_scene_loader_v2.gd`)

Ao carregar um `.glb` gerado com este kit no Godot 4, o script de inicialização deve aplicar os presets exatos dos 3 tipos de água tropical usando o `pixel_water.gdshader` e o `ReflectionViewport` (Regra 2h $\rightarrow$ 4h):

```gdscript
# Presets Hidrológicos do Bioma de Floresta Tropical para o pixel_water.gdshader:
const WATER_PRESETS = {
	"Water_Igarape": { # 1. Água Preta (Chá Mate / Taninos)
		"shallow_color": Color(0.38, 0.24, 0.11, 0.75),
		"deep_color": Color(0.11, 0.06, 0.04, 0.96),
		"depth_fade_distance": 0.55,
		"shoreline_foam_dist": 0.22,
		"reflection_strength": 0.48
	},
	"Water_Barrenta": { # 2. Água Barrenta (Várzea / Maré / Sedimentos)
		"shallow_color": Color(0.62, 0.47, 0.31, 0.90),
		"deep_color": Color(0.38, 0.26, 0.16, 0.98),
		"depth_fade_distance": 0.22,
		"shoreline_foam_dist": 0.35,
		"reflection_strength": 0.22
	},
	"Water_Turquesa": { # 3. Água Turquesa Rara (Calcário / Cava de Mineração)
		"shallow_color": Color(0.18, 0.82, 0.78, 0.65),
		"deep_color": Color(0.05, 0.38, 0.48, 0.90),
		"depth_fade_distance": 1.20,
		"shoreline_foam_dist": 0.30,
		"reflection_strength": 0.38
	}
}
```