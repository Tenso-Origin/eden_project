# SYSTEM RULE: Padrão Canônico Inviolável HD Pixel Art 3D (64 PPU / 64 Texels/m / Câmera 10m)

**Status:** LEI SUPREMA E IMUTÁVEL ("Escrito em Rocha")  
**Escopo:** Todo o ecossistema do projeto (`eden_project`, `cenarios_hd_pixelart_3d`, `pipeline_3d`, Blender MCP e Shaders Godot 4).

---

## 1. Fundamentos Matemáticos Canônicos

Todo cálculo espacial, resolução de viewport, densidade de textura e projeção de câmera DEVE obedecer estritamente à matriz matemática unificada abaixo:

| Parâmetro | Valor Canônico | Descrição Técnica |
| :--- | :---: | :--- |
| **Grade Modular Base** | `1.0m x 1.0m x 1.0m` | Cubo unitário do mundo 3D |
| **Densidade Global (PPU & Texels)** | **`64.0` PPU = `64.0` Texels/m** | $1\text{ pixel na tela} = 1\text{ texel na textura} = 0.015625\text{ m}$ ($1.5625\text{ cm}$) |
| **Resolução Base SubViewport** | **`1138 x 640`** | Proporção 16:9 cravada em 640px verticais |
| **SubViewport Buffer (+2px margem)** | **`1140 x 642`** | 2 pixels de segurança para subpixel offset do `subpixel_upscale.gdshader` |
| **Tamanho Ortográfico Canônico (1x)** | **`camera.size = 10.0`** | $\frac{640\text{ px}}{10.0\text{ m}} = 64.0\text{ px/m}$ exatos (proporção 1:1 perfeita) |

---

## 2. Tabela de Zoom Canônico (Apenas Potências de 2)

É **terminantemente proibido** utilizar valores fracionários arbitrários (como `7.2`, `9.5`, `18.0`, `48.0` ou dízimas periódicas) que quebrem a paridade 1:1 entre pixels da tela e texels do mundo. Apenas os degraus potências de 2 são permitidos:

| Nível de Zoom | `camera.size` | PPU Resultante | Proporção Pixel : Texel | Escopo de Aplicação |
| :---: | :---: | :---: | :---: | :--- |
| **Zoom 2x** | `5.0 m` | `128.0 px/m` | $2\times 2$ px na tela = $1$ texel | Close-up de combate, inspeção de itens, inventário |
| **Zoom 1x (Padrão)** | **`10.0 m`** | **`64.0 px/m`** | **$1\times 1$ px na tela = $1$ texel (1:1)** | Gameplay padrão, exploração local, biomas e dioramas |
| **Zoom 0.5x** | `20.0 m` | `32.0 px/m` | $1$ px na tela = $2\times 2$ texels | Cenas médias 16x16, hidrologia com bacias e corredeiras |
| **Zoom 0.25x** | `40.0 m` | `16.0 px/m` | $1$ px na tela = $4\times 4$ texels | Macrovisão, mundo procedural aberto, grandes vales |

---

## 3. Sincronia Geométrica de Malhas no Blender MCP

Para evitar *mixels* (pixels de tamanhos divergentes) ou desalinhamento com os shaders:
1. **Solo Orgânico e Rochas (`8x8` subdivisões por metro):**
   * Cada face subdividida ($0.125\text{ m} \times 0.125\text{ m}$) contém exatamente **`8 x 8` texels**.
2. **Lâmina d'Água (`16x16` subdivisões por metro):**
   * Cada face subdividida ($0.0625\text{ m} \times 0.0625\text{ m}$) contém exatamente **`4 x 4` texels**.
3. **Quantização de Shaders (`pixel_grid_density = 64.0`):**
   * Todos os shaders com quantização espacial (`pixel_water.gdshader`, `pixel_waterfall.gdshader`, `pixel_water_surface.gdshader`) DEVEM utilizar obrigatoriamente:
     ```glsl
     uniform float pixel_grid_density : hint_range(8.0, 128.0) = 64.0; // 64 Texels por metro
     ```

---

## 4. Pipeline de Personagens e Humanoides (Rig 5 Cabeças)

1. **Escala Canônica:** $1.0\text{ Head Unit (1.0H)} = 1.0\text{ metro}$ no espaço 3D.
2. **Densidade de Textura Obrigatória:** **`64 texels por Head Unit / metro (1.0H = 64 texels)`**.
3. **Adulto Padrão (5 Cabeças = 5.0m):**
   * Ocupa exatos $5 \times 64 = 320$ texels verticais no atlas e na renderização da visão ortográfica.
   * Elimina completamente qualquer discrepância de resolução entre personagens, equipamentos, solo e água.

