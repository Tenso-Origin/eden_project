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
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0, 0, -0.6))
    obj = bpy.context.active_object
    obj.name = "Riverbed"
    obj.data.name = "Riverbed"
    obj.scale = (16.0, 12.0, 0.2)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    
    # Subdivide top face for vertex color variation
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.subdivide(number_cuts=15)
    bpy.ops.object.mode_set(mode='OBJECT')
    
    mesh = obj.data
    color_attr = mesh.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    base_col = hex_to_rgb("#12354a")
    dark_col = hex_to_rgb("#0b2233")
    
    # Dark spots below island (0, 0) and pillars (-3.2, -1.8), (3.1, 2.2), (-5.2, 3.4)
    shadow_centers = [
        Vector((0.0, 0.0, 0.0)),
        Vector((-3.2, -1.8, 0.0)),
        Vector((3.1, 2.2, 0.0)),
        Vector((-5.2, 3.4, 0.0))
    ]
    shadow_radii = [2.2, 1.4, 1.4, 1.4]
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        for loop_idx in poly.loop_indices:
            v_idx = mesh.loops[loop_idx].vertex_index
            v_pos = mesh.vertices[v_idx].co
            
            # Check proximity to shadows
            is_dark = False
            for c, r in zip(shadow_centers, shadow_radii):
                if (Vector((v_pos.x, v_pos.y, 0)) - c).length < r:
                    is_dark = True
                    break
            
            color_attr.data[loop_idx].color = dark_col if is_dark else base_col
            
    return obj

def create_soil_island():
    # Octagonal/cylinder beveled block at (0, 0, -0.15), scale (2.4, 2.2, 0.45)
    # Shade Flat. Top: olive-green #4e7a32, sides: brown #4a3525
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=10,
        radius=1.0,
        depth=1.0,
        location=(0, 0, 0)
    )
    obj = bpy.context.active_object
    obj.name = "Soil_Island"
    obj.data.name = "Soil_Island"
    obj.scale = (1.2, 1.1, 0.45) # diameter ~ 2.4 x 2.2
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.location = (0.0, 0.0, -0.15)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    
    mesh = obj.data
    color_attr = mesh.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    top_col = hex_to_rgb("#4e7a32")
    side_col = hex_to_rgb("#4a3525")
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        is_top = (poly.normal.z > 0.5)
        for loop_idx in poly.loop_indices:
            color_attr.data[loop_idx].color = top_col if is_top else side_col
            
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
            # Dark patch at bottom (z < 0.1)
            t_attr.data[loop_idx].color = dark_patch if z < 0.1 else birch_col

    # 2. Canopy: Droplet / rounded cone at (0, 0, 1.85), base width 2.4m, top 1.4m, height 2.8m
    # Multiple merged low-poly icospheres for organic stepped silhouette
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
    
    # Join into one canopy
    bpy.ops.object.select_all(action='DESELECT')
    for s in spheres:
        s.select_set(True)
    bpy.context.view_layer.objects.active = s1
    bpy.ops.object.join()
    canopy = bpy.context.active_object
    canopy.name = "Tree_Canopy"
    canopy.data.name = "Tree_Canopy"
    
    # Triangulate and flat shade
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.quads_convert_to_tris(quad_method='BEAUTY', ngon_method='BEAUTY')
    bpy.ops.object.mode_set(mode='OBJECT')
    set_flat_shading(canopy)
    
    # Vertex colors: Vertical gradient RGB (#568235 at base to #c5e063 at top-left sun direction)
    # Alpha = 0.0 at center to 1.0 at outer tips
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
            
            # Vertical height factor (z from ~0.8 to ~3.3)
            z_norm = (v_pos.z - 0.8) / 2.5
            z_norm = max(0.0, min(1.0, z_norm))
            
            # Sun bias towards top-left
            dir_dot = max(0.0, v_pos.normalized().dot(sun_dir))
            t = max(0.0, min(1.0, z_norm * 0.75 + dir_dot * 0.35))
            
            rgb = col_base.lerp(col_top, t)
            
            # Wind alpha: 0.0 at center, 1.0 at outer tips
            dist_xy = Vector((v_pos.x, v_pos.y)).length
            alpha = max(0.0, min(1.0, (dist_xy / 1.1) * z_norm))
            
            c_attr.data[loop_idx].color = (rgb.x, rgb.y, rgb.z, alpha)
            
    return trunk, canopy

