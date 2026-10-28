# Padrão Canônico de Proporções e Rig Humanoide (Eden Project)

Este documento registra a matriz biométrica e proporcional canônica definida no script [`humanrighdpixelart.py`](file:///d:/Tenso/Documents/eden_project/pipeline_3d/humanrighdpixelart.py). Todas as raças e variantes humanóides do jogo utilizam essas medidas e pivôs como padrão.

---

## 1. Unidade de Medida e Resolução (Head Units & Texels)
- **1 Head Unit (1.0H)**: 1.0 metro no espaço do Blender.
- **Densidade de Texels**: 24 a 32 pixels de textura por Head Unit na textura (atlas).
- **Adulto Canônico**: 5 Cabeças de altura total ($5.0H \approx 120$ texels verticais aparentes).

---

## 2. Tabela de Proporções por Faixa Etária

| Marco Anatômico | Adulto (`ADULT`, 5H) | Jovem (`YOUTH`, 4H) | Criança (`CHILD`, 3H) | Bebê (`BABY`, 2H) |
| :--- | :---: | :---: | :---: | :---: |
| **Topo da Cabeça (`z_top`)** | **5.00** | **4.00** | **3.00** | **2.00** |
| Olhos (`z_eye`) | 4.50 | 3.50 | 2.50 | 1.50 |
| Queixo / Pescoço (`z_neck`) | 4.00 | 3.00 | 2.00 | 1.00 |
| Ombro (`z_shoulder`) | 3.75 | 2.75 | 1.75 | 0.875 |
| Peitoral (`z_chest`) | 3.00 | 2.25 | 1.50 | 0.75 |
| Cotovelo (`z_elbow`) | 2.50 | 1.875 | 1.25 | 0.625 |
| Quadril / Cinto (`z_hip`) | 2.00 | 1.50 | 1.00 | 0.50 |
| Pulso (`z_wrist`) | 1.75 | 1.35 | 0.90 | 0.45 |
| Joelho (`z_knee`) | 1.00 | 0.75 | 0.50 | 0.25 |
| Tornozelo (`z_ankle`) | 0.25 | 0.25 | 0.20 | 0.125 |
| **Solo / Planta do Pé (`z_ground`)** | **0.00** | **0.00** | **0.00** | **0.00** |
| *Abertura de Ombros (`arm_span`)* | 0.42 | 0.32 | 0.25 | 0.20 |
| *Abertura de Pernas (`leg_span`)* | 0.20 | 0.16 | 0.13 | 0.10 |

---

## 3. Topologia e Hierarquia Esquelética (Stick Figure)

```
Root (0.0H)
└── Hips (2.0H -> 2.5H)
    ├── Spine (2.5H -> 3.0H)
    │   └── Chest (3.0H -> 4.0H)
    │       ├── Head (4.0H -> 5.0H)
    │       ├── Shoulder.L -> UpperArm.L -> Forearm.L -> Hand.L -> Weapon.L
    │       └── Shoulder.R -> UpperArm.R -> Forearm.R -> Hand.R -> Weapon.R
    ├── Thigh.L -> Shin.L -> Foot.L
    └── Thigh.R -> Shin.R -> Foot.R
```

---

## 4. Diretrizes Técnicas de Modelagem e UV
1. **Malha Low/Mid-Poly Estilizada**: Geometria anatômica chanfrada (chanfros chanfrados de 0.03m), sem triangulação excessiva e **sem cubos/voxels rígidos**.
2. **UV Mapping 100% Assimétrico**: Não há espelhamento UV entre lados esquerdo e direito, permitindo detalhes assimétricos como armas na mão direita, braçadeiras únicas e variações de iluminação.
3. **Interpolação de Textura**: Interpolação `Closest` (Pixel Art crisp) aplicada em material PBR Principled BSDF (Roughness ~0.75).
