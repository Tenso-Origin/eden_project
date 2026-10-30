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
    # 16x12m subdivided plane at (0, 0, 0)
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, 0, 0))
    obj = bpy.context.active_object
    obj.name = "Water_Surface"
    obj.data.name = "Water_Surface"
    obj.scale = (16.0, 12.0, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    
    # Subdivide so there are vertices across the surface
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.subdivide(number_cuts=15)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    create_color_attribute(obj, "AlbedoCol", (0.18, 0.68, 0.82, 0.88))
    set_flat_shading(obj)
    return obj

def create_riverbed():
    # Riverbed mesh at (0, 0, -0.6), dim 16x12x0.2
    # Cor uniforme azul-petróleo escuro #12354a SEM manchas falsas
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.6))
    obj = bpy.context.active_object
    obj.name = "Riverbed"
    obj.data.name = "Riverbed"
    obj.scale = (16.0, 12.0, 0.2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.subdivide(number_cuts=7)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    mesh = obj.data
    color_attr = mesh.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    base_col = hex_to_rgb("#12354a")
    for poly in mesh.polygons:
        poly.use_smooth = False
        for loop_idx in poly.loop_indices:
            color_attr.data[loop_idx].color = base_col
            
    return obj

def create_soil_island():
    # Ilha central estendida para baixo até Z = -0.65m (cravada no Riverbed a -0.60m)
    # Topo em Z = +0.10m, base em Z = -0.65m (altura total = 0.75m, centro em Z = -0.275m)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12,
        radius=1.0,
        depth=0.75,
        location=(0.0, 0.0, -0.275)
    )
    obj = bpy.context.active_object
    obj.name = "Soil_Island"
    obj.data.name = "Soil_Island"
    obj.scale = (1.2, 1.1, 1.0) # diâmetro ~ 2.4 x 2.2
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    
    mesh = obj.data
    color_attr = mesh.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    top_col = hex_to_rgb("#4e7a32")       # Grama verde-oliva
    side_col = hex_to_rgb("#4a3525")      # Terra marrom visível
    sub_col = hex_to_rgb("#2d2017")       # Terra escura submersa
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        is_top = (poly.normal.z > 0.5)
        for loop_idx in poly.loop_indices:
            v_idx = mesh.loops[loop_idx].vertex_index
            z = mesh.vertices[v_idx].co.z
            if is_top:
                color_attr.data[loop_idx].color = top_col
            elif z < 0.0:
                color_attr.data[loop_idx].color = sub_col
            else:
                color_attr.data[loop_idx].color = side_col
            
    return obj

def create_tree():
    # 1. Trunk: 6-sided cylinder at (0, 0, 0.4), radius 0.28m, height 1.2m
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6,
        radius=0.28,
        depth=1.2,
        location=(0.0, 0.0, 0.4)
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
            t_attr.data[loop_idx].color = dark_patch if z < 0.1 else birch_col

    # 2. Canopy: Droplet / rounded cone at (0, 0, 1.85), base width 2.4m, top 1.4m, height 2.8m
    spheres = []
    
    # Bottom cluster
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.1, location=(0.0, 0.0, 1.35))
    s1 = bpy.context.active_object
    s1.scale = (1.1, 1.05, 0.75)
    bpy.ops.object.transform_apply(scale=True)
    spheres.append(s1)
    
    # Mid-body cluster
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(0.0, 0.0, 1.95))
    s2 = bpy.context.active_object
    s2.scale = (0.95, 0.9, 0.9)
    bpy.ops.object.transform_apply(scale=True)
    spheres.append(s2)
    
    # Upper-top droplet cone
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.75, location=(0.0, 0.0, 2.65))
    s3 = bpy.context.active_object
    s3.scale = (0.7, 0.7, 0.85)
    bpy.ops.object.transform_apply(scale=True)
    spheres.append(s3)
    
    # Side bumps for asymmetric foliage
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.65, location=(-0.45, 0.25, 1.6))
    s4 = bpy.context.active_object
    spheres.append(s4)

    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.6, location=(0.5, -0.2, 1.7))
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
    
    col_base = Vector((0.337, 0.510, 0.208)) # #568235
    col_top = Vector((0.773, 0.878, 0.388))  # #c5e063
    sun_dir = Vector((-0.707, 0.5, 0.8)).normalized()
    
    for poly in canopy.data.polygons:
        poly.use_smooth = False
        for loop_idx in poly.loop_indices:
            v_idx = canopy.data.loops[loop_idx].vertex_index
            v_pos = canopy.data.vertices[v_idx].co
            
            z_norm = max(0.0, min(1.0, (v_pos.z - 0.8) / 2.5))
            dir_dot = max(0.0, v_pos.normalized().dot(sun_dir))
            t = max(0.0, min(1.0, z_norm * 0.75 + dir_dot * 0.35))
            rgb = col_base.lerp(col_top, t)
            
            dist_xy = Vector((v_pos.x, v_pos.y)).length
            alpha = max(0.0, min(1.0, (dist_xy / 1.1) * z_norm))
            c_attr.data[loop_idx].color = (rgb.x, rgb.y, rgb.z, alpha)
            
    return trunk, canopy

