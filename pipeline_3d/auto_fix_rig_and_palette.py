import bpy
import bmesh
import math
import os
from mathutils import Vector

# ==============================================================================
# CONFIGURAÇÃO UNIVERSAL (CANÔNICO EDEN PROJECT - PROJETADO PELO AGENTE ARGON)
# ==============================================================================
CURRENT_DIR    = os.path.dirname(os.path.abspath(__file__))
CAMINHO_GLB    = os.path.join(CURRENT_DIR, "guerreiro_hunyuan.glb")
if not os.path.exists(CAMINHO_GLB):
    CAMINHO_GLB = os.path.join(CURRENT_DIR, "guerreiro_3d.glb")

CAMINHO_IMG_2D = os.path.join(CURRENT_DIR, "guerreiro_ref_limpo.png")
if not os.path.exists(CAMINHO_IMG_2D):
    CAMINHO_IMG_2D = os.path.join(CURRENT_DIR, "guerreiro_ref.png")

SAIDA_GLB_FIX   = os.path.join(CURRENT_DIR, "guerreiro_pronto_5h.glb")
SAIDA_BLEND_FIX = os.path.join(CURRENT_DIR, "guerreiro_pronto_5h.blend")

TOTAL_HEADS       = 5.0   # 5.0 (Adulto Canônico), 4.0 (Jovem), 3.0 (Criança), 2.0 (Bebê)
REMOVER_ARMA_MAO  = True  # Poda apêndices finos projetados além do punho (espadas/facões)
LIMPAR_SOLA_BOTA  = True  # Remove os "espinhos" de sombra nos pés
TARGET_FACES      = 18000 # Reduz de 250k triângulos para 18k (otimizado, leve e sem perder a silhueta)

print("=" * 70)
print("  PIPELINE UNIVERSAL: AUTO-FIX DE EIXOS, PODA, PALETA E RIG ADAPTATIVO")
print("=" * 70)
print(f"GLB Entrada  : {CAMINHO_GLB}")
print(f"Imagem Ref 2D: {CAMINHO_IMG_2D}")
print(f"GLB Saída    : {SAIDA_GLB_FIX}")
print("=" * 70)

# ==============================================================================
# 1. LIMPAR CENA E IMPORTAR GLB
# ==============================================================================
bpy.ops.wm.read_factory_settings(use_empty=True)

for block in bpy.data.actions:
    bpy.data.actions.remove(block)
for block in bpy.data.armatures:
    bpy.data.armatures.remove(block)
for block in bpy.data.meshes:
    bpy.data.meshes.remove(block)

print("-> Importando malha bruta do Hunyuan3D-2...")
bpy.ops.import_scene.gltf(filepath=CAMINHO_GLB)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
bpy.ops.object.select_all(action='DESELECT')
for m in meshes:
    m.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()

mesh_obj = bpy.context.active_object
mesh_obj.name = "Character_Shell"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# ==============================================================================
# 2. CORRIGIR ORIENTAÇÃO DE EIXOS AUTOMÁTICA (De Y-Up deitado para Z-Up em pé)
# ==============================================================================
dims = mesh_obj.dimensions
print(f"-> Dimensões brutas iniciais: X={dims.x:.2f}, Y={dims.y:.2f}, Z={dims.z:.2f}")

if dims.y > dims.z and dims.y > dims.x:
    print(" -> Detectado modelo deitado no eixo Y! Rotacionando +90° no eixo X para Z-Up...")
    mesh_obj.rotation_euler.x = math.radians(90)
    bpy.ops.object.transform_apply(rotation=True)
elif dims.x > dims.z and dims.x > dims.y:
    print(" -> Detectado modelo inclinado no eixo X! Rotacionando para Z-Up...")
    mesh_obj.rotation_euler.y = math.radians(90)
    bpy.ops.object.transform_apply(rotation=True)

# Centralizar X/Y pela mediana do tronco (ignora armas que puxam a Bounding Box para o lado!)
bm = bmesh.new()
bm.from_mesh(mesh_obj.data)
zs = [v.co.z for v in bm.verts]
min_z, max_z = min(zs), max(zs)
h_raw = max_z - min_z

