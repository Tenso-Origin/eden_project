import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix, Euler

def hex_to_rgb(hex_str, alpha=1.0):
    hex_str = hex_str.lstrip('#')
    r = int(hex_str[0:2], 16) / 255.0
    g = int(hex_str[2:4], 16) / 255.0
    b = int(hex_str[4:6], 16) / 255.0
    return (r, g, b, alpha)

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def create_color_attribute(obj, name="AlbedoCol", default_color=(1.0, 1.0, 1.0, 1.0)):
    mesh = obj.data
    color_attr = mesh.color_attributes.new(
        name=name,
        type='FLOAT_COLOR',
        domain='CORNER'
    )
    mesh.color_attributes.active_color_name = name
    for i in range(len(color_attr.data)):
        color_attr.data[i].color = default_color
    return color_attr

def set_flat_shading(obj):
    for poly in obj.data.polygons:
        poly.use_smooth = False

def create_water_surface():
    """
    Superfície da água: plano subdividido de 16x12m no Z local = 0.0.
    No Godot, o nó Water_Surface tem sua altura Y variada entre -0.8m e -0.2m (maré procedural).
    """
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, 0, 0))
    obj = bpy.context.active_object
    obj.name = "Water_Surface"
    obj.data.name = "Water_Surface"
    obj.scale = (16.0, 12.0, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.subdivide(number_cuts=23)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    create_color_attribute(obj, "AlbedoCol", (0.18, 0.68, 0.82, 0.88))
    set_flat_shading(obj)
    return obj

def create_sand_riverbed():
    """
    Leito de Areia Modular (16x12m) por 1.0m de altura:
    - Face superior dos blocos de areia cravada em Z = -1.0m.
    - Face inferior em Z = -2.0m.
    - Grade modular com chanfros de 0.025m no topo para acentuar contornos 1px do pixel_outline.
    - Variação tonal de areia (ouro/bege/areia molhada) com sombras suaves sob estruturas.
    """
    bm = bmesh.new()
    
    # Grid 16x12 blocos de 1x1m
    grid_w = 16
    grid_d = 12
    start_x = -grid_w / 2.0
    start_y = -grid_d / 2.0
    
    # Pontos de sombra sob as ruínas e ilha para tingimento escuro de areia
    shadow_centers = [
        Vector((0.0, 0.0)),     # Ilha
        Vector((-3.2, -1.8)),   # Pilar SW
        Vector((3.1, 2.2)),     # Pilar NE
        Vector((-5.2, 3.4)),    # Pilar NW
        Vector((-1.65, 1.45)),  # Rocha NW
        Vector((1.55, 1.45))    # Rocha NE
    ]
    shadow_radii = [2.2, 1.5, 1.5, 1.5, 1.3, 1.3]
    
    # Paleta de areia
    sand_base = Vector(hex_to_rgb("#d4ba85")[:3])
    sand_light = Vector(hex_to_rgb("#e3cc96")[:3])
    sand_wet = Vector(hex_to_rgb("#b89d6c")[:3])
    sand_shadow = Vector(hex_to_rgb("#7a6542")[:3])
    
    block_size = 1.0
    block_h = 1.0 # 1m de altura (Z de -2.0 a -1.0)
    top_z = -1.0
    bot_z = -2.0
    
    for gx in range(grid_w):
        for gy in range(grid_d):
            cx = start_x + gx * block_size + block_size * 0.5
            cy = start_y + gy * block_size + block_size * 0.5
            
            # Sutil ondulação nas dunas centrais (sem quebrar a costura nas bordas)
            dist_edge_x = min(gx, grid_w - 1 - gx)
            dist_edge_y = min(gy, grid_d - 1 - gy)
            edge_dist = min(dist_edge_x, dist_edge_y)
            
            dune_offset = 0.0
            if edge_dist > 1:
                # Variação suave de relevo de dunas de areia de até +/- 0.035m
                dune_offset = (math.sin(cx * 0.8) * math.cos(cy * 0.8)) * 0.035
            
            b_top = top_z + dune_offset
            
            # Cria cubo do bloco
            bm_block = bmesh.new()
            bmesh.ops.create_cube(bm_block, size=1.0)
            
            # Ajusta vértices para dimensão 1x1x1m com leve bisel de 0.02m no topo
            bevel_inset = 0.015
            for v in bm_block.verts:
                # Normaliza cubo centrado em (0,0,0)
                is_top = (v.co.z > 0.0)
                shrink = (1.0 - bevel_inset * 2.0) if is_top else 1.0
                
                v.co.x = cx + v.co.x * block_size * shrink
                v.co.y = cy + v.co.y * block_size * shrink
                v.co.z = b_top if is_top else bot_z
            
            # Adiciona ao bmesh principal
            for f in bm_block.faces:
                bm.faces.new([bm.verts.new(v.co) for v in f.verts])
            bm_block.free()
            
    mesh = bpy.data.meshes.new("Riverbed")
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new("Riverbed", mesh)
    bpy.context.collection.objects.link(obj)
    set_flat_shading(obj)
    
    attr = mesh.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        is_top = (poly.normal.z > 0.5)
        
        # Posição central do polígono
        poly_center = Vector((0.0, 0.0, 0.0))
        for loop_idx in poly.loop_indices:
            v_idx = mesh.loops[loop_idx].vertex_index
            poly_center += mesh.vertices[v_idx].co
        poly_center /= float(len(poly.loop_indices))
        
        # Fator de sombra
        c_2d = Vector((poly_center.x, poly_center.y))
        shadow_weight = 0.0
        for sc, sr in zip(shadow_centers, shadow_radii):
            dist = (c_2d - sc).length
            if dist < sr:
                shadow_weight = max(shadow_weight, 1.0 - (dist / sr))
        
        # Variação pseudo-aleatória sutil por face (mosaico pixel art)
        hash_val = math.sin(poly_center.x * 12.9898 + poly_center.y * 78.233) * 43758.5453
        tint_noise = (hash_val - math.floor(hash_val)) * 0.14 - 0.07
        
        if is_top:
            col = sand_base.lerp(sand_light, 0.3 + tint_noise)
            if shadow_weight > 0.0:
                col = col.lerp(sand_shadow, shadow_weight * 0.85)
        else:
            col = sand_wet.lerp(sand_shadow, 0.4 + shadow_weight * 0.4)
            
        for loop_idx in poly.loop_indices:
            attr.data[loop_idx].color = (col.x, col.y, col.z, 1.0)
            
    return obj

def create_soil_island():
    """
    Ilha Central apoiada no leito de areia (Z = -1.0m) e subindo até Z = +0.15m.
    - Base assenta perfeitamente sobre a areia.
    - Camada subterrânea de argila/rocha submersa.
    - Camada superior de terra fértil com topo de grama verde (#4e7a32) em Z = +0.15m.
    """
    bm = bmesh.new()
    
    # Camada 1: Base submersa de rocha/solo firme (Z de -1.0m a -0.4m, raio 1.35x1.25m)
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=True,
        segments=10,
        radius1=1.40,
        radius2=1.30,
        depth=0.60
    )
    for v in bm.verts:
        v.co.x *= 1.15
        v.co.y *= 1.05
        v.co.z = (v.co.z + 0.30) - 1.0 # Base em -1.0m, topo em -0.4m
        
    # Camada 2: Solo fértil superior que emerge da água (Z de -0.4m a +0.15m, altura 0.55m)
    bm_top = bmesh.new()
    bmesh.ops.create_cone(
        bm_top,
        cap_ends=True,
        cap_tris=True,
        segments=10,
        radius1=1.28,
        radius2=1.18,
        depth=0.55
    )
    for v in bm_top.verts:
        v.co.x *= 1.12
        v.co.y *= 1.02
        v.co.z = (v.co.z + 0.275) - 0.4 # Base em -0.4m, topo em +0.15m
        
    for f in bm_top.faces:
        bm.faces.new([bm.verts.new(v.co) for v in f.verts])
    bm_top.free()
    
    mesh = bpy.data.meshes.new("Soil_Island")
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new("Soil_Island", mesh)
    bpy.context.collection.objects.link(obj)
    set_flat_shading(obj)
    
    attr = mesh.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    grass_col = hex_to_rgb("#4e7a32")
    soil_upper = hex_to_rgb("#543d2b")
    soil_submerged = hex_to_rgb("#382a1e")
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        is_top = (poly.normal.z > 0.5)
        
        # Média Z
        z_avg = sum([mesh.vertices[mesh.loops[li].vertex_index].co.z for li in poly.loop_indices]) / len(poly.loop_indices)
        
        if is_top and z_avg > 0.05:
            col = grass_col
        elif z_avg < -0.35:
            col = soil_submerged
        else:
            col = soil_upper
            
        for loop_idx in poly.loop_indices:
            attr.data[loop_idx].color = col
            
    return obj

