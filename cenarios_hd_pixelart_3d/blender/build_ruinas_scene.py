import bpy
import bmesh
import math
import random
from mathutils import Vector, Matrix, Euler

def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # Remove all collections and objects
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for col in list(bpy.data.collections):
        bpy.data.collections.remove(col)
    for mesh in list(bpy.data.meshes):
        bpy.data.meshes.remove(mesh)
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)

def setup_materials():
    # 1. Clay Terrain Material
    mat_terrain = bpy.data.materials.new(name="Mat_ClayTerrain")
    mat_terrain.use_nodes = True
    nodes = mat_terrain.node_tree.nodes
    principled = nodes.get("Principled BSDF")
    if principled:
        principled.inputs['Base Color'].default_value = (0.91, 0.91, 0.92, 1.0)
        principled.inputs['Roughness'].default_value = 0.85
    
    # 2. Clay Ruins Material (Stone blocks, columns, fountain)
    mat_ruins = bpy.data.materials.new(name="Mat_ClayRuins")
    mat_ruins.use_nodes = True
    nodes = mat_ruins.node_tree.nodes
    principled = nodes.get("Principled BSDF")
    if principled:
        principled.inputs['Base Color'].default_value = (0.84, 0.84, 0.86, 1.0)
        principled.inputs['Roughness'].default_value = 0.75
        
    # 3. Fountain Interior / Pool Floor Material
    mat_pool = bpy.data.materials.new(name="Mat_PoolFloor")
    mat_pool.use_nodes = True
    nodes = mat_pool.node_tree.nodes
    principled = nodes.get("Principled BSDF")
    if principled:
        principled.inputs['Base Color'].default_value = (0.76, 0.77, 0.80, 1.0)
        principled.inputs['Roughness'].default_value = 0.65

    # 4. Translucent Turquoise Water Material
    mat_water = bpy.data.materials.new(name="Mat_Water")
    mat_water.use_nodes = True
    nodes = mat_water.node_tree.nodes
    principled = nodes.get("Principled BSDF")
    if principled:
        principled.inputs['Base Color'].default_value = (0.16, 0.74, 0.84, 1.0)
        principled.inputs['Roughness'].default_value = 0.05
        if 'Transmission Weight' in principled.inputs:
            principled.inputs['Transmission Weight'].default_value = 0.92
        elif 'Transmission' in principled.inputs:
            principled.inputs['Transmission'].default_value = 0.92
        if 'IOR' in principled.inputs:
            principled.inputs['IOR'].default_value = 1.333

    return mat_terrain, mat_ruins, mat_pool, mat_water

def create_terrain(mat_terrain):
    size = 42.0
    segments = 84
    
    mesh = bpy.data.meshes.new("TerrainMesh")
    bm = bmesh.new()
    
    bmesh.ops.create_grid(bm, x_segments=segments, y_segments=segments, size=size/2.0)
    
    # Deform vertices into rolling hills with a flat clearing in the center
    for v in bm.verts:
        x, y = v.co.x, v.co.y
        dist = math.sqrt(x*x + y*y)
        
        # Clearing radius
        r_inner = 6.2
        r_outer = 10.0
        
        if dist <= r_inner:
            blend = 0.0
        elif dist >= r_outer:
            blend = 1.0
        else:
            t = (dist - r_inner) / (r_outer - r_inner)
            blend = t * t * (3.0 - 2.0 * t) # smoothstep
            
        # Large rolling hills around perimeter
        wave1 = 2.4 * math.sin(0.12 * x + 0.4) * math.cos(0.11 * y - 0.2)
        wave2 = 1.3 * math.cos(0.08 * x - 0.14 * y + 1.2)
        wave3 = 0.7 * math.sin(0.22 * x + 0.18 * y)
        elevation = (wave1 + wave2 + wave3) * blend
        
        # Lift outer perimeter slightly higher
        border_lift = blend * 0.8 * (dist / 20.0)
        
        v.co.z = max(0.0, elevation + border_lift)
        
    bm.to_mesh(mesh)
    bm.free()
    
    # Shade smooth
    for poly in mesh.polygons:
        poly.use_smooth = True
        
    obj = bpy.data.objects.new("Terrain_RollingDunes", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat_terrain)
    return obj

