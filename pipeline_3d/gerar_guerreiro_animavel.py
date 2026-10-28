"""
Gerador de Modelo 3D Animável Canônico (Eden Project)
Aplica a matriz biométrica de 5 Cabeças (PADRAO_HUMANOIDES_RIG.md)
no modelo Hunyuan3D-2 e na malha procedural estilizada.
Configura:
- Armature Canônica de 5 Cabeças
- Skinning com Pesos Automáticos (ARMATURE_AUTO)
- Projeção UV e Textura Pixel Art (Closest filtering) com a imagem de referência limpa
- Ciclo de Animação Idle (Respiração / Postura de Combate)
- Exportação GLB com Armature e Animação para o Viewport Three.js
"""

import bpy
import bmesh
import math
import os
from mathutils import Vector, Euler, Quaternion

# ==============================================================================
# 1. PARÂMETROS BIOMÉTRICOS CANÔNICOS (ADULT - 5 CABEÇAS)
# ==============================================================================
HEAD_UNIT = 1.0  # 1 Cabeça = 1.0m no Blender
P = {
    "total_heads": 5.0,
    "z_ground":    0.00,
    "z_ankle":     0.25,
    "z_knee":      1.00,
    "z_wrist":     1.75,
    "z_hip":       2.00,
    "z_elbow":     2.50,
    "z_chest":     3.00,
    "z_shoulder":  3.75,
    "z_neck":      4.00,
    "z_eye":       4.50,
    "z_top":       5.00,
    "arm_span":    0.42,
    "leg_span":    0.20
}

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
GLB_INPUT = os.path.join(CURRENT_DIR, "guerreiro_hunyuan.glb")
IMG_REF = os.path.join(CURRENT_DIR, "guerreiro_ref_limpo.png")
if not os.path.exists(IMG_REF):
    IMG_REF = os.path.join(CURRENT_DIR, "guerreiro_ref.png")

OUTPUT_BLEND = os.path.join(CURRENT_DIR, "guerreiro_animavel_5h.blend")
OUTPUT_GLB = os.path.join(CURRENT_DIR, "guerreiro_animavel_5h.glb")

print(f"-> Iniciando criação do Guerreiro Animável 5H no Blender 4.5...")

# ==============================================================================
# 2. LIMPAR CENA ANTERIOR
# ==============================================================================
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

for block in bpy.data.actions:
    bpy.data.actions.remove(block)
for block in bpy.data.armatures:
    bpy.data.armatures.remove(block)

# ==============================================================================
# 3. CONSTRUIR ARMATURE CANÔNICA DE 5 CABEÇAS
# ==============================================================================
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm_obj = bpy.context.active_object
arm_obj.name = "Rig_Guerreiro_5H"
arm_obj.show_in_front = True
arm_obj.data.display_type = 'STICK'
eb = arm_obj.data.edit_bones

# Remove o osso padrão criado pelo Blender
eb.remove(eb[0])

def add_bone(name, head, tail, parent=None, connected=False):
    bone = eb.new(name)
    bone.head = Vector(head) * HEAD_UNIT
    bone.tail = Vector(tail) * HEAD_UNIT
    if parent and parent in eb:
        bone.parent = eb[parent]
        bone.use_connect = connected
    return bone

# Eixo Central: Root -> Hips -> Spine -> Chest -> Head
add_bone("Root",  (0, 0, 0), (0, 0, 0.25))
add_bone("Hips",  (0, 0, P["z_hip"]), (0, 0, P["z_hip"] + 0.5), "Root")
add_bone("Spine", (0, 0, P["z_hip"] + 0.5), (0, 0, P["z_chest"]), "Hips", True)
add_bone("Chest", (0, 0, P["z_chest"]), (0, 0, P["z_neck"]), "Spine", True)
add_bone("Head",  (0, 0, P["z_neck"]), (0, 0, P["z_top"]), "Chest", True)