def create_ruin_pillar(name, pos, height, has_capital=True):
    # Pilares estendidos até o fundo do lago (Z = -0.65m no Blender)
    # Base submersa de fundação: Z de -0.65 até 0.0 (0.65m de altura)
    bm = bmesh.new()
    
    # 1. Bloco de fundação submerso: de Z = -0.65 até Z = 0.0 (1.0x1.0m)
    bm_sub = bmesh.new()
    bmesh.ops.create_cube(bm_sub, size=1.0)
    for v in bm_sub.verts:
        v.co.x *= 1.0
        v.co.y *= 1.0
        v.co.z = v.co.z * 0.65 - 0.325 # Z de -0.65 a 0.0
    for f in bm_sub.faces:
        bm.faces.new([bm.verts.new(v.co) for v in f.verts])
    bm_sub.free()

    # 2. Base emersa logo acima da água: de Z = 0.0 até Z = 0.5 (0.9x0.9m)
    bm_base = bmesh.new()
    bmesh.ops.create_cube(bm_base, size=1.0)
    for v in bm_base.verts:
        v.co.x *= 0.9
        v.co.y *= 0.9
        v.co.z = v.co.z * 0.5 + 0.25 # Z de 0.0 a 0.5
    for f in bm_base.faces:
        bm.faces.new([bm.verts.new(v.co) for v in f.verts])
    bm_base.free()
        
    # 3. Fuste central modular: de Z = 0.5 até (height - 0.4)
    z_cur = 0.5
    shaft_w = 0.7
    block_h = 0.45
    step_idx = 0
    while z_cur + block_h <= (height - 0.4 if has_capital else height):
        offset_x = (0.06 if step_idx % 2 == 0 else -0.05)
        offset_y = (-0.05 if step_idx % 3 == 0 else 0.06)
        
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
        
    # 4. Capitel no topo: 1.1x1.1x0.4m
    if has_capital:
        bm_cap = bmesh.new()
        bmesh.ops.create_cube(bm_cap, size=1.0)
        for v in bm_cap.verts:
            v.co.x *= 1.1
            v.co.y *= 1.1
            v.co.z = v.co.z * 0.4 + height - 0.2
        for f in bm_cap.faces:
            bm.faces.new([bm.verts.new(v.co) for v in f.verts])
        bm_cap.free()
        
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new(name, mesh)
    obj.data.name = name
    bpy.context.collection.objects.link(obj)
    obj.location = pos
    
    set_flat_shading(obj)
    
    attr = mesh.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    top_col = hex_to_rgb("#b8b2a6")
    side_col = hex_to_rgb("#78757a")
    sub_col = hex_to_rgb("#4e4b52") # Pedra úmida submersa
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        is_top = (poly.normal.z > 0.5)
        for loop_idx in poly.loop_indices:
            v_idx = mesh.loops[loop_idx].vertex_index
            z = mesh.vertices[v_idx].co.z
            if is_top:
                attr.data[loop_idx].color = top_col
            elif z < 0.0:
                attr.data[loop_idx].color = sub_col
            else:
                attr.data[loop_idx].color = side_col
            
    return obj

