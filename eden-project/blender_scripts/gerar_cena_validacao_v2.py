"""
Script de Geração da Cena 2 HD Pixel Art 3D (Refinamento David Holland)
Implementa:
1. Soil_Block: Cubo sólido 1x1x1m com borda denteada de grama (overhang 0.035m),
   faixas horizontais de estratos no subsolo e corte de margem em X=0.0 (Z=0.85m).
2. Grass_Tuft: 50 lâminas densas de grama 3D sólida (3 segmentos cada, levemente arqueadas),
   com AlbedoCol.a codificando o peso de flexibilidade do vento (0.0 base, 1.0 ponta).
3. Riverbed: Leito de rio sólido escavado internamente (Z=0.32m) com bordas em Z=0.85m.
4. Water_Surface: Volume diorama completo (superfície superior 16x16 em Z=0.85m + paredes laterais verticais até Z=0.0m).
5. Rock_Submerged: Rocha facetada semi-submersa (Z=0.35m até 1.18m).
6. Ore_Crystals: Cristais verde-água salientes com facetas bem marcadas.

Exporta para cenario_validacao_v2.glb
"""

import bpy
import bmesh
import math
import random
from mathutils import Vector

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for col in bpy.data.collections:
        bpy.data.collections.remove(col)
    scene_col = bpy.data.collections.new("ValidationScene2")
    bpy.context.scene.collection.children.link(scene_col)

def clamp(val, min_val, max_val):
    return max(min_val, min(max_val, val))

