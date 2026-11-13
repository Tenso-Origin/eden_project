# CHANGELOG — EDEN PROJECT

Todas as alterações notáveis neste projeto serão documentadas neste arquivo.
O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Versionamento Semântico](https://semver.org/lang/pt-BR/).

---

## [0.1.2-alpha] - 2026-11-13

### Adicionado
- **Minimapa Tático HUD e Bússola Azimutal (`biosphere_minimap_hud.gd`):**
  - Radar vetorial 2D desenhado a 60 FPS via `_draw()` sobreposto à viewport 3D com feixe rotativo de varredura.
  - Diferenciação cromática das espécies amazônicas: 🔴 Vermelho (Onça e Jaguatirica / Predadores), 🟢 Verde Claro (Capivara e Cutia / Herbívoros), 🟡 Amarelo (Jabuti / Quelônio) e 🔵 Ciano (Harpia / Aéreo).
  - Bússola com rosa dos ventos e indicação dinâmica de octantes cardeais (N, NE, E, SE, S, SW, W, NW) e azimute angular sincronizados com a rotação contínua da câmera (`CameraPivot`).
  - Painel de telemetria em tempo real com coordenadas globais métricas $(X, Z, Y)$, índice matricial do chunk atual $[cx, cz]$ e contagem de fauna ativa.
  - Tecla `M` para alternar entre Minimapa no Canto, Expandido no Centro e Oculto (com `mouse_filter = MOUSE_FILTER_IGNORE` para liberdade total de câmera e clique).

### Modificado
- **Expansão e Spawning Dinâmico de Fauna nos 100x100 Chunks (`amazon_biosphere_controller.gd`):**
  - Desacoplamento do confinamento no chunk inicial $[-7.8\text{m}, +7.8\text{m}]$: limites de mundo agora cobrem todo o mapa de $1,6\text{ km} \times 1,6\text{ km}$ ($[-800\text{m}, +800\text{m}]$).
  - Algoritmo de navegação contínua vetorial no relevo procedural (`_steer_open_world`), com atratividade biológica realista para terra firme, várzea, água e rastros tróficos.
  - Spawning e culling dinâmico por anel de câmera: novas populações são geradas nos chunks ativos ao viajar pelo mapa, mantendo teto fixo de 50 a 65 animais ativos (< 50 MB de RAM e 60 FPS cravados) e reciclando entidades que ficam a mais de 7 chunks (> 112m) de distância.
- **Cena e Atalhos de Inicialização:**
  - Cena `cena_mundo_100x100_biosfera.tscn` configurada com o nó `MinimapHUD` conectado aos sistemas de streaming, câmera e biosfera.
  - Script `ABRIR_MUNDO_100X100.bat` atualizado com as instruções da tecla `M`.

---

## [0.1.1-alpha] - 2026-11-13

### Adicionado
- **Biodiversidade Neotropical Completa (Substituição de Gato e Rato):**
  - Substituição canônica de espécies invasoras/sintéticas por espécies nativas da Bacia Amazônica:
    - Rato (*Rattus norvegicus*) $\rightarrow$ **Cutia-vermelha (*Dasyprocta leporina*)** e **Capivara (*Hydrochoerus hydrochaeris*)**.
    - Gato (*Felis catus*) $\rightarrow$ **Jaguatirica (*Leopardus pardalis*)** e **Onça-Pintada (*Panthera onca*)**.
    - Aliases retrocompatíveis `IdRat = IdAgouti` e `IdCat = IdOcelot` garantem interoperabilidade contínua.
  - Inclusão taxonômica de 18 espécies da fauna neotropical: Anta-brasileira (*Tapirus terrestris*), Preguiça-real (*Choloepus didactylus*), Macaco-prego (*Sapajus apella*), Ariranha (*Pteronura brasiliensis*), Sucuri-verde (*Eunectes murinus*), Pirarucu (*Arapaima gigas*), Sapo-ponta-de-flecha (*Dendrobates tinctorius*), Jabuti-tinga (*Chelonoidis denticulatus*), Jacaré-açu (*Melanosuchus niger*), Harpia (*Harpia harpyja*), Tucano-toco (*Ramphastos toco*), Carcará (*Caracara plancus*), Tambaqui (*Colossoma macropomum*), Traíra (*Hoplias malabaricus*) e microfauna de insetos.
  - Inclusão botânica e produtores: Castanheira-do-Pará (*Bertholletia excelsa*), Açaizeiro (*Euterpe oleracea*), Vitória-régia (*Victoria amazonica*) e Arroz Silvestre de Várzea (*Oryza glumaepatula*).
- **Mecânicas Comportamentais e Ecológicas Realistas:**
  - **Estratificação de Dossel (`CanopyLayer`):** Preguiças e macacos no estrato de copa alta protegidos contra predadores terrestres sem escalada, vulneráveis a ataques aéreos da Harpia.
  - **Refúgio Semi-Aquático e Mergulho:** Capivara e Cutia com tempo de fôlego prolongado e imunidade submersa contra rasantes aéreos e botes terrestres.
  - **Defesa de Carapaça e Esmagamento Mandibular:** Jabuti-tinga com alta armadura corporal defletindo mesopredadores, vulnerável apenas à mordida craniana de $1000\text{ psi}$ da Onça-Pintada.
  - **Dispersão Zoocórica e Polinização:** Cutias com retenção de memória espacial de touceiras e dispersão de sementes; polinização entomófila por abelhas e borboletas acelerando renovação e frutificação.
  - **Pedogênese de Terra Preta e Ciclagem de Nutrientes:** Autômato de decomposição acelerada de serapilheira e carcaças fertilizando o solo e convertendo areia/minerais em Terra Preta fértil.
- **Gradientes de Influência Ponderados e Telemetria Multitrófica:**
  - `InfluenceMap`: Emissão escalonada de perigo (Onça 100, Jacaré 85, Jaguatirica 60, Carcará 30).
  - `EcosystemTelemetry`: Cálculo de homeostase adaptado à razão ótima presas/predadores (~28:1) e capacidade de suporte da cobertura vegetal.
- **Mundo Procedural em Escala Territorial (100x100 Chunks / 1.6 km):**
  - Implementado `world_streaming_manager_100x100.gd` gerenciando streaming dinâmico de 10.000 chunks ($1.600\text{m} \times 1.600\text{m} = 2,56\text{ km}^2$) com anel ativo em torno da câmera ($9\times 9 = 81$ chunks em memória) cravando 60 FPS com < 50 MB de RAM.
  - Relevo procedural contínuo C0/C1 com `FastNoiseLite`, igarapé meândrico navegável e quantização vertical de 0.25m.
  - Implementado modo turbo na câmera (`camera_pivot_controller.gd`) ativado via `SHIFT` (4.0x velocidade) para exploração rápida do mapa.
  - Cena integrada `cena_mundo_100x100_biosfera.tscn` e inicializador executável `ABRIR_MUNDO_100X100.bat`.
- **Suíte de Testes Unitários de Ecologia Amazônica (`BiosphereTests.cs`):**
  - Testes cobrindo coexistência e dinâmica das espécies nativas, caça e esmagamento de cascos pela Onça, mergulho evasivo da Capivara, proteção vertical de dossel e verificação rigorosa de Zero Garbage Collection (`GC = 0`).

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