def create_octagonal_basin(mat_ruins, mat_pool):
    """Creates the central octagonal fountain basin with stepped rim and sunken pool."""
    mesh = bpy.data.meshes.new("BasinMesh")
    bm = bmesh.new()
    
    # Octagon properties
    n_sides = 8
    outer_base_r = 3.65
    outer_rim_r = 3.25
    inner_rim_r = 2.45
    floor_r = 2.45
    
    z_ground = 0.0
    z_base = 0.14
    z_rim = 0.58
    z_floor = 0.12
    
    angles = [i * (2.0 * math.pi / n_sides) + (math.pi / n_sides) for i in range(n_sides)]
    
    # Create rings of vertices
    v_base_bot = [bm.verts.new(Vector((outer_base_r * math.cos(a), outer_base_r * math.sin(a), z_ground))) for a in angles]
    v_base_top = [bm.verts.new(Vector((outer_base_r * math.cos(a), outer_base_r * math.sin(a), z_base))) for a in angles]
    v_rim_out  = [bm.verts.new(Vector((outer_rim_r * math.cos(a), outer_rim_r * math.sin(a), z_rim))) for a in angles]
    v_rim_in   = [bm.verts.new(Vector((inner_rim_r * math.cos(a), inner_rim_r * math.sin(a), z_rim))) for a in angles]
    v_floor    = [bm.verts.new(Vector((floor_r * math.cos(a), floor_r * math.sin(a), z_floor))) for a in angles]
    v_center   = bm.verts.new(Vector((0.0, 0.0, z_floor)))
    
    # Build faces
    for i in range(n_sides):
        nxt = (i + 1) % n_sides
        # Base plinth vertical face
        bm.faces.new([v_base_bot[i], v_base_bot[nxt], v_base_top[nxt], v_base_top[i]])
        # Base plinth to outer rim chamfer
        bm.faces.new([v_base_top[i], v_base_top[nxt], v_rim_out[nxt], v_rim_out[i]])
        # Top rim horizontal face
        bm.faces.new([v_rim_out[i], v_rim_out[nxt], v_rim_in[nxt], v_rim_in[i]])
        # Inner wall vertical face
        bm.faces.new([v_rim_in[i], v_rim_in[nxt], v_floor[nxt], v_floor[i]])
        # Pool floor triangles
        bm.faces.new([v_floor[i], v_floor[nxt], v_center])
        
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new("Fountain_Basin_Octagon", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat_ruins)
    obj.data.materials.append(mat_pool)
    
    # Assign pool floor material to pool faces
    for i in range(n_sides):
        # The pool floor faces are the last n_sides faces
        mesh.polygons[-(i+1)].material_index = 1
        
    # Bevel modifier for subtle stone edge rounding
    bev = obj.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.04
    bev.segments = 2
    bev.limit_method = 'ANGLE'
    bev.angle_limit = math.radians(35.0)
    
    return obj