def create_soil_tile_v2():
    """Tile 1: Bloco de Solo Sólido 1x1x1m com estratos horizontais chanfrados e borda denteada de grama"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x -= 0.5
        v.co.z += 0.5
        
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=5, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    
    random.seed(404)
    for v in bm.verts:
        is_top = abs(v.co.z - 1.0) < 0.005
        is_right = abs(v.co.x - 0.0) < 0.01  # Margem do rio
        is_left = abs(v.co.x - (-1.0)) < 0.01
        is_y_border = abs(abs(v.co.y) - 0.5) < 0.01
        
        # 1. Corte de margem na borda X perto de 0.0: desce 0.15m (Z = 0.85m)
        if is_top and v.co.x > -0.22:
            frac = (v.co.x - (-0.22)) / 0.22
            v.co.z = 1.0 - frac * 0.15
        elif is_top and not (is_left or is_y_border):
            v.co.z += random.uniform(-0.02, 0.02)
            
        # 2. Overhang denteado da grama nas laterais livres (esquerda e Y)
        if (0.76 < v.co.z < 0.98) and (is_left or is_y_border):
            lip = 0.038 + random.uniform(-0.006, 0.006)
            if is_left:
                v.co.x -= lip
            if is_y_border:
                v.co.y += lip if v.co.y > 0 else -lip
                
        # 3. Leves recuos/chanfros horizontais nos estratos de subsolo
        if (0.35 < v.co.z < 0.45) and (is_left or is_y_border):
            dent = 0.02
            if is_left:
                v.co.x += dent
            if is_y_border:
                v.co.y -= dent if v.co.y > 0 else -dent

    mesh = bpy.data.meshes.new("Mesh_Soil_v2")
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new("Soil_Block", mesh)
    bpy.data.collections["ValidationScene2"].objects.link(obj)
    
    # ÚNICO Color Attribute: AlbedoCol (RGB = cor, Alpha = peso do vento 0.0)
    col_attr = mesh.color_attributes.new(name="AlbedoCol", type='BYTE_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    col_grass = Vector((0.30, 0.64, 0.22))
    col_shore_dirt = Vector((0.44, 0.32, 0.18))
    col_topsoil = Vector((0.34, 0.22, 0.13))
    col_subsoil = Vector((0.24, 0.15, 0.10))
    col_bedrock = Vector((0.18, 0.14, 0.12))
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        cz = poly.center.z
        cx = poly.center.x
        jitter = random.uniform(0.95, 1.05)
        
        if poly.normal.z > 0.4:
            if cx > -0.18:
                c = col_shore_dirt * jitter
            else:
                c = col_grass * jitter
        elif cz > 0.74:
            c = col_grass * 0.92 * jitter # Borda denteada de grama
        elif cz > 0.48:
            c = col_topsoil * jitter
        elif cz > 0.22:
            c = col_subsoil * jitter
        else:
            c = col_bedrock * jitter
            
        for loop_idx in poly.loop_indices:
            col_attr.data[loop_idx].color = (min(c.x, 1.0), min(c.y, 1.0), min(c.z, 1.0), 0.0)
            
    return obj

def create_dense_grass_tuft():
    """Gera 50 lâminas de grama densas com 3 segmentos arqueados cobrindo o topo do solo"""
    bm = bmesh.new()
    random.seed(777)
    
    base_center = Vector((-0.55, 0.0, 1.0))
    
    # 50 lâminas distribuídas sobre o bloco de terra
    for i in range(50):
        # Distribui pelo topo do bloco (X de -0.9 a -0.25, Y de -0.38 a 0.38)
        root_x = random.uniform(-0.88, -0.26)
        root_y = random.uniform(-0.38, 0.38)
        root_pos = Vector((root_x, root_y, 1.0))
        
        angle = random.uniform(0, math.pi * 2.0)
        height = random.uniform(0.30, 0.48)
        width = random.uniform(0.035, 0.065)
        tilt = random.uniform(0.10, 0.28)
        
        side_dir = Vector((-math.sin(angle), math.cos(angle), 0.0)).normalized() * (width * 0.5)
        fwd_dir = Vector((math.cos(angle), math.sin(angle), 0.0)).normalized() * tilt
        
        # 3 Segmentos:
        # 1. Base (Z=1.0)
        v0 = bm.verts.new(root_pos - side_dir)
        v1 = bm.verts.new(root_pos + side_dir)
        
        # 2. Meio (Z=1.0 + height*0.5)
        mid_pos = root_pos + fwd_dir * 0.5 + Vector((0, 0, height * 0.5))
        v2 = bm.verts.new(mid_pos - side_dir * 0.65)
        v3 = bm.verts.new(mid_pos + side_dir * 0.65)
        
        # 3. Ponta (Z=1.0 + height)
        tip_pos = root_pos + fwd_dir * 1.2 + Vector((0, 0, height))
        v4 = bm.verts.new(tip_pos)
        
        bm.faces.new((v0, v1, v3, v2))
        bm.faces.new((v2, v3, v4))
        
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    
    mesh = bpy.data.meshes.new("Mesh_GrassTuft_v2")
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new("Grass_Tuft", mesh)
    bpy.data.collections["ValidationScene2"].objects.link(obj)
    
    col_attr = mesh.color_attributes.new(name="AlbedoCol", type='BYTE_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    col_root = Vector((0.14, 0.36, 0.18))
    col_tip = Vector((0.50, 0.88, 0.24))
    custom_normals = []
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        for loop_idx in poly.loop_indices:
            loop = mesh.loops[loop_idx]
            v = mesh.vertices[loop.vertex_index]
            
            # Fator de altura (0.0 na raiz Z=1.0, 1.0 na ponta Z>=1.35)
            h = clamp((v.co.z - 1.0) / 0.35, 0.0, 1.0)
            c = col_root.lerp(col_tip, h)
            
            # RGB = cor do vértice, A = flexibilidade do vento (0 na base, 1 na ponta!)
            col_attr.data[loop_idx].color = (c.x, c.y, c.z, h)
            custom_normals.append(Vector((0.0, 0.0, 1.0)))
            
    mesh.normals_split_custom_set(custom_normals)
    return obj

def create_riverbed_tile_v2():
    """Tile 2: Leito do rio sólido escavado internamente"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x += 0.5
        v.co.z += 0.5
        
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=5, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    
    random.seed(505)
    for v in bm.verts:
        if abs(v.co.z - 1.0) < 0.005:
            dist_border = min(abs(v.co.x - 0.0), abs(v.co.x - 1.0), abs(v.co.y - (-0.5)), abs(v.co.y - 0.5))
            if dist_border < 0.01:
                v.co.z = 0.85
            else:
                center_dist = math.sqrt((v.co.x - 0.5)**2 + v.co.y**2)
                v.co.z = 0.30 + min(0.55, center_dist * 0.95) + random.uniform(-0.015, 0.015)
        elif v.co.z > 0.85:
            v.co.z = 0.85

    mesh = bpy.data.meshes.new("Mesh_Riverbed_v2")
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new("Riverbed", mesh)
    bpy.data.collections["ValidationScene2"].objects.link(obj)
    
    col_attr = mesh.color_attributes.new(name="AlbedoCol", type='BYTE_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    col_deep_mud = Vector((0.20, 0.22, 0.26))
    col_bed_sand = Vector((0.40, 0.36, 0.28))
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        jitter = random.uniform(0.94, 1.06)
        depth_fac = clamp((poly.center.z - 0.30) / 0.55, 0.0, 1.0)
        c = col_deep_mud.lerp(col_bed_sand, depth_fac) * jitter
        for loop_idx in poly.loop_indices:
            col_attr.data[loop_idx].color = (c.x, c.y, c.z, 0.0)
            
    return obj

def create_diorama_water_volume():
    """Volume Diorama da Água: Superfície superior 16x16 em Z=0.85m + paredes laterais verticais até Z=0.0m"""
    bm = bmesh.new()
    
    # 1. Cria grid superior em Z = 0.85m
    bmesh.ops.create_grid(bm, x_segments=16, y_segments=16, size=0.5)
    for v in bm.verts:
        v.co.x += 0.5
        v.co.z = 0.85
        
    # 2. Cria paredes laterais verticais (diorama cut / aquário em corte)
    # Paredes em X=1.0, Y=-0.5 e Y=0.5 descendo de Z=0.85m até Z=0.0m
    # (A face X=0.0 encontra a margem de terra)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    
    # Coleta bordas externas para extrusão lateral
    boundary_edges = [e for e in bm.edges if e.is_boundary]
    
    # Cria vértices inferiores para as laterais visíveis no diorama
    # Lado X = 1.0
    v_b1 = bm.verts.new(Vector((1.0, -0.5, 0.0)))
    v_b2 = bm.verts.new(Vector((1.0, 0.5, 0.0)))
    # Lado Y = -0.5
    v_b0 = bm.verts.new(Vector((0.0, -0.5, 0.0)))
    # Lado Y = 0.5
    v_b3 = bm.verts.new(Vector((0.0, 0.5, 0.0)))
    
    # Vértices do topo correspondentes
    v_t0 = min(bm.verts, key=lambda v: (v.co - Vector((0.0, -0.5, 0.85))).length)
    v_t1 = min(bm.verts, key=lambda v: (v.co - Vector((1.0, -0.5, 0.85))).length)
    v_t2 = min(bm.verts, key=lambda v: (v.co - Vector((1.0, 0.5, 0.85))).length)
    v_t3 = min(bm.verts, key=lambda v: (v.co - Vector((0.0, 0.5, 0.85))).length)
    
    # Paredes laterais (quads triangulados)
    bm.faces.new((v_t0, v_t1, v_b1, v_b0)) # Face Y = -0.5
    bm.faces.new((v_t1, v_t2, v_b2, v_b1)) # Face X = 1.0
    bm.faces.new((v_t2, v_t3, v_b3, v_b2)) # Face Y = 0.5
    
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("Mesh_WaterDiorama_v2")
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new("Water_Surface", mesh)
    bpy.data.collections["ValidationScene2"].objects.link(obj)
    
    col_attr = mesh.color_attributes.new(name="AlbedoCol", type='BYTE_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    # Flow direction em +X
    for loop in mesh.loops:
        col_attr.data[loop.index].color = (1.0, 0.5, 0.0, 1.0)
        
    return obj

def create_submerged_rock_and_luminous_crystals():
    """Rocha facetada com veio de cristais verde-água luminosos"""
    # 1. Rocha Base
    bm_rock = bmesh.new()
    bmesh.ops.create_icosphere(bm_rock, subdivisions=2, radius=0.36)
    
    random.seed(616)
    for _ in range(7):
        plane_no = Vector((random.uniform(-1, 1), random.uniform(-1, 1), random.uniform(0.1, 1))).normalized()
        plane_co = plane_no * random.uniform(0.22, 0.30)
        bmesh.ops.bisect_plane(bm_rock, geom=bm_rock.verts[:]+bm_rock.edges[:]+bm_rock.faces[:],
                               plane_co=plane_co, plane_no=plane_no, clear_outer=True)
        bmesh.ops.holes_fill(bm_rock, edges=[e for e in bm_rock.edges if e.is_boundary])
        
    center_pos = Vector((0.52, -0.02, 0.76))
    for v in bm_rock.verts:
        v.co.z *= 1.35
        v.co += center_pos
        
    bmesh.ops.triangulate(bm_rock, faces=bm_rock.faces[:])
    mesh_rock = bpy.data.meshes.new("Mesh_Rock_v2")
    bm_rock.to_mesh(mesh_rock)
    bm_rock.free()
    
    obj_rock = bpy.data.objects.new("Rock_Submerged", mesh_rock)
    bpy.data.collections["ValidationScene2"].objects.link(obj_rock)
    
    col_attr_rock = mesh_rock.color_attributes.new(name="AlbedoCol", type='BYTE_COLOR', domain='CORNER')
    mesh_rock.color_attributes.active_color_name = "AlbedoCol"
    
    col_dry = Vector((0.54, 0.56, 0.60))
    col_wet_line = Vector((0.28, 0.30, 0.35))
    col_underwater = Vector((0.18, 0.20, 0.24))
    
    for poly in mesh_rock.polygons:
        poly.use_smooth = False
        cz = poly.center.z
        jitter = random.uniform(0.95, 1.05)
        if cz > 0.90:
            c = col_dry * jitter
        elif cz > 0.82:
            c = col_wet_line * jitter
        else:
            c = col_underwater * jitter
            
        for loop_idx in poly.loop_indices:
            col_attr_rock.data[loop_idx].color = (c.x, c.y, c.z, 0.0)

    # 2. Cristais Verde-Água Luminosos
    bm_cryst = bmesh.new()
    crystal_origins = [
        Vector((0.64, 0.02, 0.96)),
        Vector((0.60, 0.10, 0.88)),
        Vector((0.42, -0.12, 0.93)),
        Vector((0.54, -0.16, 0.82)),
        Vector((0.46, 0.08, 1.05)),
    ]
    
    for origin in crystal_origins:
        dir_out = (origin - center_pos).normalized()
        cryst_verts = bmesh.ops.create_cone(bm_cryst, cap_ends=True, segments=5, 
                                            radius1=0.065, radius2=0.005, depth=0.22)["verts"]
        rot_quat = Vector((0, 0, 1)).rotation_difference(dir_out)
        for v in cryst_verts:
            v.co = rot_quat @ v.co + origin + dir_out * 0.06
            
    bmesh.ops.triangulate(bm_cryst, faces=bm_cryst.faces[:])
    mesh_cryst = bpy.data.meshes.new("Mesh_Crystals_v2")
    bm_cryst.to_mesh(mesh_cryst)
    bm_cryst.free()
    
    obj_cryst = bpy.data.objects.new("Ore_Crystals", mesh_cryst)
    bpy.data.collections["ValidationScene2"].objects.link(obj_cryst)
    
    col_attr_cryst = mesh_cryst.color_attributes.new(name="AlbedoCol", type='BYTE_COLOR', domain='CORNER')
    mesh_cryst.color_attributes.active_color_name = "AlbedoCol"
    
    # Cristal Verde-Água Luminoso
    cryst_base = Vector((0.35, 0.95, 0.78))
    cryst_tip = Vector((0.92, 1.0, 0.96))
    
    for poly in mesh_cryst.polygons:
        poly.use_smooth = False
        bright = 1.25 if poly.normal.z > 0.2 else 0.85
        c = cryst_base.lerp(cryst_tip, clamp(poly.normal.z, 0.0, 1.0)) * bright
        for loop_idx in poly.loop_indices:
            col_attr_cryst.data[loop_idx].color = (min(c.x, 1.0), min(c.y, 1.0), min(c.z, 1.0), 1.0)
            
    return obj_rock, obj_cryst

def main():
    reset_scene()
    print("[1/5] Gerando Solo Refinado v2...")
    create_soil_tile_v2()
    
    print("[2/5] Gerando Grama Densa (50 lâminas, 3 segmentos)...")
    create_dense_grass_tuft()
    
    print("[3/5] Gerando Leito do Rio...")
    create_riverbed_tile_v2()
    
    print("[4/5] Gerando Volume Diorama da Água...")
    create_diorama_water_volume()
    
    print("[5/5] Gerando Rocha e Cristais Verde-Água...")
    create_submerged_rock_and_luminous_crystals()
    
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    
    export_path = "d:/Tenso/Documents/eden_project/cenarios_hd_pixelart_3d/cenario_validacao_v2.glb"
    print(f"Exportando cena refinada para {export_path}...")
    bpy.ops.export_scene.gltf(
        filepath=export_path,
        export_format='GLB',
        use_selection=False,
        export_normals=True,
        export_all_vertex_colors=True,
        export_attributes=True,
        export_yup=True
    )
    print("Exportação da Cena 2 concluída com sucesso!")

if __name__ == "__main__":
    main()
