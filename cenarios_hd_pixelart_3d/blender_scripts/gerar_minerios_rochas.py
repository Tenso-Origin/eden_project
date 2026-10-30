"""
Gerador de Rochas com Veios de Minério e Cristais Salientes para Blender MCP
Regra: regras_de_minerios_e_rochas_blender_mcp.md
"""
import bpy
import bmesh
import random
from mathutils import Vector

def create_pixel_art_ore_node(name="Iron_Ore_Block", ore_color=(0.85, 0.55, 0.25), crystal_mode=False):
    # Limpa caso já exista
    if name in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
        
    bm = bmesh.new()
    # 1. Cria a rocha-mãe facetada dentro de 1x1x1m
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=0.48)
    
    # Deforma e achata planos usando cortes (Bisect) para criar quinas vivas
    random.seed(42)
    for _ in range(8):
        plane_no = Vector((random.uniform(-1,1), random.uniform(-1,1), random.uniform(-0.2, 1))).normalized()
        plane_co = plane_no * random.uniform(0.32, 0.45)
        bmesh.ops.bisect_plane(bm, geom=bm.verts[:]+bm.edges[:]+bm.faces[:], 
                               plane_co=plane_co, plane_no=plane_no, clear_outer=True)
        # Fecha os buracos dos cortes com faces planas (Hard Edges!)
        bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary])

    # Move para assentar perfeitamente em Z=0
    for v in bm.verts:
        v.co.z += 0.35
        if v.co.z < 0.0:
            v.co.z = 0.0
            
    # Garante indexação de Material (0 = Rocha, 1 = Minério)
    for f in bm.faces:
        f.material_index = 0
        f.smooth = False

    # 2. Gera Cristais/Pepitas saltados para fora da rocha
    for _ in range(random.randint(5, 9)):
        nugget_verts = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.11)["verts"]
        dir_vec = Vector((random.uniform(-1,1), random.uniform(-1,1), random.uniform(0.2, 1.0))).normalized()
        pos_offset = dir_vec * 0.32 + Vector((0, 0, 0.35))
        
        for v in nugget_verts:
            if crystal_mode:
                v.co.z *= 2.2 # Alonga em formato de cristal
            v.co += pos_offset
            
        for f in bm.faces:
            if all(v in nugget_verts for v in f.verts):
                f.material_index = 1
                f.smooth = False

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    
    # 3. Pigmentação Automática por Normal de Face (AlbedoCol)
    col_attr = mesh.color_attributes.new(name="AlbedoCol", type='BYTE_COLOR', domain='CORNER')
    mesh.color_attributes.default_color_attribute = "AlbedoCol"
    
    rock_top = Vector((0.48, 0.50, 0.55))
    rock_side = Vector((0.32, 0.33, 0.38))
    rock_bot = Vector((0.18, 0.18, 0.24))
    ore_vec = Vector(ore_color)
    
    for poly in mesh.polygons:
        poly.use_smooth = False
        if poly.material_index == 0:
            if poly.normal.z > 0.45:
                c = rock_top
            elif poly.normal.z > -0.2:
                c = rock_side
            else:
                c = rock_bot
        else:
            bright = 1.15 if poly.normal.z > 0.3 else 0.85
            c = ore_vec * bright
            
        for loop_idx in poly.loop_indices:
            col_attr.data[loop_idx].color = (min(c.x, 1.0), min(c.y, 1.0), min(c.z, 1.0), 1.0)
            
    return obj

if __name__ == "__main__":
    create_pixel_art_ore_node("Gold_Ore_Block", ore_color=(0.95, 0.75, 0.15))