def create_submerged_debris():
    debris_coords = [
        Vector((-4.5, -2.5, -0.45)),
        Vector((-4.2, -2.7, -0.48)),
        Vector((2.5, -3.2, -0.48)),
        Vector((2.8, -3.0, -0.46)),
        Vector((1.8, -3.5, -0.45)),
        Vector((1.5, -3.3, -0.47))
    ]
    
    bm = bmesh.new()
    for i, c in enumerate(debris_coords):
        bm_block = bmesh.new()
        bmesh.ops.create_cube(bm_block, size=1.0)
        rot_angle = i * 0.8
        cos_r = math.cos(rot_angle)
        sin_r = math.sin(rot_angle)
        for v in bm_block.verts:
            vx = v.co.x * 0.4
            vy = v.co.y * 0.4
            vz = v.co.z * 0.25
            rx = vx * cos_r - vy * sin_r + c.x
            ry = vx * sin_r + vy * cos_r + c.y
            rz = vz + c.z
            v.co = Vector((rx, ry, rz))
        for f in bm_block.faces:
            bm.faces.new([bm.verts.new(v.co) for v in f.verts])
        bm_block.free()
        
    mesh = bpy.data.meshes.new("Ruin_Debris_Submerged")
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new("Ruin_Debris_Submerged", mesh)
    obj.data.name = "Ruin_Debris_Submerged"
    bpy.context.collection.objects.link(obj)
    set_flat_shading(obj)
    
    attr = mesh.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    top_col = hex_to_rgb("#78757a")
    side_col = hex_to_rgb("#4e4b52")
    for poly in mesh.polygons:
        poly.use_smooth = False
        is_top = (poly.normal.z > 0.5)
        for loop_idx in poly.loop_indices:
            attr.data[loop_idx].color = top_col if is_top else side_col
    return obj