def create_fountain_pedestal_and_cup(mat_ruins):
    """Creates the central chalice/pedestal font inside the fountain pool."""
    mesh = bpy.data.meshes.new("FountainCenterMesh")
    bm = bmesh.new()
    
    # Stepped octagonal base
    n = 8
    angles = [i * (2.0 * math.pi / n) for i in range(n)]
    
    def add_oct_layer(r_bot, r_top, z_bot, z_top):
        vb = [bm.verts.new(Vector((r_bot * math.cos(a), r_bot * math.sin(a), z_bot))) for a in angles]
        vt = [bm.verts.new(Vector((r_top * math.cos(a), r_top * math.sin(a), z_top))) for a in angles]
        for i in range(n):
            nxt = (i + 1) % n
            bm.faces.new([vb[i], vb[nxt], vt[nxt], vt[i]])
        return vb, vt

    # Plinth step 1
    add_oct_layer(0.65, 0.60, 0.12, 0.28)
    # Plinth step 2
    add_oct_layer(0.52, 0.45, 0.28, 0.42)
    # Stem / shaft (flared cylinder)
    add_oct_layer(0.24, 0.22, 0.42, 0.85)
    # Mid-collar torus ring
    add_oct_layer(0.30, 0.28, 0.85, 0.95)
    # Upper neck
    add_oct_layer(0.22, 0.26, 0.95, 1.15)
    
    # Chalice bowl exterior (flaring out)
    add_oct_layer(0.28, 0.62, 1.15, 1.48)
    # Chalice rim top
    v_rim_b, v_rim_t = add_oct_layer(0.62, 0.62, 1.48, 1.58)
    
    # Hollow interior bowl
    v_in_rim = [bm.verts.new(Vector((0.48 * math.cos(a), 0.48 * math.sin(a), 1.58))) for a in angles]
    v_in_bot = [bm.verts.new(Vector((0.25 * math.cos(a), 0.25 * math.sin(a), 1.32))) for a in angles]
    v_in_cen = bm.verts.new(Vector((0.0, 0.0, 1.32)))
    
    for i in range(n):
        nxt = (i + 1) % n
        # Top rim face
        bm.faces.new([v_rim_t[i], v_rim_t[nxt], v_in_rim[nxt], v_in_rim[i]])
        # Inner bowl wall
        bm.faces.new([v_in_rim[i], v_in_rim[nxt], v_in_bot[nxt], v_in_bot[i]])
        # Inner bowl floor
        bm.faces.new([v_in_bot[i], v_in_bot[nxt], v_in_cen])
        
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new("Fountain_Chalice_Center", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat_ruins)
    
    bev = obj.modifiers.new("Bevel", "BEVEL")
    bev.width = 0.025
    bev.segments = 2
    bev.limit_method = 'ANGLE'
    bev.angle_limit = math.radians(35.0)
    
    return obj

def create_fountain_water(mat_water):
    """Creates the water meshes for the octagonal fountain basin and chalice bowl."""
    # 1. Main Octagonal Basin Water
    n_sides = 8
    angles = [i * (2.0 * math.pi / n_sides) + (math.pi / n_sides) for i in range(n_sides)]
    r_outer = 2.43
    z_water_basin = 0.38
    
    mesh_basin = bpy.data.meshes.new("WaterBasinMesh")
    bm_basin = bmesh.new()
    
    # Outer ring, mid ring, inner ring (around pedestal), center
    v_outer = [bm_basin.verts.new(Vector((r_outer * math.cos(a), r_outer * math.sin(a), z_water_basin))) for a in angles]
    r_mid = 1.45
    v_mid = [bm_basin.verts.new(Vector((r_mid * math.cos(a), r_mid * math.sin(a), z_water_basin))) for a in angles]
    r_in = 0.52
    v_in = [bm_basin.verts.new(Vector((r_in * math.cos(a), r_in * math.sin(a), z_water_basin))) for a in angles]
    v_cen = bm_basin.verts.new(Vector((0.0, 0.0, z_water_basin)))
    
    for i in range(n_sides):
        nxt = (i + 1) % n_sides
        bm_basin.faces.new([v_outer[i], v_outer[nxt], v_mid[nxt], v_mid[i]])
        bm_basin.faces.new([v_mid[i], v_mid[nxt], v_in[nxt], v_in[i]])
        bm_basin.faces.new([v_in[i], v_in[nxt], v_cen])
        
    bm_basin.to_mesh(mesh_basin)
    bm_basin.free()
    
    obj_basin = bpy.data.objects.new("Fountain_Water_Basin", mesh_basin)
    bpy.context.collection.objects.link(obj_basin)
    obj_basin.data.materials.append(mat_water)
    
    # 2. Chalice Bowl Water
    r_chalice = 0.46
    z_water_chalice = 1.48
    angles_chalice = [i * (2.0 * math.pi / n_sides) for i in range(n_sides)]
    
    mesh_chalice = bpy.data.meshes.new("WaterChaliceMesh")
    bm_chalice = bmesh.new()
    v_ch_rim = [bm_chalice.verts.new(Vector((r_chalice * math.cos(a), r_chalice * math.sin(a), z_water_chalice))) for a in angles_chalice]
    v_ch_cen = bm_chalice.verts.new(Vector((0.0, 0.0, z_water_chalice)))
    
    for i in range(n_sides):
        nxt = (i + 1) % n_sides
        bm_chalice.faces.new([v_ch_rim[i], v_ch_rim[nxt], v_ch_cen])
        
    bm_chalice.to_mesh(mesh_chalice)
    bm_chalice.free()
    
    obj_chalice = bpy.data.objects.new("Fountain_Water_Chalice", mesh_chalice)
    bpy.context.collection.objects.link(obj_chalice)
    obj_chalice.data.materials.append(mat_water)
    
    return obj_basin, obj_chalice

