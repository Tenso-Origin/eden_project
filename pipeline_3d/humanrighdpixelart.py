import bpy
import bmesh
import math
import os
from mathutils import Vector

# ==============================================================================
# HUMAN RIG HD PIXEL ART - PADRÃO CANÔNICO PARA HUMANOIDES (EDEN PROJECT)
# ==============================================================================
# Este script define as proporções métricas e de cabeça (Head Units) canônicas
# para a raça Humana e serve como matriz base para todas as demais raças humanóides.
#
# Proporções fundamentais:
#   ADULT (5H  / 120 texels verticais): Guerreiro / Adulto padrão
#   YOUTH (4H  / 96 texels verticais): Jovem
#   CHILD (3H  / 72 texels verticais): Criança
#   BABY  (2H  / 48 texels verticais): Bebê
# ==============================================================================

AGE_CATEGORY    = "ADULT"  # "ADULT" (5H), "YOUTH" (4H), "CHILD" (3H), "BABY" (2H)
TEXELS_PER_HEAD = 24       # 24 ou 32 pixels de textura por Cabeça (NÃO altera a malha para cubos!)
HEAD_UNIT       = 1.0      # 1 Cabeça = 1.0m no Blender

# Se você já gerou o guerreiro_3d.glb no Hunyuan3D-2, coloque o caminho abaixo.
# Se deixar vazio (""), ele cria um Base Mesh Low/Mid-Poly estilizado (anatômico/chanfrado) de 5 cabeças!
EXTERNAL_GLB_PATH = ""

PROPORTIONS = {
    "ADULT": { # 5 Cabeças (120 Texels verticais aparentes) - Guerreiro da Referência
        "total_heads": 5.0,
        "z_ground":    0.00,
        "z_ankle":     0.25, # 1/4 da Cabeça 5
        "z_knee":      1.00, # Linha divisória Cabeça 5 / Cabeça 4
        "z_wrist":     1.75, # 3/4 da Cabeça 4
        "z_hip":       2.00, # Linha divisória Cabeça 4 / Cabeça 3 (Cinto)
        "z_elbow":     2.50, # 1/2 da Cabeça 3
        "z_chest":     3.00, # Linha divisória Cabeça 3 / Cabeça 2 (Peitoral)
        "z_shoulder":  3.75, # 3/4 da Cabeça 2
        "z_neck":      4.00, # Linha divisória Cabeça 2 / Cabeça 1 (Queixo)
        "z_eye":       4.50, # 1/2 da Cabeça 1
        "z_top":       5.00, # Topo da Cabeça 1
        "arm_span":    0.42, # Largura heroica do ombro (igual à imagem)
        "leg_span":    0.20  # Abertura das pernas
    },
    "YOUTH": {
        "total_heads": 4.0, "z_ground": 0.0, "z_ankle": 0.25, "z_knee": 0.75,
        "z_wrist": 1.35, "z_hip": 1.50, "z_elbow": 1.875, "z_chest": 2.25,
        "z_shoulder": 2.75, "z_neck": 3.00, "z_eye": 3.50, "z_top": 4.00,
        "arm_span": 0.32, "leg_span": 0.16
    },
    "CHILD": {
        "total_heads": 3.0, "z_ground": 0.0, "z_ankle": 0.20, "z_knee": 0.50,
        "z_wrist": 0.90, "z_hip": 1.00, "z_elbow": 1.25, "z_chest": 1.50,
        "z_shoulder": 1.75, "z_neck": 2.00, "z_eye": 2.50, "z_top": 3.00,
        "arm_span": 0.25, "leg_span": 0.13
    },
    "BABY": {
        "total_heads": 2.0, "z_ground": 0.0, "z_ankle": 0.125, "z_knee": 0.25,
        "z_wrist": 0.45, "z_hip": 0.50, "z_elbow": 0.625, "z_chest": 0.75,
        "z_shoulder": 0.875, "z_neck": 1.00, "z_eye": 1.50, "z_top": 2.00,
        "arm_span": 0.20, "leg_span": 0.10
    }
}

P = PROPORTIONS[AGE_CATEGORY]

# ==============================================================================
# 1. LIMPAR CENA
# ==============================================================================
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

# ==============================================================================
# 2. GUIAS DE PROPORÇÃO DAS 5 CABEÇAS (NÃO RENDERIZÁVEIS)
# ==============================================================================
guide_col = bpy.data.collections.get("Head_Scale_Guides")
if not guide_col:
    guide_col = bpy.data.collections.new("Head_Scale_Guides")
    bpy.context.scene.collection.children.link(guide_col)

