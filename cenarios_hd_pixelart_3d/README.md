# Pipeline de Cenários HD Pixel Art 3D (David Holland Architecture)

Este módulo implementa a arquitetura de renderização **HD Pixel Art 3D** para Godot 4 (Forward+), eliminando de forma matemática o "pixel creep" (cintilação/tremedeira de pixels) em câmeras ortográficas durante o movimento, inspirado nas técnicas desenvolvidas por **David Holland**.

---

## 🏛️ Os Três Pilares da Arquitetura

1. **Câmera Ortográfica com Texel Snapping + Compensação Sub-pixel**:
   - A `Camera3D` trava matematicamente a sua posição nos eixos $X$ e $Y$ do espaço de visão (*view space*) à grade discreta de texels da resolução interna alvo (ex: 480×270).
   - O resíduo fracionário do movimento (erro sub-pixel entre $-0.5$ e $+0.5$ texels) é repassado como parâmetro uniforme (`cam_offset`) para o shader 2D do `SubViewportContainer`.
   - O shader do container translada as UVs em frações exatas de pixel sobre uma margem de segurança de **2 pixels extras** ($482 \times 272$), garantindo um deslize contínuo sem amassar ou deformar pixels.

2. **Post-Process de Contornos 1px (Depth + Normal Buffer)**:
   - Um `MeshInstance3D` com `QuadMesh` 2×2 atrelado à câmera projeta-se diretamente no *Clip Space* (`POSITION = vec4(VERTEX.xy, 1.0, 1.0)`).
   - O shader lê `depth_texture` e `normal_roughness_texture` com amostragem em cruz (4 vizinhos a 1 texel de distância).
   - **Silhueta Externa**: Descontinuidade de profundidade modulada pelo ângulo rasante (evitando artefatos em pisos).
   - **Vincos Internos (Creases)**: Descontinuidade de normais com viés direcional (simulando luz de topo nas quinas convexas).

3. **Toon Shading / Iluminação Discreta com Matriz Bayer 4×4**:
   - Degraus discretos de cel-shading em faixas sólidas de luz.
   - Matriz clássica de Bayer 4×4 aplicada nas transições de sombra para recriar o visual autêntico de 16/32-bits.
   - Sombra com tom frio/azulada configurável via `shadow_tint`.

---

## 📁 Estrutura de Arquivos Criados