def create_faceted_rock(name, pos, scale, rot_z_deg=0.0):
    # Rochas estendidas até Z = -0.65m para tocarem o leito do lago
    # Criamos o cone com base estendida para baixo
    total_height = scale[2] * 1.5 + 0.70 # Altura estendida
    z_center = pos[2] - 0.35            # Centro deslocado para baixo
    
    bpy.ops.mesh.primitive_cone_add(
        vertices=7,
        radius1=1.0,
        radius2=0.35,
        depth=total_height,
        location=(0, 0, 0)
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    
    obj.scale = (scale[0], scale[1], 1.0)
    obj.rotation_euler.z = math.radians(rot_z_deg)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    
    # Ajusta os vértices da base para garantir que toquem Z = -0.65m
    mesh = obj.data
    for v in mesh.vertices:
        v.co.x += pos[0]
        v.co.y += pos[1]
        v.co.z += z_center
        if v.co.z < -0.65:
            v.co.z = -0.65
            
    set_flat_shading(obj)
    
    attr = mesh.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    top_col = Vector(hex_to_rgb("#7c8288")[:3])
    water_col = Vector(hex_to_rgb("#3b4048")[:3])
    sub_col = Vector(hex_to_rgb("#23272e")[:3]) # Fundo escuro submerso
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        for loop_idx in poly.loop_indices:
            v_idx = mesh.loops[loop_idx].vertex_index
            z = mesh.vertices[v_idx].co.z
            if z < 0.0:
                factor = max(0.0, min(1.0, (z + 0.65) / 0.65))
                rgb = sub_col.lerp(water_col, factor)
            else:
                factor = max(0.0, min(1.0, z / (scale[2] * 1.5)))
                rgb = water_col.lerp(top_col, factor)
            attr.data[loop_idx].color = (rgb.x, rgb.y, rgb.z, 1.0)
            
    return obj

def create_grass_tufts():
    tuft_coords = [
        Vector((-1.2, -0.4, 0.05)),
        Vector((-3.8, -2.2, 0.05)),
        Vector((3.9, 1.5, 0.05)),
        Vector((4.2, -1.8, 0.05)),
        Vector((-2.1, 2.8, 0.05)),
        Vector((1.6, -2.9, 0.05))
    ]
    
    bm = bmesh.new()
    blade_w = 0.06
    blade_h = 0.35
    
    tuft_col = Vector(hex_to_rgb("#88d47e")[:3])
    
    for c in tuft_coords:
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
            
    mesh = bpy.data.meshes.new("Grass_Tuft")
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new("Grass_Tuft", mesh)
    obj.data.name = "Grass_Tuft"
    bpy.context.collection.objects.link(obj)
    set_flat_shading(obj)
    
    attr = mesh.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        for loop_idx in poly.loop_indices:
            v_idx = mesh.loops[loop_idx].vertex_index
            z = mesh.vertices[v_idx].co.z
            alpha = max(0.0, min(1.0, (z - 0.05) / blade_h))
            attr.data[loop_idx].color = (tuft_col.x, tuft_col.y, tuft_col.z, alpha)
            
    return obj

def main():
    print("Iniciando geração da cena lago_ruinas.glb refinada...")
    clear_scene()
    
    # 1. Água e Leito do Lago (uniforme, sem manchas falsas)
    water = create_water_surface()
    riverbed = create_riverbed()
    
    # 2. Ilha Central e Árvore (ilha estendida até Z = -0.65m)
    island = create_soil_island()
    trunk, canopy = create_tree()
    
    # 3. Pilares das Ruínas (estendidos com fundações submersas até Z = -0.65m)
    pillar_sw = create_ruin_pillar("Ruin_Pillar_SW", (-3.2, -1.8, 0.0), 2.6, has_capital=True)
    pillar_ne = create_ruin_pillar("Ruin_Pillar_NE", (3.1, 2.2, 0.0), 2.8, has_capital=True)
    pillar_nw = create_ruin_pillar("Ruin_Pillar_NW", (-5.2, 3.4, 0.0), 2.5, has_capital=True)
    debris = create_submerged_debris()
    
    # 4. Rochas Facetadas (estendidas até Z = -0.65m)
    rocks = [
        create_faceted_rock("Rock_Center_Front", (0.35, -1.35, 0.05), (0.75, 0.65, 0.85), rot_z_deg=25.0),
        create_faceted_rock("Rock_Center_Small", (1.25, -1.20, 0.02), (0.35, 0.35, 0.40)),
        create_faceted_rock("Rock_NW_Big", (-1.65, 1.45, 0.05), (0.95, 0.75, 0.75), rot_z_deg=-15.0),
        create_faceted_rock("Rock_NE_Big", (1.55, 1.45, 0.05), (1.05, 0.80, 0.80), rot_z_deg=40.0),
        create_faceted_rock("Rock_NE_Small", (2.10, 0.85, 0.02), (0.35, 0.35, 0.35)),
        create_faceted_rock("Rock_West_1", (-2.50, 0.45, 0.05), (0.70, 0.60, 0.75)),
        create_faceted_rock("Rock_West_2", (-2.85, -0.25, 0.05), (0.65, 0.55, 0.80)),
        create_faceted_rock("Rock_SW_NearPillar", (-2.45, -1.45, 0.05), (0.75, 0.65, 0.95)),
        create_faceted_rock("Rock_East_1", (3.15, -0.15, 0.05), (0.75, 0.65, 0.85)),
        create_faceted_rock("Rock_East_2", (2.65, -0.95, 0.03), (0.45, 0.40, 0.50))
    ]
    
    # 5. Tufos de Vegetação Aquática
    grass_tufts = create_grass_tufts()
    
    # Exportar GLB
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