def create_tree():
    """
    Árvore com tronco apoiado na ilha (Z = +0.15m) e copa orgânica escalonada.
    """
    # 1. Tronco: cilindro de 6 lados iniciando em Z = +0.15m e subindo até Z = +1.35m (altura 1.2m)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6,
        radius=0.28,
        depth=1.2,
        location=(0.0, 0.0, 0.75) # Centro em 0.75m -> base em 0.15m, topo em 1.35m
    )
    trunk = bpy.context.active_object
    trunk.name = "Tree_Trunk"
    trunk.data.name = "Tree_Trunk"
    set_flat_shading(trunk)
    
    t_attr = trunk.data.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    trunk.data.color_attributes.active_color_name = "AlbedoCol"
    
    birch_col = hex_to_rgb("#e0dcd5")
    dark_patch = hex_to_rgb("#3a353a")
    
    for poly in trunk.data.polygons:
        poly.use_smooth = False
        for loop_idx in poly.loop_indices:
            v_idx = trunk.data.loops[loop_idx].vertex_index
            z = trunk.data.vertices[v_idx].co.z
            t_attr.data[loop_idx].color = dark_patch if z < 0.35 else birch_col

    # 2. Copa: clusters low-poly icosphere mesclados (ajustados para topo do tronco em 1.35m)
    spheres = []
    
    # Cluster inferior
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.1, location=(0.0, 0.0, 1.70))
    s1 = bpy.context.active_object
    s1.scale = (1.1, 1.05, 0.75)
    bpy.ops.object.transform_apply(scale=True)
    spheres.append(s1)
    
    # Cluster médio
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(0.0, 0.0, 2.30))
    s2 = bpy.context.active_object
    s2.scale = (0.95, 0.9, 0.9)
    bpy.ops.object.transform_apply(scale=True)
    spheres.append(s2)
    
    # Cone topo
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.75, location=(0.0, 0.0, 3.00))
    s3 = bpy.context.active_object
    s3.scale = (0.7, 0.7, 0.85)
    bpy.ops.object.transform_apply(scale=True)
    spheres.append(s3)
    
    # Saliências laterais para silhueta orgânica
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.65, location=(-0.45, 0.25, 1.95))
    s4 = bpy.context.active_object
    spheres.append(s4)

    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.6, location=(0.5, -0.2, 2.05))
    s5 = bpy.context.active_object
    spheres.append(s5)
    
    bpy.ops.object.select_all(action='DESELECT')
    for s in spheres:
        s.select_set(True)
    bpy.context.view_layer.objects.active = s1
    bpy.ops.object.join()
    canopy = bpy.context.active_object
    canopy.name = "Tree_Canopy"
    canopy.data.name = "Tree_Canopy"
    
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.quads_convert_to_tris(quad_method='BEAUTY', ngon_method='BEAUTY')
    bpy.ops.object.mode_set(mode='OBJECT')
    set_flat_shading(canopy)
    
    c_attr = canopy.data.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    canopy.data.color_attributes.active_color_name = "AlbedoCol"
    
    col_base = Vector((0.337, 0.510, 0.208))
    col_top = Vector((0.773, 0.878, 0.388))
    sun_dir = Vector((-0.707, 0.5, 0.8)).normalized()
    
    for poly in canopy.data.polygons:
        poly.use_smooth = False
        for loop_idx in poly.loop_indices:
            v_idx = canopy.data.loops[loop_idx].vertex_index
            v_pos = canopy.data.vertices[v_idx].co
            
            z_norm = (v_pos.z - 1.1) / 2.5
            z_norm = max(0.0, min(1.0, z_norm))
            
            dir_dot = max(0.0, v_pos.normalized().dot(sun_dir))
            t = max(0.0, min(1.0, z_norm * 0.75 + dir_dot * 0.35))
            rgb = col_base.lerp(col_top, t)
            
            dist_xy = Vector((v_pos.x, v_pos.y)).length
            alpha = max(0.0, min(1.0, (dist_xy / 1.1) * z_norm))
            
            c_attr.data[loop_idx].color = (rgb.x, rgb.y, rgb.z, alpha)
            
    return trunk, canopy

