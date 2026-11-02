@tool
extends Node3D

## Loader do Kit de Bioma de Floresta Tropical (David Holland Architecture)
@export_file("*.glb") var glb_path: String = "res://kit_bioma_floresta.glb"

const SHADER_SURFACE = preload("res://pixel_surface.gdshader")
const SHADER_WATER = preload("res://pixel_water.gdshader")

func _ready() -> void:
	for child in get_children():
		child.queue_free()
		
	var scene_res = load(glb_path) as PackedScene
	if not scene_res:
		push_error("Falha ao carregar " + glb_path)
		return
		
	var instance = scene_res.instantiate()
	add_child(instance)
	setup_materials(instance)

func setup_materials(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			var m_name: String = child.name
			
			if m_name.begins_with("Water_"):
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_WATER
				mat.set_shader_parameter("pixel_grid_density", 52.0)
				mat.set_shader_parameter("wave_speed", 1.8)
				mat.set_shader_parameter("wave_height", 0.02)
				mat.set_shader_parameter("reflection_strength", 0.40)
				
				if "Igarape" in m_name:
					# 1. Água Preta (Chá Mate / Ácidos Húmicos)
					mat.set_shader_parameter("shallow_color", Color(0.38, 0.24, 0.11, 0.75))
					mat.set_shader_parameter("deep_color", Color(0.11, 0.06, 0.04, 0.96))
					mat.set_shader_parameter("depth_fade_distance", 0.55)
					mat.set_shader_parameter("shoreline_foam_dist", 0.22)
				elif "Barrenta" in m_name:
					# 2. Água Barrenta (Várzea / Sedimentos / Maré)
					mat.set_shader_parameter("shallow_color", Color(0.62, 0.47, 0.31, 0.90))
					mat.set_shader_parameter("deep_color", Color(0.38, 0.26, 0.16, 0.98))
					mat.set_shader_parameter("depth_fade_distance", 0.22)
					mat.set_shader_parameter("shoreline_foam_dist", 0.32)
				elif "Turquesa" in m_name:
					# 3. Água Turquesa (Calcário / Lagoa de Mineração / Clearwater)
					mat.set_shader_parameter("shallow_color", Color(0.18, 0.82, 0.78, 0.65))
					mat.set_shader_parameter("deep_color", Color(0.05, 0.38, 0.48, 0.90))
					mat.set_shader_parameter("depth_fade_distance", 1.20)
					mat.set_shader_parameter("shoreline_foam_dist", 0.28)
					
				child.material_override = mat
				
			else:
				# Todos os solos, piçarra, areia e rochas
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_SURFACE
				mat.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
				mat.set_shader_parameter("shadow_tint", Color(0.15, 0.12, 0.28, 1.0))
				mat.set_shader_parameter("light_bands", 3)
				mat.set_shader_parameter("dither_spread", 0.0)
				child.material_override = mat

		if child.get_child_count() > 0:
			setup_materials(child)