# Pegar apenas vértices do tronco (entre 45% e 85% da altura) para achar o centro real do corpo
torso_verts = [v.co for v in bm.verts if (min_z + 0.45 * h_raw) < v.co.z < (min_z + 0.85 * h_raw)]
if torso_verts:
    center_x = sum(v.x for v in torso_verts) / len(torso_verts)
    center_y = sum(v.y for v in torso_verts) / len(torso_verts)
else:
    center_x = (max(v.co.x for v in bm.verts) + min(v.co.x for v in bm.verts)) / 2.0
    center_y = (max(v.co.y for v in bm.verts) + min(v.co.y for v in bm.verts)) / 2.0

for v in bm.verts:
    v.co.x -= center_x
    v.co.y -= center_y
    v.co.z -= min_z

# Escalar para a altura exata de N Cabeças (ex: 5.0 unidades no eixo Z)
scale_factor = TOTAL_HEADS / h_raw
for v in bm.verts:
    v.co *= scale_factor

# ==============================================================================
# 3. LIMPEZA GENÉRICA: REMOVER ESPINHOS DO PÉ E OBJETOS SEGURADOS (FACÃO)
# ==============================================================================
bm.verts.ensure_lookup_table()
verts_to_delete = []

if LIMPAR_SOLA_BOTA:
    # Corta ruídos de sombra na base extrema (abaixo de 0.06H) e achata a sola
    for v in bm.verts:
        if v.co.z < 0.06:
            v.co.z = 0.0

if REMOVER_ARMA_MAO:
    # Qualquer geometria abaixo da cintura (Z < 1.85H) que esteja muito afastada do eixo X das pernas
    # ou projetada muito à frente do corpo (Y < -0.52H ou X < -0.55H) é um objeto segurado (espada/facão)
    for v in bm.verts:
        if v.co.z < 1.85 and (v.co.x < -0.55 or v.co.y < -0.50):
            verts_to_delete.append(v)

if verts_to_delete:
    print(f" -> Podando {len(verts_to_delete)} vértices do facão fundido e apêndices de mão...")
    bmesh.ops.delete(bm, geom=verts_to_delete, context='VERTS')

bm.to_mesh(mesh_obj.data)
bm.free()
mesh_obj.data.update()

# Remover ilhas flutuantes desconectadas (restos da lâmina ou sujeira do piso)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.bisect(plane_co=(0, 0, 0.02), plane_no=(0, 0, 1), use_fill=True, clear_inner=True)
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.remove_doubles(threshold=0.002)
bpy.ops.object.mode_set(mode='OBJECT')

# Otimizar de 250k triângulos para 18k (mantém todos os detalhes e destrava o Rigging!)
current_polys = len(mesh_obj.data.polygons)
print(f"-> Polígonos antes da otimização: {current_polys}")
if current_polys > TARGET_FACES:
    dec = mesh_obj.modifiers.new("Optimize_Shell", 'DECIMATE')
    dec.ratio = TARGET_FACES / current_polys
    bpy.ops.object.modifier_apply(modifier=dec.name)
    print(f"-> Polígonos otimizados para: {len(mesh_obj.data.polygons)}")

# ==============================================================================
# 4. EXTRAÇÃO SEMÂNTICA DE PALETA DA IMAGEM 2D + PINTURA SÓLIDA (SEM BURACOS!)
# ==============================================================================
print("-> Extraindo paleta semântica 2D e pintando malha com Vertex Colors Opacos...")

# Carrega a imagem de referência nativamente no Blender
img_ref = bpy.data.images.load(CAMINHO_IMG_2D)
w_img, h_img = img_ref.size[0], img_ref.size[1]
raw_pixels = list(img_ref.pixels) # Normalizados 0.0 a 1.0

def get_pixel_rgba(x, y):
    x = max(0, min(w_img - 1, int(x)))
    y = max(0, min(h_img - 1, int(y)))
    idx = (y * w_img + x) * 4
    return (raw_pixels[idx], raw_pixels[idx + 1], raw_pixels[idx + 2], raw_pixels[idx + 3])

# Criar projeção UV limpa com ilhas separadas
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(66.0), island_margin=0.02)
bpy.ops.object.mode_set(mode='OBJECT')

# Atributo de cor por vértice/face lendo a paleta da imagem 2D (garante frente e costas sólidas!)
if "Col_Palette" not in mesh_obj.data.color_attributes:
    col_attr = mesh_obj.data.color_attributes.new(name="Col_Palette", type='BYTE_COLOR', domain='CORNER')
