"""
Configurador de Normais e Atributos de Vegetação/Vento/Chuva para Blender MCP
Regra: regras_de_vegetacao_e_folhagem_blender_mcp.md
"""
import bpy
from mathutils import Vector
import random

def setup_foliage_attributes_and_normals(obj, is_grass=False, canopy_center=Vector((0,0,1.0))):
    mesh = obj.data
    
    # 1. Garante atributos de Cor (Pigmentação) e Clima (Vento/Chuva)
    if "AlbedoCol" not in mesh.color_attributes:
        mesh.color_attributes.new(name="AlbedoCol", type='BYTE_COLOR', domain='CORNER')
    if "WeatherData" not in mesh.color_attributes:
        mesh.color_attributes.new(name="WeatherData", type='BYTE_COLOR', domain='CORNER')
        
    albedo_layer = mesh.color_attributes["AlbedoCol"].data
    weather_layer = mesh.color_attributes["WeatherData"].data
    mesh.color_attributes.default_color_attribute = "AlbedoCol"
    
    # Encontra limites Z para normalizar a altura
    z_coords = [v.co.z for v in mesh.vertices]
    min_z, max_z = min(z_coords), max(z_coords)
    height_span = max(max_z - min_z, 0.001)
    
    # Cores base (Estilo Pixel Art Vibrante)
    col_bottom = Vector((0.12, 0.32, 0.18)) # Verde sombra profundo
    col_top = Vector((0.45, 0.78, 0.25))    # Verde luz solar
    
    custom_normals = []
    
    for poly in mesh.polygons:
        island_phase = random.uniform(0.0, 1.0)
        for loop_idx in poly.loop_indices:
            loop = mesh.loops[loop_idx]
            v = mesh.vertices[loop.vertex_index]
            
            # Fator de altura (0 na base, 1 no topo)
            h_factor = max(0.0, min(1.0, (v.co.z - min_z) / height_span))
            # Fator radial (distância do eixo central X/Y)
            r_factor = min(1.0, Vector((v.co.x, v.co.y)).length / 0.5)
            
            # Pigmentação Procedural (Gradiente + variação sutil por face)
            c = col_bottom.lerp(col_top, h_factor)
            albedo_layer[loop_idx].color = (c.x, c.y, c.z, 1.0)
            
            # Dados de Vento e Chuva: R=PesoVento, G=FlutterPonta, B=Fase, A=ExposiçãoChuva
            rain_exposure = 1.0 if poly.normal.z > 0.1 else 0.25
            weather_layer[loop_idx].color = (h_factor, r_factor, island_phase, rain_exposure)
            
            # Cálculo de Normais para HD Pixel Art
            if is_grass:
                custom_normals.append(Vector((0.0, 0.0, 1.0)))
            else:
                n = (v.co - canopy_center).normalized()
                custom_normals.append(n)
                
    # Aplica normais customizadas
    mesh.normals_split_custom_set(custom_normals)