| Arquivo | Tipo | Descrição |
| :--- | :--- | :--- |
| [`pixel_camera.gd`](file:///d:/Tenso/Documents/eden_project/cenarios_hd_pixelart_3d/pixel_camera.gd) | GDScript | Script anexado à `Camera3D` para cálculo de Texel Snapping e erro sub-pixel. |
| [`subpixel_upscale.gdshader`](file:///d:/Tenso/Documents/eden_project/cenarios_hd_pixelart_3d/subpixel_upscale.gdshader) | CanvasItem Shader | Shader aplicado no `SubViewportContainer` que compensa o erro sub-pixel e corta a borda de 1px. |
| [`pixel_outline.gdshader`](file:///d:/Tenso/Documents/eden_project/cenarios_hd_pixelart_3d/pixel_outline.gdshader) | Spatial Shader | Shader pós-processamento de bordas 1px e vincos convexos via buffers lineares de profundidade e normais. |
| [`pixel_surface.gdshader`](file:///d:/Tenso/Documents/eden_project/cenarios_hd_pixelart_3d/pixel_surface.gdshader) | Spatial Shader | Shader de superfície para blocos, construções e terreno com Bayer dither e cel shading. |
| [`pixel_foliage.gdshader`](file:///d:/Tenso/Documents/eden_project/cenarios_hd_pixelart_3d/pixel_foliage.gdshader) | Spatial Shader | Shader especializado para gramas e folhagens com o *Normal Trick* (`NORMAL = (VIEW_MATRIX * vec4(0, 1, 0, 0)).xyz`). |
| [`pixel_rain_surface.gdshader`](file:///d:/Tenso/Documents/eden_project/cenarios_hd_pixelart_3d/pixel_rain_surface.gdshader) | Spatial Shader | Superfície sob chuva: anéis de impacto no XZ do mundo, escorrimento em paredes, escurecimento de umidade e tremer de folhas. |
| [`pixel_water.gdshader`](file:///d:/Tenso/Documents/eden_project/cenarios_hd_pixelart_3d/pixel_water.gdshader) | Spatial Shader | Água e rios: ondas quantizadas, anéis de espuma de profundidade linear (Depth Ripples), cáusticas e reflexo espelhado. |
| [`pixel_metal_mirror.gdshader`](file:///d:/Tenso/Documents/eden_project/cenarios_hd_pixelart_3d/pixel_metal_mirror.gdshader) | Spatial Shader | Metais cromados Toon e pisos espelhados com bandas de horizonte quantizadas e reflexo screen-space pixel-snapped. |
| [`camera_pivot_controller.gd`](file:///d:/Tenso/Documents/eden_project/cenarios_hd_pixelart_3d/camera_pivot_controller.gd) | GDScript | Controlador de movimento do `CameraPivot` (WASD para mover, Q/E para girar, R/F para altura). |
| [`pixel_art_scene.tscn`](file:///d:/Tenso/Documents/eden_project/cenarios_hd_pixelart_3d/pixel_art_scene.tscn) | PackedScene | Cena completa montada com a hierarquia canônica pronta para execução. |
| [`project.godot`](file:///d:/Tenso/Documents/eden_project/cenarios_hd_pixelart_3d/project.godot) | Project Config | Configuração de Forward+, Hard Shadows, Nearest filtering e resolução base. |
| [`blender_scripts/`](file:///d:/Tenso/Documents/eden_project/cenarios_hd_pixelart_3d/blender_scripts) | Python Scripts | Scripts de automação `bpy` para geração e preparação modular 1x1x1m no Blender MCP. |

---

## 📜 Regras do Sistema Integradas (`.agents/rules/`)

As seguintes diretrizes canônicas para o Blender MCP e Godot 4 estão ativas no projeto:
- [**Solos e Subsolos Modulares**](file:///d:/Tenso/Documents/eden_project/.agents/rules/regras_de_solos_e_subsolos_blender_mcp.md): Bounding box 1x1x1m, trava de vértices de borda (seamless), estratificação geológica e pigmentação `AlbedoCol`.
- [**Minérios, Cristais e Rochas**](file:///d:/Tenso/Documents/eden_project/.agents/rules/regras_de_minerios_e_rochas_blender_mcp.md): Geometria hard-edge/bisect, pepitas e cristais salientes (>=0.06m) para depth-outline e múltiplos slots de material.
- [**Vegetação e Folhagem**](file:///d:/Tenso/Documents/eden_project/.agents/rules/regras_de_vegetacao_e_folhagem_blender_mcp.md): Clusters sólidos sem alpha sujo, split normals manipuladas e canal `WeatherData` (vento, tremor e chuva).
- [**Chuva e Efeitos Climáticos**](file:///d:/Tenso/Documents/eden_project/.agents/rules/regras_de_chuva_e_efeitos_climaticos_blender_mcp_godot.md): Anéis de impacto XZ no mundo, trilhas de escorrimento vertical, porosidade úmida e malhas de respingos (`GPUParticles3D`).
- [**Água, Ondulações e Reflexos**](file:///d:/Tenso/Documents/eden_project/.agents/rules/regras_de_agua_ondulacoes_e_reflexos_espelhados_blender_mcp_godot.md): Reconstrução de profundidade linear para espuma de contato (rochas e margens), ondas Voronoi pixel-snapped e metais cromados.

---

## 🌳 Árvore Canônica de Nós na Cena

```
Main (Control, Full Rect)
└── SubViewportContainer (Stretch: false, Filter: Nearest)
    ├── Material: subpixel_upscale.gdshader
    └── SubViewport (Size: 482x272, Snap 2D Transforms: true, MSAA 3D: Disabled)
        └── World3D (Node3D)
            ├── WorldEnvironment
            ├── MapGeometry (Node3D)
            │   ├── Ground (MeshInstance3D -> pixel_surface.gdshader)
            │   ├── Building1 (MeshInstance3D -> pixel_surface.gdshader)
            │   ├── StoneBlock (MeshInstance3D -> pixel_surface.gdshader)
            │   └── FoliageSample (MeshInstance3D -> pixel_foliage.gdshader)
            ├── DirectionalLight3D (Shadow Bias: 0.02, Shadow Blur: 0.0, Filter: Hard)
            └── CameraPivot (Node3D) <--- NÓ QUE DEVE SER MOVIMENTADO!
                └── Camera3D (Projection: Orthographic, Size: 7.0, Script: pixel_camera.gd)
                    └── PostProcessQuad (MeshInstance3D - QuadMesh 2x2, Material: pixel_outline.gdshader)
```

> [!IMPORTANT]
> **Regra de Ouro da Câmera**: Nunca aplique transformações ou movimentação diretamente no nó `Camera3D`. Toda navegação, interpolação ou rastreamento de jogador deve ser aplicado ao nó pai `CameraPivot`. O nó `Camera3D` sobrescreve sua própria posição a cada frame para alinhar-se à grade de texels.

---

## ⚙️ Configurações Críticas do Godot 4

1. **Renderizador**: Deve ser **Forward+** (`rendering/renderer/rendering_method="forward_plus"`). O renderizador Compatibility ou Mobile não expõem a textura de normais e rugosidade (`hint_normal_roughness_texture`).
2. **Sombras sem Borrão**:
   - Na `DirectionalLight3D`: `Shadow -> Blur = 0.0`.
   - Nas configurações do projeto: `Rendering -> Lights and Shadows -> Directional Shadow -> Soft Shadow Filter Quality = Hard (Fast)`.
3. **Texture Filtering**:
   - `Rendering -> Textures -> Canvas Textures -> Default Texture Filter = Nearest`.
4. **SubViewportContainer**:
   - `Stretch` **DEVE** estar marcado como `false`. Se `stretch` estiver ativado, a SubViewport não aceita o ajuste manual de resolução de $+2$ pixels de margem.

---

## 🎮 Controles de Teste na Cena (`pixel_art_scene.tscn`)

- **W / A / S / D** ou **Setas**: Mover o pivô da câmera pelo cenário no plano horizontal.
- **Q / E**: Rotacionar a câmera em torno do eixo vertical.
- **R / F**: Elevar ou abaixar a altura da câmera.

---

## 🔗 Referências

- Baseado nos princípios demonstrados por David Holland em [How my 3D PIXEL ART Camera Works](https://www.youtube.com/watch?v=LQfAGAj9oNQ).

