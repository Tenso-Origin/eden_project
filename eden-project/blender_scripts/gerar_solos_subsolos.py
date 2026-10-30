"""
Gerador de Blocos Modulares de Solo e Subsolo 1x1x1m para Blender MCP
Regra: regras_de_solos_e_subsolos_blender_mcp.md
"""
import bpy
import bmesh
import random
from mathutils import Vector

def create_stratified_soil_tile(name="Soil_Grass_Block_1m", has_grass_cap=True):
    if name in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
        
    bm = bmesh.new()
    # Cria cubo 1x1x1m e move para Z [0.0, 1.0]
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.z += 0.5
        
    # Subdivide para criar estratos no subsolo e relevo no topo
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=4, use_grid_fill=True)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    
    random.seed(101)
    for v in bm.verts:
        is_border_x = abs(abs(v.co.x) - 0.5) < 0.001
        is_border_y = abs(abs(v.co.y) - 0.5) < 0.001
        is_top = abs(v.co.z - 1.0) < 0.001
        
        # 1. Mantém bordas do topo perfeitamente alinhadas em Z=1.0 (Seamless Tile!)
        if is_top and not (is_border_x or is_border_y):
            v.co.z += random.uniform(-0.04, 0.04)
            
        # 2. Cria saliência da capa de grama (Overhang) nas laterais superiores
        if has_grass_cap and (0.72 < v.co.z < 0.99) and (is_border_x or is_border_y):
            if is_border_x:
                v.co.x += 0.035 if v.co.x > 0 else -0.035
            if is_border_y:
                v.co.y += 0.035 if v.co.y > 0 else -0.035

    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    
    # 3. Pigmentação Estratificada por Altura Z e Normal (AlbedoCol)
    col_attr = mesh.color_attributes.new(name="AlbedoCol", type='BYTE_COLOR', domain='CORNER')
    mesh.color_attributes.default_color_attribute = "AlbedoCol"
    
    col_grass = Vector((0.30, 0.62, 0.24))
    col_topsoil = Vector((0.36, 0.24, 0.15))
    col_subsoil = Vector((0.28, 0.17, 0.11))
    col_deep_clay = Vector((0.20, 0.14, 0.12))
    
    for poly in mesh.polygons:
        poly.use_smooth = False # Shade Flat obrigatório para HD Pixel Art!
        center_z = poly.center.z
        
        jitter = random.uniform(0.93, 1.07)
        if has_grass_cap and (poly.normal.z > 0.65 or center_z > 0.78):
            c = col_grass * jitter
        elif center_z > 0.55:
            c = col_topsoil * jitter
        elif center_z > 0.25:
            c = col_subsoil * jitter
        else:
            c = col_deep_clay * jitter
            
        for loop_idx in poly.loop_indices:
            col_attr.data[loop_idx].color = (min(c.x, 1.0), min(c.y, 1.0), min(c.z, 1.0), 1.0)
            
    return obj

if __name__ == "__main__":
    create_stratified_soil_tile()