else:
    col_attr = mesh_obj.data.color_attributes["Col_Palette"]

# Calcular limites X e Z da malha limpa e reorientada
xs = [v.co.x for v in mesh_obj.data.vertices]
zs = [v.co.z for v in mesh_obj.data.vertices]
min_x, max_x = min(xs), max(xs)
min_z, max_z = min(zs), max(zs)

def amostrar_cor_solida(u_norm, v_norm):
    """Busca o pixel opaco na coordenada correspondente da arte 2D (quantizado em grade Pixel Art)."""
    # Quantizar coordenadas em blocos de 120 texels verticais (24 texels por cabeça!)
    u_q = round(u_norm * 72) / 72.0
    v_q = round(v_norm * (24 * TOTAL_HEADS)) / (24 * TOTAL_HEADS)

    px = int(min(max(u_q, 0.02), 0.98) * (w_img - 1))
    py = int(min(max(v_q, 0.02), 0.98) * (h_img - 1))

    r, g, b, a = get_pixel_rgba(px, py)
    if a > 0.78:
        return (r, g, b, 1.0)

    # Se bateu na borda transparente (laterais ou costas), varre para o centro na mesma linha Z
    cx = w_img // 2
    step = 1 if cx > px else -1
    for x_scan in range(px, cx, step):
        r, g, b, a = get_pixel_rgba(x_scan, py)
        if a > 0.85:
            # Escurece 12% para volume nas costas/laterais
            return (r * 0.88, g * 0.88, b * 0.88, 1.0)
    return (0.35, 0.25, 0.18, 1.0)

for poly in mesh_obj.data.polygons:
    # Usar o centro da face para cor sólida (estética HD Pixel Art!)
    f_center = poly.center
    u_n = (f_center.x - min_x) / (max_x - min_x + 1e-5)
    v_n = (f_center.z - min_z) / (max_z - min_z + 1e-5)
    rgba = amostrar_cor_solida(u_n, v_n)

    # Se a normal aponta para trás (+Y), aplica leve sombreamento de oclusão 3D
    if poly.normal.y > 0.25:
        rgba = (rgba[0] * 0.82, rgba[1] * 0.82, rgba[2] * 0.82, 1.0)

    for loop_idx in poly.loop_indices:
        col_attr.data[loop_idx].color = rgba

# Material 100% Sólido Opaco PBR (Zero Alpha Blend, Zero Buracos!)
mesh_obj.data.materials.clear()
mat = bpy.data.materials.new(name="Universal_PixelPalette_Mat")
mat.use_nodes = True
mat.blend_method = 'OPAQUE'
nodes = mat.node_tree.nodes
links = mat.node_tree.links
nodes.clear()

out_node = nodes.new('ShaderNodeOutputMaterial')
bsdf = nodes.new('ShaderNodeBsdfPrincipled')
bsdf.inputs["Roughness"].default_value = 0.85

vcol_node = nodes.new('ShaderNodeVertexColor')
vcol_node.layer_name = "Col_Palette"

links.new(vcol_node.outputs["Color"], bsdf.inputs["Base Color"])
links.new(bsdf.outputs["BSDF"], out_node.inputs["Surface"])
mesh_obj.data.materials.append(mat)
print("-> Material Opaco e Cores de Vértices configurados com sucesso.")

# ==============================================================================
# 5. AUTO-RIGGING ADAPTATIVO (CENTROID TRACKING POR FATIAMENTO HORIZONTAL)
# ==============================================================================
print("-> Escaneando centróides anatômicos para posicionamento preciso do Rig...")

def find_slice_centroids(z_level, band=0.12):
    """Escaneia a fatia horizontal Z da malha e acha o centro exato do tronco, braços e pernas!"""
    slice_v = [v.co for v in mesh_obj.data.vertices if abs(v.co.z - z_level) < band]
    if not slice_v:
        return Vector((0, 0, z_level)), Vector((0.3, 0, z_level)), Vector((-0.3, 0, z_level))

    center = sum(slice_v, Vector((0, 0, 0))) / len(slice_v)
    left_v = [v for v in slice_v if v.x > 0.05]
    right_v = [v for v in slice_v if v.x < -0.05]

    c_left = sum(left_v, Vector((0, 0, 0))) / len(left_v) if left_v else Vector((0.2, 0, z_level))
    c_right = sum(right_v, Vector((0, 0, 0))) / len(right_v) if right_v else Vector((-0.2, 0, z_level))
    return center, c_left, c_right