def create_ruin_pillar(name, pos_2d, total_height, has_capital=True):
    """
    Pilar das Ruínas apoiado diretamente no leito de areia em Z = -1.0m.
    - Base de sustentação: 1.05x1.05x0.6m (Z de -1.0m a -0.4m).
    - Fuste escalonado em blocos modulares subindo até o capitel.
    """
    bm = bmesh.new()
    
    base_h = 0.6
    # Bloco de fundação em Z [0.0, base_h]
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= 1.05
        v.co.y *= 1.05
        v.co.z = v.co.z * base_h + base_h * 0.5
        
    z_cur = base_h
    shaft_w = 0.75
    block_h = 0.45
    step_idx = 0
    
    max_shaft_z = (total_height - 0.4 if has_capital else total_height)
    while z_cur + block_h <= max_shaft_z:
        offset_x = (0.05 if step_idx % 2 == 0 else -0.05)
        offset_y = (-0.05 if step_idx % 3 == 0 else 0.05)
        
        bm_block = bmesh.new()
        bmesh.ops.create_cube(bm_block, size=1.0)
        for v in bm_block.verts:
            v.co.x = v.co.x * shaft_w + offset_x * 0.4
            v.co.y = v.co.y * shaft_w + offset_y * 0.4
            v.co.z = v.co.z * block_h + z_cur + block_h * 0.5
            
        for f in bm_block.faces:
            bm.faces.new([bm.verts.new(v.co) for v in f.verts])
        bm_block.free()
        
        z_cur += block_h
        step_idx += 1
        
    if has_capital:
        bm_cap = bmesh.new()
        bmesh.ops.create_cube(bm_cap, size=1.0)
        for v in bm_cap.verts:
            v.co.x *= 1.15
            v.co.y *= 1.15
            v.co.z = v.co.z * 0.4 + total_height - 0.2
        for f in bm_cap.faces:
            bm.faces.new([bm.verts.new(v.co) for v in f.verts])
        bm_cap.free()
        
    # Posiciona a base exatamente em Z = -1.0m
    world_pos = (pos_2d[0], pos_2d[1], -1.0)
    
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = world_pos
    set_flat_shading(obj)
    
    attr = mesh.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    top_col = hex_to_rgb("#b8b2a6")
    side_col = hex_to_rgb("#78757a")
    wet_side_col = hex_to_rgb("#50554c")
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        is_top = (poly.normal.z > 0.5)
        
        # Média Z local para detectar parte submersa (Z local < 0.8m equivale a Z mundo < -0.2m)
        z_avg = sum([mesh.vertices[mesh.loops[li].vertex_index].co.z for li in poly.loop_indices]) / len(poly.loop_indices)
        
        if is_top:
            col = top_col
        elif z_avg < 0.8:
            col = wet_side_col
        else:
            col = side_col
            
        for loop_idx in poly.loop_indices:
            attr.data[loop_idx].color = col
            
    return obj

