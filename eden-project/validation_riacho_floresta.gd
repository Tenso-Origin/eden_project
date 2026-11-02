@tool
extends Node3D

## Loader do Cenário de Teste: Riacho de Floresta Tropical (David Holland Architecture)
@export_file("*.glb") var glb_path: String = "res://riacho_floresta.glb"

const SHADER_SURFACE = preload("res://pixel_surface.gdshader")
const SHADER_WATER = preload("res://pixel_water.gdshader")

var water_node: MeshInstance3D = null

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
				water_node = child
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_WATER
				mat.set_shader_parameter("pixel_grid_density", 52.0)
				mat.set_shader_parameter("wave_speed", 1.8)
				mat.set_shader_parameter("wave_height", 0.02)
				mat.set_shader_parameter("reflection_strength", 0.42)
				mat.set_shader_parameter("reflection_distortion_px", 2.0)
				
				# Água de Igarapé (Tom Chá-Mate / Ácidos Húmicos)
				mat.set_shader_parameter("shallow_color", Color(0.38, 0.24, 0.11, 0.75))
				mat.set_shader_parameter("deep_color", Color(0.11, 0.06, 0.04, 0.96))
				mat.set_shader_parameter("depth_fade_distance", 0.55)
				mat.set_shader_parameter("shoreline_foam_dist", 0.22)
				mat.set_shader_parameter("foam_color", Color(1.0, 1.0, 1.0))
				mat.set_shader_parameter("wave_crest_foam_threshold", 0.88)
				
				child.material_override = mat
				
			else:
				# Terrenos, leito orgânico e rocha saliente
				var mat := ShaderMaterial.new()
				mat.shader = SHADER_SURFACE
				mat.set_shader_parameter("albedo_color", Color(1.0, 1.0, 1.0, 1.0))
				mat.set_shader_parameter("shadow_tint", Color(0.14, 0.11, 0.26, 1.0))
				mat.set_shader_parameter("light_bands", 3)
				mat.set_shader_parameter("dither_spread", 0.0)
				child.material_override = mat

		if child.get_child_count() > 0:
			setup_materials(child)