def create_block(name, size, loc, rot=(0,0,0), mat=None, parent_col=None):
    """Helper to create a beveled stone block."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(scale=True)
    
    if mat:
        obj.data.materials.append(mat)
        
    bev = obj.modifiers.new("Bevel", "BEVEL")
    bev.width = min(size) * 0.06
    bev.segments = 2
    bev.limit_method = 'ANGLE'
    bev.angle_limit = math.radians(35.0)
    
    return obj

def build_modular_column(base_x, base_y, height_category, has_capital=True, rot_z=0.0, mat=None, seed=42):
    """Builds a stacked modular column matching the reference image's blocky ruined aesthetic."""
    rng = random.Random(seed)
    
    # 1. Base Stepped Plinth
    p1 = create_block("Col_Plinth_Bot", (0.95, 0.95, 0.16), (base_x, base_y, 0.08), rot=(0,0,rot_z), mat=mat)
    p2 = create_block("Col_Plinth_Top", (0.80, 0.80, 0.14), (base_x, base_y, 0.23), rot=(0,0,rot_z), mat=mat)
    
    cur_z = 0.30
    
    # Define layers based on height category
    if height_category == "tall":
        num_blocks = 9
    elif height_category == "medium":
        num_blocks = 6
    elif height_category == "stump":
        num_blocks = rng.randint(2, 3)
        has_capital = False
    else:
        num_blocks = 4
        has_capital = False
        
    blocks = [p1, p2]
    
    for b_idx in range(num_blocks):
        # Vary block width and height to give ancient modular articulation
        b_type = rng.choice(["standard", "wide_slab", "notch_narrow", "standard_protruding"])
        
        if b_type == "standard":
            w = rng.uniform(0.50, 0.56)
            d = rng.uniform(0.50, 0.56)
            h = rng.uniform(0.32, 0.44)
        elif b_type == "wide_slab":
            w = rng.uniform(0.62, 0.68)
            d = rng.uniform(0.62, 0.68)
            h = rng.uniform(0.14, 0.20)
        elif b_type == "notch_narrow":
            w = rng.uniform(0.42, 0.48)
            d = rng.uniform(0.42, 0.48)
            h = rng.uniform(0.22, 0.30)
        else: # protruding
            w = rng.uniform(0.58, 0.64)
            d = rng.uniform(0.58, 0.64)
            h = rng.uniform(0.28, 0.38)
            
        # Subtle horizontal jitter to simulate eroded misalignment
        off_x = rng.uniform(-0.025, 0.025)
        off_y = rng.uniform(-0.025, 0.025)
        
        z_center = cur_z + h / 2.0
        blk = create_block(f"Col_Block_{b_idx}", (w, d, h), (base_x + off_x, base_y + off_y, z_center), rot=(0, 0, rot_z + rng.uniform(-0.03, 0.03)), mat=mat)
        blocks.append(blk)
        cur_z += h
        
    # Top Capital if intact
    if has_capital:
        # Lower flared neck of capital
        c1 = create_block("Col_Cap_Neck", (0.68, 0.68, 0.14), (base_x, base_y, cur_z + 0.07), rot=(0,0,rot_z), mat=mat)
        # Wide square top slab of capital
        c2 = create_block("Col_Cap_Top", (0.84, 0.84, 0.22), (base_x, base_y, cur_z + 0.25), rot=(0,0,rot_z), mat=mat)
        blocks.extend([c1, c2])
        cur_z += 0.36
        
    return blocks, cur_z