def create_ruin_pillar(name, pos, height, has_capital=True):
    # Stacked beveled blocks 1x1m with protruding bricks and top capital
    bm = bmesh.new()
    
    # Base block: 0.9x0.9 x 0.5
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= 0.9
        v.co.y *= 0.9
        v.co.z = v.co.z * 0.5 + 0.25
        
    # Stack central shaft blocks up to height
    z_cur = 0.5
    shaft_w = 0.7
    block_h = 0.45
    
    step_idx = 0
    while z_cur + block_h <= (height - 0.4 if has_capital else height):
        # Add a block with slight random brick protrusion (+/- 0.06m)
        offset_x = (0.06 if step_idx % 2 == 0 else -0.05)
        offset_y = (-0.05 if step_idx % 3 == 0 else 0.06)
        
        bm_block = bmesh.new()
        bmesh.ops.create_cube(bm_block, size=1.0)
        for v in bm_block.verts:
            v.co.x = v.co.x * shaft_w + offset_x * 0.4
            v.co.y = v.co.y * shaft_w + offset_y * 0.4
            v.co.z = v.co.z * block_h + z_cur + block_h * 0.5
        bm_block.to_mesh(bpy.data.meshes.new("temp"))
        # Merge into bm
        for f in bm_block.faces:
            bm.faces.new([bm.verts.new(v.co) for v in f.verts])
        bm_block.free()
        
        z_cur += block_h
        step_idx += 1
        
    # Capital block at top: 1.1x1.1x0.4m with L-notch
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
    bpy.context.collection.objects.link(obj)
    obj.location = pos
    
    set_flat_shading(obj)
    
    # Vertex color: #b8b2a6 on top, #78757a on sides
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

def create_submerged_debris():
    debris_coords = [
        Vector((-4.5, -2.5, -0.15)),
        Vector((-4.2, -2.7, -0.18)),
        Vector((2.5, -3.2, -0.18)),
        Vector((2.8, -3.0, -0.16)),
        Vector((1.8, -3.5, -0.15)),
        Vector((1.5, -3.3, -0.17))
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
            vz = v.co.z * 0.2
            # Rotate around Z
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
    bpy.context.collection.objects.link(obj)
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
    # Faceted beveled pyramid/cone style rock (Shade Flat)
    # Upper vertices #7c8288, bottom vertices near water #3b4048
    bpy.ops.mesh.primitive_cone_add(
        vertices=7,
        radius1=1.0,
        radius2=0.35,
        depth=1.5,
        location=(0, 0, 0)
    )
    obj = bpy.context.active_object
    obj.name = name
    obj.data.name = name
    
    # Scale and apply
    obj.scale = scale
    obj.rotation_euler.z = math.radians(rot_z_deg)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.location = pos
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    
    mesh = obj.data
    set_flat_shading(obj)
    
    attr = mesh.color_attributes.new(name="AlbedoCol", type='FLOAT_COLOR', domain='CORNER')
    mesh.color_attributes.active_color_name = "AlbedoCol"
    
    top_col = Vector(hex_to_rgb("#7c8288")[:3])
    bot_col = Vector(hex_to_rgb("#3b4048")[:3])
    
    # Color gradient based on local Z
    for poly in mesh.polygons:
        poly.use_smooth = False
        for loop_idx in poly.loop_indices:
            v_idx = mesh.loops[loop_idx].vertex_index
            z = mesh.vertices[v_idx].co.z
            factor = max(0.0, min(1.0, (z - pos[2] + 0.3) / (scale[2] * 1.5)))
            rgb = bot_col.lerp(top_col, factor)
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
        # Create 4 blades per tuft with outward spread
        for b_idx in range(4):
            angle = b_idx * (math.pi / 2.0) + 0.2
            dx = math.cos(angle)
            dy = math.sin(angle)
            
            # Root
            v0 = bm.verts.new(c + Vector((-dy * blade_w, dx * blade_w, 0.0)))
            v1 = bm.verts.new(c + Vector((dy * blade_w, -dx * blade_w, 0.0)))
            # Mid
            v2 = bm.verts.new(c + Vector((-dy * blade_w * 0.8 + dx * 0.08, dx * blade_w * 0.8 + dy * 0.08, blade_h * 0.5)))
            v3 = bm.verts.new(c + Vector((dy * blade_w * 0.8 + dx * 0.08, -dx * blade_w * 0.8 + dy * 0.08, blade_h * 0.5)))
            # Tip
            v4 = bm.verts.new(c + Vector((dx * 0.18, dy * 0.18, blade_h)))
            
            # Faces
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
            alpha = max(0.0, min(1.0, (z - 0.05) / blade_h))
            attr.data[loop_idx].color = (tuft_col.x, tuft_col.y, tuft_col.z, alpha)
            
    return obj

def main():
    print("Iniciando geração da cena lago_ruinas.glb...")
    clear_scene()
    
    # 1. Água e Leito do Lago
    water = create_water_surface()
    riverbed = create_riverbed()
    
    # 2. Ilha Central e Árvore
    island = create_soil_island()
    trunk, canopy = create_tree()
    
    # 3. Pilares das Ruínas
    pillar_sw = create_ruin_pillar("Ruin_Pillar_SW", (-3.2, -1.8, 0.0), 2.6, has_capital=True)
    pillar_ne = create_ruin_pillar("Ruin_Pillar_NE", (3.1, 2.2, 0.0), 2.8, has_capital=True)
    pillar_nw = create_ruin_pillar("Ruin_Pillar_NW", (-5.2, 3.4, 0.0), 2.5, has_capital=True)
    debris = create_submerged_debris()
    
    # 4. Rochas Facetadas
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