# Alturas baseadas na proporção de N cabeças
H = TOTAL_HEADS / 5.0
z_ankle, z_knee, z_hip, z_chest, z_neck, z_top = 0.25 * H, 1.0 * H, 2.0 * H, 3.0 * H, 4.0 * H, 5.0 * H
z_sh, z_el, z_wr = 3.70 * H, 2.65 * H, 1.85 * H

c_hip, leg_L_hip, leg_R_hip = find_slice_centroids(z_hip)
_, leg_L_knee, leg_R_knee = find_slice_centroids(z_knee)
_, leg_L_ankle, leg_R_ankle = find_slice_centroids(z_ankle)
c_chest, _, _ = find_slice_centroids(z_chest)
c_neck, _, _ = find_slice_centroids(z_neck)

def find_arm_joint(z_level, side_sign):
    pts = [v.co for v in mesh_obj.data.vertices if abs(v.co.z - z_level) < 0.15 and (v.co.x * side_sign) > 0.30]
    if pts:
        return sum(pts, Vector((0, 0, 0))) / len(pts)
    return Vector((side_sign * 0.55, 0, z_level))

bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm = bpy.context.active_object
arm.name = "Adaptive_5H_Rig"
arm.show_in_front = True
eb = arm.data.edit_bones
eb.remove(eb[0])

def b_add(name, h, t, p=None, conn=False):
    b = eb.new(name)
    b.head, b.tail = h, t
    if p and p in eb:
        b.parent = eb[p]
        b.use_connect = conn
    return b

b_add("Root", (0, 0, 0), (0, 0.4, 0))
b_add("Hips", c_hip, (c_hip + c_chest) / 2.0, "Root")
b_add("Spine", (c_hip + c_chest) / 2.0, c_chest, "Hips", True)
b_add("Chest", c_chest, c_neck, "Spine", True)
b_add("Head", c_neck, Vector((c_neck.x, c_neck.y, z_top)), "Chest", True)

for s, side, l_hip, l_knee, l_ank in [
    (1, "L", leg_L_hip, leg_L_knee, leg_L_ankle),
    (-1, "R", leg_R_hip, leg_R_knee, leg_R_ankle)
]:
    sh_p = find_arm_joint(z_sh, s)
    el_p = find_arm_joint(z_el, s)
    wr_p = find_arm_joint(z_wr, s)
    hd_p = wr_p + Vector((0, -0.05, -0.22))

    b_add(f"Shoulder.{side}", Vector((s * 0.15, c_chest.y, z_sh)), sh_p, "Chest")
    b_add(f"UpperArm.{side}", sh_p, el_p, f"Shoulder.{side}", True)
    b_add(f"Forearm.{side}", el_p, wr_p, f"UpperArm.{side}", True)
    b_add(f"Hand.{side}", wr_p, hd_p, f"Forearm.{side}", True)
    b_add(f"Weapon.{side}", hd_p, hd_p + Vector((0, -0.5, -0.2)), f"Hand.{side}")

    b_add(f"Thigh.{side}", l_hip, l_knee, "Hips")
    b_add(f"Shin.{side}", l_knee, l_ank, f"Thigh.{side}", True)
    b_add(f"Foot.{side}", l_ank, l_ank + Vector((0, -0.28, -0.15)), f"Shin.{side}", True)

bpy.ops.object.mode_set(mode='OBJECT')
print("-> Esqueleto adaptativo posicionado internamente nos centróides da malha.")

# Parentesco e Pesos Automáticos
bpy.ops.object.select_all(action='DESELECT')
mesh_obj.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm

try:
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')
    print("-> Parentesco ARMATURE_AUTO aplicado com sucesso.")
except Exception as e:
    print(f"Aviso ARMATURE_AUTO: {e}. Aplicando parentesco por modificador...")
    mesh_obj.parent = arm
    mod = mesh_obj.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm

# Garantir que 100% dos vértices tenham influência de pelo menos um osso
bone_names = [b.name for b in arm.data.bones]
bone_centers = {b.name: (b.head_local + b.tail_local) / 2.0 for b in arm.data.bones}