for h in range(int(P["total_heads"]) + 1):
    bpy.ops.mesh.primitive_circle_add(vertices=32, radius=0.85, location=(0, 0, h * HEAD_UNIT))
    g = bpy.context.active_object
    g.name = f"HeadLine_{h}H"
    g.display_type = 'WIRE'
    g.hide_render = True
    if g.name in bpy.context.scene.collection.objects:
        bpy.context.scene.collection.objects.unlink(g)
    if g.name not in guide_col.objects:
        guide_col.objects.link(g)

# ==============================================================================
# 3. RIG (STICK FIGURE) COM PIVÔS EM CABEÇAS E QUARTOS (1/4, 1/2, 3/4)
# ==============================================================================
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm = bpy.context.active_object
arm.name = f"Rig_{AGE_CATEGORY}_{int(P['total_heads'])}H"
arm.show_in_front = True
arm.data.display_type = 'STICK'
eb = arm.data.edit_bones
if len(eb) > 0:
    eb.remove(eb[0])

def add_bone(name, head, tail, parent=None, connect=False):
    b = eb.new(name)
    b.head = Vector(head) * HEAD_UNIT
    b.tail = Vector(tail) * HEAD_UNIT
    if parent and parent in eb:
        b.parent = eb[parent]
        b.use_connect = connect
    return b

# Coluna e Cabeça respeitando as linhas 2.0H, 3.0H, 4.0H e 5.0H
add_bone("Root",  (0, 0, P["z_ground"]), (0, 0.35, P["z_ground"]))
add_bone("Hips",  (0, 0, P["z_hip"]),    (0, 0, P["z_elbow"]), "Root")
add_bone("Spine", (0, 0, P["z_elbow"]),  (0, 0, P["z_chest"]), "Hips", True)
add_bone("Chest", (0, 0, P["z_chest"]),  (0, 0, P["z_neck"]),  "Spine", True)
add_bone("Head",  (0, 0, P["z_neck"]),   (0, 0, P["z_top"]),   "Chest", True)

# Braços (Abaixados naturalmente como no guerreiro da imagem para seguir 3.75H -> 2.5H -> 1.75H)
for s, side in [(1, "L"), (-1, "R")]:
    sh_x = s * P["arm_span"]
    el_x = s * (P["arm_span"] + 0.14)
    wr_x = s * (P["arm_span"] + 0.10)
    hd_x = s * (P["arm_span"] + 0.08)

    add_bone(f"Shoulder.{side}", (s * 0.12, 0, P["z_shoulder"]), (sh_x, 0, P["z_shoulder"]), "Chest")
    add_bone(f"UpperArm.{side}", (sh_x, 0, P["z_shoulder"]),     (el_x, 0.04, P["z_elbow"]), f"Shoulder.{side}", True)
    add_bone(f"Forearm.{side}",  (el_x, 0.04, P["z_elbow"]),     (wr_x, -0.06, P["z_wrist"]), f"UpperArm.{side}", True)
    add_bone(f"Hand.{side}",     (wr_x, -0.06, P["z_wrist"]),    (hd_x, -0.10, P["z_wrist"] - 0.22), f"Forearm.{side}", True)
    add_bone(f"Weapon.{side}",   (hd_x, -0.10, P["z_wrist"] - 0.15), (hd_x, -0.65, P["z_wrist"] - 0.65), f"Hand.{side}")

    # Pernas: Quadril (2.0H) -> Joelho (1.0H) -> Tornozelo (0.25H) -> Planta do Pé (0.0H)
    lx = s * P["leg_span"]
    add_bone(f"Thigh.{side}", (lx, 0, P["z_hip"]),   (lx, -0.02, P["z_knee"]), "Hips")
    add_bone(f"Shin.{side}",  (lx, -0.02, P["z_knee"]), (lx, 0, P["z_ankle"]), f"Thigh.{side}", True)
    add_bone(f"Foot.{side}",  (lx, 0, P["z_ankle"]), (lx, -0.28, P["z_ground"] + 0.04), f"Shin.{side}", True)

bpy.ops.object.mode_set(mode='OBJECT')