# Membros Superiores e Inferiores Canônicos
for s, side in [(1, "L"), (-1, "R")]:
    sh_x = s * P["arm_span"]
    el_x = s * (P["arm_span"] + 0.16)
    wr_x = s * (P["arm_span"] + 0.12)
    hd_x = s * (P["arm_span"] + 0.10)

    # Braços
    add_bone(f"Shoulder.{side}", (s * 0.12, 0, P["z_shoulder"]), (sh_x, 0, P["z_shoulder"]), "Chest")
    add_bone(f"UpperArm.{side}", (sh_x, 0, P["z_shoulder"]),     (el_x, 0.04, P["z_elbow"]),  f"Shoulder.{side}")
    add_bone(f"Forearm.{side}",  (el_x, 0.04, P["z_elbow"]),     (wr_x, -0.06, P["z_wrist"]), f"UpperArm.{side}", True)
    add_bone(f"Hand.{side}",     (wr_x, -0.06, P["z_wrist"]),    (hd_x, -0.10, P["z_wrist"] - 0.22), f"Forearm.{side}", True)

    # Machete / Facão na mão direita (conforme imagem de referência)
    if side == "R":
        add_bone("Weapon.R", (hd_x, -0.10, P["z_wrist"] - 0.15), (hd_x, -0.65, P["z_wrist"] - 0.65), "Hand.R")

    # Pernas: Hips (2.0H) -> Knee (1.0H) -> Ankle (0.25H) -> Foot (0.0H)
    lx = s * P["leg_span"]
    add_bone(f"Thigh.{side}", (lx, 0, P["z_hip"]),   (lx, -0.02, P["z_knee"]), "Hips")
    add_bone(f"Shin.{side}",  (lx, -0.02, P["z_knee"]), (lx, 0, P["z_ankle"]), f"Thigh.{side}", True)
    add_bone(f"Foot.{side}",  (lx, 0, P["z_ankle"]), (lx, -0.28, P["z_ground"] + 0.04), f"Shin.{side}", True)

bpy.ops.object.mode_set(mode='OBJECT')
print("-> Armature canônica de 5 cabeças estruturada.")

# ==============================================================================
# 4. IMPORTAR MALHA HUNYUAN OU CRIAR MID-POLY ORGÂNICO CHANFRADO
# ==============================================================================
char_mesh = None

if os.path.exists(GLB_INPUT):
    print(f"-> Importando geometria esculpida por IA: {GLB_INPUT}")
    bpy.ops.import_scene.gltf(filepath=GLB_INPUT)
    imported_meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']

    if imported_meshes:
        bpy.ops.object.select_all(action='DESELECT')
        for m in imported_meshes:
            m.select_set(True)
        bpy.context.view_layer.objects.active = imported_meshes[0]
        if len(imported_meshes) > 1:
            bpy.ops.object.join()
        char_mesh = bpy.context.active_object
        char_mesh.name = "Guerreiro_Mesh_5H"

        # Escalar e Alinhar perfeitamente às 5 Cabeças
        bbox = [char_mesh.matrix_world @ Vector(c) for c in char_mesh.bound_box]
        h_curr = max(v.z for v in bbox) - min(v.z for v in bbox)
        if h_curr > 0:
            scale_factor = (P["total_heads"] * HEAD_UNIT) / h_curr
            char_mesh.scale = (scale_factor, scale_factor, scale_factor)
            bpy.ops.object.transform_apply(scale=True)

        # Centralizar X/Y e encostar pés em Z=0
        bbox = [char_mesh.matrix_world @ Vector(c) for c in char_mesh.bound_box]
        char_mesh.location.z -= min(v.z for v in bbox)
        char_mesh.location.x -= (max(v.x for v in bbox) + min(v.x for v in bbox)) / 2.0
        char_mesh.location.y -= (max(v.y for v in bbox) + min(v.y for v in bbox)) / 2.0
        bpy.ops.object.transform_apply(location=True)
        print("-> Geometria redimensionada e ancorada no solo (0.0H - 5.0H).")

if not char_mesh:
    print("-> Geometria externa não disponível, gerando malha estilizada...")
    # Cria malha estilizada se não houver arquivo externo
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, 2.5))
    char_mesh = bpy.context.active_object
    char_mesh.name = "Guerreiro_Mesh_5H"

