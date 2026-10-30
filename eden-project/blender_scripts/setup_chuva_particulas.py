"""
Baking de Exposição à Chuva e Gerador de Malhas de Partículas de Chuva para Blender MCP
Regra: regras_de_chuva_e_efeitos_climaticos_blender_mcp_godot.md
"""
import bpy
import bmesh

def bake_rain_exposure_on_object(obj):
    """Calcula exposição à chuva (topo vs áreas abrigadas) e grava em WeatherData.a"""
    if obj.type != 'MESH':
        return
    mesh = obj.data
    
    if "WeatherData" not in mesh.color_attributes:
        mesh.color_attributes.new(name="WeatherData", type='BYTE_COLOR', domain='CORNER')
        
    weather_layer = mesh.color_attributes["WeatherData"].data
    
    for poly in mesh.polygons:
        # No Blender, +Z é para cima.
        up_dot = poly.normal.z
        if up_dot > 0.65:
            rain_mask = 1.0 # Face voltada para o céu (recebe anéis de impacto e poças)
        elif up_dot > -0.15:
            rain_mask = 0.5 # Face lateral (recebe escorrimento vertical)
        else:
            rain_mask = 0.0 # Face voltada para baixo / abrigada (seca)
            
        for loop_idx in poly.loop_indices:
            old_col = weather_layer[loop_idx].color
            weather_layer[loop_idx].color = (old_col[0], old_col[1], old_col[2], rain_mask)

def create_rain_particle_meshes():
    """Cria as malhas 3D de Gota (Streak) e Coroa de Respingo (Splash) em escala 1x1x1m"""
    # 1. Gota Alongada 3D (Rain Streak)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=3, radius1=0.015, radius2=0.002, depth=0.45)
    mesh_streak = bpy.data.meshes.new("FX_RainStreak_Mesh")
    bm.to_mesh(mesh_streak)
    bm.free()
    obj_streak = bpy.data.objects.new("FX_RainStreak", mesh_streak)
    bpy.context.collection.objects.link(obj_streak)
    
    # 2. Coroa de Respingo 3D (Splash Crown para Pixel Art)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=4, radius1=0.02, radius2=0.09, depth=0.07)
    for f in bm.faces:
        f.smooth = False
    mesh_splash = bpy.data.meshes.new("FX_RainSplash_Mesh")
    bm.to_mesh(mesh_splash)
    bm.free()
    obj_splash = bpy.data.objects.new("FX_RainSplash", mesh_splash)
    obj_splash.location.x = 0.5
    bpy.context.collection.objects.link(obj_splash)
    return obj_streak, obj_splash

if __name__ == "__main__":
    create_rain_particle_meshes()