# ==============================================================================
# 4. CONSTRUÇÃO LOW/MID-POLY ORGÂNICA E CHANFRADA (ZERO VOXELS/CUBOS)
# ==============================================================================
def create_stylized_limb(name, p1, p2, rad1, rad2, segments=10, bone_name="Chest"):
    """Cria um segmento anatômico Low/Mid-Poly chanfrado entre dois pivôs."""
    v1, v2 = Vector(p1) * HEAD_UNIT, Vector(p2) * HEAD_UNIT
    mid = (v1 + v2) / 2.0
    length = (v2 - v1).length

    bpy.ops.mesh.primitive_cone_add(
        vertices=segments, radius1=rad1, radius2=rad2, depth=length, location=mid
    )
    obj = bpy.context.active_object
    obj.name = name

    # Alinhar o cilindro/cone na direção do osso
    direction = (v2 - v1).normalized()
    up = Vector((0, 0, 1))
    dot = max(-1.0, min(1.0, direction.dot(up)))
    if dot < -0.999:
        obj.rotation_euler = (math.pi, 0, 0)
    elif dot < 0.999:
        rot_axis = up.cross(direction).normalized()
        angle = math.acos(dot)
        obj.rotation_mode = 'AXIS_ANGLE'
        obj.rotation_axis_angle = (angle, rot_axis.x, rot_axis.y, rot_axis.z)
        obj.rotation_mode = 'XYZ'
    
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)

    # Chanfrar bordas para dar estética Mid-Poly estilizada (como na foto do guerreiro)
    bev = obj.modifiers.new("Stylized_Chamfer", 'BEVEL')
    bev.width = 0.03
    bev.segments = 1
    bpy.ops.object.modifier_apply(modifier=bev.name)

    vg = obj.vertex_groups.new(name=bone_name)
    vg.add([v.index for v in obj.data.vertices], 1.0, 'REPLACE')
    return obj

has_external_file = bool(EXTERNAL_GLB_PATH and os.path.isfile(bpy.path.abspath(EXTERNAL_GLB_PATH)))

if has_external_file:
    # Opção A: Importar malha orgânica do Hunyuan3D-2 e encaixar exatamente nas 5 cabeças
    filepath = bpy.path.abspath(EXTERNAL_GLB_PATH)
    bpy.ops.import_scene.gltf(filepath=filepath)
    imp = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.name not in guide_col.objects]
    bpy.ops.object.select_all(action='DESELECT')
    for m in imp: m.select_set(True)
    bpy.context.view_layer.objects.active = imp[0]
    if len(imp) > 1: bpy.ops.object.join()
    char_mesh = bpy.context.active_object
    char_mesh.name = f"Character_MidPoly_{AGE_CATEGORY}"

    bbox = [char_mesh.matrix_world @ Vector(c) for c in char_mesh.bound_box]
    h_curr = max(v.z for v in bbox) - min(v.z for v in bbox)
    sc = (P["total_heads"] * HEAD_UNIT) / h_curr
    char_mesh.scale = (sc, sc, sc)
    bpy.ops.object.transform_apply(scale=True)
    bbox = [char_mesh.matrix_world @ Vector(c) for c in char_mesh.bound_box]
    char_mesh.location.z -= min(v.z for v in bbox)
    bpy.ops.object.transform_apply(location=True)
else:
    # Opção B: Gerar Base Mesh Low/Mid-Poly Estilizado do Guerreiro (5 Cabeças)
    parts = []

    # CABEÇA 1 (4.0H a 5.0H): Crânio chanfrado + Barba volumosa angular + Cabelo
    parts.append(create_stylized_limb("Head_Skull", (0, 0, 4.25), (0, 0, 4.90), 0.30, 0.34, 12, "Head"))
    parts.append(create_stylized_limb("Beard_Volume", (0, -0.06, 3.92), (0, -0.05, 4.38), 0.22, 0.36, 8, "Head"))
    parts.append(create_stylized_limb("Hair_Crown", (0, 0.02, 4.78), (0, -0.06, 5.05), 0.35, 0.28, 10, "Head"))

    # CABEÇA 2 (3.0H a 4.0H): Trapézio e Peitoral em V (Robusto)
    parts.append(create_stylized_limb("Upper_Chest_C2", (0, 0, P["z_chest"]), (0, 0, P["z_neck"]), 0.38, 0.48, 12, "Chest"))

    # CABEÇA 3 (2.0H a 3.0H): Abdômen e Cintura/Cinto
    parts.append(create_stylized_limb("Abdomen_C3", (0, 0, P["z_hip"]), (0, 0, P["z_chest"]), 0.34, 0.38, 12, "Spine"))
    parts.append(create_stylized_limb("Pelvis_Belt", (0, 0, P["z_hip"] - 0.15), (0, 0, P["z_hip"] + 0.12), 0.36, 0.37, 12, "Hips"))

    # BRAÇOS E PERNAS ESTILIZADOS (Ombros arredondados, braceletes, calça larga e botas)
    for s, side in [(1, "L"), (-1, "R")]:
        sh = (s * P["arm_span"], 0, P["z_shoulder"])
        el = (s * (P["arm_span"] + 0.14), 0.04, P["z_elbow"])
        wr = (s * (P["arm_span"] + 0.10), -0.06, P["z_wrist"])
        hd = (s * (P["arm_span"] + 0.08), -0.10, P["z_wrist"] - 0.22)

        # Deltoide/Ombro (Icosfera Mid-Poly)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.24, location=sh)
        delt = bpy.context.active_object
        delt.name = f"Deltoid_{side}"
        vg = delt.vertex_groups.new(name=f"UpperArm.{side}")
        vg.add([v.index for v in delt.data.vertices], 1.0, 'REPLACE')
        parts.append(delt)

        parts.append(create_stylized_limb(f"Bicep_{side}", el, sh, 0.17, 0.22, 10, f"UpperArm.{side}"))
        parts.append(create_stylized_limb(f"Forearm_Bracer_{side}", wr, el, 0.19, 0.18, 10, f"Forearm.{side}"))
        parts.append(create_stylized_limb(f"Hand_Fist_{side}", hd, wr, 0.14, 0.16, 8, f"Hand.{side}"))

        # Facão Assimétrico apenas na mão Direita (-X)
        if side == "R":
            w_base = (hd[0], -0.12, P["z_wrist"] - 0.12)
            w_tip  = (hd[0], -0.68, P["z_wrist"] - 0.65)
            blade = create_stylized_limb("Machete_Blade_R", w_tip, w_base, 0.04, 0.10, 4, "Weapon.R")
            blade.scale.x = 0.25
            bpy.ops.object.transform_apply(scale=True)
            parts.append(blade)

        # CABEÇA 4 (2.0H a 1.0H): Coxas da calça
        lx = s * P["leg_span"]
        hip_p  = (lx, 0, P["z_hip"])
        knee_p = (lx, -0.02, P["z_knee"])
        ank_p  = (lx, 0, P["z_ankle"])
        foot_p = (lx, -0.26, P["z_ground"] + 0.08)

        parts.append(create_stylized_limb(f"Thigh_C4_{side}", knee_p, hip_p, 0.20, 0.23, 10, f"Thigh.{side}"))
        # CABEÇA 5 (1.0H a 0.0H): Canela/Dobra da Calça + Bota Robusta
        parts.append(create_stylized_limb(f"Shin_Boot_C5_{side}", ank_p, knee_p, 0.18, 0.22, 10, f"Shin.{side}"))
        parts.append(create_stylized_limb(f"Boot_Shoe_{side}", foot_p, (lx, 0.08, P["z_ankle"] * 0.6), 0.17, 0.19, 8, f"Foot.{side}"))

    bpy.ops.object.select_all(action='DESELECT')
    for p in parts: p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    char_mesh = bpy.context.active_object
    char_mesh.name = f"Stylized_MidPoly_{AGE_CATEGORY}_5H"