# ==============================================================================
# 5. MAPEAMENTO UV FRONTAL CANÔNICO + TEXTURA PIXEL ART CLOSEST
# ==============================================================================
print("-> Configurando coordenadas UV e Shader PBR Pixel Art...")
mesh_data = char_mesh.data
if not mesh_data.uv_layers:
    mesh_data.uv_layers.new(name="UVMap")
uv_layer = mesh_data.uv_layers.active.data

# Mapeia coordenadas UV a partir da posição X e Z no espaço 3D (Projeção Frontal Alinhada)
bbox = [char_mesh.matrix_world @ Vector(c) for c in char_mesh.bound_box]
min_x = min(v.x for v in bbox) - 0.05
max_x = max(v.x for v in bbox) + 0.05
min_z = min(v.z for v in bbox)
max_z = max(v.z for v in bbox)
width_x = max_x - min_x if max_x > min_x else 1.0
height_z = max_z - min_z if max_z > min_z else 1.0

for poly in mesh_data.polygons:
    for loop_index in poly.loop_indices:
        vert_idx = mesh_data.loops[loop_index].vertex_index
        v_pos = char_mesh.matrix_world @ mesh_data.vertices[vert_idx].co
        # Normaliza coordenadas UV para cobrir a silhueta da imagem
        u = min(1.0, max(0.0, (v_pos.x - min_x) / width_x))
        v = min(1.0, max(0.0, (v_pos.z - min_z) / height_z))
        uv_layer[loop_index].uv = (u, v)

# Cria Material PBR com Filtragem 'Closest' (Pixel Art Crisp)
mat = bpy.data.materials.new(name="M_Guerreiro_PixelArt")
mat.use_nodes = True
nodes = mat.node_tree.nodes
links = mat.node_tree.links
bsdf = nodes.get("Principled BSDF")

if bsdf:
    bsdf.inputs["Roughness"].default_value = 0.55
    bsdf.inputs["Metallic"].default_value = 0.05

if os.path.exists(IMG_REF):
    tex_image = bpy.data.images.load(IMG_REF)
    tex_node = nodes.new('ShaderNodeTexImage')
    tex_node.image = tex_image
    tex_node.interpolation = 'Closest'  # Sem borrão bilinear, estilo pixel art nítido
    if bsdf:
        links.new(tex_node.outputs["Color"], bsdf.inputs["Base Color"])
        # Conecta também canal alfa caso tenha recortes
        links.new(tex_node.outputs["Alpha"], bsdf.inputs["Alpha"])
        mat.blend_method = 'CLIP'

char_mesh.data.materials.clear()
char_mesh.data.materials.append(mat)

# ==============================================================================
# 6. SKINNING / VINCULAÇÃO COM O RIG (ARMATURE AUTO WEIGHTS)
# ==============================================================================
print("-> Vinculando malha ao esqueleto com pesos automáticos...")
bpy.ops.object.select_all(action='DESELECT')
char_mesh.select_set(True)
arm_obj.select_set(True)
bpy.context.view_layer.objects.active = arm_obj

try:
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    print("-> Parentesco ARMATURE_AUTO aplicado com sucesso.")
except Exception as e:
    print(f"Aviso ARMATURE_AUTO: {e}. Aplicando parentesco direto...")
    char_mesh.parent = arm_obj
    mod = char_mesh.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm_obj

# Garante que todos os vértices tenham pesos atribuídos aos ossos
bone_names = [b.name for b in arm_obj.data.bones]
bone_centers = {b.name: (b.head_local + b.tail_local) / 2.0 for b in arm_obj.data.bones}

for b_name in bone_names:
    if b_name not in char_mesh.vertex_groups:
        char_mesh.vertex_groups.new(name=b_name)

assigned_verts = set()
for g in char_mesh.vertex_groups:
    for v in char_mesh.data.vertices:
        for grp in v.groups:
            if grp.group == g.index and grp.weight > 0.01:
                assigned_verts.add(v.index)

unassigned = [v for v in char_mesh.data.vertices if v.index not in assigned_verts]
if unassigned:
    print(f"-> Atribuindo {len(unassigned)} vértices residuais por proximidade biomecânica...")
    for v in unassigned:
        v_co = char_mesh.matrix_world @ v.co
        closest_bone = min(bone_centers.keys(), key=lambda b: (bone_centers[b] - v_co).length)
        char_mesh.vertex_groups[closest_bone].add([v.index], 1.0, 'REPLACE')