def create_ruined_gateway(base_x, base_y, mat):
    """Builds the monumental stone gateway portal on the right side."""
    # Shared stepped foundation plinth
    base1 = create_block("Gate_Base_1", (1.20, 2.80, 0.18), (base_x, base_y, 0.09), rot=(0,0,math.radians(18.0)), mat=mat)
    base2 = create_block("Gate_Base_2", (0.95, 2.50, 0.16), (base_x, base_y, 0.26), rot=(0,0,math.radians(18.0)), mat=mat)
    
    # Left jamb pillar (broken angled top)
    jamb_l_pos = Vector((base_x - 0.28, base_y - 0.75, 0.34))
    cur_z = 0.34
    for i in range(6):
        h = 0.38
        w = 0.58 if i % 2 == 0 else 0.50
        create_block(f"Gate_JambL_{i}", (w, 0.60, h), (jamb_l_pos.x, jamb_l_pos.y, cur_z + h/2.0), rot=(0,0,math.radians(18.0)), mat=mat)
        cur_z += h
    # Ruined angled sheared top slab
    create_block("Gate_JambL_Shear", (0.45, 0.55, 0.26), (jamb_l_pos.x, jamb_l_pos.y, cur_z + 0.13), rot=(math.radians(16.0), 0, math.radians(22.0)), mat=mat)
    
    # Right jamb pillar (standing tall)
    jamb_r_pos = Vector((base_x + 0.28, base_y + 0.75, 0.34))
    cur_z = 0.34
    for i in range(8):
        h = 0.40
        w = 0.62 if i % 3 == 0 else 0.52
        create_block(f"Gate_JambR_{i}", (w, 0.60, h), (jamb_r_pos.x, jamb_r_pos.y, cur_z + h/2.0), rot=(0,0,math.radians(18.0)), mat=mat)
        cur_z += h
    # Capital on right jamb
    create_block("Gate_JambR_Cap", (0.80, 0.80, 0.26), (jamb_r_pos.x, jamb_r_pos.y, cur_z + 0.13), rot=(0,0,math.radians(18.0)), mat=mat)
    
    # Fallen/resting lintel slab
    lintel = create_block("Gate_Lintel_Piece", (0.50, 1.40, 0.32), (base_x - 0.35, base_y + 0.50, 0.55), rot=(math.radians(12.0), math.radians(-14.0), math.radians(45.0)), mat=mat)

def create_toppled_column_pile(base_x, base_y, mat):
    """Builds the cluster of tumbled, fallen column chunks behind the right side."""
    # Base stump
    create_block("Toppled_Stump_Base", (0.90, 0.90, 0.16), (base_x, base_y, 0.08), mat=mat)
    create_block("Toppled_Stump_1", (0.54, 0.54, 0.42), (base_x, base_y, 0.37), rot=(0,0,math.radians(12.0)), mat=mat)
    
    # Fallen chunk 1 (tilted on ground)
    create_block("Toppled_Chunk_1", (0.55, 1.25, 0.48), (base_x + 0.55, base_y - 0.40, 0.25), rot=(math.radians(8.0), math.radians(16.0), math.radians(35.0)), mat=mat)
    
    # Fallen chunk 2 (propped against chunk 1)
    create_block("Toppled_Chunk_2", (0.52, 0.95, 0.45), (base_x + 0.90, base_y - 0.85, 0.32), rot=(math.radians(-12.0), math.radians(22.0), math.radians(-25.0)), mat=mat)
    
    # Broken capital piece
    create_block("Toppled_Cap_Piece", (0.75, 0.75, 0.25), (base_x + 1.35, base_y - 1.15, 0.14), rot=(math.radians(5.0), math.radians(-8.0), math.radians(52.0)), mat=mat)

