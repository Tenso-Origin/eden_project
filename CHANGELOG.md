# CHANGELOG — EDEN PROJECT

Todas as alterações notáveis neste projeto serão documentadas neste arquivo.
O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

---

## [0.1.0-alpha] - 2026-11-07

### Adicionado
- **Master Plan de Desenvolvimento Triple-A:** Documento mestre de arquitetura, fases graduais de entrega, governança técnica e orquestração autônoma (`eden_project_master_plan.md`).
- **Documentação Canônica Profissional (`/docs`):**
  - `docs/GDD.md`: Game Design Document completo com pilares de sobrevivência, vitals fisiológicos, mecânicas de palafita e ciclo equatorial de 365 dias.
  - `docs/TDD.md`: Technical Design Document detalhando a arquitetura dual Godot 4.7 + C# SimCore, viewport 1138×640, densidade de 64 PPU e pipeline de subpixel upscale (David Holland Architecture).
  - `docs/ART_BIBLE.md`: Bíblia de Arte com convenções visuais, paletas atmosféricas equatoriais, tamanhos de câmera restritos a potências de 2 (5, 10, 20, 40) e diretriz mandatória de rotação 180° sem espelhamento 2D.
  - `docs/BIOME_BIBLE.md`: Bíblia Científica do Bioma Floresta Tropical Úmida Amazônica baseada em dados reais (PanTHERIA, TRY, INPA), cobrindo Terra Firme, Várzeas, Igapós, Encontro das Águas e teias tróficas alométricas.
- **Ferramentas `@tool` de Otimização de Sombras:**
  - `ShadowCleaner.gd`: Script para desativação em lote de sombras em malhas filhas, preservando nós essenciais com sufixo `_ShadowCaster`.
  - `ShadowProxyGenerator.gd`: Gerador procedural de malhas combinadas via `SurfaceTool` configuradas para projeção exclusiva de sombra (`SHADOW_CASTING_SETTING_SHADOWS_ONLY`).
- **Estratégia de Branching GitFlow:** Inicialização da branch `develop` como tronco ativo de integração e releases na `main`.

### Corrigido
- **Eliminação de Shadow Acne ao Meio-Dia:**
  - Refatoração da função `light()` em `pixel_surface.gdshader`, desacoplando o cálculo de bandas toon de luz direta ($N \cdot L$) do shadow map (`ATTENUATION`).
  - Implementação de atenuação com interpolação suave (`smoothstep`) e piso mínimo de iluminação (`shadow_floor = 0.35`) para preservar a leitura de texturas sob sombras longas.
- **Correção de Contornos Indevidos em Terreno Modular:**
  - Calibração de `normal_threshold` em `pixel_outline.gdshader` (ajustado de 0.38 para 0.72) na cena procedural, eliminando linhas brancas espúrias entre blocos adjacentes de 1×1m.
- **Prevenção de Gimbal Lock Solar:**
  - Migração de rotações Euler para Quatérnions combinados ($\mathbf{q}_x \times \mathbf{q}_z$) em `day_night_cycle_controller.gd` e `sun_directional_light.gd` com ângulo azimutal de 10° (`ZENITH_OFFSET_ANGLE`).
  - Desligamento inteligente de luz à noite (`visible = false`, `energy = 0.0`) para alívio de draw calls e consumo de GPU.