# ==============================================================================
# 5. UV MAP 100% ASSIMÉTRICO + TEXTURA PIXEL ART (DENSIDADE DE TEXELS FIXA)
# ==============================================================================
bpy.context.view_layer.objects.active = char_mesh
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')

# Projeção UV com ilhas independentes (Zero espelhamento entre L e R!)
bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
bpy.ops.object.mode_set(mode='OBJECT')

# Resolução da Textura calculada pelos Texels da Cabeça (ex: 256x256 com filtro Closest)
tex_res = 256
mat = bpy.data.materials.new(name="Stylized_PixelTex_Mat")
mat.use_nodes = True
nodes = mat.node_tree.nodes
bsdf = nodes.get("Principled BSDF")
if bsdf:
    bsdf.inputs["Roughness"].default_value = 0.75

tex_node = nodes.new('ShaderNodeTexImage')
tex_node.interpolation = 'Closest' # Os pixels ficam aparentes na TEXTURA, mas a malha é Mid-Poly!
img_name = f"Tex_Atlas_{tex_res}px"
if img_name not in bpy.data.images:
    bpy.ops.image.new(name=img_name, width=tex_res, height=tex_res, generated_type='COLOR_GRID')
tex_node.image = bpy.data.images[img_name]
if bsdf:
    mat.node_tree.links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])

if not char_mesh.data.materials:
    char_mesh.data.materials.append(mat)

# Vincular ao Rig
bpy.ops.object.select_all(action='DESELECT')
char_mesh.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
try:
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
except Exception as e:
    char_mesh.parent = arm
    mod = char_mesh.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm

print(f"Modelo Low/Mid-Poly Estilizado ({AGE_CATEGORY} - {int(P['total_heads'])} Cabeças) pronto com sucesso!")

# Salva arquivo .blend e exporta .glb para o Viewport
output_dir = os.path.dirname(os.path.abspath(__file__))
blend_out = os.path.join(output_dir, f"humanoide_canonico_{AGE_CATEGORY.lower()}_{int(P['total_heads'])}h.blend")
glb_out = os.path.join(output_dir, f"humanoide_canonico_{AGE_CATEGORY.lower()}_{int(P['total_heads'])}h.glb")

bpy.ops.wm.save_as_mainfile(filepath=blend_out)
print(f"Arquivo Blend salvo: {blend_out}")

bpy.ops.export_scene.gltf(
    filepath=glb_out,
    export_format='GLB',
    export_skins=True,
    export_all_influences=True,
    export_yup=True
)
print(f"Arquivo GLB exportado: {glb_out}")

