"""
Gerador de Canal de Água Modular 1x1x1m com FlowData para Blender MCP
Regra: regras_de_agua_ondulacoes_e_reflexos_espelhados_blender_mcp_godot.md
"""
import bpy
import bmesh
from mathutils import Vector

def create_water_tile_1x1m(name="Water_Channel_Tile", flow_dir=(1.0, 0.0), has_rocks=True):
    """Cria um bloco modular 1x1x1m com Leito Rochoso + Lâmina d'Água subdividida com FlowData"""
    if f"{name}_Bed" in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[f"{name}_Bed"], do_unlink=True)
    if f"{name}_Surface" in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[f"{name}_Surface"], do_unlink=True)

    # 1. Cria o Leito do Rio (Fundo côncavo para gerar gradiente de profundidade real)
    bm_bed = bmesh.new()
    bmesh.ops.create_cube(bm_bed, size=1.0)
    for v in bm_bed.verts:
        v.co.z += 0.5
    bmesh.ops.subdivide_edges(bm_bed, edges=bm_bed.edges[:], cuts=5, use_grid_fill=True)
    bmesh.ops.triangulate(bm_bed, faces=bm_bed.faces[:])
    
    for v in bm_bed.verts:
        if v.co.z > 0.99:
            # Escava o interior do tile mantendo as bordas controladas
            dist_center = Vector((v.co.x, v.co.y)).length
            v.co.z = 0.25 + min(0.65, dist_center * 1.1)
            
    # Adiciona pedras submersas que vão ativar os anéis de espuma (ripples) no Godot
    if has_rocks:
        rock_verts = bmesh.ops.create_icosphere(bm_bed, subdivisions=1, radius=0.18)["verts"]
        for v in rock_verts:
            v.co += Vector((0.1, -0.05, 0.78)) # Ponta da pedra passa de Z=0.85 (emerge da água!)
            
    for f in bm_bed.faces:
        f.smooth = False
        
    mesh_bed = bpy.data.meshes.new(f"{name}_Bed")
    bm_bed.to_mesh(mesh_bed)
    bm_bed.free()
    obj_bed = bpy.data.objects.new(f"{name}_Bed", mesh_bed)
    bpy.context.collection.objects.link(obj_bed)
    
    # 2. Cria a Lâmina d'Água em Z = 0.85m (Subdividida 12x12 para ondas de vértice)
    bm_water = bmesh.new()
    bmesh.ops.create_grid(bm_water, x_segments=12, y_segments=12, size=0.5)
    for v in bm_water.verts:
        v.co.z = 0.85
    for f in bm_water.faces:
        f.smooth = False
        
    mesh_water = bpy.data.meshes.new(f"{name}_Surface")
    bm_water.to_mesh(mesh_water)
    bm_water.free()
    obj_water = bpy.data.objects.new(f"{name}_Surface", mesh_water)
    obj_water.parent = obj_bed
    bpy.context.collection.objects.link(obj_water)
    
    # 3. Grava FlowData nos vértices da água
    flow_attr = mesh_water.color_attributes.new(name="FlowData", type='BYTE_COLOR', domain='CORNER')
    mesh_water.color_attributes.default_color_attribute = "FlowData"
    r_flow = flow_dir[0] * 0.5 + 0.5
    g_flow = flow_dir[1] * 0.5 + 0.5
    for loop_idx in range(len(mesh_water.loops)):
        flow_attr.data[loop_idx].color = (r_flow, g_flow, 0.0, 1.0)
        
    return obj_bed, obj_water

if __name__ == "__main__":
    create_water_tile_1x1m()