def create_submerged_debris():
    """
    Blocos de ruínas caídos apoiados na areia em Z = -1.0m.
    - Tops entre -0.75m e -0.65m.
    - Ficam descobertos/rasos na maré baixa (-0.8m) e submersos na maré alta (-0.2m).
    """
    debris_coords = [
        Vector((-4.5, -2.5, -1.0)),
        Vector((-4.2, -2.7, -1.0)),
        Vector((2.5, -3.2, -1.0)),
        Vector((2.8, -3.0, -1.0)),
        Vector((1.8, -3.5, -1.0)),
        Vector((1.5, -3.3, -1.0))
    ]
    
    bm = bmesh.new()
    for i, c in enumerate(debris_coords):
        bm_block = bmesh.new()
        bmesh.ops.create_cube(bm_block, size=1.0)
        rot_angle = i * 0.8
        cos_r = math.cos(rot_angle)
        sin_r = math.sin(rot_angle)
        
        block_w = 0.45
        block_h = 0.30
        
        for v in bm_block.verts:
            vx = v.co.x * block_w
            vy = v.co.y * block_w
            vz = (v.co.z + 0.5) * block_h # Base em 0.0
            
            rx = vx * cos_r - vy * sin_r + c.x
            ry = vx * sin_r + vy * cos_r + c.y
            rz = vz + c.z # Base apoiada em c.z = -1.0m
            v.co = Vector((rx, ry, rz))
            
        for f in bm_block.faces:
            bm.faces.new([bm.verts.new(v.co) for v in f.verts])
        bm_block.free()
        
    mesh = bpy.data.meshes.new("Ruin_Debris_Submerged")
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new("Ruin_Debris_Submerged", mesh)
    bpy.context.collection.objects.link(obj)
    set_flat_shading(obj)
    
    attr = mesh.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    top_col = hex_to_rgb("#a5a095")
    side_col = hex_to_rgb("#5e635a")
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        is_top = (poly.normal.z > 0.5)
        for loop_idx in poly.loop_indices:
            attr.data[loop_idx].color = top_col if is_top else side_col
    return obj