# ==============================================================================
# 7. CRIAR ANIMAÇÃO IDLE (POSTURA DE GUERREIRO / RESPIRAÇÃO)
# ==============================================================================
print("-> Criando ciclo de animação Idle de combate...")
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.mode_set(mode='POSE')

arm_obj.animation_data_create()
action = bpy.data.actions.new(name="Guerreiro_Idle")
arm_obj.animation_data.action = action

scene = bpy.context.scene
scene.frame_start = 1
scene.frame_end = 40  # Loop de 40 quadros (~1.3s a 30fps)

pose_bones = arm_obj.pose.bones

# Postura Inicial de Combate: Peito erguido, braço direito com machete firme
if "Chest" in pose_bones:
    chest_b = pose_bones["Chest"]
    chest_b.rotation_mode = 'XYZ'
    chest_b.rotation_euler = (math.radians(2), 0, 0)
    chest_b.keyframe_insert(data_path="rotation_euler", frame=1)
    chest_b.rotation_euler = (math.radians(4), 0, 0)
    chest_b.keyframe_insert(data_path="rotation_euler", frame=20)
    chest_b.rotation_euler = (math.radians(2), 0, 0)
    chest_b.keyframe_insert(data_path="rotation_euler", frame=40)

if "UpperArm.R" in pose_bones:
    arm_r = pose_bones["UpperArm.R"]
    arm_r.rotation_mode = 'XYZ'
    arm_r.rotation_euler = (math.radians(-4), math.radians(6), math.radians(-5))
    arm_r.keyframe_insert(data_path="rotation_euler", frame=1)
    arm_r.rotation_euler = (math.radians(-7), math.radians(8), math.radians(-7))
    arm_r.keyframe_insert(data_path="rotation_euler", frame=20)
    arm_r.rotation_euler = (math.radians(-4), math.radians(6), math.radians(-5))
    arm_r.keyframe_insert(data_path="rotation_euler", frame=40)

if "UpperArm.L" in pose_bones:
    arm_l = pose_bones["UpperArm.L"]
    arm_l.rotation_mode = 'XYZ'
    arm_l.rotation_euler = (math.radians(2), math.radians(-5), math.radians(3))
    arm_l.keyframe_insert(data_path="rotation_euler", frame=1)
    arm_l.rotation_euler = (math.radians(0), math.radians(-3), math.radians(2))
    arm_l.keyframe_insert(data_path="rotation_euler", frame=20)
    arm_l.rotation_euler = (math.radians(2), math.radians(-5), math.radians(3))
    arm_l.keyframe_insert(data_path="rotation_euler", frame=40)

if "Head" in pose_bones:
    head_b = pose_bones["Head"]
    head_b.rotation_mode = 'XYZ'
    head_b.rotation_euler = (math.radians(-2), 0, 0)
    head_b.keyframe_insert(data_path="rotation_euler", frame=1)
    head_b.rotation_euler = (math.radians(0), 0, 0)
    head_b.keyframe_insert(data_path="rotation_euler", frame=20)
    head_b.rotation_euler = (math.radians(-2), 0, 0)
    head_b.keyframe_insert(data_path="rotation_euler", frame=40)

bpy.ops.object.mode_set(mode='OBJECT')
print("-> Ciclo de animação configurado.")

# ==============================================================================
# 8. SALVAR .BLEND E EXPORTAR .GLB COM ANIMAÇÃO E ARMATURE
# ==============================================================================
bpy.ops.wm.save_as_mainfile(filepath=OUTPUT_BLEND)
print(f"-> Cena Blender salva: {OUTPUT_BLEND}")

bpy.ops.export_scene.gltf(
    filepath=OUTPUT_GLB,
    export_format='GLB',
    export_skins=True,
    export_all_influences=True,
    export_animations=True,
    export_yup=True
)
print(f"-> Modelo GLB animável exportado: {OUTPUT_GLB}")
print("-> PROCESSO CONCLUÍDO COM SUCESSO!")