def create_environment_props(mat):
    """Creates paving slabs and loose debris stones scattered around."""
    # 1. Back rectangular flat paving stones
    create_block("Paver_Slab_1", (1.10, 1.10, 0.08), (0.2, 3.8, 0.04), rot=(0, 0, math.radians(15.0)), mat=mat)
    create_block("Paver_Slab_2", (1.25, 0.95, 0.08), (1.5, 3.5, 0.04), rot=(0, 0, math.radians(-8.0)), mat=mat)
    
    # 2. Large ruined stone cube in front-right
    create_block("Ruin_Cube_Front", (0.72, 0.72, 0.65), (0.75, -2.85, 0.33), rot=(math.radians(5.0), math.radians(8.0), math.radians(24.0)), mat=mat)
    
    # 3. Small loose rubble stones
    rubble_data = [
        (-0.2, -2.5, 0.08, 0.22, 0.20, 0.14, 15.0),
        (0.2, -3.4, 0.07, 0.28, 0.24, 0.12, -30.0),
        (1.4, -2.6, 0.06, 0.18, 0.18, 0.10, 45.0),
        (2.8, -1.8, 0.07, 0.25, 0.20, 0.12, 12.0),
        (3.2, -2.9, 0.06, 0.22, 0.16, 0.10, -15.0),
        (-3.0, -1.2, 0.08, 0.30, 0.22, 0.14, 60.0),
        (-2.2, 2.2, 0.07, 0.24, 0.18, 0.12, -45.0),
        (-0.8, 2.9, 0.06, 0.20, 0.18, 0.10, 20.0),
        (3.0, 1.2, 0.08, 0.26, 0.22, 0.14, -10.0),
        (4.5, -0.4, 0.07, 0.22, 0.18, 0.12, 35.0),
    ]
    for idx, (rx, ry, rz, sx, sy, sz, rrot) in enumerate(rubble_data):
        create_block(f"Rubble_Stone_{idx}", (sx, sy, sz), (rx, ry, rz), rot=(0, 0, math.radians(rrot)), mat=mat)

def setup_camera_and_lighting():
    # 1. World Lighting (Clay Ambient)
    world = bpy.data.worlds.new("World_ClayRuins")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg_node = world.node_tree.nodes.get("Background")
    if bg_node:
        bg_node.inputs['Color'].default_value = (0.75, 0.77, 0.82, 1.0)
        bg_node.inputs['Strength'].default_value = 0.55
        
    # 2. Main Sun Light (Crisp directional contact shadows matching reference)
    sun_data = bpy.data.lights.new(name="SunLight", type='SUN')
    sun_data.energy = 3.8
    sun_data.color = (1.0, 0.99, 0.96)
    sun_data.angle = math.radians(0.5) # Crisp shadows
    sun_obj = bpy.data.objects.new(name="Sun_Directional", object_data=sun_data)
    bpy.context.collection.objects.link(sun_obj)
    
    # Sun angle: coming from top-left, casting shadows towards bottom-right
    sun_obj.rotation_euler = Euler((math.radians(52.0), math.radians(12.0), math.radians(-42.0)), 'XYZ')
    
    # 3. Orthographic Isometric Camera
    cam_data = bpy.data.cameras.new(name="IsoCamera")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 16.5
    cam_data.clip_start = 0.1
    cam_data.clip_end = 200.0
    
    cam_obj = bpy.data.objects.new(name="Camera_Isometric", object_data=cam_data)
    bpy.context.collection.objects.link(cam_obj)
    bpy.context.scene.camera = cam_obj
    
    # Position camera in standard isometric view
    # Elevation: ~33.5 degrees, Yaw: ~-38 degrees, targeting center (0, 0, 0.4)
    cam_dist = 40.0
    elev = math.radians(33.0)
    azim = math.radians(-38.0)
    
    cx = cam_dist * math.cos(elev) * math.sin(azim)
    cy = -cam_dist * math.cos(elev) * math.cos(azim)
    cz = cam_dist * math.sin(elev) + 0.4
    
    cam_obj.location = Vector((cx, cy, cz))
    
    # Point at target (0, 0, 0.4)
    target = Vector((0.0, 0.0, 0.4))
    direction = target - cam_obj.location
    rot_quat = direction.to_track_quat('-Z', 'Y')
    cam_obj.rotation_euler = rot_quat.to_euler()