for b_name in bone_names:
    if b_name not in mesh_obj.vertex_groups:
        mesh_obj.vertex_groups.new(name=b_name)

assigned_verts = set()
for g in mesh_obj.vertex_groups:
    for v in mesh_obj.data.vertices:
        for grp in v.groups:
            if grp.group == g.index and grp.weight > 0.01:
                assigned_verts.add(v.index)

unassigned = [v for v in mesh_obj.data.vertices if v.index not in assigned_verts]
if unassigned:
    print(f"-> Atribuindo {len(unassigned)} vértices residuais por proximidade biomecânica...")
    for v in unassigned:
        v_co = mesh_obj.matrix_world @ v.co
        closest_bone = min(bone_centers.keys(), key=lambda b: (bone_centers[b] - v_co).length)
        mesh_obj.vertex_groups[closest_bone].add([v.index], 1.0, 'REPLACE')

# ==============================================================================
# 6. CICLO DE ANIMAÇÃO IDLE (POSTURA DE GUERREIRO / RESPIRAÇÃO)
# ==============================================================================
print("-> Configurando ciclo de animação Idle de combate...")
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode='POSE')

arm.animation_data_create()
action = bpy.data.actions.new(name="Warrior_Combat_Idle")
arm.animation_data.action = action

scene = bpy.context.scene
scene.frame_start = 1
scene.frame_end = 40  # Loop de 40 quadros (~1.3s a 30fps)

pose_bones = arm.pose.bones

# Postura de Combate e Respiração Canônica
if "Chest" in pose_bones:
    chest_b = pose_bones["Chest"]
    chest_b.rotation_mode = 'XYZ'
    chest_b.rotation_euler = (math.radians(2), 0, 0)
    chest_b.keyframe_insert(data_path="rotation_euler", frame=1)
    chest_b.rotation_euler = (math.radians(5), 0, 0)
    chest_b.keyframe_insert(data_path="rotation_euler", frame=20)
    chest_b.rotation_euler = (math.radians(2), 0, 0)
    chest_b.keyframe_insert(data_path="rotation_euler", frame=40)

if "UpperArm.R" in pose_bones:
    arm_r = pose_bones["UpperArm.R"]
    arm_r.rotation_mode = 'XYZ'
    arm_r.rotation_euler = (math.radians(-6), math.radians(8), math.radians(-6))
    arm_r.keyframe_insert(data_path="rotation_euler", frame=1)
    arm_r.rotation_euler = (math.radians(-9), math.radians(10), math.radians(-8))
    arm_r.keyframe_insert(data_path="rotation_euler", frame=20)
    arm_r.rotation_euler = (math.radians(-6), math.radians(8), math.radians(-6))
    arm_r.keyframe_insert(data_path="rotation_euler", frame=40)

if "UpperArm.L" in pose_bones:
    arm_l = pose_bones["UpperArm.L"]
    arm_l.rotation_mode = 'XYZ'
    arm_l.rotation_euler = (math.radians(3), math.radians(-6), math.radians(4))
    arm_l.keyframe_insert(data_path="rotation_euler", frame=1)
    arm_l.rotation_euler = (math.radians(1), math.radians(-4), math.radians(2))
    arm_l.keyframe_insert(data_path="rotation_euler", frame=20)
    arm_l.rotation_euler = (math.radians(3), math.radians(-6), math.radians(4))
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

# ==============================================================================
# 7. SALVAR ARQUIVO .BLEND E EXPORTAR .GLB COMPLETO
# ==============================================================================
bpy.ops.wm.save_as_mainfile(filepath=SAIDA_BLEND_FIX)
print(f"-> Arquivo .blend salvo com sucesso: {SAIDA_BLEND_FIX}")

bpy.ops.export_scene.gltf(
    filepath=SAIDA_GLB_FIX,
    export_format='GLB',
    export_skins=True,
    export_all_influences=True,
    export_animations=True,
    export_attributes=True,
    export_yup=True
)
print(f"-> Arquivo .glb corrigido e animável exportado: {SAIDA_GLB_FIX}")
print("=" * 70)
print("  PROCESSO UNIVERSAL CONCLUÍDO COM SUCESSO!")
print("=" * 70)
