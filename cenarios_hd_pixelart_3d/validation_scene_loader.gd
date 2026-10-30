@tool
extends Node3D

## Carregador e Configurador da Cena de Validação HD Pixel Art 3D
## Carrega cenario_validacao.glb e atribui automaticamente os shaders customizados:
## - Soil_Block: pixel_surface.gdshader
## - Riverbed: pixel_surface.gdshader
## - Rock_Submerged: pixel_surface.gdshader
## - Ore_Crystals: pixel_metal_mirror.gdshader
## - Grass_Tuft: pixel_foliage.gdshader (com balanço de vento)
## - Water_Surface: pixel_water.gdshader (com ondas e espuma de profundidade)

const GLB_PATH = "res://cenario_validacao.glb"
const SHADER_SURFACE = preload("res://pixel_surface.gdshader")
const SHADER_FOLIAGE = preload("res://pixel_foliage.gdshader")
const SHADER_WATER = preload("res://pixel_water.gdshader")
const SHADER_METAL = preload("res://pixel_metal_mirror.gdshader")

func _ready() -> void:
	# Limpa filhos anteriores se existirem
	for child in get_children():
		child.queue_free()
		
	var scene_res = load(GLB_PATH) as PackedScene
	if not scene_res:
		push_error("Falha ao carregar " + GLB_PATH)
		return
		
	var instance = scene_res.instantiate()
	add_child(instance)
	
	setup_materials(instance)

func setup_materials(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			var mesh_name = child.name
			match mesh_name:
				"Soil_Block":
					var mat := ShaderMaterial.new()
					mat.shader = SHADER_SURFACE
					mat.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
					mat.set_shader_parameter("shadow_tint", Color(0.15, 0.12, 0.28, 1.0))
					mat.set_shader_parameter("light_bands", 3)
					mat.set_shader_parameter("dither_spread", 0.12)
					child.material_override = mat
					
				"Riverbed":
					var mat := ShaderMaterial.new()
					mat.shader = SHADER_SURFACE
					mat.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
					mat.set_shader_parameter("shadow_tint", Color(0.12, 0.10, 0.24, 1.0))
					mat.set_shader_parameter("light_bands", 3)
					mat.set_shader_parameter("dither_spread", 0.12)
					child.material_override = mat
					
				"Rock_Submerged":
					var mat := ShaderMaterial.new()
					mat.shader = SHADER_SURFACE
					mat.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
					mat.set_shader_parameter("shadow_tint", Color(0.16, 0.13, 0.26, 1.0))
					mat.set_shader_parameter("light_bands", 3)
					mat.set_shader_parameter("dither_spread", 0.12)
					child.material_override = mat
					
				"Ore_Crystals":
					var mat := ShaderMaterial.new()
					mat.shader = SHADER_METAL
					mat.set_shader_parameter("metal_base_color", Color(0.9, 0.95, 1.0, 1.0))
					mat.set_shader_parameter("metal_dark_band", Color(0.20, 0.25, 0.40, 1.0))
					mat.set_shader_parameter("metal_highlight", Color(1.0, 0.98, 0.95, 1.0))
					mat.set_shader_parameter("mirror_reflectivity", 0.45)
					child.material_override = mat
					
				"Grass_Tuft":
					var mat := ShaderMaterial.new()
					mat.shader = SHADER_FOLIAGE
					mat.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
					mat.set_shader_parameter("shadow_tint", Color(0.12, 0.10, 0.24, 1.0))
					mat.set_shader_parameter("light_bands", 3)
					mat.set_shader_parameter("dither_spread", 0.12)
					mat.set_shader_parameter("wind_strength", 0.35)
					mat.set_shader_parameter("wind_speed", 2.5)
					child.material_override = mat
					
				"Water_Surface":
					var mat := ShaderMaterial.new()
					mat.shader = SHADER_WATER
					mat.set_shader_parameter("shallow_color", Color(0.20, 0.72, 0.78, 0.85))
					mat.set_shader_parameter("deep_color", Color(0.06, 0.24, 0.46, 0.95))
					mat.set_shader_parameter("foam_color", Color(0.96, 0.98, 1.0))
					mat.set_shader_parameter("depth_fade_distance", 0.6)
					mat.set_shader_parameter("pixel_grid_density", 32.0)
					mat.set_shader_parameter("wave_speed", 2.0)
					mat.set_shader_parameter("wave_height", 0.02)
					mat.set_shader_parameter("shoreline_foam_dist", 0.35)
					mat.set_shader_parameter("shoreline_ripple_rings", 3)
					mat.set_shader_parameter("reflection_strength", 0.35)
					child.material_override = mat
					
		if child.get_child_count() > 0:
			setup_materials(child)