def configure_render(out_path):
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 64
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1920
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 100
    scene.render.filepath = out_path

def main():
    print("Iniciando reproducao 3D da cena de ruinas no Blender 4.5...")
    clear_scene()
    
    mat_terrain, mat_ruins, mat_pool, mat_water = setup_materials()
    
    # 1. Undulating Terrain
    create_terrain(mat_terrain)
    
    # 2. Central Octagonal Basin
    create_octagonal_basin(mat_ruins, mat_pool)
    
    # 3. Central Fountain Chalice / Font
    create_fountain_pedestal_and_cup(mat_ruins)
    
    # 4. Fountain Water (Basin pool + Chalice pool)
    create_fountain_water(mat_water)
    
    # 4. Ring of Modular Ruined Columns
    # Column 1: Left-Front (medium height)
    build_modular_column(-3.3, -2.0, "medium", has_capital=False, rot_z=math.radians(12.0), mat=mat_ruins, seed=101)
    
    # Column 2: Far-Left (tall, with capital)
    build_modular_column(-4.3, 0.4, "tall", has_capital=True, rot_z=math.radians(-8.0), mat=mat_ruins, seed=102)
    
    # Column 3: Back-Left (very tall, prominent capital)
    build_modular_column(-2.7, 3.2, "tall", has_capital=True, rot_z=math.radians(15.0), mat=mat_ruins, seed=103)
    
    # Column 4: Right-Mid (tall, with capital)
    build_modular_column(3.6, 0.3, "tall", has_capital=True, rot_z=math.radians(-14.0), mat=mat_ruins, seed=104)
    
    # Column 5: Front-Right stump
    build_modular_column(2.1, -2.6, "stump", has_capital=False, rot_z=math.radians(25.0), mat=mat_ruins, seed=105)
    
    # Column 6: Front-Center stump
    build_modular_column(-0.9, -3.2, "stump", has_capital=False, rot_z=math.radians(-10.0), mat=mat_ruins, seed=106)
    
    # 5. Ruined Gateway Portal on the Right
    create_ruined_gateway(4.8, 1.4, mat_ruins)
    
    # 6. Toppled Column Pile in Back-Right
    create_toppled_column_pile(2.3, 2.4, mat_ruins)
    
    # 7. Environment Props (Pavers, Rubble, Fallen Cubes)
    create_environment_props(mat_ruins)
    
    # 8. Camera and Lighting
    setup_camera_and_lighting()
    
    # 9. Save .blend file
    blend_path = r"c:\Users\jlyra\Documents\eden_project\cenarios_hd_pixelart_3d\blender\ruinas_fonte.blend"
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    print(f"Arquivo Blender salvo com sucesso em: {blend_path}")
    
    # 10. Export .glb
    glb_path = r"c:\Users\jlyra\Documents\eden_project\cenarios_hd_pixelart_3d\blender\ruinas_fonte.glb"
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format='GLB')
    print(f"Arquivo GLB exportado com sucesso em: {glb_path}")
    
    # 11. Render preview image
    render_path = r"c:\Users\jlyra\Documents\eden_project\cenarios_hd_pixelart_3d\blender\ruinas_fonte_render.png"
    configure_render(render_path)
    bpy.ops.render.render(write_still=True)
    print(f"Renderizacao concluida e salva em: {render_path}")

if __name__ == "__main__":
    main()
