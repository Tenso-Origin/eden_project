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
    # 16x12m subdivided plane at Z = 0.0
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, 0, 0))
    obj = bpy.context.active_object
    obj.name = "Water_Surface"
    obj.data.name = "Water_Surface"
    obj.scale = (16.0, 12.0, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.subdivide(number_cuts=15)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    create_color_attribute(obj, "AlbedoCol", (0.18, 0.68, 0.82, 0.88))
    set_flat_shading(obj)
    return obj

def create_riverbed():
    # Riverbed: plano 100% liso e sem relevo em Z = -0.15 para dar fundo uniforme
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, 0, -0.15))
    obj = bpy.context.active_object
    obj.name = "Riverbed"
    obj.data.name = "Riverbed"
    obj.scale = (16.0, 12.0, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    
    create_color_attribute(obj, "AlbedoCol", hex_to_rgb("#12354a"))
    set_flat_shading(obj)
    return obj

def create_soil_island():
    # Ilha central cravada rente à água em Z = -0.02m (sem camadas subterrâneas profundas)
    # Altura total = 0.22m (de Z = -0.02m até Z = +0.20m, centro em Z = 0.09m)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12,
        radius=1.0,
        depth=0.22,
        location=(0.0, 0.0, 0.09)
    )
    obj = bpy.context.active_object
    obj.name = "Soil_Island"
    obj.data.name = "Soil_Island"
    obj.scale = (1.2, 1.1, 1.0) # diâmetro ~ 2.4 x 2.2
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    
    mesh = obj.data
    color_attr = mesh.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    top_col = hex_to_rgb("#4e7a32")  # Grama verde-oliva
    side_col = hex_to_rgb("#4a3525") # Terra marrom
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        is_top = (poly.normal.z > 0.5)
        for loop_idx in poly.loop_indices:
            color_attr.data[loop_idx].color = top_col if is_top else side_col
            
    return obj

def create_tree():
    # Tronco hexagonal em (0, 0, 0.70), altura 1.0m (começa em Z = 0.20 no topo da ilha)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6,
        radius=0.28,
        depth=1.0,
        location=(0.0, 0.0, 0.70)
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

    # Copa orgânica em gota / cone arredondado
    spheres = []
    
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.1, location=(0.0, 0.0, 1.45))
    s1 = bpy.context.active_object
    s1.scale = (1.1, 1.05, 0.75)
    bpy.ops.object.transform_apply(scale=True)
    spheres.append(s1)
    
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=(0.0, 0.0, 2.05))
    s2 = bpy.context.active_object
    s2.scale = (0.95, 0.9, 0.9)
    bpy.ops.object.transform_apply(scale=True)
    spheres.append(s2)
    
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.75, location=(0.0, 0.0, 2.75))
    s3 = bpy.context.active_object
    s3.scale = (0.7, 0.7, 0.85)
    bpy.ops.object.transform_apply(scale=True)
    spheres.append(s3)
    
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.65, location=(-0.45, 0.25, 1.7))
    s4 = bpy.context.active_object
    spheres.append(s4)

    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.6, location=(0.5, -0.2, 1.8))
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
            
            z_norm = max(0.0, min(1.0, (v_pos.z - 0.9) / 2.5))
            dir_dot = max(0.0, v_pos.normalized().dot(sun_dir))
            t = max(0.0, min(1.0, z_norm * 0.75 + dir_dot * 0.35))
            rgb = col_base.lerp(col_top, t)
            
            dist_xy = Vector((v_pos.x, v_pos.y)).length
            alpha = max(0.0, min(1.0, (dist_xy / 1.1) * z_norm))
            c_attr.data[loop_idx].color = (rgb.x, rgb.y, rgb.z, alpha)
            
    return trunk, canopy

def create_ruin_pillar(name, pos, height, has_capital=True):
    # Pilares cravados em Z = -0.02m (sem blocos submersos extras)
    bm = bmesh.new()
    
    # 1. Base única cravada em Z = -0.02m: vai até Z = 0.50m (altura = 0.52m)
    bm_base = bmesh.new()
    bmesh.ops.create_cube(bm_base, size=1.0)
    for v in bm_base.verts:
        v.co.x *= 0.9
        v.co.y *= 0.9
        v.co.z = v.co.z * 0.52 + 0.24 # Z de -0.02 a 0.50
    for f in bm_base.faces:
        bm.faces.new([bm.verts.new(v.co) for v in f.verts])
    bm_base.free()
        
    # 2. Fuste central modular: de Z = 0.50m até (height - 0.40m)
    z_cur = 0.50
    shaft_w = 0.70
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
        
    # 3. Capitel no topo: 1.1x1.1x0.4m
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
    obj.location = (pos[0], pos[1], 0.0)
    
    set_flat_shading(obj)
    
    attr = mesh.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    top_col = hex_to_rgb("#b8b2a6")
    side_col = hex_to_rgb("#78757a")
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        is_top = (poly.normal.z > 0.5)
        for loop_idx in poly.loop_indices:
            attr.data[loop_idx].color = top_col if is_top else side_col
            
    return obj