def create_faceted_rock(name, pos_2d, scale, rot_z_deg=0.0):
    """
    Rocha facetada com a base perfeitamente apoiada na areia em Z = -1.0m.
    - Base alinhada flush a Z = 0.0 local -> Z = -1.0m mundo.
    - Gradiente de cor de rocha molhada/escura (#2f333a) na base até granito seco (#7c8288) no topo.
    """
    bpy.ops.mesh.primitive_cone_add(
        vertices=7,
        radius1=1.0,
        radius2=0.35,
        depth=1.0,
        location=(0, 0, 0)
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    
    # Ajusta os vértices locais para a base ficar perfeitamente em Z = 0.0
    for v in obj.data.vertices:
        v.co.z += 0.5
        
    obj.scale = scale
    obj.rotation_euler.z = math.radians(rot_z_deg)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    
    # Posiciona a base na areia em Z = -1.0m
    world_pos = (pos_2d[0], pos_2d[1], -1.0)
    obj.location = world_pos
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    
    mesh = obj.data
    set_flat_shading(obj)
    
    attr = mesh.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    top_col = Vector(hex_to_rgb("#7c8288")[:3])
    mid_col = Vector(hex_to_rgb("#4e555e")[:3])
    bot_col = Vector(hex_to_rgb("#282c33")[:3])
    
    rock_height = scale[2] * 1.0
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        for loop_idx in poly.loop_indices:
            v_idx = mesh.loops[loop_idx].vertex_index
            z = mesh.vertices[v_idx].co.z # Z absoluto no mundo
            
            # Fator de altura de -1.0m até o topo
            factor = max(0.0, min(1.0, (z - (-1.0)) / max(0.1, rock_height)))
            
            if factor < 0.4:
                rgb = bot_col.lerp(mid_col, factor / 0.4)
            else:
                rgb = mid_col.lerp(top_col, (factor - 0.4) / 0.6)
                
            attr.data[loop_idx].color = (rgb.x, rgb.y, rgb.z, 1.0)
            
    return obj

def create_grass_tufts():
    """
    Vegetação:
    - Tufos de grama na ilha central (Z = +0.15m).
    - Tufos de juncos/algas aquáticas enraizados na areia (Z = -1.0m).
    """
    tuft_island_coords = [
        Vector((-0.8, -0.3, 0.15)),
        Vector((0.7, 0.4, 0.15)),
        Vector((-0.3, 0.7, 0.15)),
        Vector((0.4, -0.6, 0.15))
    ]
    
    aquatic_reeds_coords = [
        Vector((-3.8, -2.2, -1.0)),
        Vector((3.9, 1.5, -1.0)),
        Vector((4.2, -1.8, -1.0)),
        Vector((-2.1, 2.8, -1.0)),
        Vector((1.6, -2.9, -1.0))
    ]
    
    bm = bmesh.new()
    blade_w = 0.06
    
    tuft_col = Vector(hex_to_rgb("#88d47e")[:3])
    reed_col = Vector(hex_to_rgb("#4a7a58")[:3])
    
    # Grama na ilha (altura 0.35m)
    for c in tuft_island_coords:
        blade_h = 0.35
        for b_idx in range(4):
            angle = b_idx * (math.pi / 2.0) + 0.2
            dx = math.cos(angle)
            dy = math.sin(angle)
            v0 = bm.verts.new(c + Vector((-dy * blade_w, dx * blade_w, 0.0)))
            v1 = bm.verts.new(c + Vector((dy * blade_w, -dx * blade_w, 0.0)))
            v2 = bm.verts.new(c + Vector((-dy * blade_w * 0.8 + dx * 0.08, dx * blade_w * 0.8 + dy * 0.08, blade_h * 0.5)))
            v3 = bm.verts.new(c + Vector((dy * blade_w * 0.8 + dx * 0.08, -dx * blade_w * 0.8 + dy * 0.08, blade_h * 0.5)))
            v4 = bm.verts.new(c + Vector((dx * 0.18, dy * 0.18, blade_h)))
            bm.faces.new([v0, v1, v3, v2])
            bm.faces.new([v2, v3, v4])
            
    # Juncos aquáticos enraizados na areia (altura 1.1m -> pontas em +0.1m)
    for c in aquatic_reeds_coords:
        blade_h = 1.10
        for b_idx in range(4):
            angle = b_idx * (math.pi / 2.0) + 0.35
            dx = math.cos(angle)
            dy = math.sin(angle)
            v0 = bm.verts.new(c + Vector((-dy * blade_w, dx * blade_w, 0.0)))
            v1 = bm.verts.new(c + Vector((dy * blade_w, -dx * blade_w, 0.0)))
            v2 = bm.verts.new(c + Vector((-dy * blade_w * 0.8 + dx * 0.12, dx * blade_w * 0.8 + dy * 0.12, blade_h * 0.5)))
            v3 = bm.verts.new(c + Vector((dy * blade_w * 0.8 + dx * 0.12, -dx * blade_w * 0.8 + dy * 0.12, blade_h * 0.5)))
            v4 = bm.verts.new(c + Vector((dx * 0.25, dy * 0.25, blade_h)))
            bm.faces.new([v0, v1, v3, v2])
            bm.faces.new([v2, v3, v4])
            
    mesh = bpy.data.meshes.new("Grass_Tuft")
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new("Grass_Tuft", mesh)
    bpy.context.collection.objects.link(obj)
    set_flat_shading(obj)
    
    attr = mesh.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        for loop_idx in poly.loop_indices:
            v_idx = mesh.loops[loop_idx].vertex_index
            z = mesh.vertices[v_idx].co.z
            is_aquatic = (z < 0.1)
            col = reed_col if is_aquatic else tuft_col
            alpha = max(0.0, min(1.0, (z + 1.0) / 1.1)) if is_aquatic else max(0.0, min(1.0, (z - 0.15) / 0.35))
            attr.data[loop_idx].color = (col.x, col.y, col.z, alpha)
            
    return obj

def main():
    print("Iniciando geração da cena lago_ruinas.glb com leito de areia em Z = -1.0m...")
    clear_scene()
    
    # 1. Leito de Areia (Área total 16x12m por 1m de altura, topo em Z = -1.0m)
    sandbed = create_sand_riverbed()
    
    # 2. Superfície da Água (Plano 16x12m, Z local = 0.0)
    water = create_water_surface()
    
    # 3. Ilha Central e Árvore (apoiadas no leito de areia)
    island = create_soil_island()
    trunk, canopy = create_tree()
    
    # 4. Pilares das Ruínas (apoiados no leito de areia em Z = -1.0m)
    pillar_sw = create_ruin_pillar("Ruin_Pillar_SW", (-3.2, -1.8), 3.6, has_capital=True)
    pillar_ne = create_ruin_pillar("Ruin_Pillar_NE", (3.1, 2.2), 3.8, has_capital=True)
    pillar_nw = create_ruin_pillar("Ruin_Pillar_NW", (-5.2, 3.4), 3.5, has_capital=True)
    debris = create_submerged_debris()
    
    # 5. Rochas Facetadas (apoiadas no leito de areia em Z = -1.0m)
    rocks = [
        create_faceted_rock("Rock_Center_Front", (0.35, -1.35), (0.85, 0.75, 1.45), rot_z_deg=25.0),
        create_faceted_rock("Rock_Center_Small", (1.25, -1.20), (0.55, 0.50, 0.95)),
        create_faceted_rock("Rock_NW_Big", (-1.65, 1.45), (1.15, 0.95, 1.70), rot_z_deg=-15.0),
        create_faceted_rock("Rock_NE_Big", (1.55, 1.45), (1.20, 1.00, 1.80), rot_z_deg=40.0),
        create_faceted_rock("Rock_NE_Small", (2.10, 0.85), (0.60, 0.55, 0.90)),
        create_faceted_rock("Rock_West_1", (-2.50, 0.45), (0.80, 0.70, 1.35)),
        create_faceted_rock("Rock_West_2", (-2.85, -0.25), (0.75, 0.65, 1.30)),
        create_faceted_rock("Rock_SW_NearPillar", (-2.45, -1.45), (0.90, 0.80, 1.55)),
        create_faceted_rock("Rock_East_1", (3.15, -0.15), (0.85, 0.75, 1.40)),
        create_faceted_rock("Rock_East_2", (2.65, -0.95), (0.65, 0.60, 0.80))
    ]
    
    # 6. Tufos de Vegetação
    grass_tufts = create_grass_tufts()
    
    # Exportar GLB para cenarios_hd_pixelart_3d e eden-project
    target_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_glb_1 = os.path.join(target_dir, "lago_ruinas.glb")
    out_glb_2 = os.path.join(os.path.dirname(target_dir), "eden-project", "lago_ruinas.glb")
    
    for path in [out_glb_1, out_glb_2]:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format='GLB',
            use_selection=False,
            export_apply=True,
            export_yup=True,
            export_all_vertex_colors=True,
            export_attributes=True
        )
        print(f"Exportado com sucesso para: {path}")

if __name__ == "__main__":
    main()
