"""
Script de Geração da Cena de Validação HD Pixel Art 3D (Sólida e Estanque)
Gera 1 tile de cada categoria lado a lado:
1. Soil_Block: Cubo sólido 1x1x1m com corte de margem em X=0.0 (Z=0.85m) e overhang de grama
2. Riverbed: Cubo sólido 1x1x1m escavado internamente (Z=0.35m) com bordas estanques em Z=0.85m
3. Water_Surface: Lâmina d'água subdividida 16x16 em Z=0.85m com FlowData
4. Rock_Submerged: Rocha facetada semi-submersa (Z=0.35m até 1.18m)
5. Ore_Crystals: Cristais salientes facetados brotando da rocha
6. Grass_Tuft: Tufo de grama 3D sólida com Up-Normals e WeatherData
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
    scene_col = bpy.data.collections.new("ValidationScene")
    bpy.context.scene.collection.children.link(scene_col)

def create_soil_tile_with_shoreline():
    """Tile 1: Bloco de Solo Sólido 1x1x1m [X: -1.0 a 0.0, Y: -0.5 a 0.5, Z: 0.0 a 1.0]"""
    bm = bmesh.new()
    # Cria cubo sólido 1x1x1m
    bmesh.ops.create_cube(bm, size=1.0)
    # Move para X=[-1.0, 0.0], Y=[-0.5, 0.5], Z=[0.0, 1.0]
    for v in bm.verts:
        v.co.x -= 0.5
        v.co.z += 0.5
        
    # Subdivide edges para criar relevo e estratos
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=5, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    
    random.seed(101)
    for v in bm.verts:
        is_top = abs(v.co.z - 1.0) < 0.005
        is_right_border = abs(v.co.x - 0.0) < 0.01 # Lado voltado para a água
        is_left_border = abs(v.co.x - (-1.0)) < 0.01
        is_y_border = abs(abs(v.co.y) - 0.5) < 0.01
        
        # 1. Corte de margem na borda X perto de 0.0: desce 0.15m (Z = 0.85m)
        if is_top and v.co.x > -0.22:
            frac = (v.co.x - (-0.22)) / 0.22
            v.co.z = 1.0 - frac * 0.15
        elif is_top and not (is_left_border or is_y_border):
            v.co.z += random.uniform(-0.025, 0.025)
            
        # 2. Overhang lip da grama nas laterais livres (esquerda e Y)
        if (0.75 < v.co.z < 0.98) and (is_left_border or is_y_border):
            if is_left_border:
                v.co.x -= 0.035
            if is_y_border:
                v.co.y += 0.035 if v.co.y > 0 else -0.035

    mesh = bpy.data.meshes.new("Mesh_Soil")
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new("Soil_Block", mesh)
    bpy.data.collections["ValidationScene"].objects.link(obj)
    
    # Cores de Vértice
    col_attr = mesh.color_attributes.new(name="AlbedoCol", type='BYTE_COLOR', domain='CORNER')
    weather_attr = mesh.color_attributes.new(name="WeatherData", type='BYTE_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    col_grass = Vector((0.30, 0.62, 0.24))
    col_shore_dirt = Vector((0.44, 0.32, 0.20))
    col_topsoil = Vector((0.35, 0.23, 0.14))
    col_subsoil = Vector((0.26, 0.16, 0.11))
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        center_z = poly.center.z
        center_x = poly.center.x
        jitter = random.uniform(0.95, 1.05)
        
        if poly.normal.z > 0.4:
            if center_x > -0.18:
                c = col_shore_dirt * jitter
            else:
                c = col_grass * jitter
        elif center_z > 0.68:
            c = col_topsoil * jitter
        else:
            c = col_subsoil * jitter
            
        rain_mask = 1.0 if poly.normal.z > 0.3 else 0.5
        for loop_idx in poly.loop_indices:
            col_attr.data[loop_idx].color = (min(c.x, 1.0), min(c.y, 1.0), min(c.z, 1.0), 1.0)
            weather_attr.data[loop_idx].color = (0.0, 0.0, 0.0, rain_mask)
            
    return obj

def create_riverbed_tile():
    """Tile 2: Leito do Rio Sólido 1x1x1m [X: 0.0 a 1.0, Y: -0.5 a 0.5, Z: 0.0 a 0.85m]"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x += 0.5
        v.co.z += 0.5
        
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=5, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    
    random.seed(202)
    for v in bm.verts:
        # Altura do topo do leito é em Z = 0.85m (alinha com a margem do solo)
        if abs(v.co.z - 1.0) < 0.005:
            dist_border = min(abs(v.co.x - 0.0), abs(v.co.x - 1.0), abs(v.co.y - (-0.5)), abs(v.co.y - 0.5))
            if dist_border < 0.01:
                v.co.z = 0.85
            else:
                # Centro escavado até Z = 0.32m
                center_dist = math.sqrt((v.co.x - 0.5)**2 + v.co.y**2)
                v.co.z = 0.32 + min(0.53, center_dist * 0.95) + random.uniform(-0.02, 0.02)
        elif v.co.z > 0.85:
            v.co.z = 0.85 # Ajusta paredes para não passarem da margem

    mesh = bpy.data.meshes.new("Mesh_Riverbed")
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new("Riverbed", mesh)
    bpy.data.collections["ValidationScene"].objects.link(obj)
    
    col_attr = mesh.color_attributes.new(name="AlbedoCol", type='BYTE_COLOR', domain='CORNER')
    weather_attr = mesh.color_attributes.new(name="WeatherData", type='BYTE_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    col_deep_mud = Vector((0.20, 0.22, 0.26))
    col_pebble_gray = Vector((0.36, 0.34, 0.32))
    col_bed_sand = Vector((0.42, 0.38, 0.28))
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        jitter = random.uniform(0.93, 1.07)
        depth_fac = clamp((poly.center.z - 0.32) / 0.53, 0.0, 1.0)
        c = col_deep_mud.lerp(col_bed_sand, depth_fac) * jitter
        for loop_idx in poly.loop_indices:
            col_attr.data[loop_idx].color = (c.x, c.y, c.z, 1.0)
            weather_attr.data[loop_idx].color = (0.0, 0.0, 0.0, 1.0)
            
    return obj

def create_water_surface():
    """Lâmina d'Água: Plano subdividido 16x16 em Z = 0.85m de X=[0.0, 1.0], Y=[-0.5, 0.5]"""
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=16, y_segments=16, size=0.5)
    for v in bm.verts:
        v.co.x += 0.5
        v.co.z = 0.85
        
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new("Mesh_WaterSurface")
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new("Water_Surface", mesh)
    bpy.data.collections["ValidationScene"].objects.link(obj)
    
    flow_attr = mesh.color_attributes.new(name="FlowData", type='BYTE_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "FlowData"
    
    # Correnteza em +X
    for loop in mesh.loops:
        flow_attr.data[loop.index].color = (1.0, 0.5, 0.0, 1.0)
        
    return obj

def create_submerged_rock_and_crystals():
    """Rocha facetada assentada no fundo (Z=0.35m) e emergindo até Z=1.16m"""
    # 1. Rocha
    bm_rock = bmesh.new()
    bmesh.ops.create_icosphere(bm_rock, subdivisions=2, radius=0.36)
    
    random.seed(333)
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
    mesh_rock = bpy.data.meshes.new("Mesh_Rock")
    bm_rock.to_mesh(mesh_rock)
    bm_rock.free()
    
    obj_rock = bpy.data.objects.new("Rock_Submerged", mesh_rock)
    bpy.data.collections["ValidationScene"].objects.link(obj_rock)
    
    col_attr_rock = mesh_rock.color_attributes.new(name="AlbedoCol", type='BYTE_COLOR', domain='CORNER')
    weather_attr_rock = mesh_rock.color_attributes.new(name="WeatherData", type='BYTE_COLOR', domain='CORNER')
    mesh_rock.color_attributes.active_color_name = "AlbedoCol"
    
    col_dry = Vector((0.54, 0.55, 0.60))
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
            
        rain_mask = 1.0 if poly.normal.z > 0.3 and cz > 0.85 else 0.4
        for loop_idx in poly.loop_indices:
            col_attr_rock.data[loop_idx].color = (c.x, c.y, c.z, 1.0)
            weather_attr_rock.data[loop_idx].color = (0.0, 0.0, 0.0, rain_mask)

    # 2. Cristais / Veio de Minério
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
    mesh_cryst = bpy.data.meshes.new("Mesh_Crystals")
    bm_cryst.to_mesh(mesh_cryst)
    bm_cryst.free()
    
    obj_cryst = bpy.data.objects.new("Ore_Crystals", mesh_cryst)
    bpy.data.collections["ValidationScene"].objects.link(obj_cryst)
    
    col_attr_cryst = mesh_cryst.color_attributes.new(name="AlbedoCol", type='BYTE_COLOR', domain='CORNER')
    mesh_cryst.color_attributes.active_color_name = "AlbedoCol"
    
    cryst_base = Vector((0.20, 0.72, 0.95))
    cryst_tip = Vector((0.85, 0.98, 1.0))
    
    for poly in mesh_cryst.polygons:
        poly.use_smooth = False
        bright = 1.25 if poly.normal.z > 0.2 else 0.85
        c = cryst_base.lerp(cryst_tip, clamp(poly.normal.z, 0.0, 1.0)) * bright
        for loop_idx in poly.loop_indices:
            col_attr_cryst.data[loop_idx].color = (min(c.x, 1.0), min(c.y, 1.0), min(c.z, 1.0), 1.0)
            
    return obj_rock, obj_cryst

def create_grass_tuft():
    """Tufo de grama 3D sólida sobre o solo com Up-Normals e WeatherData"""
    bm = bmesh.new()
    random.seed(999)
    base_center = Vector((-0.55, 0.05, 1.0))
    
    for i in range(16):
        angle = (i / 16.0) * math.pi * 2.0 + random.uniform(-0.15, 0.15)
        tilt = random.uniform(0.12, 0.32)
        height = random.uniform(0.35, 0.55)
        width = random.uniform(0.045, 0.075)
        offset_rad = random.uniform(0.02, 0.14)
        
        root_pos = base_center + Vector((math.cos(angle) * offset_rad, math.sin(angle) * offset_rad, 0.0))
        side_dir = Vector((-math.sin(angle), math.cos(angle), 0.0)).normalized() * (width * 0.5)
        forward_dir = Vector((math.cos(angle), math.sin(angle), 0.0)).normalized() * tilt
        
        v0 = bm.verts.new(root_pos - side_dir)
        v1 = bm.verts.new(root_pos + side_dir)
        mid_pos = root_pos + forward_dir * 0.5 + Vector((0, 0, height * 0.55))
        v2 = bm.verts.new(mid_pos - side_dir * 0.65)
        v3 = bm.verts.new(mid_pos + side_dir * 0.65)
        tip_pos = root_pos + forward_dir + Vector((0, 0, height))
        v4 = bm.verts.new(tip_pos)
        
        bm.faces.new((v0, v1, v3, v2))
        bm.faces.new((v2, v3, v4))
        
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    
    mesh = bpy.data.meshes.new("Mesh_GrassTuft")
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new("Grass_Tuft", mesh)
    bpy.data.collections["ValidationScene"].objects.link(obj)
    
    col_attr = mesh.color_attributes.new(name="AlbedoCol", type='BYTE_COLOR', domain='CORNER')
    weather_attr = mesh.color_attributes.new(name="WeatherData", type='BYTE_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    col_root = Vector((0.14, 0.35, 0.18))
    col_tip = Vector((0.48, 0.85, 0.22))
    custom_normals = []
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        island_phase = random.uniform(0.0, 1.0)
        for loop_idx in poly.loop_indices:
            loop = mesh.loops[loop_idx]
            v = mesh.vertices[loop.vertex_index]
            h = clamp((v.co.z - 1.0) / 0.55, 0.0, 1.0)
            c = col_root.lerp(col_tip, h)
            col_attr.data[loop_idx].color = (c.x, c.y, c.z, 1.0)
            weather_attr.data[loop_idx].color = (h, h, island_phase, 1.0)
            custom_normals.append(Vector((0.0, 0.0, 1.0)))
            
    mesh.normals_split_custom_set(custom_normals)
    return obj

def clamp(val, min_val, max_val):
    return max(min_val, min(max_val, val))

def main():
    reset_scene()
    print("[1/5] Gerando Bloco de Solo Sólido...")
    create_soil_tile_with_shoreline()
    
    print("[2/5] Gerando Tufo de Grama 3D sólida...")
    create_grass_tuft()
    
    print("[3/5] Gerando Leito de Rio Sólido...")
    create_riverbed_tile()
    
    print("[4/5] Gerando Lâmina d'Água 16x16...")
    create_water_surface()
    
    print("[5/5] Gerando Rocha Semi-submersa com Cristais...")
    create_submerged_rock_and_crystals()
    
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    
    export_path = "d:/Tenso/Documents/eden_project/cenarios_hd_pixelart_3d/cenario_validacao.glb"
    print(f"Exportando cena para {export_path}...")
    bpy.ops.export_scene.gltf(
        filepath=export_path,
        export_format='GLB',
        use_selection=False,
        export_normals=True,
        export_all_vertex_colors=True,
        export_attributes=True,
        export_yup=True
    )
    print("Exportação concluída com sucesso!")

if __name__ == "__main__":
    main()