def create_faceted_rock(name, pos, scale, rot_z_deg=0.0):
    # Rochas cravadas em Z = -0.02m (sem prolongamento profundo)
    rock_h = scale[2] * 1.5
    z_center = rock_h * 0.5 - 0.02
    
    bpy.ops.mesh.primitive_cone_add(
        vertices=7,
        radius1=1.0,
        radius2=0.35,
        depth=rock_h,
        location=(pos[0], pos[1], z_center)
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    
    obj.scale = (scale[0], scale[1], 1.0)
    obj.rotation_euler.z = math.radians(rot_z_deg)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    
    mesh = obj.data
    set_flat_shading(obj)
    
    attr = mesh.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    top_col = Vector(hex_to_rgb("#7c8288")[:3])
    water_col = Vector(hex_to_rgb("#3b4048")[:3])
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        for loop_idx in poly.loop_indices:
            v_idx = mesh.loops[loop_idx].vertex_index
            z = mesh.vertices[v_idx].co.z
            factor = max(0.0, min(1.0, z / rock_h))
            rgb = water_col.lerp(top_col, factor)
            attr.data[loop_idx].color = (rgb.x, rgb.y, rgb.z, 1.0)
            
    return obj

def create_grass_tufts():
    tuft_coords = [
        Vector((-1.2, -0.4, 0.0)),
        Vector((-3.8, -2.2, 0.0)),
        Vector((3.9, 1.5, 0.0)),
        Vector((4.2, -1.8, 0.0)),
        Vector((-2.1, 2.8, 0.0)),
        Vector((1.6, -2.9, 0.0))
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
            
            v0 = bm.verts.new(c + Vector((-dy * blade_w, dx * blade_w, -0.02)))
            v1 = bm.verts.new(c + Vector((dy * blade_w, -dx * blade_w, -0.02)))
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
            alpha = max(0.0, min(1.0, (z + 0.02) / blade_h))
            attr.data[loop_idx].color = (tuft_col.x, tuft_col.y, tuft_col.z, alpha)
            
    return obj

def main():
    print("Iniciando geração da cena lago_ruinas.glb limpa e sem degraus submersos...")
    clear_scene()
    
    # 1. Água e Leito liso (sem relevo subterrâneo)
    water = create_water_surface()
    riverbed = create_riverbed()
    
    # 2. Ilha Central e Árvore (cravada em Z = -0.02m)
    island = create_soil_island()
    trunk, canopy = create_tree()
    
    # 3. Pilares das Ruínas (base cravada em Z = -0.02m)
    pillar_sw = create_ruin_pillar("Ruin_Pillar_SW", (-3.2, -1.8, 0.0), 2.6, has_capital=True)
    pillar_ne = create_ruin_pillar("Ruin_Pillar_NE", (3.1, 2.2, 0.0), 2.8, has_capital=True)
    pillar_nw = create_ruin_pillar("Ruin_Pillar_NW", (-5.2, 3.4, 0.0), 2.5, has_capital=True)
    
    # 4. Rochas Facetadas (base cravada em Z = -0.02m)
    rocks = [
        create_faceted_rock("Rock_Center_Front", (0.35, -1.35, 0.0), (0.75, 0.65, 0.85), rot_z_deg=25.0),
        create_faceted_rock("Rock_Center_Small", (1.25, -1.20, 0.0), (0.35, 0.35, 0.40)),
        create_faceted_rock("Rock_NW_Big", (-1.65, 1.45, 0.0), (0.95, 0.75, 0.75), rot_z_deg=-15.0),
        create_faceted_rock("Rock_NE_Big", (1.55, 1.45, 0.0), (1.05, 0.80, 0.80), rot_z_deg=40.0),
        create_faceted_rock("Rock_NE_Small", (2.10, 0.85, 0.0), (0.35, 0.35, 0.35)),
        create_faceted_rock("Rock_West_1", (-2.50, 0.45, 0.0), (0.70, 0.60, 0.75)),
        create_faceted_rock("Rock_West_2", (-2.85, -0.25, 0.0), (0.65, 0.55, 0.80)),
        create_faceted_rock("Rock_SW_NearPillar", (-2.45, -1.45, 0.0), (0.75, 0.65, 0.95)),
        create_faceted_rock("Rock_East_1", (3.15, -0.15, 0.0), (0.75, 0.65, 0.85)),
        create_faceted_rock("Rock_East_2", (2.65, -0.95, 0.0), (0.45, 0.40, 0.50))
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
