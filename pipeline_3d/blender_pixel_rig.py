import bpy
import math
import os
from mathutils import Vector

# Caminho do arquivo gerado pelo Hunyuan3D-2 no pipeline_3d
CAMINHO_GLB = r"d:\Tenso\Documents\eden_project\pipeline_3d\guerreiro_3d.glb"
RESOLUCAO_PIXEL_ART = 256  # 128 ou 256 deixa os pixels bem visíveis estilo retrô HD-2D

# 1. Limpar cena e importar o modelo .GLB
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete()

bpy.ops.import_scene.gltf(filepath=CAMINHO_GLB)

# Encontrar o objeto Mesh importado
meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
if not meshes:
    raise Exception("Nenhuma malha encontrada no GLB!")

bpy.ops.object.select_all(action='DESELECT')
for m in meshes:
    m.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()

char_mesh = bpy.context.active_object
char_mesh.name = "Hero_25D_Mesh"

# Normalizar tamanho (2 metros de altura e pés no chão Z=0)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bbox = [char_mesh.matrix_world @ Vector(corner) for corner in char_mesh.bound_box]
min_z = min(v.z for v in bbox)
max_z = max(v.z for v in bbox)
altura_atual = max_z - min_z

fator_escala = 2.0 / altura_atual if altura_atual > 0 else 1.0
char_mesh.scale = (fator_escala, fator_escala, fator_escala)
bpy.ops.object.transform_apply(scale=True)

bbox = [char_mesh.matrix_world @ Vector(corner) for corner in char_mesh.bound_box]
min_z = min(v.z for v in bbox)
char_mesh.location.z -= min_z
bpy.ops.object.transform_apply(location=True)

# 2. Converter Material para HD Pixel Art 3D (Filtro Closest + Downscale)
for mat_slot in char_mesh.material_slots:
    mat = mat_slot.material
    if mat and mat.use_nodes:
        for node in mat.node_tree.nodes:
            if node.type == 'TEX_IMAGE' and node.image:
                # Pixelizar a textura para deixar os quadradinhos aparentes
                node.image.scale(RESOLUCAO_PIXEL_ART, RESOLUCAO_PIXEL_ART)
                # Trava a interpolação em 'Closest' (sem borrão linear!)
                node.interpolation = 'Closest'
            elif node.type == 'BSDF_PRINCIPLED':
                # Ajuste para iluminação 2.5D reagir bem às sombras
                node.inputs["Roughness"].default_value = 0.75

# 3. Otimizar malha para Game Engine e suavizar normais para Rigging
decimate = char_mesh.modifiers.new(name="Game_Optimization", type='DECIMATE')
decimate.ratio = 0.35 # Mantém 35% dos triângulos para deformar leve
bpy.ops.object.modifier_apply(modifier=decimate.name)

# 4. Criar Rig (Armature) adaptado às proporções da malha
bpy.ops.object.armature_add(enter_editmode=True, location=(0, 0, 0))
arm = bpy.context.active_object
arm.name = "Hero_25D_Rig"
arm.show_in_front = True
eb = arm.data.edit_bones
eb.remove(eb[0])

def add_bone(name, head, tail, parent=None, connect=False):
    b = eb.new(name)
    b.head = head
    b.tail = tail
    if parent and parent in eb:
        b.parent = eb[parent]
        b.use_connect = connect
    return b

# Esqueleto proporcionado para 2.0m de altura (alinhado à pose da arte)
add_bone("Root", (0, 0, 0), (0, 0.25, 0))
add_bone("Hips", (0, 0, 0.95), (0, 0, 1.15), "Root")
add_bone("Spine", (0, 0, 1.15), (0, 0, 1.42), "Hips", True)
add_bone("Chest", (0, 0, 1.42), (0, 0, 1.68), "Spine", True)
add_bone("Head", (0, 0, 1.68), (0, 0, 2.00), "Chest", True)

# Braços (Acompanhando a pose abaixada da imagem 2D)
for s, side in [(1, 'L'), (-1, 'R')]:
    add_bone(f"Shoulder.{side}", (s*0.12, 0, 1.60), (s*0.28, 0, 1.58), "Chest")
    add_bone(f"UpperArm.{side}", (s*0.28, 0, 1.58), (s*0.38, 0, 1.28), f"Shoulder.{side}", True)
    add_bone(f"Forearm.{side}", (s*0.38, 0, 1.28), (s*0.36, -0.08, 0.98), f"UpperArm.{side}", True)
    add_bone(f"Hand.{side}", (s*0.36, -0.08, 0.98), (s*0.35, -0.12, 0.85), f"Forearm.{side}", True)

    add_bone(f"Thigh.{side}", (s*0.14, 0, 0.95), (s*0.16, 0, 0.52), "Hips")
    add_bone(f"Shin.{side}", (s*0.16, 0, 0.52), (s*0.16, 0, 0.14), f"Thigh.{side}", True)
    add_bone(f"Foot.{side}", (s*0.16, 0, 0.14), (s*0.16, -0.22, 0.04), f"Shin.{side}", True)

# Osso extra para o facão na mão direita
add_bone("Weapon.R", (-0.35, -0.12, 0.85), (-0.42, -0.45, 0.45), "Hand.R")

bpy.ops.object.mode_set(mode='OBJECT')

# 5. Fazer o Bind Automático de Pesos (Automatic Weights)
bpy.ops.object.select_all(action='DESELECT')
char_mesh.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = arm
bpy.ops.object.parent_set(type='ARMATURE_AUTO')

print("Pipeline HD-2D Pixel Art + Rigging finalizado no Blender!")

saida_blend = os.path.splitext(CAMINHO_GLB)[0] + "_rigged.blend"
bpy.ops.wm.save_as_mainfile(filepath=saida_blend)
print(f"Arquivo Blender salvo com sucesso em: {saida_blend}")
